#!/bin/sh

set -e

DUDE=%DUDE%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%

# On first build, setup Oracle
if [ ! -e ~/oracled ]; then
    while [ ! -f /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip ]; do
        echo "Please scp oracle-xe-11.2.0-1.0.x86_64.rpm.zip to my /tmp."
        echo "  example: scp -i ssh-key/openxt oracle-xe-11.2.0-1.0.x86_64.rpm.zip build@192.168.${IP_C}.103:/tmp"
        sleep 60
    done
    unzip /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip
    sudo rpm -ivh Disk1/oracle-xe-11.2.0-1.0.x86_64.rpm
    sudo /etc/init.d/oracle-xe configure <<EOF


xenroot
xenroot

EOF
    . /u01/app/oracle/product/11.2.0/xe/bin/oracle_env.sh
    sudo -E pip install cx_Oracle
    touch ~/oracled
fi

mkdir -p $BUILD_DIR/repo/RPMS
cd $BUILD_DIR

KERNEL_VERSION=`ls /lib/modules | tail -1`

rm -rf pv-linux-drivers
git clone -b lxc https://github.com/jean-edouard/pv-linux-drivers.git

# Build the tools
for i in `ls -d pv-linux-drivers/openxt-*`; do
    tool=`basename $i`

    # Remove package
    sudo dkms remove -m ${tool} -v 1.0 --all || true
    sudo rm -rf /usr/src/${tool}-1.0

    # Fetch package
    sudo cp -r pv-linux-drivers/${tool} /usr/src/${tool}-1.0

    # Build package
    sudo dkms add -m ${tool} -v 1.0
    sudo dkms build -m ${tool} -v 1.0 -k ${KERNEL_VERSION} --kernelsourcedir=/usr/src/kernels/${KERNEL_VERSION}
    sudo dkms mkrpm -m ${tool} -v 1.0 -k ${KERNEL_VERSION}
    cp /var/lib/dkms/${tool}/1.0/rpm/* repo/RPMS
done

# Build syncxt
rm -rf openxt
git clone https://github.com/OpenXT/openxt.git
cd openxt
OPENXT_DIR=`pwd`
mkdir src
cd src
git clone https://github.com/OpenXT/sync-database.git
git clone https://github.com/OpenXT/sync-cli.git
git clone https://github.com/OpenXT/sync-server.git
git clone https://github.com/OpenXT/sync-ui-helper.git
cd ..
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/u01/app/oracle/product/11.2.0/xe/lib"
./do_sync_xt.sh ${OPENXT_DIR}
cd ..
cp openxt/out/* repo/RPMS

# Create the repo
createrepo repo

# Copy the resulting repository
scp -r repo ${DUDE}@192.168.${IP_C}.1:${BUILD_DIR}/rpms

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
