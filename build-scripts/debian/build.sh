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
SUBNET_PREFIX=%SUBNET_PREFIX%
ALL_BUILDS_SUBDIR_NAME=%ALL_BUILDS_SUBDIR_NAME%

SBUILD="sbuild --purge-deps=never"

# Build
mkdir $BUILD_DIR
cd $BUILD_DIR
git clone https://github.com/OpenXT/pv-linux-drivers.git
git clone https://github.com/OpenXT/v4v.git
git clone https://github.com/OpenXT/xctools.git
cp -r v4v/v4v/linux v4v/libv4v/src/
cp -r v4v/v4v/include/xen v4v/libv4v/src/
mkdir all
cd all
for tool in ../pv-linux-drivers/openxt-*; do
    $SBUILD --dist=wheezy --arch-all $tool
done
$SBUILD --dist=wheezy --arch=i386  ../v4v/libv4v
$SBUILD --dist=wheezy --arch=amd64 ../v4v/libv4v
$SBUILD --dist=wheezy --arch=i386  ../xctools/xc-switcher
$SBUILD --dist=wheezy --arch=amd64 ../xctools/xc-switcher
cd - >/dev/null
mkdir wheezy
cd wheezy
# Build Wheezy-specific packages here.
cd - >/dev/null
mkdir jessie
cd jessie
# Build Jessie-specific packages here.
cd - >/dev/null

# Create a repository
mkdir repo
cd repo
mkdir conf
cat > conf/distributions <<EOF
Origin: OpenXT
Label: OpenXT
Codename: wheezy
Architectures: i386 amd64 source
Components: main
Description: Apt repository for OpenXT

Origin: OpenXT
Label: OpenXT
Codename: jessie
Architectures: i386 amd64 source
Components: main
Description: Apt repository for OpenXT
EOF
# Add the main packages to Wheezy
reprepro includedeb wheezy ../all/*.deb
# Add the main packages to Jessie
reprepro includedeb jessie ../all/*.deb
# Add Wheezy-specific packages to Wheezy
ls ../wheezy/*.deb >/dev/null 2>&1 && reprepro includedeb wheezy ../wheezy/*.deb
# Add Jessie-specific packages to Wheezy
ls ../jessie/*.deb >/dev/null 2>&1 && reprepro includedeb jessie ../jessie/*.deb
cd - >/dev/null

# Copy the resulting repository
scp -r repo "${BUILD_USER}@${SUBNET_PREFIX}.${IP_C}.1:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/debian"

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
