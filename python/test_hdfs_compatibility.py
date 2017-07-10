#!/usr/bin/env python
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Run HDFS CLI and WebHDFS compability tests against two version of HDFS.

It accepts two .tar.gz tarball files or URLs of different HDFS releases.
"""

from hdfs import *
from util import *

import argparse
import logging
import os
import subprocess
import sys
import tempfile
import unittest

class MultipleHdfsClusterTestBase(unittest.TestCase):
    """Run HDFS test with multiple Hdfs clusters.
    """
    OLD_HADOOP_HOME = ''
    NEW_HADOOP_HOME = ''

    @classmethod
    def setUpClass(cls):
        make_new_dir('new')
        make_new_dir('old')
        cls.old_cluster = HdfsCluster('old', cls.OLD_HADOOP_HOME)
        cls.new_cluster = HdfsCluster('new', cls.NEW_HADOOP_HOME)
        cls.old_cluster.start()
        cls.new_cluster.start()
        cls.old_cluster.wait_active()
        cls.new_cluster.wait_active()

    @classmethod
    def tearDownClass(cls):
        try:
            cls.old_cluster.stop()
        finally:
            cls.new_cluster.stop()

    def get_old_uri(self, path):
        """Get URI of a file on the old cluster.
        """
        return self.old_cluster.url + path

    def get_new_uri(self, path):
        """Get URI of a file on the new cluster.
        """
        return self.new_cluster.url + path


class TestCLICompatibility(MultipleHdfsClusterTestBase):
    def test_copy_file_to_new_cluster(self):
        """Copy files from the old cluster to the new cluster, using both
        version of HDFS clients.
        """
        with tempfile.NamedTemporaryFile() as testfile:
            testfile.write("123456")
            testfile.flush()
            self.old_cluster.run_dfs(
                "-put %s /testCopyFileToNewCluster" % (testfile.name))
            self.old_cluster.run_dfs("-test -f /testCopyFileToNewCluster")

        for i, cluster in enumerate([self.old_cluster, self.new_cluster]):
            new_file_name = self.get_new_uri(
                "/testCopyFileToNewCluster-%d" % i)
            cluster.run_dfs("-cp %s %s" % (
                self.get_old_uri("/testCopyFileToNewCluster"), new_file_name))
            self.new_cluster.run_dfs("-test -f %s" % new_file_name)
            content = self.new_cluster.run_dfs("-cat %s" % new_file_name)
            self.assertEqual("123456", content)
        self.old_cluster.run_dfs("-rm /testCopyFileToNewCluster*")
        self.new_cluster.run_dfs("-rm /testCopyFileToNewCluster*")

    def assertCompatible(self, cmd):
        times_regex = re.compile(r"\d\d\d\d-\d\d-\d\d \d\d:\d\d")
        clean_times = lambda text: re.sub(times_regex, "", text)

        ports_regex = re.compile(r"(?<=localhost:)\d+")
        clean_ports = lambda text: re.sub(ports_regex, "", text)

        clean = lambda text: clean_times(clean_ports(text))

        old_text = None
        new_text = None
        old_failed = False
        new_failed = False
        try:
            old_text = clean(self.old_cluster.run_dfs(cmd))
        except subprocess.CalledProcessError:
            old_failed = True

        try:
            new_text = clean(self.new_cluster.run_dfs(cmd))
        except subprocess.CalledProcessError:
            new_failed = True

        self.assertEqual(old_failed, new_failed)
        self.assertEqual(old_text, new_text)

    """
        This doesn't necessarily check correct behavior - it runs every command
        and ensures that the resulting listing yields sufficiently similar
        output and / or behavior in both versions.
    """
    def test_hdfs_dfs(self):
        print("Starting new cluster...")
        testfile = tempfile.NamedTemporaryFile(delete=False)
        testfile.write("0123456789")
        testfile.close()

        # TODO: test [-f] [-p] [-l] [-d] for -put / -copyFromlocal
        # TODO: test [-f] [-p] [-ignoreCrc] [-crc] for get, -copyToLocal
        self.assertCompatible("-put %s /0.txt" % testfile.name)
        self.assertCompatible("-copyFromLocal %s /1.txt" % testfile.name)

        # helper assertions are not used here, as local state changes between each command
        for cluster in [self.old_cluster, self.new_cluster]:
            cluster.run_dfs("-moveFromLocal %s /2.txt" % testfile.name)
            self.assertFalse(os.path.isfile(testfile.name))
            cluster.run_dfs("-get /0.txt %s" % testfile.name)
            self.assertTrue(os.path.isfile(testfile.name))
            os.remove(testfile.name)
            cluster.run_dfs("-copyToLocal /1.txt %s" % testfile.name)
            self.assertTrue(os.path.isfile(testfile.name))
        os.remove(testfile.name)

        self.assertCompatible("-mkdir /single-dir")
        self.assertCompatible("-mkdir /parent-dir/child-dir")
        self.assertCompatible("-mkdir -p /parent-dir/child-dir")
        self.assertCompatible("-touchz /empty-file")
        #self.assertCompatible("-stat /empty-file")

        for flag in ['d', 'e', 'f', 'r', 's', 'w', 'z']:
            self.assertCompatible("-test -%s /empty-file" % flag)

        self.assertCompatible("-touchz /deleted-file")
        self.assertCompatible("-rm -skipTrash /deleted-file")

        self.assertCompatible("-touchz /trashed-file")
        self.assertCompatible("-rm /trashed-file")

        self.assertCompatible("-mkdir /deleted-dir")
        self.assertCompatible("-rmdir /deleted-dir")

        self.assertCompatible("-mkdir -p /non-deleted-dir/child")
        self.assertCompatible("-rmdir /non-deleted-dir")
        self.assertCompatible("-rmdir --ignore-fail-on-non-empty /non-deleted-dir")

        # TODO: test bin/hadoop fs [-cp [-f] [-p | -p[topax]] [-d] <src> ... <dst>]
        self.assertCompatible("-mv /0.txt /3.txt")
        self.assertCompatible("-cp /3.txt /4.txt")
        self.assertCompatible("-cp /single-dir /twin-dir")

        # Fixme - this fails because of a bad datanode on the pipeline
        #self.assertCompatible("-appendToFile %s /4.txt" % tempfile_name)
        self.assertCompatible("-cat /4.txt")
        self.assertCompatible("-cat -ignoreCrc /4.txt")
        self.assertCompatible("-checksum /4.txt")
        self.assertCompatible("-text /4.txt")
        self.assertCompatible("-text -ignoreCrc /4.txt")
        # TODO test "tail -f"
        self.assertCompatible("-tail /4.txt")

        # TODO test -w
        self.assertCompatible("-truncate 10 /4.txt")
        self.assertCompatible("-cat -ignoreCrc /4.txt")
        self.assertCompatible("-truncate 0 /4.txt")
        self.assertCompatible("-cat -ignoreCrc /4.txt")

        self.assertCompatible("-mkdir -p /ch-parent/ch-child")
        self.assertCompatible("-chgrp -R child_group /ch-parent")
        self.assertCompatible("-chgrp parent_group /ch-parent")
        self.assertCompatible("-chmod -R 000 /ch-parent")
        self.assertCompatible("-chmod 444 /ch-parent")
        self.assertCompatible("-chmod +x /ch-parent")

        # TODO: expand ls and find (bin/hadoop fs [-ls [-C] [-d] [-h] [-q] [-R] [-t] [-S] [-r] [-u] [<path> ...]])
        # Listing is tested at the end to compare the overall outcome of other tests
        self.assertCompatible("-ls /")
        self.assertCompatible("-ls -R /")
        self.assertCompatible("-find /")

        self.assertCompatible("-count -q -h -v -t -u -x /")
        #self.assertCompatible("-df -h /") # Fails
        #self.assertCompatible("-du -s -h -x /")

        self.assertCompatible("-expunge")
        self.assertCompatible("-getmerge -nl -skip-empty-file / /merge")
        self.assertCompatible("-setrep -R -w 2 /merge")

        self.assertCompatible("-createSnapshot / snap1")
        self.assertCompatible("-renameSnapshot / snap1 snap2")
        self.assertCompatible("-deleteSnapshot / snap2")

        self.assertCompatible("-setfattr -n user.myAttr -v myValue /merge")
        self.assertCompatible("-getfattr -n user.myAttr /merge")





    #def test_classpath(self):
    #    bin/yarn classpath
    #    bin/hadoop classpath
    #    bin/hdfs classpath
    #    bin/mapred classpath



def get_scratch_dir():
    """Get scratch directory.
    """
    if ARGS is not None and ARGS.scratch:
        return ARGS.scratch
    return os.path.join(WORKDIR, 'target', 'scratch')

def main():
    """Test API compability between two hadoop versions.
    """
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        'old', metavar='OLD', nargs=1,
        help='file or URL to a .tar.gz tarball for the old HDFS version')
    parser.add_argument(
        'new', metavar='NEW', nargs=1,
        help='file or URL to a .tar.gz tarball for the new HDFS version')
    parser.add_argument('--scratch', metavar='DIR', default='',
                        help='set scratch directory')

    global ARGS
    ARGS = parser.parse_args()
    sys.argv = sys.argv[:1]  # clear argv for unittests.

    # TODO accept git commit hash or branch names.
    old = ARGS.old[0]
    new = ARGS.new[0]
    if not old.endswith('.tar.gz'):
        logging.error('Must specify .tar.gz file or URL for old release')
        sys.exit(1)
    if not new.endswith('.tar.gz'):
        logging.error('Must specify .tar.gz file or URL for new release')
        sys.exit(1)
    check_envs()

    if not os.path.exists(get_scratch_dir()):
        os.makedirs(get_scratch_dir())

    with cd(get_scratch_dir()):
        extract_tarball(old, '.')
        extract_tarball(new, '.')
        MultipleHdfsClusterTestBase.OLD_HADOOP_HOME = \
            os.path.join(get_scratch_dir(), splitext(os.path.basename(old))[0])
        MultipleHdfsClusterTestBase.NEW_HADOOP_HOME = \
            os.path.join(get_scratch_dir(), splitext(os.path.basename(new))[0])

        unittest.main()


if __name__ == '__main__':
    main()
