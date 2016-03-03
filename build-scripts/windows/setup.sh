#!/bin/bash -e
#
# OpenXT setup script.
# This script sets up the build host (just installs packages and adds a user),
# and sets up LXC containers to build OpenXT.
#
# Copyright (c) 2016 Assured Information Security, Inc.
#
# Contributions by Jean-Edouard Lejosne
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

NUMBER=$1
BUILD_USER=$2
MAC_PREFIX=$3
MAC_E=$4
ISO_URL=$5

MAC_ADDR=${MAC_PREFIX}:${MAC_E}:${NUMBER}

mkdir -p /home/windows/${BUILD_USER}
cd /home/windows/${BUILD_USER}

if [ -e disk ]; then
    echo "Windows disk already present, not setting up the Windows VM."
    exit
fi

[ -e win.iso ] || wget -O win.iso $ISO_URL

apt-get install qemu-kvm virtinst

virt-install \
    --virt-type kvm \
    --name ${BUILD_USER}-win \
    --memory 2048 \
    --cdrom /home/windows/${BUILD_USER}/win.iso \
    --disk /home/windows/${BUILD_USER}/disk,size=80 \
    -w bridge=${BUILD_USER}br0,mac=${MAC_ADDR} \
    --graphics vnc,listen=0.0.0.0,port=59${MAC_E}

echo "User action needed to install Windows"
echo "Please VNC to this machine, port 59${MAC_E}."
echo "Follow the wiki instructions for the installation:"
echo "https://openxt.atlassian.net/wiki/display/OD/How+to+build+OpenXT#HowtobuildOpenXT-Windowsbuildmachinesetup"
echo "The VM won't come back up after the first reboot,"
echo "  please type \"continue\" and press enter once you reach that point."

while read s; do
    [ "x$s" = "xcontinue" ] && break
done

virsh start ${BUILD_USER}-win

echo "The VM should come back now, please re-VNC."
echo "Finish the installation and setup the VM using the wiki instructions."
echo "This script will now terminate, use virsh to start/stop the VM if needed."
