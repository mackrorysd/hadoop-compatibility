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

VERSION=${1}
GIT_REF=${2}
IFS=' ' read -r -a HOSTNAMES <<< "$(split ${3})"

# If the tarball doesn't exist, build it
if [ ! -e ~/hadoop-${VERSION}.tar.gz ]; then
  # TODO Assumes toolchain and other environment setup is done
  temp_dir=$(mktemp -d)
  (
    cd ${temp_dir}
    git clone git://github.com/apache/hadoop.git
    cd hadoop
    git checkout ${GIT_REF}
    mvn clean package -DskipTests -Pdist -Dtar
    cp hadoop-dist/target/hadoop-${VERSION}.tar.gz ~/
  )
  rm -rf ${temp_dir}
fi

if [ ! -e ~/hadoop-${VERSION}.tar.gz ]; then
  log "Hadoop tarball was not present and failed to build!"
  exit 1
fi

scp ~/hadoop-${VERSION}.tar.gz root@${HOSTNAMES[0]}:~/

ssh -i ${ID_FILE} root@${HOSTNAMES[0]} ". /tmp/env.sh
  for hostname in ${HOSTNAMES[@]}; do
    if [ "\${hostname}" != "${HOSTNAMES[0]}" ]; then
      scp hadoop-${VERSION}.tar.gz root@\${hostname}:~/
    fi
  done
" < /dev/null
