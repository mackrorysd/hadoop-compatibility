#!/usr/bin/env bash

# Copyright 2017 Sean Mackrory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source scripts/functions.sh

set -v
set -x

IFS=' ' read -r -a HOSTNAMES <<< "$(split ${1})"
IFS=' ' read -r -a JN_QUORUM <<< "$(split ${2})"
IFS=' ' read -r -a NAMENODES <<< "$(split ${3})"
IFS=' ' read -r -a DATANODES <<< "$(split ${4})"

# Ensure NN1 is active and begin prepare for rolling upgrade
ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  bin/hdfs haadmin -failover nn2 nn1
  bin/hdfs dfsadmin -rollingUpgrade prepare
  while ! bin/hdfs dfsadmin -rollingUpgrade query | grep 'Proceed with rolling upgrade'; do
    echo 'Sleeping for 1 minute...'
    sleep 60
  done
" < /dev/null

# Shutdown and upgrade NN2, start it, then fail over to it
ssh root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/hadoop-daemon.sh stop namenode
  cd ${HADOOP_3}
  sbin/hadoop-daemon.sh start namenode -rollingUpgrade started
  while ! bin/hdfs haadmin -failover nn1 nn2; do
    echo 'Sleeping for 1 minute...'
    sleep 60
  done
" < /dev/null

# Shutdown and upgrade NN1, and start it
ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/hadoop-daemon.sh stop namenode
  cd ${HADOOP_3}
  sbin/hadoop-daemon.sh start namenode -rollingUpgrade started
" < /dev/null

# Shutdown and upgrade each DN
for datanode in ${DATANODES[@]}; do
  ssh root@${NAMENODES[0]} ". /tmp/env.sh
    cd ${HADOOP_2}
    bin/hdfs dfsadmin -shutdownDatanode ${datanode}:50020 upgrade
    while bin/hdfs dfsadmin -getDatanodeInfo ${datanode}:50020; do
      echo 'Sleeping for 1 minute...'
      sleep 60
    done
  " < /dev/null
  ssh root@${datanode} ". /tmp/env.sh
    cd ${HADOOP_3}
    sbin/hadoop-daemon.sh start datanode
  " < /dev/null
done

ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_3}
  bin/hdfs dfsadmin -rollingUpgrade finalize
" < /dev/null

# Upgrade JournalNodes 1 at a time
# Note that documentation does not currently specify how JournalNodes should be update
for hostname in ${JN_QUORUM[@]}; do
  ssh root@${hostname} ". /tmp/env.sh
    cd ${HADOOP_2}
    sbin/hadoop-daemon.sh stop journalnode
    cd ${HADOOP_3}
    sbin/hadoop-daemon.sh start journalnode
    echo 'Sleeping for 3 minutes...'
    sleep 180
  " < /dev/null
done

