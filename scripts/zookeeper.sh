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

set -v
set -x

IFS=' ' read -r -a ZK_QUORUM <<< "$(split ${1})"

declare -a IDS
for ((i=0; i<${#ZK_QUORUM[*]}; i++)); do
  IDS[${i}]=$(echo ${ZK_QUORUM[${i}]} | sed -e "s/${HOST_PREFIX}//" | sed -e "s/${HOST_SUFFIX}//")
done

for host in ${ZK_QUORUM[@]}; do
  ssh root@${host} ". /tmp/env.sh
    wget http://www-us.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION}/zookeeper-${ZK_VERSION}.tar.gz
    tar xzf zookeeper-${ZK_VERSION}.tar.gz
    mv zookeeper-${ZK_VERSION} zookeeper
    cd zookeeper
    cat > conf/zoo.cfg <<EOF
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
initLimit=5
syncLimit=2
server.${IDS[0]}=${ZK_QUORUM[0]}:2888:3888
server.${IDS[1]}=${ZK_QUORUM[1]}:2888:3888
server.${IDS[2]}=${ZK_QUORUM[2]}:2888:3888
EOF
    i=\`hostname | sed -e 's/${HOST_PREFIX}//' | sed -e 's/${HOST_SUFFIX}//'\`
    mkdir -p /var/lib/zookeeper
    chmod 777 /var/lib/zookeeper
    echo \${i} > /var/lib/zookeeper/myid
    bin/zkServer.sh start
  " < /dev/null
done

