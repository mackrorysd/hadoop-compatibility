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

set -e
set -v
set -x

IFS=' ' read -r -a HOSTNAMES <<< "$(split ${1})"
IFS=' ' read -r -a JN_QUORUM <<< "$(split ${2})"
IFS=' ' read -r -a NAMENODES <<< "$(split ${3})"
IFS=' ' read -r -a DATANODES <<< "$(split ${4})"

log "Ensuring NN1 is active and begin prepare for rolling upgrade..."

ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  bin/hdfs haadmin -failover nn2 nn1
  bin/hdfs dfsadmin -rollingUpgrade prepare
  while ! bin/hdfs dfsadmin -rollingUpgrade query | grep 'Proceed with rolling upgrade'; do
    echo 'Sleeping for 1 minute...'
    sleep 60
  done
" < /dev/null

log "Shutting down and upgrading NN2, starting it, then failing over to it..."

ssh -i ${ID_FILE} root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/hadoop-daemon.sh stop namenode

  sleep ${ARTIFICIAL_DELAY}

  cd ${HADOOP_3}
  sbin/hadoop-daemon.sh start namenode -rollingUpgrade started
  while ! bin/hdfs haadmin -failover nn1 nn2; do
    echo 'Sleeping for 1 minute...'
    sleep 60
  done

  sleep ${ARTIFICIAL_DELAY}

" < /dev/null

log "Shutting down and upgrading NN1, then starting it"

ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/hadoop-daemon.sh stop namenode

  sleep ${ARTIFICIAL_DELAY}

  cd ${HADOOP_3}
  bin/hdfs --daemon start namenode -rollingUpgrade started

  sleep ${ARTIFICIAL_DELAY}

" < /dev/null

log "Shutting down and upgrading each DN..."

for datanode in ${DATANODES[@]}; do
  ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
    cd ${HADOOP_2}
    bin/hdfs dfsadmin -shutdownDatanode ${datanode}:50020 upgrade
    while bin/hdfs dfsadmin -getDatanodeInfo ${datanode}:50020; do
      echo 'Sleeping for 1 minute...'
      sleep 60
    done

    sleep ${ARTIFICIAL_DELAY}

  " < /dev/null
  ssh -i ${ID_FILE} root@${datanode} ". /tmp/env.sh
    cd ${HADOOP_3}
    bin/hdfs --daemon start datanode

    sleep ${ARTIFICIAL_DELAY}

  " < /dev/null
done

log "Upgrading JournalNodes 1 at a time..."

# Note that documentation does not currently specify how JournalNodes should be update
for hostname in ${JN_QUORUM[@]}; do
  ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
    cd ${HADOOP_2}
    sbin/hadoop-daemon.sh stop journalnode

    sleep ${ARTIFICIAL_DELAY}

    cd ${HADOOP_3}
    bin/hdfs --daemon start journalnode
    echo 'Sleeping for 3 minutes...'
    sleep 180

    sleep ${ARTIFICIAL_DELAY}

  " < /dev/null
done

log "Upgrading Fail-over Controllers 1 at a time..."

for hostname in ${NAMENODES[@]}; do
  ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
    cd ${HADOOP_2}
    sbin/hadoop-daemon.sh stop zkfc

    sleep ${ARTIFICIAL_DELAY}

    cd ${HADOOP_3}
    bin/hdfs --daemon start zkfc
    echo 'Sleeping for 3 minutes...'
    sleep 180

    sleep ${ARTIFICIAL_DELAY}

  " < /dev/null
done

log "Finalizing rolling upgrade..."

ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_3}
  bin/hdfs dfsadmin -rollingUpgrade finalize

  sleep ${ARTIFICIAL_DELAY}

" < /dev/null

