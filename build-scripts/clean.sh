#!/bin/bash -e
#
# OpenXT build script.
# Software license: see accompanying LICENSE file.
#
# Copyright (c) 2016 Assured Information Security, Inc.
#
# Contributions by Ross Philipson <philipsonr@ainfosec.com>
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
# Invocation:
# Used to cleanup a single build or all builds.
#
# N.B. this script starts outside the containers in the OUT OF CONTAINER
# block. It then sets the variables in the IN CONTAINER part and sends
# the modified script to each container to run the IN CONTAINER block.
# Finally back out in the OUT OF CONTAINER block it cleans up the local
# build dirs in xt-builds.

BDLIST=

#------------ IN CONTAINER ------------

IN_CONTAINER=%IN_CONTAINER%
C_BUILD_DIR=%C_BUILD_DIR%
C_CLEAN_ALL=%C_CLEAN_ALL%

if [ "$IN_CONTAINER" = "y" ]; then
    if [ -n "$C_BUILD_DIR" ]; then
        echo "Cleaning up: $C_BUILD_DIR"
        rm -rf $C_BUILD_DIR
        exit 0
    fi

    if [ -z "$C_CLEAN_ALL" ]; then
        exit 0
    fi

    BDLIST=`ls | grep -e "^[0-9]\{6\}-[0-9]\+$"`
    for i in $BDLIST; do
        echo "Cleaning up: $i"
        rm -rf $i
    done

    exit 0
fi

#------------ OUT OF CONTAINER ------------

BUILD_DIR=""
CLEAN_ALL=""

usage() {
    cat >&2 <<EOF
usage: $0 [-h] [-n build] [-A]
  -h: Help
  -n: Remove specified build
  -A: Clean all builds
EOF
    exit $1
}

while getopts "hn:A" opt; do
    case $opt in
        h)
            usage 0
            ;;
        n)
            BUILD_DIR="${OPTARG}"
            ;;
        A)
            CLEAN_ALL="y"
            ;;
        \?)
            usage 1
            ;;
    esac
done

if [ -n "$BUILD_DIR" ] && [ -n "$CLEAN_ALL" ]; then
    echo "Can't specify both -n and -A"
    usage 2
fi

if [ -z "$BUILD_DIR" ] && [ -z "$CLEAN_ALL" ]; then
    echo "Nothing to do??"
    usage 2
fi

CONTAINER_USER=%CONTAINER_USER%
SUBNET_PREFIX=%SUBNET_PREFIX%
BUILD_USER="$(whoami)"
BUILD_USER_ID="$(id -u ${BUILD_USER})"
BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
IP_C=$(( 150 + ${BUILD_USER_ID} % 100 ))

clean_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe

    CONTAINER_IP="${SUBNET_PREFIX}.${IP_C}.1${NUMBER}"

    if [ -d $NAME ]; then
        echo "Cleaning build $NUMBER for container: $NAME"
    else
        echo "Cleaning all builds for container: $NAME"
    fi

    cat clean.sh | \
        sed -e "s|\%IN_CONTAINER\%|y|" \
            -e "s|\%C_BUILD_DIR%|${BUILD_DIR}|" \
            -e "s|\%C_CLEAN_ALL\%|${CLEAN_ALL}|" |\
        ssh -i "${BUILD_USER_HOME}"/ssh-key/openxt \
            -oStrictHostKeyChecking=no ${CONTAINER_USER}@${CONTAINER_IP}
}

clean_container "01" "oe"
clean_container "02" "debian"
clean_container "03" "centos"

# Cleanup local stuffs
if [ -n "$BUILD_DIR" ]; then
    echo "Cleaning up: $BUILD_DIR"
    rm -rf xt-builds/${BUILD_DIR}
    exit 0
fi

BDLIST=`ls xt-builds | grep -e "^[0-9]\{6\}-[0-9]\+$"`
for i in $BDLIST; do
    echo "Cleaning up: xt-builds/$i"
    rm -rf xt-builds/$i
done
