#!/bin/bash -e
#
# OpenXT build script.
# Software license: see accompanying LICENSE file.
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
# Invocation:
# Takes a build identifier as an optional argument to the script
# to enable rerunning this script to continue an interrupted build
# or run a build with a specified directory name.

# -- Script configuration settings.

# The branch to build. Has to be at least OpenXT 6.
# Note: this branch will be used for *everything*.
#   The build will fail if one of the OpenXT repositories doesn't have it
#   To change just the OE branch, please edit oe/build.sh
BRANCH="master"

# -- End of script configuration settings.

CONTAINER_USER=%CONTAINER_USER%
SUBNET_PREFIX=%SUBNET_PREFIX%
BUILD_USER="$(whoami)"
BUILD_USER_ID="$(id -u ${BUILD_USER})"
BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
IP_C=$(( 150 + ${BUILD_USER_ID} % 100 ))
ALL_BUILDS_SUBDIR_NAME="xt-builds"

# Determine the intended build directory
ALL_BUILDS_DIRECTORY="${BUILD_USER_HOME}/${ALL_BUILDS_SUBDIR_NAME}"
if [ -z $1 ] ; then
    BUILD_DATE=$(date +%y%m%d)

    cd ${ALL_BUILDS_DIRECTORY}
    LAST_BUILD=0
    if [[ -d "${BUILD_DATE}-1" ]]; then
	LAST_BUILD=`ls -dvr ${BUILD_DATE}-* | head -1 | cut -d '-' -f 2`
    fi
    cd - >/dev/null
    NEW_BUILD=$((LAST_BUILD + 1))
    BUILD_DIR="${BUILD_DATE}-${NEW_BUILD}"
else
    BUILD_DIR="$1"
fi

BUILD_DIR_PATH="${ALL_BUILDS_DIRECTORY}/${BUILD_DIR}"
if [ -e "$BUILD_DIR_PATH" ] ; then
    echo "Build path is already present: ${BUILD_DIR_PATH}"
fi
if ! mkdir -p "${BUILD_DIR_PATH}" ; then
    echo "Error: Failed to create build directory: ${BUILD_DIR_PATH}" >&2
    exit 1
fi

./fetch.sh

echo "Running build: ${BUILD_DIR}"

build_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe
    echo "Building container: ${NUMBER} : ${NAME}"

    CONTAINER_IP="${SUBNET_PREFIX}.${IP_C}.1${NUMBER}"

    # Build
    cat $NAME/build.sh | \
        sed -e "s|\%BUILD_USER\%|${BUILD_USER}|" \
            -e "s|\%BUILD_DIR\%|${BUILD_DIR}|" \
            -e "s|\%SUBNET_PREFIX\%|${SUBNET_PREFIX}|" \
            -e "s|\%IP_C\%|${IP_C}|" \
            -e "s|\%BRANCH\%|${BRANCH}|" \
            -e "s|\%ALL_BUILDS_SUBDIR_NAME\%|${ALL_BUILDS_SUBDIR_NAME}|" |\
        ssh -t -t -i "${BUILD_USER_HOME}"/ssh-key/openxt \
            -oStrictHostKeyChecking=no ${CONTAINER_USER}@${CONTAINER_IP}
}

build_windows() {
    NUMBER=$1           # 04
    echo "Building windows"

    DEST="${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/windows"

    mkdir -p $DEST

    # Build
    cd windows
    ./build.sh "$NUMBER" \
               "$BRANCH" \
               "$BUILD_USER" \
               "${SUBNET_PREFIX}.${IP_C}" \
               "${DEST}"
    cd - >/dev/null
}

build_container "01" "oe"
build_container "02" "debian"
build_container "03" "centos"
build_windows   "04"
