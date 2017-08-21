#!/bin/bash -e
#
# OpenXT setup script.
# This script sets up the build host (just installs packages and adds a user),
# and sets up LXC containers to build OpenXT.
#
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

# -- Script default configuration settings.

# The name of the user for which a build environment will be setup
# The script will create it if it doesn't exist
BUILD_USER="openxt"

# The FQDN path for the Debian mirror
# (some chroots don't inherit the resolv.conf search domain)
# eg. DEBIAN_MIRROR="http://httpredir.debian.org/debian"
DEBIAN_MIRROR="http://httpredir.debian.org/debian"

# The name of the local user created inside the containers
CONTAINER_USER="build"

# This /16 subnet prefix is used for networking in the containers.
# Strongly advised to use part of the private IP address space (eg. "192.168")
SUBNET_PREFIX="172.21"

# Ethernet mac address prefix for the container vnics. (eg. "00:FF:AA:42")
MAC_PREFIX="00:FF:AA:42"

# Teardown container on setup failure? 1: yes, anything-else: no.
REMOVE_CONTAINER_ON_ERROR=1

# The directory that will be used to mirror and serve git repositories
# Note: if you want to host other git repositories on this machine,
#   it is recommended to use this root path for them too,
#   and to use the code from build.sh to start the git service
GIT_ROOT_PATH="/home/git"

# URL to a Windows installer ISO
WINDOWS_ISO_URL=""

NO_OE=
NO_DEBIAN=
NO_CENTOS=
NO_WINDOWS=

# -- End of script configuration settings.

usage() {
    cat >&2 <<EOF
usage: $0 [-h] [-O] [-D] [-C] [-W] [-u build_user] [-d debian_mirror]
                  [-c container_user] [-s subnet_prefix] [-m mac_prefix]
                  [-r remove_container_on_error] [-g git_root_path]
                  [-w windows_iso_url]
  -h: help
  -O: Do not setup the OpenEmbedded container, not recommended
  -D: Do not setup the Debian container
  -C: Do not setup the Centos container
  -W: Do not setup the Windows VM even if an iso was provided with -w

 Note: debian_mirror   must be the full URL to a Debian mirror,
   like in the example below
 Note: windows_iso_url must be an http URL to a Windows 32 bits iso

 Example (defaults): $0					\\
                     -u openxt					\\
                     -d http://httpredir.debian.org/debian	\\
                     -c build					\\
                     -s 172.21					\\
                     -m 00:FF:AA:42				\\
                     -r 1					\\
                     -g /home/git

 Important: this script will create containers that could grow to
   ~100GB in size. By default, lxc stores containers in /var/lib/lxc.
   Make sure there's enough room there, or change that location by:
     - Installing lxc: apt-get install lxc
     - Runing: echo "lxc.lxcpath = <path>" >> /etc/lxc/lxc.conf
EOF
    exit $1
}


while getopts "hODCWu:d:c:s:m:r:g:w:" opt; do
    case $opt in
        h)
            usage 0
            ;;
        O)
            NO_OE=1
            ;;
        D)
            NO_DEBIAN=1
            ;;
        C)
            NO_CENTOS=1
            ;;
        W)
            NO_WINDOWS=1
            ;;
        u)
            BUILD_USER="${OPTARG}"
            ;;
        d)
            DEBIAN_MIRROR="${OPTARG}"
            ;;
        c)
            CONTAINER_USER="${OPTARG}"
            ;;
        s)
            SUBNET_PREFIX="${OPTARG}"
            ;;
        m)
            MAC_PREFIX="${OPTARG}"
            ;;
        r)
            REMOVE_CONTAINER_ON_ERROR=${OPTARG}
            ;;
        g)
            GIT_ROOT_PATH="${OPTARG}"
            ;;
        w)
            WINDOWS_ISO_URL="${OPTARG}"
            ;;
        \?)
            usage 1
            ;;
    esac
done

if [ "x${UID}" != "x0" ] ; then
    echo "Error: This script needs to be run as root.">&2
    exit 2
fi

if [ ! -f /etc/debian_version ]; then
    echo "Sorry, this script only works on Debian for now.">&2
    exit 4
fi

# Ensure that all required packages are installed on this host.
# When installing packages, do all at once to be faster.
DEB_PKGS="lxc bridge-utils libvirt-daemon-system libvirt-clients curl jq genisoimage git"
DEB_PKGS="$DEB_PKGS syslinux-utils openssl unzip rsync ebtables dnsmasq"
DEB_PKGS="$DEB_PKGS haveged" # seeds entropy
DEB_PKGS="$DEB_PKGS debootstrap" # Debian container
DEB_PKGS="$DEB_PKGS librpm3 librpmbuild3 librpmio3 libsqlite0 python-rpm \
python-sqlite python-sqlitecachec python-urlgrabber rpm \
rpm-common rpm2cpio yum" # Centos container

