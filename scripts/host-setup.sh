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

for hostname in ${HOSTNAMES[@]}; do
  scp env.sh root@${hostname}:/tmp/
  ssh -i ${ID_FILE} root@${hostname} ". /tmp/env.sh
    apt-get install -y wget
    echo 'export JAVA_HOME=${JAVA_HOME}' >> /etc/profile

    if [ \"${PLATFORM}\" != 'docker' ]; then
      # Populate hosts file
      cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
      for inner_hostname in ${HOSTNAMES[@]}; do
        address=\`ping -c 1 \${inner_hostname} | grep ^PING | sed -e 's/.* (//' | sed -e 's/) .*//'\`
        echo \"\${address}    \${inner_hostname}\" >> /etc/hosts
      done
    fi
  " < /dev/null
done

