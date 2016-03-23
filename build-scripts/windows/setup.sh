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

[ -e win.iso ]   || wget -O win.iso $ISO_URL
[ -e tools.iso ] || wget -O tools.iso 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'

apt-get install qemu-kvm virtinst

virt-install \
    --virt-type kvm \
    --name ${BUILD_USER}-win \
    --memory 2048 \
    --disk /home/windows/${BUILD_USER}/disk,bus=virtio,size=80 \
    --disk /home/windows/${BUILD_USER}/win.iso,device=cdrom,bus=ide \
    --disk /home/windows/${BUILD_USER}/tools.iso,device=cdrom,bus=ide \
    -w bridge=${BUILD_USER}br0,mac=${MAC_ADDR},model=virtio \
    --graphics vnc,listen=0.0.0.0,port=59${MAC_E}

cat <<EOF


------ IMPORTANT, please read ------

User action is needed to install Windows
Please VNC to this machine, port 59${MAC_E}. If the connection breaks, just re-VNC.

- Windows won't find a driver for the disk.
  Click "Load driver" and use the "viostor" driver from the second CDROM drive.

- The VM won't come back up after the first reboot,
  please type "continue" and press enter once you reach that point.
EOF

while read s; do
    [ "x$s" = "xcontinue" ] && break
done

virsh start ${BUILD_USER}-win

cat <<EOF


------ IMPORTANT, please read ------

- I ran "virsh start ${BUILD_USER}-win", the VM should come back now, please re-VNC.

- Once the installation is finished, install the network driver ("NetKVM" on the CD)

- Install all the critical upgrades from Windows update

- Follow the wiki instructions to install the packages needed for building the OpenXT tools:
  https://openxt.atlassian.net/wiki/display/OD/How+to+build+OpenXT#HowtobuildOpenXT-Windowsbuildmachinesetup

- Install the guest RPC tool

IMPORTANT: This script will terminate in 1 minute, but the Windows VM will stay alive.
           Use virsh to start/stop the VM as needed.
EOF

sleep 60
