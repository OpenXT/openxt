#!/bin/sh

set -e

DUDE=%DUDE%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%

# Build
mkdir $BUILD_DIR
cd $BUILD_DIR
git clone -b lxc https://github.com/jean-edouard/pv-linux-drivers.git
git clone -b build-scripts https://github.com/jean-edouard/v4v.git
cp -r v4v/v4v/linux v4v/libv4v/src/
cp -r v4v/v4v/include/xen v4v/libv4v/src/
mkdir all
cd all
for tool in ../pv-linux-drivers/openxt-*; do
    sbuild --dist=wheezy --arch-all $tool
done
sbuild --dist=wheezy --arch=i386  ../v4v/libv4v
sbuild --dist=wheezy --arch=amd64 ../v4v/libv4v
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
scp -r repo ${DUDE}@192.168.${IP_C}.1:${BUILD_DIR}/debian

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
