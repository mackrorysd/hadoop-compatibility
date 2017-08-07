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

function join() {
  local IFS=";"
  echo "$*"
}

function split {
  echo "${1//;/ }"
}

function ssh_run() {
  # Not used: fails with "unexpected end of file"
  HOSTNAME=${1}
  COMMANDS=${2}
  ssh -i ${ID_FILE} -o StrictHostKeyChecking=no root@${HOSTNAME} ". /tmp/env.sh
  ${COMMANDS}" < /dev/null
}

# Check currently running HDFS processes
function check_hdfs_daemons() {
  for hostname in ${HOSTNAMES[@]}; do
    ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
      ps -e -o cmd | egrep '(Name|Journal|Data)Node'
    " < /dev/null
  done
}

function check_yarn_daemons() {
  for hostname in ${HOSTNAMES[@]}; do
    ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
      ps -e -o cmd | egrep '(Resource|Node)Manager'
    " < /dev/null
  done
}

function log() {
  message=${1}
  echo "HADOOP-COMPATIBILITY $(date) ${message}"
}

function delay() {
  log "Introducing artificial delay of ${ARTIFICIAL_DELAY} seconds..."
  sleep ${ARTIFICIAL_DELAY}
}

