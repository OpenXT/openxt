#!/bin/sh -e

DKMS_PACKAGES="openxt-v4v openxt-vusb openxt-xenmou"
OTHER_PACKAGES="libv4v"

echo "Installing required packages..."
#yum -y -t install centos-release-xen
#yum -y -t groupinstall "Development tools"
yum -y -t install epel-release
yum -y -t install yum-utils dkms kernel-devel

# Setup symlink symlink to fix kernel-devel path
CURRENT_KERNEL="`uname -r`"
# e.g. if CURRENT_KERNEL is 3.10.0-514.el7.x86_64, SHORT KERNEL is 3.10.0-514
SHORT_KERNEL="`echo $CURRENT_KERNEL | sed 's/\.[^\.]\+\.[^\.]\+$//'`"
if [ ! -e /usr/src/kernels/$CURRENT_KERNEL ]; then 
    src=`ls -d -1 /usr/src/kernels/${SHORT_KERNEL}* | head -1`
    ln -s $src /usr/src/kernels/$CURRENT_KERNEL
fi

# Setup symlinks to make dkms happy
for kernelpath in `ls -d /usr/src/kernels/*`; do
    kernel=`basename $kernelpath`
    mkdir -p /lib/modules/virt
    [ -e /lib/modules/virt/build ] || ln -s ${kernelpath} /lib/modules/virt/build
    [ -e /lib/modules/virt/source ] || ln -s ${kernelpath} /lib/modules/virt/source
done

echo "Removing old tools..."
# Kernel modules
for pkg in `yum list installed | cut -d '.' -f 1 | grep "^openxt-"`; do
    yum -y -t remove $pkg
    dkms remove -m ${pkg} -v 1.0 --all || true
    rm -rf /var/lib/dkms/${pkg}
    rm -rf /usr/src/${pkg}-1.0
done
# Others
for pkg in libv4v; do
    if [ `yum list installed | cut -d '.' -f 1 | grep "^${pkg}$"` ]; then
        yum -y -t remove $pkg
    fi
done
rm -rf /var/opt/openxt
# yum-config-manager --del-repo openxt
rm -f /etc/yum.repos.d/OpenXT.repo
rm -f /etc/modules-load.d/openxt.conf

echo "Copying the packages to /var/opt..."
mkdir -p /var/opt/openxt
cp -r rpms /var/opt/openxt/

echo "Adding the openxt repository to yum"
# yum-config-manager --add-repo file:///var/opt/openxt
cat > /etc/yum.repos.d/OpenXT.repo <<EOF
[openxt]
name=OpenXT
baseurl=file:///var/opt/openxt/rpms
EOF

echo "Installing the tools..."
yum -y -t --nogpgcheck install $DKMS_PACKAGES $OTHER_PACKAGES

echo "Adding the new kernel modules to /etc/modules-load.d/openxt.conf"
for package in `echo $DKMS_PACKAGES | sed 's/openxt-xenmou/xenmou/'`; do
    echo $package >> /etc/modules-load.d/openxt.conf
done

echo "Done. Reboot to enable the new kernel modules."