# Version-specific Debian packages
DEB_VERS=`cut -d '.' -f 1 /etc/debian_version`
if [ $DEB_VERS -ge 9 ]; then   # Debian Stretch and later
    DEB_PKGS="$DEB_PKGS libvirt-daemon-system libvirt-clients librpmsign3"
else                           # Debian Jessie and earlier
    DEB_PKGS="$DEB_PKGS libvirt-bin librpmsign1 python-support"
fi

apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get install $DEB_PKGS || apt-get install $DEB_PKGS

# Ensure that the build user exists on the host
if [ ! `cut -d ":" -f 1 /etc/passwd | grep "^${BUILD_USER}$"` ]; then
    echo "Creating ${BUILD_USER} user for building, please choose a password."
    adduser --gecos "" ${BUILD_USER}
    BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
    mkdir -p "${BUILD_USER_HOME}/.ssh"
    touch "${BUILD_USER_HOME}"/.ssh/authorized_keys
    touch "${BUILD_USER_HOME}"/.ssh/known_hosts
    touch "${BUILD_USER_HOME}"/.ssh/config
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh
else
    # The user exists, check and verbosely fix missing configuration bits
    BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
    if [ ! -d "${BUILD_USER_HOME}"/.ssh ]; then
        echo "${BUILD_USER} has no SSH directory, creating one."
        mkdir -p "${BUILD_USER_HOME}"/.ssh
        chown ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh
    fi
    if [ ! -f "${BUILD_USER_HOME}"/.ssh/authorized_keys ]; then
        echo "${BUILD_USER} has no SSH authorized_keys file, creating one."
        touch "${BUILD_USER_HOME}"/.ssh/authorized_keys
        chown ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh/authorized_keys
    fi
    if [ ! -f "${BUILD_USER_HOME}"/.ssh/known_hosts ]; then
        echo "${BUILD_USER} has no SSH known_hosts file, creating one."
        touch "${BUILD_USER_HOME}"/.ssh/known_hosts
        chown ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh/known_hosts
    fi
    if [ ! -f "${BUILD_USER_HOME}"/.ssh/config ]; then
        echo "${BUILD_USER} has no SSH config file, creating one."
        touch "${BUILD_USER_HOME}"/.ssh/config
        chown ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh/config
    fi
fi

# Create an SSH key for the user, to communicate with the containers
if [ ! -d "${BUILD_USER_HOME}"/ssh-key ]; then
    mkdir "${BUILD_USER_HOME}"/ssh-key
    ssh-keygen -N "" -t rsa -f "${BUILD_USER_HOME}"/ssh-key/openxt
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/ssh-key
fi

# Create build certs
if [ ! -d "${BUILD_USER_HOME}"/certificates ]; then
    mkdir "${BUILD_USER_HOME}"/certificates
    openssl genrsa -out "${BUILD_USER_HOME}"/certificates/prod-cakey.pem 2048
    openssl genrsa -out "${BUILD_USER_HOME}"/certificates/dev-cakey.pem 2048
    openssl req -new -x509 -key "${BUILD_USER_HOME}"/certificates/prod-cakey.pem \
            -out "${BUILD_USER_HOME}"/certificates/prod-cacert.pem -days 1095 \
            -subj "/C=US/ST=Massachusetts/L=Boston/O=OpenXT/OU=OpenXT/CN=openxt.org"
    openssl req -new -x509 -key "${BUILD_USER_HOME}"/certificates/dev-cakey.pem \
            -out "${BUILD_USER_HOME}"/certificates/dev-cacert.pem -days 1095 \
            -subj "/C=US/ST=Massachusetts/L=Boston/O=OpenXT/OU=OpenXT/CN=openxt.org"
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/certificates
fi

# Make up a network range ${SUBNET_PREFIX}.(150 + uid % 100).0
# And a MAC range ${MAC_PREFIX}:(uid % 100):01
BUILD_USER_ID=$(id -u ${BUILD_USER})
IP_C=$(( 150 + ${BUILD_USER_ID} % 100 ))
MAC_E=$(( ${BUILD_USER_ID} % 100 ))
if [ ${MAC_E} -lt 10 ] ; then
    MAC_E="0${MAC_E}"
fi

# Setup LXC networking on the host, to give known IPs to the containers
if [ ! -f /etc/libvirt/qemu/networks/${BUILD_USER}.xml ]; then
    mkdir -p /etc/libvirt/qemu/networks
    cat > /etc/libvirt/qemu/networks/${BUILD_USER}.xml <<EOF
