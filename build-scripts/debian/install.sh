#!/bin/sh -e

DEBIAN_VERSION=`cut -d '.' -f 1 /etc/debian_version`
DEBIAN_NAME=
DKMS_PACKAGES="openxt-v4v-dkms openxt-vusb-dkms openxt-xenmou-dkms"
OTHER_PACKAGES="libv4v"

case $DEBIAN_VERSION in
    7 )
        DEBIAN_NAME=wheezy
        ;;
    8 )
        DEBIAN_NAME=jessie
        ;;
    9 )
        DEBIAN_NAME=stretch
        echo "Debian Stretch not supported yet, exiting."
        exit 1
        ;;
    * )
        echo "Unable to figure out the Debian version, exiting."
        exit 1
        ;;
esac

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

echo "Done. Reboot to enable the new kernel modules."
