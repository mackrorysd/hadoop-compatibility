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


from subprocess import check_call, check_output
import logging
import os
import re
import time
from util import *

class NameNode(object):
    """NameNode manages the life cycle of a HDFS NameNode.
    """

    def __init__(self, cluster, name):
        self.cluster = cluster
        self.workdir = os.path.abspath(cluster.workdir)
        self.hadoop_home = os.path.abspath(cluster.hadoop_home)
        self.conf_dir = os.path.join(self.workdir, 'conf', name)
        self.data_dir = os.path.join(self.workdir, 'data', name)
        self.pid_dir = os.path.join(self.workdir, 'pid', name)
        self.env = os.environ.copy()
        self.env['HADOOP_CONF_DIR'] = self.conf_dir
        self.env['HADOOP_PID_DIR'] = self.pid_dir

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        # TODO: handle exceptions
        self.stop()

    def start(self):
        conf = {
            "dfs.namenode.rpc-address": self.rpc_address,
            "fs.default.name": self.url,
            "dfs.namenode.name.dir": self.data_dir,
            "dfs.replication": 1,
            "fs.defaultFS": 'hdfs://localhost',
            "dfs.namenode.http-address": self.http_address,
        }
        dump_conf(conf, os.path.join(self.conf_dir, 'hdfs-site.xml'))
        with cd(self.hadoop_home):
            check_call(['bin/hdfs', 'namenode', '-format', '-force'],
                       env=self.env)
            if self.cluster.major_version >= 3:
                check_call(['bin/hdfs', '--daemon', 'start', 'namenode'],
                           env=self.env)
            else:
                check_call(['sbin/hadoop-daemon.sh', 'start', 'namenode'],
                           env=self.env)

    def stop(self):
        """Stops the NameNode.
        """
        with cd(self.hadoop_home):
            if self.cluster.major_version >= 3:
                check_call(['bin/hdfs', '--daemon', 'stop', 'namenode'],
                           env=self.env)
            else:
                check_call(['sbin/hadoop-daemon.sh', 'stop', 'namenode'],
                           env=self.env)

    @property
    def url(self):
        """Filesystem URL
        """
        return 'hdfs://%s' % self.rpc_address

    @property
    def http_address(self):
        return 'localhost:%d' % self.cluster.get_port(5070)

    @property
    def rpc_address(self):
        return 'localhost:%d' % self.cluster.get_port(9820)


class DataNode(object):
    def __init__(self, cluster, name):
        self.cluster = cluster
        self.workdir = os.path.abspath(cluster.workdir)
        self.hadoop_home = os.path.abspath(cluster.hadoop_home)
        self.conf_dir = os.path.join(self.workdir, 'conf', name)
        self.data_dir = os.path.join(self.workdir, 'data', name)
        self.pid_dir = os.path.join(self.workdir, 'pid', name)
        self.volumes = [os.path.join(self.data_dir, 'vol%d' % i)
                        for i in range(2)]
        self.env = os.environ.copy()
        self.env['HADOOP_CONF_DIR'] = self.conf_dir
        self.env['HADOOP_PID_DIR'] = self.pid_dir

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        # TODO: handle exceptions
        self.stop()

    def start(self):
        """Sets the configuration and starts the DataNode.
        """
        assert self.cluster.namenodes
        conf = {
            "dfs.namenode.rpc-address": self.cluster.namenodes[0].rpc_address,
            "dfs.data.dir": ",".join(self.volumes),
            "dfs.replication": 1,
        }
        dump_conf(conf, os.path.join(self.conf_dir, 'hdfs-site.xml'))

        with cd(self.hadoop_home):
            if self.cluster.major_version >= 3:
                check_call(['bin/hdfs', '--daemon', 'start', 'datanode'],
                           env=self.env)
            else:
                check_call(['sbin/hadoop-daemon.sh', 'start', 'datanode'],
                           env=self.env)

    def stop(self):
        """Stops this DataNode.
        """
        with cd(self.hadoop_home):
            if self.cluster.major_version >= 3:
                check_call(['bin/hdfs', '--daemon', 'stop', 'datanode'],
                           env=self.env)
            else:
                check_call(['sbin/hadoop-daemon.sh', 'stop', 'datanode'],
                           env=self.env)


class HdfsCluster(object):
    """Hdfs Cluster

    It works with `with` statement.
    """
    START_PORT = 10000

    def __init__(self, workdir, hadoop_home):
        self.workdir = workdir
        self.hadoop_home = hadoop_home
        self.datanodes = [DataNode(self, "dn0")]
        self.namenodes = [NameNode(self, "nn")]
        self.start_port = HdfsCluster.START_PORT
        HdfsCluster.START_PORT += 2000

        self.set_hdfs_version()

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        # TODO handle exception.
        self.stop()

    def get_port(self, port):
        return self.start_port + port

    def set_hdfs_version(self):
        """Parse "hdfs version" command and set the versions.
        """
        with cd(self.hadoop_home):
            output = check_output(['bin/hdfs', 'version'])
            line = output.split('\n')[0]
            self.version = line.split()[1].strip()
            self.major_version = int(self.version.split('.')[0])

    def start(self):
        """Starts the cluster.
        """
        for nn in self.namenodes:
            nn.start()
        for dn in self.datanodes:
            dn.start()

    def stop(self):
        """Stops the cluster
        """
        for dn in self.datanodes:
            try:
                dn.stop()
            except Exception as e:
                logging.error(e)
        for nn in self.namenodes:
            try:
                nn.stop()
            except Exception as e:
                logging.error(e)

    @property
    def url(self):
        """Filesystem URL of this HDFS cluster instance.
        """
        return self.namenodes[0].url

    def wait_active(self, retries=50):
        """Wait until the cluster is ready.
        """
        live_dns_re = re.compile(r'Live datanodes \((\d+)\)')
        with cd(self.hadoop_home):
            while retries > 0:
                logging.info("Waitting DataNodes online.")
                report = check_output(
                    ['bin/hdfs', 'dfsadmin', '-fs', self.url, '-report'])
                logging.debug(report)
                for line in report.split('\n'):
                    m = live_dns_re.match(line)
                    if m:
                        live_dns = int(m.groups()[0])
                        if live_dns == len(self.datanodes):
                            return
                        logging.info(
                            "Live datanodes %d, expect %d, %d retries left." %
                            (live_dns, len(self.datanodes), retries))
                        break
                time.sleep(2)
                retries -= 1

    def run(self, cmd):
        with cd(self.hadoop_home):
            return check_output(cmd, shell=True)

    def run_dfs(self, cmd):
        """Run "hdfs dfs" subcommand on this cluster.
        """
        with cd(self.hadoop_home):
            return check_output("bin/hdfs dfs -fs %s %s" % (self.url, cmd),
                                shell=True)