<network>
  <name>${BUILD_USER}</name>
  <bridge name="${BUILD_USER}br0"/>
  <forward/>
  <ip address="${SUBNET_PREFIX}.${IP_C}.1" netmask="255.255.255.0">
    <dhcp>
      <range start="${SUBNET_PREFIX}.${IP_C}.2" end="${SUBNET_PREFIX}.${IP_C}.254"/>
      <host mac="${MAC_PREFIX}:${MAC_E}:01" name="${BUILD_USER}-oe"      ip="${SUBNET_PREFIX}.${IP_C}.101" />
      <host mac="${MAC_PREFIX}:${MAC_E}:02" name="${BUILD_USER}-debian"  ip="${SUBNET_PREFIX}.${IP_C}.102" />
      <host mac="${MAC_PREFIX}:${MAC_E}:03" name="${BUILD_USER}-centos"  ip="${SUBNET_PREFIX}.${IP_C}.103" />
      <host mac="${MAC_PREFIX}:${MAC_E}:04" name="${BUILD_USER}-windows" ip="${SUBNET_PREFIX}.${IP_C}.104" />
    </dhcp>
  </ip>
</network>
EOF
    /etc/init.d/libvirtd restart
    virsh net-autostart ${BUILD_USER}
fi
virsh net-start ${BUILD_USER} >/dev/null 2>&1 || true

# Setup a mirror of the git repositories for the build to be consistent
# (and slightly faster)
if [ ! -d ${GIT_ROOT_PATH} ]; then
    mkdir ${GIT_ROOT_PATH}
    chown nobody:nogroup ${GIT_ROOT_PATH}
    chmod 777 ${GIT_ROOT_PATH}
fi
if [ ! -d ${GIT_ROOT_PATH}/${BUILD_USER} ]; then
    mkdir -p ${GIT_ROOT_PATH}/${BUILD_USER}
    cd ${GIT_ROOT_PATH}/${BUILD_USER}
    echo "Mirroring the OpenXT repositories..."
    for repo in \
        $(curl -s "https://api.github.com/orgs/OpenXT/repos?per_page=100" | \
          jq '.[].name' | cut -d '"' -f 2 | sort -u)
    do
        git clone --quiet --mirror https://github.com/OpenXT/${repo}.git
    done
    echo "Done"
    cd - > /dev/null
    chown -R ${BUILD_USER}:${BUILD_USER} ${GIT_ROOT_PATH}/${BUILD_USER}
fi

# Copy the main build scripts to the home directory of the user
cp -f build.sh "${BUILD_USER_HOME}/"
cp -f clean.sh "${BUILD_USER_HOME}/"
cp -f fetch.sh "${BUILD_USER_HOME}/"
sed -i "s|\%CONTAINER_USER\%|${CONTAINER_USER}|" ${BUILD_USER_HOME}/build.sh
sed -i "s|\%SUBNET_PREFIX\%|${SUBNET_PREFIX}|" ${BUILD_USER_HOME}/build.sh
sed -i "s|\%CONTAINER_USER\%|${CONTAINER_USER}|" ${BUILD_USER_HOME}/clean.sh
sed -i "s|\%SUBNET_PREFIX\%|${SUBNET_PREFIX}|" ${BUILD_USER_HOME}/clean.sh
sed -i "s|\%GIT_ROOT_PATH\%|${GIT_ROOT_PATH}|" ${BUILD_USER_HOME}/fetch.sh
chown ${BUILD_USER}:${BUILD_USER} ${BUILD_USER_HOME}/build.sh
chown ${BUILD_USER}:${BUILD_USER} ${BUILD_USER_HOME}/clean.sh
chown ${BUILD_USER}:${BUILD_USER} ${BUILD_USER_HOME}/fetch.sh

LXC_PATH=`lxc-config lxc.lxcpath`

