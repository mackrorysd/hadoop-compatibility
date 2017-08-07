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
IFS=' ' read -r -a NAMENODES <<< "$(split ${2})"
IFS=' ' read -r -a DATANODES <<< "$(split ${3})"

log "Shutting down and upgrading RM2, starting it, then failing over to it..."

ssh -i ${ID_FILE} root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/yarn-daemon.sh stop resourcemanager

  sleep ${ARTIFICIAL_DELAY}

  cd ${HADOOP_3}
  bin/yarn --daemon start resourcemanager

  sleep ${ARTIFICIAL_DELAY}

" < /dev/null

log "Shutting down and upgrading RM1, and starting it..."

ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/yarn-daemon.sh stop resourcemanager

  sleep ${ARTIFICIAL_DELAY}

  cd ${HADOOP_3}
  bin/yarn --config ~/conf --daemon start resourcemanager

  sleep ${ARTIFICIAL_DELAY}

" < /dev/null

log "Shutting down and upgrading each NodeManager..."

for datanode in ${DATANODES[@]}; do
  ssh -i ${ID_FILE} root@${NAMENODES[0]} ". /tmp/env.sh
    cd ${HADOOP_2}
    sbin/yarn-daemon.sh stop nodemanager

    sleep ${ARTIFICIAL_DELAY}

    cd ${HADOOP_3}
    bin/yarn --config ~/conf --daemon start nodemanager

    sleep ${ARTIFICIAL_DELAY}

  " < /dev/null
done

