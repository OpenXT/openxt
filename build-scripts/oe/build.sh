#!/bin/bash
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

set -e

BUILD_USER=%BUILD_USER%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%
BUILD_ID=%BUILD_ID%
BRANCH=%BRANCH%
THREADS=%THREADS%
SUBNET_PREFIX=%SUBNET_PREFIX%
ALL_BUILDS_SUBDIR_NAME=%ALL_BUILDS_SUBDIR_NAME%

HOST_IP=${SUBNET_PREFIX}.${IP_C}.1
LOCAL_USER=`whoami`
BUILD_PATH=`pwd`/${BUILD_DIR}/openxt/build
RSYNC="rsync -a --copy-links"

cd ~/certs
CERTS_PATH=`pwd`
cd ..

setupoe() {
    source version
    cp build/conf/local.conf-dist build/conf/local.conf
    cat common-config >> build/conf/local.conf
    cat >> build/conf/local.conf <<EOF
# Distribution feed
XENCLIENT_PACKAGE_FEED_URI="file:///storage/ipk"

SSTATE_DIR ?= "$BUILD_PATH/sstate-cache/$BRANCH"

DL_DIR ?= "$BUILD_PATH/downloads"
export CCACHE_DIR = "$BUILD_PATH/cache"
CCACHE_TARGET_DIR="$CACHE_DIR"

OPENXT_MIRROR="http://mirror.openxt.org"
OPENXT_GIT_MIRROR="$HOST_IP/$BUILD_USER"
OPENXT_GIT_PROTOCOL="git"
OPENXT_BRANCH="$BRANCH"
OPENXT_TAG="$BRANCH"

XENCLIENT_BUILD = "${BUILD_ID}"
XENCLIENT_BUILD_DATE = "`date +'%T %D'`"
XENCLIENT_BUILD_BRANCH = "${BRANCH}"
XENCLIENT_VERSION = "$VERSION"
XENCLIENT_RELEASE = "$RELEASE"
XENCLIENT_TOOLS = "${XC_TOOLS_MAJOR}.${XC_TOOLS_MINOR}.${XC_TOOLS_MICRO}.${BUILD_ID}"

# dir for generated deb packages
XCT_DEB_PKGS_DIR := "${BUILD_PATH}/xct_deb_packages"

# Production and development repository-signing CA certificates
REPO_PROD_CACERT="/home/${LOCAL_USER}/certs/prod-cacert.pem"
REPO_DEV_CACERT="/home/${LOCAL_USER}/certs/dev-cacert.pem"
EOF
}

configure_threads() {
    if [ ! -z ${THREADS} ] ; then
        sed -i 's/^BB_NUMBER_THREADS .*$/BB_NUMBER_THREADS ?= "'"${THREADS}"'"/' build/conf/local.conf
        sed -i 's/^PARALLEL_MAKE .*$/PARALLEL_MAKE ?= "'"-j ${THREADS}"'"/' build/conf/local.conf
    fi
}

