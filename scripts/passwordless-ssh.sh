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

if [ -z "${PASSWORD}" ]; then
  exit 0
fi

IFS=' ' read -r -a HOSTNAMES <<< "$(split ${1})"

cat > /tmp/exsci <<EOF
#! /usr/bin/expect -f

set host [lindex \$argv 0]
set password [lindex \$argv 1]
spawn ssh-copy-id -o StrictHostKeyChecking=no root@\$host
expect "*?assword:*"
send -- "\$password\r"
expect eof
EOF

chmod +x /tmp/exsci

if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
fi
sudo yum install -y expect

for hostname in ${HOSTNAMES[@]}; do
  /tmp/exsci ${hostname} ${PASSWORD}
  scp /tmp/exsci root@${hostname}:/tmp/
  ssh root@${hostname} "
  chmod +x /tmp/exsci
  if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
  fi
  yum install -y expect
  /tmp/exsci localhost ${PASSWORD}
  for inner_hostname in ${HOSTNAMES[@]}; do
    /tmp/exsci \${inner_hostname} ${PASSWORD}
  done" < /dev/null
done

# Test passwordless SSH
for hostname in ${HOSTNAMES[@]}; do
  ssh root@${hostname} "
    for inner_hostname in ${HOSTNAMES[@]}; do
      ssh -o StrictHostKeyChecking=no root@\${inner_hostname} \"hostname\"
    done
  " < /dev/null
done
# TODO how to fail if this fails?

