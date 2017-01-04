# hadoop-compatibility
Tools for testing compatibility between Hadoop releases

## Requirements

- All machines need to run some Red Hat variant of Linux.
- 1 driver machine (tested with Fedora 24).
- 9 cluster machines for the rolling upgrade test (tested with CentOS 7.2).
    It's possible with fewer, but the default topology assumes 9.
- 14 cluster machines for the pull-over-http test (tested with CentOS 7.2).
    It's possible with fewer but the default topology assues 18.
- Recommend n1-standard-1 / n1-standard-2 instances on GCE, or m3.medium /
    m3.large instances on AWS.

All clusters are set up with high-availability. For other configuration details
see scripts/configure-hadoop.sh.

## Procedure
- *Edit env.sh*: At a minimum, you'll need to provide a path to the JDK RPM
    (and possibly update JAVA\_HOME), the HOST\_PREFIX and HOST\_SUFFIX
    (assumes there's a number between them in each hostname). If passwordless
    SSH is not already set up, you should also provide a universal SSH
    password. You may want to update other versions or tweak the topologies
    defined in the *\_cluster\_env functions.
- *Get Hadoop releases or build environment*: You'll need to either place the
    required Hadoop release tarballs in the home directory, or ensure that the
    toolchain and environment setup to build it has been done.
- *Run test scripts*: pull-over-http-test.sh will test that you can pull data 
    from a cluster running the old version (as defined in old\_cluster\_env) to
    a cluster running the new version (as defined in new\_cluster\_env).
    rolling-upgrade-test.sh will test that YARN applications can continuously
    run during and after a rolling upgrade.
