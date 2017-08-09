# Tested on an Ubuntu 16.04 host

if ! dpkg-query -l docker-ce; then
  sudo apt-get update

  sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  sudo apt-get update
  sudo apt-get install docker-ce
fi

while ! sudo service docker status; do
  sudo service docker start
  sleep 60
done

if [ "$(docker images apache:hadoop-dev | wc -l)" != "2" ]; then
  sudo apt-get install -y git
  tmp=$(mktemp -d)
  (
    cd ${tmp}
    git clone http://github.com/apache/hadoop.git
    cd hadoop/dev-support/docker
    docker build -t apache:hadoop-dev .
  )
  rm -rf ${tmp}
fi

ROOT_PASSWORD=apache
# ZooKeeper seems to have a problem if the hostname doesn't include a '.'
HOST_PREFIX=container-
HOST_SUFFIX=.docker
for i in {1..9}; do
  DOCKER_HASH[i]=$(docker run \
    --detach --interactive --tty \
    --hostname ${HOST_PREFIX}${i}${HOST_SUFFIX} \
    apache:hadoop-dev)
  DOCKER_IP[i]=$(docker exec \
    ${DOCKER_HASH[${i}]} ifconfig eth0 \
    | grep 'inet addr' | awk '{print $2'} | sed 's/.*://')
  echo "${DOCKER_IP[${i}]}    ${HOST_PREFIX}${i}${HOST_SUFFIX}" >> /etc/hosts
  for command in \
    "echo 'root:${ROOT_PASSWORD}' | chpasswd" \
    "apt-get install -y ssh" \
    "sed -i -e 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" \
    "service ssh start" \
  ; do
    docker exec ${DOCKER_HASH[${i}]} bash -c "${command}"
  done
done

HOSTS_FILE=$(cat /etc/hosts)

docker exec ${DOCKER_HASH[1]} bash -c "
apt-get install -y git
git clone http://github.com/mackrorysd/hadoop-compatibility.git
cd hadoop-compatibility
git checkout docker
cat > env.sh <<EOF
export ZK_VERSION=3.4.9
export JAVA_HOME=/usr/lib/jvm/java-8-oracle/jre
export PATH=\\\${JAVA_HOME}/bin:\\\${PATH}

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

