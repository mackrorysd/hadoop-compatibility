#!/usr/bin/env bash

source scripts/functions.sh

set -v
set -x

HADOOP_HOME=${1}
IFS=' ' read -r -a JN_QUORUM <<< "$(split ${2})"
IFS=' ' read -r -a NAMENODES <<< "$(split ${3})"

for hostname in ${JN_QUORUM[@]}; do
  ssh root@${hostname} ". /tmp/env.sh
    cd ${HADOOP_HOME}
    sbin/hadoop-daemon.sh start journalnode
  " < /dev/null
done
sleep 60 # FIXME abitrary delay
ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_HOME}
  bin/hdfs namenode -format
  bin/hdfs zkfc -formatZK
  sbin/hadoop-daemon.sh start namenode
" < /dev/null
ssh root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_HOME}
  bin/hdfs namenode -bootstrapStandby
" < /dev/null

