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

set -e
set -v
set -x

cd $(dirname ${0})

source env.sh
source scripts/functions.sh
one_cluster_env

scripts/passwordless-ssh.sh $(join ${HOSTNAMES[@]})
scripts/host-setup.sh $(join ${HOSTNAMES[@]})
scripts/zookeeper.sh $(join ${ZK_QUORUM[@]})
scripts/build-distribute-hadoop.sh ${V2} ${V2_GIT} $(join ${HOSTNAMES[@]})
scripts/build-distribute-hadoop.sh ${V3} ${V3_GIT} $(join ${HOSTNAMES[@]})

for hostname in ${HOSTNAMES[@]}; do
  log "Extracting tarballs and linking configuration on ${hostname}..."
  ssh root@${hostname} ". /tmp/env.sh
    rm -rf hadoop-${V2} hadoop-${V3} ${CONF}
    tar xzf hadoop-${V2}.tar.gz
    tar xzf hadoop-${V3}.tar.gz
    mv ${HADOOP_2}/etc/hadoop ${CONF}
    ln -s ${CONF} ${HADOOP_2}/etc/hadoop
    rm -r ${HADOOP_3}/etc/hadoop
    ln -s ${CONF} ${HADOOP_3}/etc/hadoop
  " < /dev/null
done

scripts/configure-hadoop.sh ns1 $(join ${HOSTNAMES[@]}) $(join ${ZK_QUORUM[@]}) $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]})
scripts/initialize-dfs.sh "${HADOOP_2}" $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]})

ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/start-dfs.sh
  sbin/start-yarn.sh
  sbin/mr-jobhistory-daemon.sh --config ${CONF} start historyserver
" < /dev/null

ssh root@${NAMENODES[1]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/start-yarn.sh # start-yarn.sh is not HA-aware
" < /dev/null

scripts/test-workload.sh start ${HOSTNAMES[0]} ${#DATANODES[@]} &

log "Running workload for a while before starting upgrades..."

sleep ${ARTIFICIAL_DELAY}

scripts/hdfs-rolling-upgrade.sh $(join ${HOSTNAMES[@]}) $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]})

#scripts/yarn-rolling-upgrade.sh $(join ${HOSTNAMES[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]})

scripts/test-workload.sh stop ${HOSTNAMES[0]}

log "Getting YARN application list..."

ssh root@${NAMENODES[0]} ". /tmp/env.sh
  cd ${HADOOP_3}
  bin/yarn application -list -appStates ALL 2>/dev/null
" < /dev/null 2> /dev/null > /tmp/yarnApps.txt

cat /tmp/yarnApps.txt

log "Checking for failures..."

# Filter out only the Tera* jobs we ran, and anything but FINISHED
cat /tmp/yarnApps.txt | grep Tera | grep -v FINISHED*SUCCEEDED

SUCCESS=${?}
