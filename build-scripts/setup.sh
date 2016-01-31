#!/bin/bash -e
#
# OpenXT setup script.
# This script sets up the build host (just installs packages and adds a user),
# and sets up LXC containers to build OpenXT.
#
# Software license: see accompanying LICENSE file.
#
# Contributions by Jean-Edouard Lejosne: Copyright (c) 2016 AIS.
# Contributions by Christopher Clark: Copyright (c) 2016 BAE Systems.

# -- Script configuration settings.

# The FQDN path for the Debian mirror
# (some chroots don't inherit the resolv.conf search domain)
# eg. DEBIAN_MIRROR="http://httpredir.debian.org/debian"
DEBIAN_MIRROR="http://httpredir.debian.org/debian"

# This /16 subnet prefix is used for networking in the containers.
# Strongly advised to use part of the private IP address space (eg. "192.168")
SUBNET_PREFIX="192.168"

# Ethernet mac address prefix for the container vnics. (eg. "00:FF:AA:42")
MAC_PREFIX="00:FF:AA:42"

# Teardown container on setup failure? 1: yes, anything-else: no.
REMOVE_CONTAINER_ON_ERROR=1

# -- End of script configuration settings.

if [ "x${UID}" != "x0" ] ; then
    echo "Error: This script needs to be run as root.">&2
    exit 1
fi

