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
PKGS="$PKGS sed wget cvs subversion git-core coreutils unzip texi2html texinfo docbook-utils gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ desktop-file-utils chrpath cpio" # OE main deps
PKGS="$PKGS guilt iasl quilt bin86 bcc libsdl1.2-dev liburi-perl genisoimage policycoreutils unzip vim sudo rpm curl libncurses5-dev" # OpenXT-specific deps
apt-get update
# That's a lot of packages, a fetching failure can happen, try twice.
apt-get -y install $PKGS </dev/null || apt-get -y install $PKGS </dev/null

# Download the GHC prerequisites from squeeze
mkdir -p /tmp/ghc-prereq
cd /tmp/ghc-prereq
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmpxx4ldbl_4.3.2+dfsg-1_i386.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3c2_4.3.2+dfsg-1_i386.deb
wget http://archive.debian.org/debian/pool/main/g/gmp/libgmp3-dev_4.3.2+dfsg-1_i386.deb
dpkg -i libgmpxx4ldbl_4.3.2+dfsg-1_i386.deb libgmp3c2_4.3.2+dfsg-1_i386.deb libgmp3-dev_4.3.2+dfsg-1_i386.deb

# Install the required version of GHC
cd /tmp
wget http://www.haskell.org/ghc/dist/6.12.3/ghc-6.12.3-i386-unknown-linux-n.tar.bz2
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
touch /home/${CONTAINER_USER}/.ssh/authorized_keys
ssh-keygen -N "" -t dsa -C ${CONTAINER_USER}@openxt-oe -f /home/${CONTAINER_USER}/.ssh/id_dsa
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.ssh
echo "export MACHINE=xenclient-dom0" >> /home/${CONTAINER_USER}/.bashrc
chown ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.bashrc

# Create build certs
mkdir /home/${CONTAINER_USER}/certs
openssl genrsa -out /home/${CONTAINER_USER}/certs/prod-cakey.pem 2048
openssl genrsa -out /home/${CONTAINER_USER}/certs/dev-cakey.pem 2048
openssl req -new -x509 -key /home/${CONTAINER_USER}/certs/prod-cakey.pem -out /home/${CONTAINER_USER}/certs/prod-cacert.pem -days 1095 -subj "/C=US/ST=Massachusetts/L=Boston/O=OpenXT/OU=OpenXT/CN=openxt.org"
openssl req -new -x509 -key /home/${CONTAINER_USER}/certs/dev-cakey.pem -out /home/${CONTAINER_USER}/certs/dev-cacert.pem -days 1095 -subj "/C=US/ST=Massachusetts/L=Boston/O=OpenXT/OU=OpenXT/CN=openxt.org"
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/certs
