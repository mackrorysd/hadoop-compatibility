#!/usr/bin/env bash

source scripts/functions.sh

set -v
set -x

RUNNING_FLAG=/tmp/test-workload-running
SHUTDOWN_FLAG=/tmp/test-workload-shutdown
LOG_FILE=/root/mr.log

COMMAND=${1}
HOSTNAME=${2}
WORKERS=${3}

if [[ "${COMMAND}" != 'start' && "${COMMAND}" != 'stop' ]]; then
  echo "Expected 'stop' or 'start', found '${1}'"
  exit 1
fi

if [ "${COMMAND}" == 'start' ]; then
  # NOTE: underscores or hyphens in directory names fails because partition_list can't be found
  ssh root@${HOSTNAME} ". /tmp/env.sh
    touch ${RUNNING_FLAG}
    cd ${HADOOP_2}
    MR_EXAMPLES=${HADOOP_2}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${V2}.jar
    bin/hadoop jar \${MR_EXAMPLES} teragen -Dmapred.map.tasks=${WORKERS} 10000000 /terain
    for i in {0..9}; do
      (
        while [ -e ${RUNNING_FLAG} ]; do
          bin/hadoop jar \${MR_EXAMPLES} terasort /terain /teraout\${i}
          echo "\`date\` Terasort \${i}: \${?}" >> ${LOG_FILE}
          bin/hadoop fs -rm -r -skipTrash /teraout\${i}
          echo "\`date\` Deletion \${i}: \${?}" >> ${LOG_FILE}
        done
        touch ${SHUTDOWN_FLAG}_\${i}
      ) &
      sleep 10
    done
  " < /dev/null
fi

if [ "${COMMAND}" == 'stop' ]; then
  ssh root@${HOSTNAME} ". /tmp/env.sh
    rm -f ${RUNNING_FLAG}
    for i in {0..9}; do
      while [ ! -e ${SHUTDOWN_FLAG}_\${i} ]; do
        echo \"Waiting 1 minute for process \${i}...\"
        sleep 60
      done
    done
    cat ${LOG_FILE}
  " < /dev/null
  exit ${?}
fi

