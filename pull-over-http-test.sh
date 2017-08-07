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

set -v
set -x

cd $(dirname ${0})

source env.sh
source scripts/functions.sh

old_cluster_env
scripts/passwordless-ssh.sh $(join ${HOSTNAMES[@]})
scripts/host-setup.sh $(join ${HOSTNAMES[@]})
scripts/zookeeper.sh $(join ${ZK_QUORUM[@]})
scripts/build-distribute-hadoop.sh ${V2} ${V2_GIT} $(join ${HOSTNAMES[@]})
CONF=${HADOOP_2}/etc/hadoop
for hostname in ${HOSTNAMES[@]}; do
  ssh root@${hostname} ". /tmp/env.sh
    tar xzf hadoop-${V2}.tar.gz
  " < /dev/null
done

scripts/configure-hadoop.sh ns1 $(join ${HOSTNAMES[@]}) $(join ${ZK_QUORUM[@]}) $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]})
scripts/initialize-dfs.sh "${HADOOP_2}" $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]})

ssh root@${HOSTNAMES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  sbin/start-dfs.sh
  sbin/start-yarn.sh
  sbin/mr-jobhistory-daemon.sh --config ${CONF} start historyserver
" < /dev/null

ssh root@${HOSTNAMES[0]} ". /tmp/env.sh
  cd ${HADOOP_2}
  MR_EXAMPLES=${HADOOP_2}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${V2}.jar
  bin/hadoop jar \${MR_EXAMPLES} teragen -Dmapred.map.tasks=${#DATANODES[@]} 10000000 /teragen
  bin/hadoop jar \${MR_EXAMPLES} terasort /teragen /terasort
" < /dev/null

export REMOTE_NAMENODES=$(join ${NAMENODES[@]})

new_cluster_env
scripts/passwordless-ssh.sh $(join ${HOSTNAMES[@]})
scripts/host-setup.sh $(join ${HOSTNAMES[@]})
# No ZooKeeper setup - sharing a quorum with the old cluster - required to access both with HA
scripts/build-distribute-hadoop.sh ${V3} ${V3_GIT} $(join ${HOSTNAMES[@]})
CONF=${HADOOP_3}/etc/hadoop
for hostname in ${HOSTNAMES[@]}; do
  ssh root@${hostname} ". /tmp/env.sh
    tar xzf hadoop-${V3}.tar.gz
  " < /dev/null
done

scripts/configure-hadoop.sh ns2 $(join ${HOSTNAMES[@]}) $(join ${ZK_QUORUM[@]}) $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]}) ${REMOTE_NAMENODES}
scripts/initialize-dfs.sh "${HADOOP_3}" $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]})

ssh root@${HOSTNAMES[0]} ". /tmp/env.sh
  cd ${HADOOP_3}
  # start-dfs.sh may log errors that it can't SSH to the remote NameNodes
  # That's perfect - we only want to use them in clients anyway
  # Passwordless SSH is set up within each distinct cluster
  sbin/start-dfs.sh
  sbin/start-yarn.sh
  sbin/mr-jobhistory-daemon.sh --config ${CONF} start historyserver
" < /dev/null

ssh root@${HOSTNAMES[0]} ". /tmp/env.sh
  cd ${HADOOP_3}
  MR_EXAMPLES=${HADOOP_3}/share/hadoop/mapreduce/hadoop-mapreduce-examples-${V3}.jar
  bin/hadoop --config ~/client-conf fs -cp webhdfs://ns1/terasort hdfs://ns2/copy
  bin/hadoop --config ~/client-conf fs -ls /copy
" < /dev/null

