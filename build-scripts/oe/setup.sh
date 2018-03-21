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
PKGS="$PKGS sed wget cvs subversion git-core coreutils unzip texi2html texinfo docbook-utils gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ desktop-file-utils chrpath cpio screen bash-completion" # OE main deps
PKGS="$PKGS guilt iasl quilt bin86 bcc libsdl1.2-dev liburi-perl genisoimage policycoreutils unzip vim sudo rpm curl libncurses5-dev libc6-dev-amd64 libelf-dev" # OpenXT-specific deps
PKGS="$PKGS xorriso fusefat dosfstools" # installer & efiboot.img

apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get -y install $PKGS </dev/null || apt-get -y install $PKGS </dev/null

# Download the GHC prerequisites from squeeze
mkdir -p /tmp/ghc-prereq
cd /tmp/ghc-prereq
cat >sums <<EOF
2da6978f6a86d2292b58080314f93f5f5fea3de0f5fcae7083105c8f2cf4f27fbb6521db230c66b3e51eb289d99f575b  libgmp3c2_4.3.2+dfsg-1_i386.deb
8a4e137826251e97a39347b6dcf75ae817ac608a79c29a3984ec5d4f0facf0d999c4411f85beb288f813dc3ad756a020  libgmp3-dev_4.3.2+dfsg-1_i386.deb
ed14f5864e26fe66aa683ade021d8d993168acd9561b70f06a87ff5e70668eab49efd9919892fa8e7dcc8df704eda811  libgmpxx4ldbl_4.3.2+dfsg-1_i386.deb
EOF
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmpxx4ldbl_4.3.2+dfsg-1_i386.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3c2_4.3.2+dfsg-1_i386.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3-dev_4.3.2+dfsg-1_i386.deb
sha384sum -c sums --quiet || exit 1
dpkg -i libgmpxx4ldbl_4.3.2+dfsg-1_i386.deb libgmp3c2_4.3.2+dfsg-1_i386.deb libgmp3-dev_4.3.2+dfsg-1_i386.deb

# Install the required version of GHC
cd /tmp
cat >sums <<EOF
1cfdc92a0173b7d0aeea9e178a1990f37b9ef47d22cc463eb3d7f18c41595a0bcae9dfd26a55234291a9ae5cb4bef99a  ghc-6.12.3-i386-unknown-linux-n.tar.bz2
EOF
wget http://www.haskell.org/ghc/dist/6.12.3/ghc-6.12.3-i386-unknown-linux-n.tar.bz2
sha384sum -c sums --quiet || exit 1
tar jxf ghc-6.12.3-i386-unknown-linux-n.tar.bz2
cd ghc-6.12.3
./configure --prefix=/usr
make install

# Use bash instead of dash for /bin/sh
echo "dash dash/sh boolean false" > /tmp/preseed.txt
debconf-set-selections /tmp/preseed.txt
dpkg-reconfigure -f noninteractive dash

# Hack: Make uname report a 32bits kernel
mv /bin/uname /bin/uname.real
echo '#!/bin/bash' > /bin/uname
echo '/bin/uname.real $@ | sed "s/amd64/i686/g" | sed "s/x86_64/i686/g"' >> /bin/uname
chmod +x /bin/uname

# Add a build user
adduser --disabled-password --gecos "" ${CONTAINER_USER}
mkdir -p /home/${CONTAINER_USER}/.ssh
ssh-keygen -N "" -t rsa -C ${CONTAINER_USER}@openxt-oe -f /home/${CONTAINER_USER}/.ssh/id_rsa
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.ssh
echo "export MACHINE=xenclient-dom0" >> /home/${CONTAINER_USER}/.bashrc
chown ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.bashrc
