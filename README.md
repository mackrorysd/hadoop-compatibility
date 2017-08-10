# hadoop-compatibility
Tools for testing compatibility between Hadoop releases

## Requirements

This testing is now done using the Hadoop's Dockerfile, so it should have no
unusual external dependencies, but it assumes an Ubuntu 16.04 host. The rolling
upgrade test has been successully run on a machine with 16 CPU cores and 60 GB
of RAM (n1-standard-16 on GCE).

Testing was previously done on a virtualized cluster of CentOS 7 machines, but
changes are necessary to ensure a working toolchain to build and run Hadoop.
See previous iterations for details.

All clusters are set up with high-availability. For other configuration details
see scripts/configure-hadoop.sh.

## Procedure

Simply run ./docker-rolling-upgrade.sh - it should do everything else.

./rolling-upgrade.sh can be used on other environments assuming a working
toolchain for building and running Hadoop and the appropriate networking
configuration is already setup.
