#!/usr/bin/env bash
set -v
set -x

cd $(dirname ${0})

source env.sh
source scripts/functions.sh
one_cluster_env

scripts/passwordless-ssh.sh $(join ${HOSTNAMES[@]})
scripts/host-setup.sh $(join ${HOSTNAMES[@]})
scripts/zookeeper.sh $(join ${ZK_QUORUM[@]})
scripts/distribute-hadoop.sh ${V2} ${V2_GIT} $(join ${HOSTNAMES[@]})
scripts/distribute-hadoop.sh ${V3} ${V3_GIT} $(join ${HOSTNAMES[@]})

for hostname in ${HOSTNAMES[@]}; do
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

scripts/test-workload.sh start ${HOSTNAMES[0]} ${#DATANODES[@]} &

sleep 60

scripts/rolling-upgrade.sh $(join ${HOSTNAMES[@]}) $(join ${JN_QUORUM[@]}) $(join ${NAMENODES[@]}) $(join ${DATANODES[@]})

scripts/test-workload.sh stop ${HOSTNAMES[0]}
