#!/bin/bash -e

# This script sets up the host (just installs packages and adds a user),
# and sets up LXC containers to build OpenXT

# The FQDN path for the Debian mirror (some chroots don't inherit the resolv.conf search domain)
DEBIAN_MIRROR=http://httpredir.debian.org/debian

DUDE="openxt"
if [ $# -ne 0 ]; then
    if [ $# -ne 2 ] || [ $1 != "-u" ]; then
	echo "Usage: ./setup.sh [-u user]"
	exit 1
    fi
    DUDE=$2
fi

# Install packages on the host, all at once to be faster
PKGS="lxc"
#PKGS="$PKGS virtualbox" # Un-comment to setup a Windows VM
PKGS="$PKGS bridge-utils libvirt-bin curl jq git sudo" # lxc and misc
PKGS="$PKGS debootstrap" # Debian container
PKGS="$PKGS librpm3 librpmbuild3 librpmio3 librpmsign1 libsqlite0 python-rpm python-sqlite python-sqlitecachec python-support python-urlgrabber rpm rpm-common rpm2cpio yum debootstrap bridge-utils" # Centos container
apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get install $PKGS || apt-get install $PKGS

# Create an openxt user on the host and make it a sudoer
if [ ! `cut -d ":" -f 1 /etc/passwd | grep "^${DUDE}$"` ]; then
    echo "Creating an openxt user for building, please choose a password."
    adduser --gecos "" ${DUDE}
    mkdir -p /home/${DUDE}/.ssh
    touch /home/${DUDE}/.ssh/authorized_keys
    chown -R ${DUDE}:${DUDE} /home/${DUDE}/.ssh
    echo "${DUDE}  ALL=(ALL:ALL) ALL" >> /etc/sudoers
else
    if [ ! -f /home/${DUDE}/.ssh/authorized_keys ]; then
	echo "${DUDE} doesn't have an SSH authorized_keys file, creating one."
	mkdir -p /home/${DUDE}/.ssh
	touch /home/${DUDE}/.ssh/authorized_keys
	chown -R ${DUDE}:${DUDE} /home/${DUDE}/.ssh
    fi
    grep ${DUDE} /etc/sudoers >/dev/null 2>&1 || {
	echo "${DUDE} is not a sudoer, adding him."
	echo "${DUDE}  ALL=(ALL:ALL) ALL" >> /etc/sudoers
    }
fi

# Create an SSH key for the user, to communicate with the containers
if [ ! -d /home/${DUDE}/ssh-key ]; then
    mkdir /home/${DUDE}/ssh-key
    ssh-keygen -N "" -f /home/${DUDE}/ssh-key/openxt
    chown -R ${DUDE}:${DUDE} /home/${DUDE}/ssh-key
fi

# Make up a network range 192.168.(150 + uid % 100).0
# And a MAC range 00:FF:AA:42:(uid % 100):01
DUDE_ID=`id -u ${DUDE}`
IP_C=$(( 150 + ${DUDE_ID} % 100 ))
MAC_E=$(( ${DUDE_ID} % 100 ))

# Setup LXC networking on the host, to give known IPs to the containers
if [ ! -f /etc/libvirt/qemu/networks/${DUDE}.xml ]; then
    cat > /etc/libvirt/qemu/networks/${DUDE}.xml <<EOF
<network>
  <name>${DUDE}</name>
  <bridge name="${DUDE}br0"/>
  <forward/>
  <ip address="192.168.${IP_C}.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.${IP_C}.2" end="192.168.${IP_C}.254"/>
      <host mac="00:FF:AA:42:${MAC_E}:01" name="${DUDE}-oe"     ip="192.168.${IP_C}.101" />
      <host mac="00:FF:AA:42:${MAC_E}:02" name="${DUDE}-debian" ip="192.168.${IP_C}.102" />
      <host mac="00:FF:AA:42:${MAC_E}:03" name="${DUDE}-centos" ip="192.168.${IP_C}.103" />
    </dhcp>
  </ip>
</network>
EOF
    /etc/init.d/libvirtd restart
    virsh net-autostart ${DUDE}
fi
virsh net-start ${DUDE} >/dev/null 2>&1 || true

LXC_PATH=`lxc-config lxc.lxcpath`

setup_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe
    TEMPLATE=$3         # debian
    MIRROR=$4           # http://httpredir.debian.org/debian
    TEMPLATE_OPTIONS=$5 # --arch i386 --release squeeze

    # Bail if the container already exists
    if [ `lxc-ls | grep ${DUDE}-${NAME}` ]; then
	echo "Container ${DUDE}-${NAME} already exists, skipping."
	return
    fi

    # Create the container
    echo "Creating the ${NAME} container..."
    MIRROR=${MIRROR} lxc-create -n ${DUDE}-${NAME} -t $TEMPLATE -- $TEMPLATE_OPTIONS
    cat >> ${LXC_PATH}/${DUDE}-${NAME}/config <<EOF
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = ${DUDE}br0
lxc.network.hwaddr = 00:FF:AA:42:${MAC_E}:${NUMBER}
lxc.network.ipv4 = 0.0.0.0/24
EOF
    echo "Configuring the ${NAME} container..."
    #mount -o bind /dev ${LXC_PATH}/${DUDE}-${NAME}/rootfs/dev
    cat ${NAME}/setup.sh | sed "s|\%MIRROR\%|${MIRROR}|" | chroot ${LXC_PATH}/${DUDE}-${NAME}/rootfs /bin/bash -e
    #umount ${LXC_PATH}/${DUDE}-${NAME}/rootfs/dev
    # Allow the host to SSH to the container
    cat /home/${DUDE}/ssh-key/openxt.pub >> ${LXC_PATH}/${DUDE}-${NAME}/rootfs/home/build/.ssh/authorized_keys
    # Allow the container to SSH to the host
    cat ${LXC_PATH}/${DUDE}-${NAME}/rootfs/home/build/.ssh/id_dsa.pub >> /home/${DUDE}/.ssh/authorized_keys
    ssh-keyscan -H 192.168.${IP_C}.1 >> ${LXC_PATH}/${DUDE}-${NAME}/rootfs/home/build/.ssh/known_hosts

    # Copy the build script for that container to the user home directory
    mkdir -p /home/${DUDE}/${NAME}
    cp ${NAME}/build.sh /home/${DUDE}/${NAME}/
    chown -R ${DUDE}:${DUDE} /home/${DUDE}/${NAME}

    # Copy resolv.conf over for networking, shouldn't be needed
    #cp /etc/resolv.conf ${LXC_PATH}/${DUDE}-${NAME}/rootfs/etc/resolv.conf
}

# Create a container for the main part of the OpenXT build
setup_container "01" "oe"     "debian" "${DEBIAN_MIRROR}" "--arch i386  --release squeeze"

# Create a container for the Debian tool packages for OpenXT
setup_container "02" "debian" "debian" "${DEBIAN_MIRROR}" "--arch amd64 --release jessie"

# Create a container for the Centos tool packages for OpenXT
setup_container "03" "centos" "centos" "" "--arch x86_64 --release 7"

# Setup a mirror of the git repositories, for the build to be consistant (and slightly faster)
if [ ! -d /home/git ]; then
    mkdir /home/git
    chown nobody:nogroup /home/git
    chmod 777 /home/git
fi
if [ ! -d /home/git/${DUDE} ]; then
    mkdir -p /home/git/${DUDE}
    cd /home/git/${DUDE}
    for repo in `curl -s "https://api.github.com/orgs/OpenXT/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2 | sort -u`; do
	git clone --mirror https://github.com/OpenXT/${repo}.git
    done
    cd - > /dev/null
    chown -R ${DUDE}:${DUDE} /home/git/${DUDE}
fi

cp build.sh /home/${DUDE}
chown ${DUDE}:${DUDE} /home/${DUDE}/build.sh
echo "Done! Now login as ${DUDE} and run ./build.sh to start a build."
