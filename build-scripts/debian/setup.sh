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

MIRROR=%MIRROR%
CONTAINER_USER=%CONTAINER_USER%

# Remove the root password
passwd -d root

# Install required packages
PKGS=""
PKGS="$PKGS openssh-server openssl git"
# Debian package building deps
PKGS="$PKGS schroot sbuild reprepro dh-make dkms pkg-config libfile-fcntllock-perl dh-autoreconf"
apt-get update
apt-get -y install $PKGS </dev/null

# Add a build user
adduser --disabled-password --gecos "" ${CONTAINER_USER}
mkdir -p /home/${CONTAINER_USER}/.ssh
ssh-keygen -N "" -t rsa -C ${CONTAINER_USER}@openxt-debian -f /home/${CONTAINER_USER}/.ssh/id_rsa
chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}/.ssh

# Setup sbuild
INCLUDE="build-essential,dh-make,dkms,dh-autoreconf" # Packages needed by chroots to build stuffs
mkdir /root/.gnupg
sbuild-createchroot wheezy /home/chroots/wheezy-i386  $MIRROR --arch=i386  --include=$INCLUDE
sbuild-createchroot wheezy /home/chroots/wheezy-amd64 $MIRROR --arch=amd64 --include=$INCLUDE
sbuild-createchroot jessie /home/chroots/jessie-i386  $MIRROR --arch=i386  --include=$INCLUDE
sbuild-createchroot jessie /home/chroots/jessie-amd64 $MIRROR --arch=amd64 --include=$INCLUDE
# The 2 following steps are done before creating the chroot in the documentation
# However, at that point, there's not enough entropy for the keygen...
# In that case, it seems to be OK to run them after.
# See https://wiki.debian.org/sbuild
sbuild-update --keygen
sbuild-adduser ${CONTAINER_USER}
