# Test on a CentOS 7.3 host

if ! rpm -q docker; then
  sudo yum install -y docker
fi

while ! sudo service docker status; do
  sudo service docker start
  sleep 60
done

ROOT_PASSWORD=apache
# ZooKeeper seems to have a problem if the hostname doesn't include a '.'
HOST_PREFIX=container-
HOST_SUFFIX=.docker
for i in {1..9}; do
  DOCKER_HASH[i]=$(docker run \
    --detach --interactive --tty \
    --hostname ${HOST_PREFIX}${i}${HOST_SUFFIX} \
    centos:6)
  DOCKER_IP[i]=$(docker exec \
    ${DOCKER_HASH[${i}]} ifconfig eth0 \
    | grep 'inet addr' | awk '{print $2'} | sed 's/.*://')
  echo "${DOCKER_IP[${i}]}    ${HOST_PREFIX}${i}${HOST_SUFFIX}" >> /etc/hosts
  for command in \
    "echo 'root:${ROOT_PASSWORD}' | chpasswd" \
    "yum install -y openssh-server openssh-clients" \
    "service sshd start" \
  ; do
    docker exec ${DOCKER_HASH[${i}]} bash -c "${command}"
  done
done

HOSTS_FILE=$(cat /etc/hosts)

docker exec ${DOCKER_HASH[1]} bash -c "
yum install -y git
git clone http://github.com/mackrorysd/hadoop-compatibility.git
cd hadoop-compatibility
cat > env.sh <<EOF
export ZK_VERSION=3.4.9
export MAVEN_TGZ= # HTTP path to Maven binary .tar.gz release
export PROTOC_RPM= # HTTP path to Protocol Buffers RPM
export JDK_RPM= # HTTP path to Java Development Kit RPM
export JAVA_HOME= # Path to Java as installed by RPM
PROTOC_PATH= # Path to protoc as installed by RPM
export PATH=\\\${PROTOC_PATH}:\\\${JAVA_HOME}/bin:\\\${PATH}

export HOST_PREFIX=${HOST_PREFIX}
export HOST_SUFFIX=${HOST_SUFFIX}

export PASSWORD=${ROOT_PASSWORD}
export ID_FILE=~/.ssh/id_rsa

export V2=2.8.0
export V3=3.0.0-beta1-SNAPSHOT
export V2_GIT=branch-2.8.0
export V3_GIT=trunk
export ROOT=/root
export HADOOP_2=\\\${ROOT}/hadoop-\\\${V2}
export HADOOP_3=\\\${ROOT}/hadoop-\\\${V3}

export ARTIFICIAL_DELAY=1 # increase later

export PLATFORM=docker

function one_cluster_env() {
  IFS=' ' read -r -a HOSTNAMES <<< \\\$(echo ${HOST_PREFIX}{1..9}${HOST_SUFFIX})
  IFS=' ' read -r -a NAMENODES <<< \\\$(echo ${HOST_PREFIX}{1..2}${HOST_SUFFIX})
  IFS=' ' read -r -a DATANODES <<< \\\$(echo ${HOST_PREFIX}{4..9}${HOST_SUFFIX})
  IFS=' ' read -r -a JN_QUORUM <<< \\\$(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  IFS=' ' read -r -a ZK_QUORUM <<< \\\$(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  CONF=\\\${ROOT}/conf
  export_cluster_env
}

function export_cluster_env() {
  export HOSTNAMES
  export NAMENODES
  export DATANODES
  export JN_QUORUM
  export ZK_QUORUM
  export CONF
}
EOF

cat > /etc/hosts <<EOF
${HOSTS_FILE}
EOF
./rolling-upgrade-test.sh
"

for hash in ${DOCKER_HASH[@]}; do
    docker rm --force ${hash}
done
for ip in ${DOCKER_IP[@]}; do
  sed -i -e "/${ip}    /d" /etc/hosts
done

