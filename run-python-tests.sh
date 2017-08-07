#!/usr/bin/env bash

MIRROR=http://apache.cs.utah.edu/hadoop/common
RELEASE_1=2.8.0
RELEASE_2=3.0.0-beta1-SNAPSHOT

cd python

python ./test_hdfs_compatibility.py \
  ${MIRROR}/hadoop-${RELEASE_1}/hadoop-${RELEASE_1}.tar.gz \
  ${MIRROR}/hadoop-${RELEASE_2}/hadoop-${RELEASE_2}.tar.gz
