#!/bin/bash -e

DUDE=`whoami`
DUDE_ID=`id -u ${DUDE}`
IP_C=$(( 150 + ${DUDE_ID} % 100 ))

# Fetch git mirrors
for i in /home/git/${DUDE}/*.git; do
    echo -n "Fetching `basename $i`: "
    cd $i
    git fetch --all > /dev/null 2>&1
    git log -1 --pretty='tformat:%H'
    cd - > /dev/null
done | tee /tmp/git_heads_$DUDE

# Start the git service if needed
ps -p `cat /tmp/openxt_git.pid 2>/dev/null` >/dev/null 2>&1 || {
    rm -f /tmp/openxt_git.pid
    git daemon --base-path=/home/git --pid-file=/tmp/openxt_git.pid --detach --syslog --export-all
    chmod 666 /tmp/openxt_git.pid
}

# Create a build dir
BUILD_DIR=`date +%y%m%d`
[ -d $BUILD_DIR ] && rm -ri $BUILD_DIR
mkdir $BUILD_DIR

build_container() {
    NUMBER=$1           # 01
    NAME=$2             # oe

    # Start the OE container
    sudo lxc-info -n ${DUDE}-${NAME} | grep STOPPED >/dev/null && sudo lxc-start -d -n ${DUDE}-${NAME}

    # Wait a few seconds and exit if the host doesn't respond
    ping -c 1 192.168.${IP_C}.1${NUMBER} >/dev/null 2>&1 || ping -w 30 192.168.${IP_C}.1${NUMBER} >/dev/null 2>&1 || {
	echo "Could not connect to openxt-${NAME}, exiting."
	exit 1
    }

    # Build
    cat $NAME/build.sh | sed -e "s|\%DUDE\%|${DUDE}|" -e "s|\%BUILD_DIR\%|${BUILD_DIR}|" -e "s|\%IP_C\%|${IP_C}|" | ssh -t -t -i ssh-key/openxt -oStrictHostKeyChecking=no build@192.168.${IP_C}.1${NUMBER}
}

build_container "01" "oe"
build_container "02" "debian"
build_container "03" "centos"
