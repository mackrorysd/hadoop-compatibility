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

from contextlib import contextmanager
from subprocess import check_call
from xml.dom import minidom
import logging
import os
import shutil
import urllib2
import xml.etree.ElementTree as et

WORKDIR = os.getcwd()

@contextmanager
def cd(newdir):
    """Change directory and run commands in context.
    """
    prevdir = os.getcwd()
    os.chdir(os.path.expanduser(newdir))
    try:
        yield
    finally:
        os.chdir(prevdir)

def splitext(filepath):
    """Support split extention like .tar.gz.
    """
    suffix = '.tar.gz'
    if filepath and filepath.endswith(suffix):
        pos = 0 - len(suffix)
        return filepath[:pos], filepath[pos:]
    return os.path.splitext(filepath)


def extract_tarball(url, dest):
    """Download Hadoop release tarball to the dest
    """
    if not os.path.exists(dest):
        os.makedirs(dest)

    tarball_file = os.path.basename(url)
    if url.startswith('http://') or url.startswith('https://'):
        tarball_file = os.path.basename(url)
        dest_file = os.path.join(dest, tarball_file)
        if os.path.exists(dest_file):
            logging.info("Tarball %s has been already downloaded, skip...", url)
            return
        logging.info("Downloading %s...", url)
        req = urllib2.urlopen(url)
        with open(dest_file, 'w') as fobj:
            fobj.write(req.read())

    check_call(['tar', '-xzf', tarball_file])


def make_new_dir(dirpath):
    """Make a new directory. If the directory exists, deletes it first.
    """
    if os.path.exists(dirpath):
        shutil.rmtree(dirpath)
    os.makedirs(dirpath)
    return dirpath


def dump_conf(conf, filepath):
    """Dump a configuration dict to the file.
    """
    parent = os.path.dirname(filepath)
    make_new_dir(parent)
    configuration = et.Element('configuration')
    tree = et.ElementTree(configuration)
    for key, val in conf.items():
        prop = et.SubElement(configuration, 'property')
        name = et.SubElement(prop, 'name')
        name.text = str(key)
        value = et.SubElement(prop, 'value')
        value.text = str(val)
    # Prettify XML outputs
    xml_string = et.tostring(tree.getroot(), 'utf-8')
    reparsed = minidom.parseString(xml_string)
    with open(filepath, 'w') as xml_file:
        xml_file.write(reparsed.toprettyxml(indent='  '))

def check_envs():
    """Check environments are set.
    """
    required_envs = ['JAVA_HOME']
    for env in required_envs:
        if os.getenv(env) is None:
            raise ValueError('%s is not set' % env)