build_image() {
    MACHINE=$1
    IMAGE_NAME=$2
    EXTENSION=$3

    REAL_NAME=`echo $IMAGE_NAME | sed 's/^[^-]\+-//'`

    # Build the step
    MACHINE=$MACHINE ./bb ${IMAGE_NAME}-image | tee -a build.log

    # The return value of `./bb` got hidden by `tee`. Bring it back.
    # Get the return value
    ret=${PIPESTATUS[0]}
    # Surface the value, the "-e" bash flag will pick up on any error
    ( exit $ret )

    SOURCE_BASE=tmp-glibc/deploy/images/${MACHINE}/${IMAGE_NAME}-image
    SOURCE_IMAGE=${SOURCE_BASE}-${MACHINE}.${EXTENSION}
    SOURCE_LICENSES=${SOURCE_BASE}-licences.csv
    SOURCE_EXTRAS=${SOURCE_BASE}-${MACHINE}
    TARGET=${BUILD_USER}@${HOST_IP}:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/

    # Transfer image and give it the expected name
    if [ -f ${SOURCE_IMAGE} ]; then
        if [ "$IMAGE_NAME" = "xenclient-installer-part2" ]; then
            $RSYNC ${SOURCE_IMAGE} ${TARGET}/raw/control.${EXTENSION}
            $RSYNC tmp-glibc/deploy/images/${MACHINE}/*.acm \
                   tmp-glibc/deploy/images/${MACHINE}/tboot.gz \
                   tmp-glibc/deploy/images/${MACHINE}/xen.gz \
                   ${TARGET}/netboot/
            if [ -f tmp-glibc/deploy/images/${MACHINE}/microcode_intel.bin ]; then
                $RSYNC tmp-glibc/deploy/images/${MACHINE}/microcode_intel.bin \
                       ${TARGET}/netboot/
            fi
            $RSYNC tmp-glibc/deploy/images/${MACHINE}/bzImage-${MACHINE}.bin \
                   ${TARGET}/netboot/vmlinuz
        else
            $RSYNC ${SOURCE_IMAGE} ${TARGET}/raw/${REAL_NAME}-rootfs.i686.${EXTENSION}
        fi
    fi

    # Transfer licenses
    if [ -f ${SOURCE_LICENSES} ]; then
        $RSYNC ${SOURCE_LICENSES} ${TARGET}/licenses/
    fi

    # Transfer additionnal files
    if [ -d ${SOURCE_EXTRAS} ]; then
        $RSYNC ${SOURCE_EXTRAS}/ ${TARGET}/${REAL_NAME}
    fi

    # Transfer installer EFI files
    if [ -f tmp-glibc/deploy/images/${MACHINE}/grubx64.efi ]; then
        $RSYNC tmp-glibc/deploy/images/${MACHINE}/grubx64.efi ${TARGET}/raw/
        $RSYNC tmp-glibc/deploy/images/${MACHINE}/isohdpfx.bin ${TARGET}/raw/
    fi
}

collect_packages() {
    # Build the extra packages
    MACHINE=xenclient-dom0 ./bb packagegroup-xenclient-extra | tee -a build.log
    MACHINE=xenclient-dom0 ./bb package-index | tee -a build.log

    $RSYNC tmp-glibc/deploy/ipk ${TARGET}/packages
}

collect_logs() {
    TARGET=${BUILD_USER}@${HOST_IP}:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/

    mkdir -p logs

    echo "Collecting build logs..."
    ls tmp-glibc/work/*/*/*/temp/log.do_* | tar -cjf logs/build_logs.tar.bz2 --files-from=-
    echo "Collecting sigdata..."
    find tmp-glibc/stamps -name "*.sigdata.*" | tar -cjf logs/sigdata.tar.bz2 --files-from=-

    $RSYNC logs ${TARGET}/logs
}

mkdir -p $BUILD_DIR
cd $BUILD_DIR

if [ ! -d openxt ] ; then
    # Clone main repos
    git clone -b $BRANCH git://${HOST_IP}/${BUILD_USER}/openxt.git
    cd openxt

    # Fetch the "upstream" layers
    # Initialise the submodules using .gitmodules
    git submodule init
    # Clone the submodules, using their saved HEAD
    git submodule update --checkout
    # Update the submodules that follow a branch (update != none)
    git submodule update --remote

    # Clone OpenXT layers
    for layer in $openxt_layers; do
        name_var="openxt_layer_${layer}_name"
        repo_var="openxt_layer_${layer}_repository"
        rev_var="openxt_layer_${layer}_revision"
        if [ -z ${!repo_var} ]; then
            git clone git://${HOST_IP}/${BUILD_USER}/${!name_var}.git build/repos/${!name_var}
        else
            git clone ${!repo_var} build/repos/${!name_var}
        fi
        cd build/repos/${!name_var}
        if [ -z ${!rev_var} ]; then
            git checkout $BRANCH
        else
            git checkout ${!rev_var}
        fi
        cd - >/dev/null
        echo "BBLAYERS =+ \"\${TOPDIR}/repos/${!name_var}\"" >> build/conf/bblayers.conf
    done

    # Configure OpenXT
    setupoe
else
    cd openxt
fi

configure_threads

# Build
mkdir -p build
cd build
for layer in $openxt_layers; do
    echo "Building layer ${layer}..."
    images_var="openxt_layer_${layer}_images[@]"
    for image in "${!images_var}"; do
        echo $image
        machine=`echo $image | awk '{print $1}'`
        step=`echo $image | awk '{print $2}'`
        format=`echo $image | awk '{print $3}'`
        echo "Building $step for $machine in $format"
        build_image $machine $step $format
    done
done

collect_packages
collect_logs

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
