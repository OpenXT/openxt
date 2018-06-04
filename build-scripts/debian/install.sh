#!/bin/sh
# This script installs the Debian tools into Debian-based guests.
# Tested on Debian Wheezy, Debian Jessie and Ubuntu 16.04.

set -e

cd `dirname $0`

VERSION=%VERSION%
DKMS_PACKAGES="v4v-dkms openxt-vusb-dkms openxt-xenmou-dkms"
OTHER_PACKAGES="libv4v"

DEBIAN_NAME=jessie
DEBIAN_VERSION=`cut -d '.' -f 1 /etc/debian_version 2>/dev/null`
[ "x$DEBIAN_VERSION" = "x7" ] && DEBIAN_NAME=wheezy

echo "Removing old tools..."
# Kernel modules
for pkg in `dpkg -l | awk '{print $2}' | grep "^openxt-.*-dkms$"`; do
    apt-get -y remove --purge $pkg
done
# Others
for pkg in libv4v; do
    if [ `dpkg -l | awk '{print $2}' | grep "^${pkg}$"` ]; then
        apt-get -y remove $pkg
    fi
done
rm -rf /var/opt/openxt
rm -f /etc/apt/sources.list.d/openxt.list
rm -f /etc/modules-load.d/openxt.conf

echo "Copying the packages to /var/opt..."
mkdir -p /var/opt/openxt
cp -r debian /var/opt/openxt/

echo "Writing /etc/apt/sources.list.d/openxt.list"
cat > /etc/apt/sources.list.d/openxt.list <<EOF
deb file:///var/opt/openxt/debian $DEBIAN_NAME main
EOF

echo "Installing the tools..."
apt-get update
apt-get -y --force-yes install $DKMS_PACKAGES $OTHER_PACKAGES

echo "Adding the new kernel modules to /etc/modules-load.d/openxt.conf"
for package in `echo $DKMS_PACKAGES | sed 's/-dkms//g' | sed 's/openxt-xenmou/xenmou/'`; do
    echo $package >> /etc/modules-load.d/openxt.conf
done

echo "Writing the tools version to xenstore..."
apt-get -y install xenstore-utils
MAJORVERSION=$(echo "${VERSION}" | cut -d. -f1)
MINORVERSION=$(echo "${VERSION}" | cut -d. -f2)
MICROVERSION=$(echo "${VERSION}" | cut -d. -f3)
BUILDVERSION=$(echo "${VERSION}" | cut -d. -f4)
mount -t xenfs none /proc/xen || true
xenstore-exists attr || xenstore-write "attr" ""
xenstore-exists "attr/PVAddons" || xenstore-write "attr/PVAddons" ""
xenstore-write "attr/PVAddons/Installed"  "1"
xenstore-write "attr/PVAddons/MajorVersion"  "${MAJORVERSION}"
xenstore-write "attr/PVAddons/MinorVersion"  "${MINORVERSION}"
xenstore-write "attr/PVAddons/MicroVersion"  "${MICROVERSION}"
xenstore-write "attr/PVAddons/BuildVersion"  "${BUILDVERSION}"

echo "Done. Reboot to enable the new kernel modules."
