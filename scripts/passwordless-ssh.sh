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

if [ -z "${PASSWORD}" ]; then
  exit 0
fi

IFS=' ' read -r -a HOSTNAMES <<< "$(split ${1})"

cat > /tmp/local-exsci <<EOF
#! /usr/bin/expect -f

set host [lindex \$argv 0]
set password [lindex \$argv 1]
spawn ssh-copy-id -i ${ID_FILE} root@\$host
expect "*?assword:*"
send -- "\$password\r"
expect eof
EOF

cat > /tmp/remote-exsci <<EOF
#! /usr/bin/expect -f

set host [lindex \$argv 0]
set password [lindex \$argv 1]
spawn ssh-copy-id root@\$host
expect "*?assword:*"
send -- "\$password\r"
expect eof
EOF


chmod +x /tmp/local-exsci

echo "USER: ${USER}"
echo "HOME: ${HOME}"
echo "whoami: $(whoami)"
echo "~: $(echo ~)"

if [ ! -f ${ID_FILE} ]; then
  mkdir -p $(dirname ${ID_FILE})
  ssh-keygen -f ${ID_FILE} -t rsa -N ''
  echo "Host *" >> ~/.ssh/config
  echo "  StrictHostKeyChecking no" >> ~/.ssh/config
fi
sudo yum install -y expect

for hostname in ${HOSTNAMES[@]}; do
  /tmp/local-exsci ${hostname} ${PASSWORD}
  scp /tmp/remote-exsci root@${hostname}:/tmp/exsci
  ssh -i ${ID_FILE} root@${hostname} "
  chmod +x /tmp/exsci
  if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
    echo \"Host *\" >> ~/.ssh/config
    echo \"  StrictHostKeyChecking no\" >> ~/.ssh/config
  fi
  yum install -y expect
  /tmp/exsci localhost ${PASSWORD}
  for inner_hostname in ${HOSTNAMES[@]}; do
    /tmp/exsci \${inner_hostname} ${PASSWORD}
  done" < /dev/null
done

# Test passwordless SSH
for hostname in ${HOSTNAMES[@]}; do
  ssh -i ${ID_FILE} root@${hostname} "
    for inner_hostname in ${HOSTNAMES[@]}; do
      ssh root@\${inner_hostname} \"hostname\"
    done
  " < /dev/null
done
# TODO fail if this fails?

