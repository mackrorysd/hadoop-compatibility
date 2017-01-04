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
  ssh -o StrictHostKeyChecking=no root@${HOSTNAME} ". /tmp/env.sh
  ${COMMANDS}" < /dev/null
}

# Check currently running HDFS processes
function check_hdfs_daemons() {
  for hostname in ${HOSTNAMES[@]}; do
    ssh root@${hostname} ". /tmp/env.sh
      ps -e -o cmd | egrep '(Name|Journal|Data)Node'
    " < /dev/null
  done
}

function check_yarn_daemons() {
  for hostname in ${HOSTNAMES[@]}; do
    ssh root@${hostname} ". /tmp/env.sh
      ps -e -o cmd | egrep '(Resource|Node)Manager'
    " < /dev/null
  done
}

