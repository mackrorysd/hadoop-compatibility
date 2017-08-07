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

NS=${1}
IFS=' ' read -r -a HOSTNAMES <<< "$(split ${2})"
IFS=' ' read -r -a ZK_QUORUM <<< "$(split ${3})"
IFS=' ' read -r -a JN_QUORUM <<< "$(split ${4})"
IFS=' ' read -r -a NAMENODES <<< "$(split ${5})"
IFS=' ' read -r -a DATANODES <<< "$(split ${6})"
IFS=' ' read -r -a REMOTE_NAMENODES <<< "$(split ${7})"

NS1=""
NS1="${NS1}<property><name>dfs.nameservices</name>                        <value>ns1,ns2</value></property>"
NS1="${NS1}<property><name>dfs.ha.namenodes.ns1</name>                    <value>nn1,nn2</value></property>"
NS1="${NS1}<property><name>dfs.namenode.rpc-address.ns1.nn1</name>        <value>${REMOTE_NAMENODES[0]}:8020</value></property>"
NS1="${NS1}<property><name>dfs.namenode.rpc-address.ns1.nn2</name>        <value>${REMOTE_NAMENODES[1]}:8020</value></property>"
NS1="${NS1}<property><name>dfs.namenode.http-address.ns1.nn1</name>       <value>${REMOTE_NAMENODES[0]}:50070</value></property>"
NS1="${NS1}<property><name>dfs.namenode.http-address.ns1.nn2</name>       <value>${REMOTE_NAMENODES[1]}:50070</value></property>"
NS1="${NS1}<property><name>dfs.client.failover.proxy.provider.ns1</name>  <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value></property>"

for hostname in ${HOSTNAMES[@]}; do
  ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
    mkdir -p ${CONF}
    cat > ${CONF}/hdfs-site.xml <<EOF
<configuration>
    <property><name>dfs.ha.namenodes.${NS}</name>                    <value>nn1,nn2</value></property>
    <property><name>dfs.namenode.rpc-address.${NS}.nn1</name>        <value>${NAMENODES[0]}:8020</value></property>
    <property><name>dfs.namenode.rpc-address.${NS}.nn2</name>        <value>${NAMENODES[1]}:8020</value></property>
    <property><name>dfs.namenode.http-address.${NS}.nn1</name>       <value>${NAMENODES[0]}:50070</value></property>
    <property><name>dfs.namenode.http-address.${NS}.nn2</name>       <value>${NAMENODES[1]}:50070</value></property>
    <property><name>dfs.client.failover.proxy.provider.${NS}</name>  <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value></property>
    <property><name>dfs.namenode.shared.edits.dir</name>           <value>qjournal://${JN_QUORUM[0]}:8485;${JN_QUORUM[1]}:8485;${JN_QUORUM[2]}:8485/${NS}</value></property>
    <property><name>dfs.ha.fencing.methods</name>                  <value>sshfence</value></property>
    <property><name>dfs.journalnode.edits.dir</name>               <value>/data/jn</value></property>
    <property><name>dfs.ha.automatic-failover.enabled</name>       <value>true</value></property>
    <property><name>dfs.namenode.name.dir</name>                   <value>/data/nn</value></property>
    <property><name>dfs.datanode.data.dir</name>                   <value>/data/dn</value></property>
    <property><name>dfs.nameservices</name>                        <value>${NS}</value></property>
</configuration>
EOF
    cat > ${CONF}/core-site.xml <<EOF
<configuration>
    <property><name>dfs.min.replication</name>                     <value>3</value></property>
    <property><name>fs.defaultFS</name>                            <value>hdfs://${NS}</value></property>
    <property><name>ha.zookeeper.quorum</name>                     <value>${ZK_QUORUM[0]}:2181,${ZK_QUORUM[1]}:2181,${ZK_QUORUM[2]}:2181</value></property>
    <property><name>hadoop.proxyuser.root.hosts</name>             <value>*</value></property>
    <property><name>hadoop.proxyuser.root.groups</name>            <value>*</value></property>
</configuration>
EOF
    cat > ${CONF}/mapred-site.xml <<EOF
<configuration>
    <property><name>mapreduce.framework.name</name>                <value>yarn</value></property>
</configuration>
EOF
    cat > ${CONF}/yarn-site.xml <<EOF
<configuration>
    <property><name>yarn.resourcemanager.ha.enabled</name>         <value>true</value></property>
    <property><name>yarn.resourcemanager.cluster-id</name>         <value>cluster1</value></property>
    <property><name>yarn.resourcemanager.ha.rm-ids</name>          <value>rm1,rm2</value></property>
    <property><name>yarn.resourcemanager.hostname.rm1</name>       <value>${NAMENODES[0]}</value></property>
    <property><name>yarn.resourcemanager.hostname.rm2</name>       <value>${NAMENODES[1]}</value></property>
    <property><name>yarn.resourcemanager.zk-address</name>         <value>${ZK_QUORUM[0]}:2181,${ZK_QUORUM[1]}:2181,${ZK_QUORUM[2]}:2181</value></property>

    <property><name>yarn.nodemanager.aux-services</name>           <value>mapreduce_shuffle</value></property>
    <property><name>yarn.resourcemanager.recovery.enabled</name>   <value>true</value></property>

    <!-- Had problems with FS-based restart - not meant for HA anyway -->
    <property><name>yarn.resourcemanager.store.class</name>        <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value></property>
    <property><name>yarn.resourcemanager.zk-address</name>         <value>${ZK_QUORUM[0]}:2181,${ZK_QUORUM[1]}:2181,${ZK_QUORUM[2]}:2181</value></property>
</configuration>
EOF
    rm -f ${CONF}/slaves
    rm -f ${CONF}/workers
    for inner_hostname in ${DATANODES[@]}; do
      echo \${inner_hostname} >> ${CONF}/slaves
    done
    echo \"export JAVA_HOME=${JAVA_HOME}\" >> ${CONF}/hadoop-env.sh

    # Create client-configuration that can point to other clusters
    cp -r ${CONF} ~/client-conf
    if [[ -n \"${REMOTE_NAMENODES[@]}\" ]]; then
      sed -i -e 's#.*dfs.nameservices.*#${NS1}#' ~/client-conf/hdfs-site.xml
    fi
  " < /dev/null
done