setup_container() {
    local NUMBER=$1           # 01
    local NAME=$2             # oe
    local TEMPLATE=$3         # debian
    local MIRROR=$4           # http://httpredir.debian.org/debian
    local TEMPLATE_OPTIONS=$5 # --arch i386 --release squeeze

    # Skip setup if the container already exists
    if [ `lxc-ls | grep -w ${BUILD_USER}-${NAME}` ]; then
        echo "Container ${BUILD_USER}-${NAME} already exists, skipping."
        return
    fi

    # Create the container
    echo "Creating the ${NAME} container..."
    MIRROR=${MIRROR} lxc-create -n "${BUILD_USER}-${NAME}" -t $TEMPLATE -- $TEMPLATE_OPTIONS
    cat >> ${LXC_PATH}/${BUILD_USER}-${NAME}/config <<EOF
# Autostart
lxc.start.auto = 1
lxc.start.delay = 5

# Network
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = ${BUILD_USER}br0
lxc.network.hwaddr = ${MAC_PREFIX}:${MAC_E}:${NUMBER}
lxc.network.ipv4 = 0.0.0.0/24
EOF

    local ROOTFS=${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs

    echo "Configuring the ${NAME} container..."
    #mount -o bind /dev ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/dev

    set +e
    cat ${NAME}/setup.sh | \
        sed "s|\%MIRROR\%|${MIRROR}|" | \
        sed "s|\%CONTAINER_USER\%|${CONTAINER_USER}|" | \
        chroot ${ROOTFS} /bin/bash -e

    # If the in-container setup script failed, check our configuration to see
    # whether to destroy the container so that it can be recreated and setup
    # reattempted when this script is rerun.
    if [ $? != 0 ] ; then
        echo "Failure executing in-container setup for ${NAME}. Abort.">&2
        if [ "x${REMOVE_CONTAINER_ON_ERROR}" == "x1" ] ; then
            lxc-destroy -n "${BUILD_USER}-${NAME}" || echo \
                "Error tearing down container ${BUILD_USER}-${NAME}">&2
        fi
        exit 3
    fi
    set -e

    #umount ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/dev

    # Find the UID and GID of CONTAINER_USER
    local cpasswd=`grep "^${CONTAINER_USER}:" ${ROOTFS}/etc/passwd`
    local cuid=`echo $cpasswd | cut -d ':' -f 3`
    local cgid=`echo $cpasswd | cut -d ':' -f 4`

    # Allow the host to SSH to the container
    cat "${BUILD_USER_HOME}"/ssh-key/openxt.pub \
        >> ${ROOTFS}/home/${CONTAINER_USER}/.ssh/authorized_keys
    chown ${cuid}:${cgid} ${ROOTFS}/home/${CONTAINER_USER}/.ssh/authorized_keys

    # Allow the container to SSH to the host
    cat ${ROOTFS}/home/${CONTAINER_USER}/.ssh/id_rsa.pub \
        >> "${BUILD_USER_HOME}"/.ssh/authorized_keys

    ssh-keyscan -H ${SUBNET_PREFIX}.${IP_C}.1 \
                >> ${ROOTFS}/home/${CONTAINER_USER}/.ssh/known_hosts
    chown ${cuid}:${cgid} ${ROOTFS}/home/${CONTAINER_USER}/.ssh/known_hosts

    # Add config bits to easily ssh to the container
    cat >> "${BUILD_USER_HOME}/.ssh/config" <<EOF
Host ${NAME}
        HostName ${SUBNET_PREFIX}.${IP_C}.1${NUMBER}
        User ${CONTAINER_USER}
        IdentityFile ~/ssh-key/openxt

EOF

    # Copy the build certificates into the container for signing build bits
    cp -r "${BUILD_USER_HOME}"/certificates \
       ${ROOTFS}/home/${CONTAINER_USER}/certs
    chown -R ${cuid}:${cgid} ${ROOTFS}/home/${CONTAINER_USER}/certs

    # Copy resolv.conf over for networking, shouldn't be needed
    #cp /etc/resolv.conf ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/etc/resolv.conf

    # Start the container
    lxc-start -d -n "${BUILD_USER}-${NAME}"
}

# Create a container for the main part of the OpenXT build
[ -z $NO_OE ] && setup_container "01" "oe" \
                "debian" "${DEBIAN_MIRROR}" "--arch i386  --release jessie"

# Create a container for the Debian tool packages for OpenXT
[ -z $NO_DEBIAN ] && setup_container "02" "debian" \
                "debian" "${DEBIAN_MIRROR}" "--arch amd64 --release jessie"

# Create a container for the Centos tool packages for OpenXT
[ -z $NO_CENTOS ] && setup_container "03" "centos" \
                "centos" "" "--arch x86_64 --release 7"

# Create a Windows VM
if [ -z $NO_WINDOWS ] && [ "x${WINDOWS_ISO_URL}" != "x" ]; then
    cd windows
    ./setup.sh "04" "${BUILD_USER}" \
               "${MAC_PREFIX}" "${MAC_E}" "${WINDOWS_ISO_URL}" \
               "${SUBNET_PREFIX}.${IP_C}"
    cd - > /dev/null
fi

echo "Done! Now login as ${BUILD_USER} and run ~/build.sh to start a build."
