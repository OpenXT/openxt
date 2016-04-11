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
IP_PREFIX=$6

MAC_ADDR=${MAC_PREFIX}:${MAC_E}:${NUMBER}
IP=${IP_PREFIX}.1${NUMBER}
BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"

continue_or_fail() {
    cat <<EOF

Please type "continue" and press enter once you reach that point,
    or type "fail" if anything went wrong, and I'll wipe out the VM so you can try again
EOF

    while read s; do
        echo
        [ "x$s" = "xcontinue" ] && break
        [ "x$s" = "xfail" ] && {
            echo "Trying to shutdown and remove the VM..." >&2
            set +e
            set -x
            virsh destroy ${vm_name}
            virsh undefine ${vm_name}
            virsh vol-delete --pool ${disk_pool} disk
            virsh pool-destroy ${disk_pool}
            virsh pool-delete ${disk_pool}
            virsh pool-undefine ${disk_pool}
            /etc/init.d/libvirtd restart
            exit 1
        }
    done
}

mkdir -p /home/${BUILD_USER}/windows
cd /home/${BUILD_USER}/windows

disk_pool=${BUILD_USER}-pool
vm_name=${BUILD_USER}-win
mkdir -p $disk_pool

if [ -e ${disk_pool}/disk ]; then
    echo "Windows disk already present, not setting up the Windows VM."
    exit
fi

[ -e win.iso ]   || wget -O win.iso $ISO_URL
[ -e tools.iso ] || wget -O tools.iso 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'

apt-get install qemu-kvm virtinst

virt-install \
    --virt-type kvm \
    --name ${vm_name} \
    --memory 2048 \
    --disk /home/${BUILD_USER}/windows/${disk_pool}/disk,bus=virtio,size=80 \
    --disk /home/${BUILD_USER}/windows/win.iso,device=cdrom,bus=ide \
    --disk /home/${BUILD_USER}/windows/tools.iso,device=cdrom,bus=ide \
    -w bridge=${BUILD_USER}br0,mac=${MAC_ADDR},model=virtio \
    --graphics vnc,listen=0.0.0.0,port=59${MAC_E} \
    --noautoconsole \
    --autostart || {
    rm /home/${BUILD_USER}/windows/${disk_pool}/disk
    echo "virt-install failed. Please make sure vt-x is enabled."
    echo "If it is, try to rmmod kvm_intel and kvm and modprobe them back."
    echo "Then restart this script."
    exit 2
}

cat <<EOF


------ IMPORTANT, please read ------

User action is needed to install Windows
Please VNC to this machine, port 59${MAC_E}. If the connection breaks, just re-VNC.

- Windows won't find a driver for the disk.
  Click "Load driver" and use the "viostor" driver from the second CDROM drive.

- The VM won't come back up after the first reboot,
EOF

continue_or_fail

virsh start ${BUILD_USER}-win

cat <<EOF


------ IMPORTANT, please read ------

- I ran "virsh start ${BUILD_USER}-win", the VM should come back now, please re-VNC.

- Once the installation is finished, install the network driver ("NetKVM" on the CD)

- Install all the critical upgrades from Windows update

- Follow the wiki instructions to install the packages needed for building the OpenXT tools:
  https://openxt.atlassian.net/wiki/display/OD/How+to+build+OpenXT#HowtobuildOpenXT-Windowsbuildmachinesetup
  and install the guest RPC tool
OR
- Disable UAC, Set-ExecutionPolicy Unrestricted, install git, open Administrator cmd and run:
  cd \\
  git clone https://github.com/OpenXT/openxt.git
  cd openxt\\windows
  powershell .\mkbuildserver.ps1

- Reboot the VM and wait for winbuildd to come up
EOF

continue_or_fail

cd - > /dev/null

set +e
get_ssh_public_key="curl -s -m 5 -H \"Content-Type: text/xml\" --data @xmls/xml_get_ssh_public_key http://${IP}:6288"
ssh_public_key=`$get_ssh_public_key | xmllint --xpath 'string(methodResponse/params/param/value/string)' -`
while [ -z "$ssh_public_key" ]; do
    echo "winbuildd is not installed/running/configured properly."
    continue_or_fail
    ssh_public_key=`$get_ssh_public_key | xmllint --xpath 'string(methodResponse/params/param/value/string)' -`
done
echo "$ssh_public_key" >> ${BUILD_USER_HOME}/.ssh/authorized_keys
set -e

echo
echo 'Success! The Windows build VM is now properly configured.'
echo
