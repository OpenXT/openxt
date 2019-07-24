#!/bin/sh
# This script installs the Debian tools into Debian-based guests.
# Tested on Debian Wheezy, Debian Jessie and Ubuntu 16.04.

set -e

cd `dirname $0`

VERSION=%VERSION%
DKMS_PACKAGES="openxt-vusb-dkms"

DEBIAN_NAME=jessie
DEBIAN_VERSION=`cut -d '.' -f 1 /etc/debian_version 2>/dev/null || true`
[ "x$DEBIAN_VERSION" = "x7" ] && DEBIAN_NAME=wheezy

echo "Removing old tools..."
# Kernel modules
for pkg in `dpkg -l | awk '{print $2}' | grep "^openxt-.*-dkms$\|^v4v-dkms$"`; do
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
deb [trusted=yes] file:///var/opt/openxt/debian $DEBIAN_NAME main
EOF

echo "Installing the tools..."
apt-get update
apt-get -y --force-yes install linux-headers-$(uname -r) $DKMS_PACKAGES

mod_dir=/etc/modules-load.d
mod_file=$mod_dir/openxt.conf

# Handle the non-systemd case
[ ! -d $mod_dir ] && mod_file=/etc/modules

echo "Adding the new kernel modules to $mod_file"
for package in `echo $DKMS_PACKAGES | sed 's/-dkms//g' | sed 's/openxt-xenmou/xenmou/'`; do
    echo $package >> $mod_file
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