BUILD_USER="openxt"
if [ $# -ne 0 ]; then
    if [ $# -ne 2 ] || [ $1 != "-u" ]; then
        echo "Usage: $0 [-u user]"
        exit 1
    fi
    BUILD_USER=$2
fi

# Ensure that all required packages are installed on this host.
# When installing packages, do all at once to be faster.
PKGS="lxc"
#PKGS="$PKGS virtualbox" # Un-comment to setup a Windows VM
PKGS="$PKGS bridge-utils libvirt-bin curl jq git sudo" # lxc and misc
PKGS="$PKGS debootstrap" # Debian container
PKGS="$PKGS librpm3 librpmbuild3 librpmio3 librpmsign1 libsqlite0 python-rpm \
python-sqlite python-sqlitecachec python-support python-urlgrabber rpm \
rpm-common rpm2cpio yum debootstrap bridge-utils" # Centos container

apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get install $PKGS || apt-get install $PKGS

# Ensure that the build user exists on the host and is a sudoer.
if [ ! `cut -d ":" -f 1 /etc/passwd | grep "^${BUILD_USER}$"` ]; then
    echo "Creating ${BUILD_USER} user for building, please choose a password."
    adduser --gecos "" ${BUILD_USER}
    BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
    mkdir -p "${BUILD_USER_HOME}/.ssh"
    touch "${BUILD_USER_HOME}"/.ssh/authorized_keys
    touch "${BUILD_USER_HOME}"/.ssh/known_hosts
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh
    echo "${BUILD_USER}  ALL=(ALL:ALL) ALL" >> /etc/sudoers
else
    BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
    if [ ! -f "${BUILD_USER_HOME}"/.ssh/authorized_keys ]; then
        echo "${BUILD_USER} has no SSH authorized_keys file, creating one."
        mkdir -p "${BUILD_USER_HOME}"/.ssh
        touch "${BUILD_USER_HOME}"/.ssh/authorized_keys
        chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/.ssh
    fi
    grep ${BUILD_USER} /etc/sudoers >/dev/null 2>&1 || {
        echo "${BUILD_USER} is not a sudoer, adding him."
        echo "${BUILD_USER}  ALL=(ALL:ALL) ALL" >> /etc/sudoers
    }
fi

# Create an SSH key for the user, to communicate with the containers
if [ ! -d "${BUILD_USER_HOME}"/ssh-key ]; then
    mkdir "${BUILD_USER_HOME}"/ssh-key
    ssh-keygen -N "" -f "${BUILD_USER_HOME}"/ssh-key/openxt
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/ssh-key
fi

# Make up a network range ${SUBNET_PREFIX}.(150 + uid % 100).0
# And a MAC range ${MAC_PREFIX}:(uid % 100):01
BUILD_USER_ID=$(id -u ${BUILD_USER})
IP_C=$(( 150 + ${BUILD_USER_ID} % 100 ))
MAC_E=$(( ${BUILD_USER_ID} % 100 ))
if [ "x${MAC_E}" == "x0" ] ; then
    MAC_E="00"
fi

# Setup LXC networking on the host, to give known IPs to the containers
if [ ! -f /etc/libvirt/qemu/networks/${BUILD_USER}.xml ]; then
    cat > /etc/libvirt/qemu/networks/${BUILD_USER}.xml <<EOF
<network>
  <name>${BUILD_USER}</name>
  <bridge name="${BUILD_USER}br0"/>
  <forward/>
  <ip address="${SUBNET_PREFIX}.${IP_C}.1" netmask="255.255.255.0">
    <dhcp>
      <range start="${SUBNET_PREFIX}.${IP_C}.2" end="${SUBNET_PREFIX}.${IP_C}.254"/>
      <host mac="${MAC_PREFIX}:${MAC_E}:01" name="${BUILD_USER}-oe"     ip="${SUBNET_PREFIX}.${IP_C}.101" />
      <host mac="${MAC_PREFIX}:${MAC_E}:02" name="${BUILD_USER}-debian" ip="${SUBNET_PREFIX}.${IP_C}.102" />
      <host mac="${MAC_PREFIX}:${MAC_E}:03" name="${BUILD_USER}-centos" ip="${SUBNET_PREFIX}.${IP_C}.103" />
    </dhcp>
  </ip>
</network>
EOF
    /etc/init.d/libvirtd restart
    virsh net-autostart ${BUILD_USER}
fi
virsh net-start ${BUILD_USER} >/dev/null 2>&1 || true

LXC_PATH=`lxc-config lxc.lxcpath`

setup_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe
    TEMPLATE=$3         # debian
    MIRROR=$4           # http://httpredir.debian.org/debian
    TEMPLATE_OPTIONS=$5 # --arch i386 --release squeeze

    # Skip setup if the container already exists
    if [ `lxc-ls | grep ${BUILD_USER}-${NAME}` ]; then
        echo "Container ${BUILD_USER}-${NAME} already exists, skipping."
        return
    fi

    # Create the container
    echo "Creating the ${NAME} container..."
    MIRROR=${MIRROR} lxc-create -n "${BUILD_USER}-${NAME}" -t $TEMPLATE -- $TEMPLATE_OPTIONS
    cat >> ${LXC_PATH}/${BUILD_USER}-${NAME}/config <<EOF
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = ${BUILD_USER}br0
lxc.network.hwaddr = ${MAC_PREFIX}:${MAC_E}:${NUMBER}
lxc.network.ipv4 = 0.0.0.0/24
EOF

    echo "Configuring the ${NAME} container..."
    #mount -o bind /dev ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/dev

    set +e
    cat ${NAME}/setup.sh | \
        sed "s|\%MIRROR\%|${MIRROR}|" | \
        chroot ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs /bin/bash -e

    # If the in-container setup script failed, check our configuration to see
    # whether to destroy the container so that it can be recreated and setup
    # reattempted when this script is rerun.
    if [ $? != 0 ] ; then
        echo "Failure executing in-container setup for ${NAME}. Abort.">&2
        if [ "x${REMOVE_CONTAINER_ON_ERROR}" == "x1" ] ; then
            lxc-destroy -n "${BUILD_USER}-${NAME}" || echo \
                "Error tearing down container ${BUILD_USER}-${NAME}">&2
        fi
        exit 1
    fi
    set -e

    #umount ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/dev

    # Allow the host to SSH to the container
    cat "${BUILD_USER_HOME}"/ssh-key/openxt.pub \
        >> ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/home/build/.ssh/authorized_keys

    # Allow the container to SSH to the host
    cat ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/home/build/.ssh/id_dsa.pub \
        >> "${BUILD_USER_HOME}"/.ssh/authorized_keys

    ssh-keyscan -H ${SUBNET_PREFIX}.${IP_C}.1 \
        >> ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/home/build/.ssh/known_hosts

    # Copy the build script for that container to the user home directory
    mkdir -p "${BUILD_USER_HOME}"/${NAME}
    cp ${NAME}/build.sh "${BUILD_USER_HOME}"/${NAME}/
    chown -R ${BUILD_USER}:${BUILD_USER} "${BUILD_USER_HOME}"/${NAME}

    # Copy resolv.conf over for networking, shouldn't be needed
    #cp /etc/resolv.conf ${LXC_PATH}/${BUILD_USER}-${NAME}/rootfs/etc/resolv.conf
}

# Create a container for the main part of the OpenXT build
setup_container "01" "oe" \
                "debian" "${DEBIAN_MIRROR}" "--arch i386  --release squeeze"

# Create a container for the Debian tool packages for OpenXT
setup_container "02" "debian" \
                "debian" "${DEBIAN_MIRROR}" "--arch amd64 --release jessie"

# Create a container for the Centos tool packages for OpenXT
setup_container "03" "centos" \
                "centos" "" "--arch x86_64 --release 7"

# Setup a mirror of the git repositories for the build to be consistent
# (and slightly faster)
if [ ! -d /home/git ]; then
    mkdir /home/git
    chown nobody:nogroup /home/git
    chmod 777 /home/git
fi
if [ ! -d /home/git/${BUILD_USER} ]; then
    mkdir -p /home/git/${BUILD_USER}
    cd /home/git/${BUILD_USER}
    for repo in \
        $(curl -s "https://api.github.com/orgs/OpenXT/repos?per_page=100" | \
          jq '.[].name' | cut -d '"' -f 2 | sort -u)
    do
        git clone --mirror https://github.com/OpenXT/${repo}.git
    done
    cd - > /dev/null
    chown -R ${BUILD_USER}:${BUILD_USER} /home/git/${BUILD_USER}
fi

cp -f build.sh "${BUILD_USER_HOME}/"
chown ${BUILD_USER}:${BUILD_USER} ${BUILD_USER_HOME}/build.sh
echo "Done! Now login as ${BUILD_USER} and run ~/build.sh to start a build."
