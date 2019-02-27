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

# This scripts sets up the OE container for OpenXT

CONTAINER_USER=%CONTAINER_USER%

# Remove root password
passwd -d root

# Fix networking
sed -i '/^start)$/a        mkdir -p /dev/shm/network/' /etc/init.d/networking
PKGS=""
PKGS="$PKGS openssh-server openssl"
PKGS="$PKGS sed wget cvs subversion git-core coreutils unzip texi2html texinfo docbook-utils gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ desktop-file-utils chrpath cpio screen bash-completion python3 iputils-ping" # OE main deps
PKGS="$PKGS guilt iasl quilt bin86 bcc libsdl1.2-dev liburi-perl genisoimage policycoreutils unzip vim sudo rpm curl libncurses5-dev libc6-dev-i386 libelf-dev" # OpenXT-specific deps
PKGS="$PKGS xorriso mtools dosfstools" # installer & efiboot.img

apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get -y install $PKGS </dev/null || apt-get -y install $PKGS </dev/null

# Download the GHC prerequisites from squeeze
mkdir -p /tmp/ghc-prereq
cd /tmp/ghc-prereq
cat >sums <<EOF
e16a0ebd9a78ab45675f3d2005903325329539b200b2e632878b19d544dfdb6360edbba30fd79872c29b7294c6031db8  libgmp3c2_4.3.2+dfsg-1_amd64.deb
dc6a4f88d4bf32254916c70ba77cb4b8eddfefb3164e8458a987ef8de5725262f1bb32578365db6c5df68bc735cfa1ce  libgmp3-dev_4.3.2+dfsg-1_amd64.deb
eec6ce0392ed808f1526cc214a88453581c0895079dd43e844618514a31094d664181172df87980b3d9062978ff5a27f  libgmpxx4ldbl_4.3.2+dfsg-1_amd64.deb
EOF
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmpxx4ldbl_4.3.2+dfsg-1_amd64.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3c2_4.3.2+dfsg-1_amd64.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3-dev_4.3.2+dfsg-1_amd64.deb
sha384sum -c sums --quiet || exit 1
dpkg -i libgmpxx4ldbl_4.3.2+dfsg-1_amd64.deb libgmp3c2_4.3.2+dfsg-1_amd64.deb libgmp3-dev_4.3.2+dfsg-1_amd64.deb

# Install the required version of GHC
cd /tmp
cat >sums <<EOF
0a803af298fb89143599406b82725744c7567be08a0a5ba18b724b0ad9d5421cc3402c7a49670d5d850a4c4cac122f98  ghc-6.12.3-x86_64-unknown-linux-n.tar.bz2
EOF
wget https://downloads.haskell.org/~ghc/6.12.3/ghc-6.12.3-x86_64-unknown-linux-n.tar.bz2
sha384sum -c sums --quiet || exit 1
tar jxf ghc-6.12.3-x86_64-unknown-linux-n.tar.bz2
cd ghc-6.12.3
./configure --prefix=/usr
make install

# Use bash instead of dash for /bin/sh
echo "dash dash/sh boolean false" > /tmp/preseed.txt
debconf-set-selections /tmp/preseed.txt
dpkg-reconfigure -f noninteractive dash

# Add a build user
adduser --disabled-password --gecos "" ${CONTAINER_USER}
mkdir -p /home/${CONTAINER_USER}/.ssh
ssh-keygen -N "" -t rsa -C ${CONTAINER_USER}@openxt-oe -f /home/${CONTAINER_USER}/.ssh/id_rsa
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.ssh
echo "export MACHINE=xenclient-dom0" >> /home/${CONTAINER_USER}/.bashrc
chown ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.bashrc

cat >/home/${CONTAINER_USER}/.quiltrc <<EOF
# Options passed to GNU diff when generating patches
QUILT_DIFF_OPTS="--show-c-function"

# Options passed to GNU patch when applying patches.
QUILT_PATCH_OPTS="--unified"

# Do not include index lines
QUILT_NO_DIFF_INDEX=1
# Do not include timestamps
QUILT_NO_DIFF_TIMESTAMPS=1

# Options to pass to commands (QUILT_${COMMAND}_ARGS)
# Generate a/ b/ patches to cut down on churn
#QUILT_DIFF_ARGS="--no-timestamps --color=auto -p ab"
#QUILT_REFRESH_ARGS="--no-timestamps --backup -p ab"
QUILT_DIFF_ARGS="--color=auto -p ab"
QUILT_REFRESH_ARGS="--backup -p ab"
QUILT_PUSH_ARGS="--color=auto"
QUILT_SERIES_ARGS="--color=auto"
QUILT_PATCHES_ARGS="--color=auto"
QUILT_NEW_ARGS="-p ab"
EOF
