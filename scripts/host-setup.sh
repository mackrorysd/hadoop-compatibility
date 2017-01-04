#!/usr/bin/env bash

source scripts/functions.sh

set -v
set -x

IFS=' ' read -r -a HOSTNAMES <<< "$(split ${1})"

for hostname in ${HOSTNAMES[@]}; do
  scp env.sh root@${hostname}:/tmp/
  ssh root@${hostname} ". /tmp/env.sh
    # Install JDK
    rpm -i ${JDK_RPM}
    echo 'export JAVA_HOME=${JAVA_HOME}' >> /etc/profile

    # Populate hosts file
    cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
    for inner_hostname in ${HOSTNAMES[@]}; do
      address=\`ping -c 1 \${inner_hostname} | grep ^PING | sed -e 's/.* (//' | sed -e 's/) .*//'\`
      echo \"\${address}    \${inner_hostname}\" >> /etc/hosts
    done
  " < /dev/null
done

