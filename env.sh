export ZK_VERSION=3.4.9
export JDK_RPM= # HTTP path to JDK RPM
export JAVA_HOME=/usr/java/jdk1.8.0_91

export HOST_PREFIX=
export HOST_SUFFIX=

export PASSWORD=

export V2=2.7.0
export V3=3.0.0-alpha2-SNAPSHOT
export V2_GIT=release-2.7.0
export V3_GIT=trunk
export ROOT=/root
export HADOOP_2=${ROOT}/hadoop-${V2}
export HADOOP_3=${ROOT}/hadoop-${V3}


function one_cluster_env() {
  IFS=' ' read -r -a HOSTNAMES <<< $(echo ${HOST_PREFIX}{1..9}${HOST_SUFFIX})
  IFS=' ' read -r -a NAMENODES <<< $(echo ${HOST_PREFIX}{1..2}${HOST_SUFFIX})
  IFS=' ' read -r -a DATANODES <<< $(echo ${HOST_PREFIX}{4..9}${HOST_SUFFIX})
  IFS=' ' read -r -a JN_QUORUM <<< $(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  IFS=' ' read -r -a ZK_QUORUM <<< $(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  CONF=${ROOT}/conf
  export_cluster_env
}

function old_cluster_env() {
  IFS=' ' read -r -a HOSTNAMES <<< $(echo ${HOST_PREFIX}{1..9}${HOST_SUFFIX})
  IFS=' ' read -r -a NAMENODES <<< $(echo ${HOST_PREFIX}{1..2}${HOST_SUFFIX})
  IFS=' ' read -r -a DATANODES <<< $(echo ${HOST_PREFIX}{4..9}${HOST_SUFFIX})
  IFS=' ' read -r -a JN_QUORUM <<< $(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  IFS=' ' read -r -a ZK_QUORUM <<< $(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  CONF=${HADOOP_2}/etc/hadoop
  export_cluster_env
}

function new_cluster_env() {
  IFS=' ' read -r -a HOSTNAMES <<< $(echo ${HOST_PREFIX}{10..18}${HOST_SUFFIX})
  IFS=' ' read -r -a NAMENODES <<< $(echo ${HOST_PREFIX}{10..11}${HOST_SUFFIX})
  IFS=' ' read -r -a DATANODES <<< $(echo ${HOST_PREFIX}{13..18}${HOST_SUFFIX})
  IFS=' ' read -r -a JN_QUORUM <<< $(echo ${HOST_PREFIX}{10..12}${HOST_SUFFIX})
  IFS=' ' read -r -a ZK_QUORUM <<< $(echo ${HOST_PREFIX}{1..3}${HOST_SUFFIX})
  CONF=${HADOOP_3}/etc/hadoop
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

