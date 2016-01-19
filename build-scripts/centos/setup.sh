#!/bin/sh

# Remove the root password
passwd -d root

# Install required packages
# The following line must be done first,
#  it will make the next yum command use the correct packages
yum -y install centos-release-xen
yum -y groupinstall "Development tools"
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install rpm-build createrepo which sudo git which wget gcc make kernel-devel tar dkms libaio bc iproute2 net-tools python-devel python-argparse python-pip

# Setup symlinks to make dkms happy
for kernelpath in `ls -d /usr/src/kernels/*`; do
    kernel=`basename $kernelpath`
    mkdir -p /lib/modules/virt
    [ -e /lib/modules/virt/build ] || ln -s ${kernelpath} /lib/modules/virt/build
    [ -e /lib/modules/virt/source ] || ln -s ${kernelpath} /lib/modules/virt/source
done

# Add a build user
adduser build
mkdir -p /home/build/.ssh
touch /home/build/.ssh/authorized_keys
ssh-keygen -N "" -t dsa -C build@openxt-centos -f /home/build/.ssh/id_dsa
chown -R build:build /home/build/.ssh

# Make the user a passwordless sudoer, as dkms unfortunately needs to run as root
echo "build   ALL=(ALL)       NOPASSWD:ALL" >> /etc/sudoers
