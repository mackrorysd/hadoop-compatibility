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

HADOOP_HOME=${1}
IFS=' ' read -r -a JN_QUORUM <<< "$(split ${2})"
IFS=' ' read -r -a NAMENODES <<< "$(split ${3})"

for hostname in ${JN_QUORUM[@]}; do
  ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
    cd ${HADOOP_HOME}
    sbin/hadoop-daemon.sh start journalnode
  " < /dev/null
done
sleep 60 # FIXME abitrary delay
ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_HOME}
  bin/hdfs namenode -format
  bin/hdfs zkfc -formatZK
  sbin/hadoop-daemon.sh start namenode
" < /dev/null
ssh -i ${ID_FILE} root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_HOME}
  bin/hdfs namenode -bootstrapStandby
" < /dev/null

