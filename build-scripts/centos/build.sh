#!/bin/sh
# Copyright (c) 2016 Assured Information Security, Inc.
# Copyright (c) 2016 BAE Systems
#
# Contributions by Jean-Edouard Lejosne
# Contributions by Christopher Clark
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

set -e

BUILD_USER=%BUILD_USER%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%
BUILD_ID=%BUILD_ID%
BRANCH=%BRANCH%
SUBNET_PREFIX=%SUBNET_PREFIX%
ALL_BUILDS_SUBDIR_NAME=%ALL_BUILDS_SUBDIR_NAME%

GIT_MIRROR=git://${SUBNET_PREFIX}.${IP_C}.1/${BUILD_USER}

# On first build, setup Oracle
if [ ! -e ~/oracled ]; then
    while [ ! -f /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip ]; do
        echo "Please scp oracle-xe-11.2.0-1.0.x86_64.rpm.zip to my /tmp."
        echo "  example: scp oracle-xe-11.2.0-1.0.x86_64.rpm.zip centos:/tmp"
        sleep 60
    done
    unzip /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip
    sudo rpm -ivh Disk1/oracle-xe-11.2.0-1.0.x86_64.rpm
    sudo /etc/init.d/oracle-xe configure <<EOF


xenroot
xenroot

EOF
    . /u01/app/oracle/product/11.2.0/xe/bin/oracle_env.sh
    sudo -E pip install cx_Oracle
    touch ~/oracled
fi

mkdir -p $BUILD_DIR/repo/RPMS
cd $BUILD_DIR

KERNEL_VERSION=`ls /lib/modules | tail -1`

rm -rf pv-linux-drivers
rm -rf v4v
git clone -b $BRANCH $GIT_MIRROR/pv-linux-drivers.git
git clone -b $BRANCH $GIT_MIRROR/v4v.git

# Build the dkms tools
for i in pv-linux-drivers/openxt-{vusb,xenmou} v4v/v4v; do
    tool=`basename $i`

    # Remove package
    sudo dkms remove -m ${tool} -v 1.0 --all || true
    sudo rm -rf /var/lib/dkms/${tool}
    sudo rm -rf /usr/src/${tool}-1.0

    # Fetch package
    sudo cp -r ${i} /usr/src/${tool}-1.0

    # Build package
    sudo dkms add -m ${tool} -v 1.0
    sudo dkms build -m ${tool} -v 1.0 -k ${KERNEL_VERSION}
    sudo dkms mkrpm -m ${tool} -v 1.0 -k ${KERNEL_VERSION}
    cp /var/lib/dkms/${tool}/1.0/rpm/* repo/RPMS
done

# Build the binary tools
# Note: only building for 64 bits target. Building for 32 bits requires a chroot
rm -rf repo/SOURCES/libv4v* libv4v-1.0
mkdir -p repo/SOURCES libv4v-1.0
cp -ar v4v/libv4v/* libv4v-1.0
cp -ar v4v/v4v/include/linux v4v/v4v/include/xen libv4v-1.0/src
tar cjf repo/SOURCES/libv4v.tar.gz libv4v-1.0
rpmbuild --target=x86_64 --noclean --define="_topdir `pwd`/repo" -bb -v v4v/libv4v/libv4v.spec
# The following succeeds but actually builds 64 bits binaries...
#setarch i686 rpmbuild --target=i686 --noclean --define="_topdir `pwd`" -bb -v v4v/libv4v/libv4v.spec

# Build syncxt
rm -rf openxt
git clone -b $BRANCH $GIT_MIRROR/openxt.git
cd openxt
OPENXT_DIR=`pwd`
mkdir src
cd src
git clone -b $BRANCH $GIT_MIRROR/sync-database.git
git clone -b $BRANCH $GIT_MIRROR/sync-cli.git
git clone -b $BRANCH $GIT_MIRROR/sync-server.git
git clone -b $BRANCH $GIT_MIRROR/sync-ui-helper.git
cd ..
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/u01/app/oracle/product/11.2.0/xe/lib"
./do_sync_xt.sh -i $BUILD_ID ${OPENXT_DIR}
cd ..
cp openxt/out/* repo/RPMS

# Create the repo
createrepo repo

# Copy the resulting repository
scp -r repo "${BUILD_USER}@${SUBNET_PREFIX}.${IP_C}.1:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/rpms"

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
