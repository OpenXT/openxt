#!/bin/sh

set -e

BUILD_USER=%BUILD_USER%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%
SUBNET_PREFIX=%SUBNET_PREFIX%
ALL_BUILDS_SUBDIR_NAME=%ALL_BUILDS_SUBDIR_NAME%

mkdir $BUILD_DIR
cd $BUILD_DIR

# commented out this usual clone line:
#git clone git://${SUBNET_PREFIX}.${IP_C}.1/${BUILD_USER}/openxt.git

# get the correct openxt.git repo for jethro
# and merge the branch into master to use it.
git clone https://github.com/aikidokatech/openxt.git
cd openxt
git checkout jethro-merge
git checkout master
git config user.email "build@localhost"
git config user.name "automated build"
git merge --no-edit jethro-merge

cp example-config .config
cat >>.config <<EOF
OPENXT_GIT_MIRROR="${SUBNET_PREFIX}.${IP_C}.1/${BUILD_USER}"
OPENXT_GIT_PROTOCOL="git"
REPO_PROD_CACERT="/home/build/certs/prod-cacert.pem"
REPO_DEV_CACERT="/home/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_CERT="/home/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_KEY="/home/build/certs/dev-cakey.pem"
EOF

./do_build.sh -s setupoe | tee setupoe.log

# now remove setupoe from STEPS:
sed -i 's/^STEPS="setupoe,/STEPS="/' ./do_build.sh

# get the right jethro xenclient-oe repo
# and again merge into master to use it
cd build/repos/xenclient-oe
git remote rm origin || echo ok no prior origin
git remote add origin "https://github.com/aikidokatech/xenclient-oe.git"
git fetch
git checkout jethro-merge
git checkout master
git config user.email "build@localhost"
git config user.name "automated build"
git merge --no-edit jethro-merge
cd -

# Apply Eric's temporary workaround:
sed -i 's/^LOCALE_GENERATION_WITH_CROSS-LOCALEDEF = "1"/LOCALE_GENERATION_WITH_CROSS-LOCALEDEF = "0"/' ./build/repos/openembedded-core/meta/recipes-core/glibc/glibc-locale.inc

./do_build.sh | tee build.log

# Copy the build output
scp -r build-output/* "${BUILD_USER}@${SUBNET_PREFIX}.${IP_C}.1:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/"

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
