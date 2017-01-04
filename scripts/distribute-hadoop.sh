#!/usr/bin/env bash

source scripts/functions.sh

set -v
set -x

VERSION=${1}
GIT_REF=${2}
IFS=' ' read -r -a HOSTNAMES <<< "$(split ${3})"

# If the tarball doesn't exist, build it
if [ ! -e ~/hadoop-${VERSION}.tar.gz ]; then
  # TODO Assumes toolchain and other environment setup is done
  (
    git clone git://git.apache.org/hadoop.git
    cd hadoop
    git checkout ${GIT_REF}
    mvn clean package -DskipTests -Pdist -Dtar
    cp hadoop-dist/target/hadoop-${VERSION}.tar.gz ~/
    cd ..
    rm -rf hadoop
  )
fi
scp ~/hadoop-${VERSION}.tar.gz root@${HOSTNAMES[0]}:~/

ssh root@${HOSTNAMES[0]} ". /tmp/env.sh
  for hostname in ${HOSTNAMES[@]}; do
    if [ "\${hostname}" != "${HOSTNAMES[0]}" ]; then
      scp hadoop-${VERSION}.tar.gz root@\${hostname}:~/
    fi
  done
" < /dev/null
