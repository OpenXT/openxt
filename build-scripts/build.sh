#!/bin/bash -e
#
# OpenXT build script.
# Software license: see accompanying LICENSE file.
#
# Contributions by Jean-Edouard Lejosne: Copyright (c) 2016 AIS.
# Contributions by Christopher Clark: Copyright (c) 2016 BAE Systems

# Invocation:
# Takes a build identifier as an optional argument to the script
# to enable rerunning this script to continue an interrupted build
# or run a build with a specified directory name.

# -- Script configuration settings.

# This /16 subnet prefix is used for networking in the containers.
# Strongly advised to use part of the private IP address space (eg. "192.168")
# This value should be configured to match the setting used in setup.sh
SUBNET_PREFIX="192.168"

# -- End of script configuration settings.


BUILD_USER="$(whoami)"
BUILD_USER_ID="$(id -u ${BUILD_USER})"
BUILD_USER_HOME="$(eval echo ~${BUILD_USER})"
IP_C=$(( 150 + ${BUILD_USER_ID} % 100 ))
ALL_BUILDS_SUBDIR_NAME="xt-builds"

# Determine the intended build directory
ALL_BUILDS_DIRECTORY="${BUILD_USER_HOME}/${ALL_BUILDS_SUBDIR_NAME}"
if [ -z $1 ] ; then
    BUILD_DIR_PREFIX=$(date +%y%m%d)

#FIXME: the sorting in this isnt quite correct:
    COUNTER=$(/bin/ls -1d "${ALL_BUILDS_DIRECTORY}/${BUILD_DIR_PREFIX}"-* \
                      2>/dev/null | \
              sort -nr | \
              sed -e 's/^.*-//' -n  -e 1p)
    COUNTER=$((COUNTER + 1))
    BUILD_DIR="${BUILD_DIR_PREFIX}-${COUNTER}"
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

# Fetch git mirrors
for i in /home/git/${BUILD_USER}/*.git; do
    echo -n "Fetching `basename $i`: "
    cd $i
    git fetch --all > /dev/null 2>&1
    git log -1 --pretty='tformat:%H'
    cd - > /dev/null
done | tee /tmp/git_heads_$BUILD_USER

# Start the git service if needed
ps -p `cat /tmp/openxt_git.pid 2>/dev/null` >/dev/null 2>&1 || {
    rm -f /tmp/openxt_git.pid
    git daemon --base-path=/home/git \
               --pid-file=/tmp/openxt_git.pid \
               --detach \
               --syslog \
               --export-all
    chmod 666 /tmp/openxt_git.pid
}

echo "Running build: ${BUILD_DIR}"

build_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe
    echo "Building container: ${NUMBER} : ${NAME}"

    # Start the OE container
    sudo lxc-info -n ${BUILD_USER}-${NAME} | \
        grep STOPPED >/dev/null && sudo lxc-start -d -n ${BUILD_USER}-${NAME}

    # Wait a few seconds and exit if the host doesn't respond
    CONTAINER_IP="${SUBNET_PREFIX}.${IP_C}.1${NUMBER}"
    echo "Accessing container at network address: ${CONTAINER_IP}"

    ping -c 1 ${CONTAINER_IP} >/dev/null 2>&1 || \
        ping -w 30 ${CONTAINER_IP} >/dev/null 2>&1 || \
    {
        echo "Error: Could not connect to container ${BUILD_USER}-${NAME}" \
             "at ${CONTAINER_IP}. Exiting." >&2
        exit 2
    }

    # Build
    cat $NAME/build.sh | \
        sed -e "s|\%BUILD_USER\%|${BUILD_USER}|" \
            -e "s|\%BUILD_DIR\%|${BUILD_DIR}|" \
            -e "s|\%SUBNET_PREFIX\%|${SUBNET_PREFIX}|" \
            -e "s|\%IP_C\%|${IP_C}|" \
            -e "s|\%ALL_BUILDS_SUBDIR_NAME\%|${ALL_BUILDS_SUBDIR_NAME}|" |\
        ssh -t -t -i "${BUILD_USER_HOME}"/ssh-key/openxt \
            -oStrictHostKeyChecking=no build@${CONTAINER_IP}
}

build_container "01" "oe"
build_container "02" "debian"
build_container "03" "centos"
