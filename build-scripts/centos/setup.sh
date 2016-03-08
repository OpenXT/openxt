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

CONTAINER_USER=%CONTAINER_USER%

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
adduser ${CONTAINER_USER}
mkdir -p /home/${CONTAINER_USER}/.ssh
touch /home/${CONTAINER_USER}/.ssh/authorized_keys
touch /home/${CONTAINER_USER}/.ssh/known_hosts
ssh-keygen -N "" -t dsa -C ${CONTAINER_USER}@openxt-centos -f /home/${CONTAINER_USER}/.ssh/id_dsa
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.ssh

# Make the user a passwordless sudoer, as dkms unfortunately needs to run as root
echo "${CONTAINER_USER}   ALL=(ALL)       NOPASSWD:ALL" >> /etc/sudoers
