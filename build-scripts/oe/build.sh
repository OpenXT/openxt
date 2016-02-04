#!/bin/sh

set -e

BUILD_USER=%BUILD_USER%
BUILD_DIR=%BUILD_DIR%
IP_C=%IP_C%
SUBNET_PREFIX=%SUBNET_PREFIX%
ALL_BUILDS_SUBDIR_NAME=%ALL_BUILDS_SUBDIR_NAME%

mkdir $BUILD_DIR
cd $BUILD_DIR

git clone git://${SUBNET_PREFIX}.${IP_C}.1/${BUILD_USER}/openxt.git

cd openxt
cp example-config .config
cat >>.config <<EOF
OPENXT_GIT_MIRROR="${SUBNET_PREFIX}.${IP_C}.1/${BUILD_USER}"
OPENXT_GIT_PROTOCOL="git"
REPO_PROD_CACERT="/home/build/certs/prod-cacert.pem"
REPO_DEV_CACERT="/home/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_CERT="/home/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_KEY="/home/build/certs/dev-cakey.pem"
EOF

./do_build.sh | tee build.log

# Copy the build output
scp -r build-output/* "${BUILD_USER}@${SUBNET_PREFIX}.${IP_C}.1:${ALL_BUILDS_SUBDIR_NAME}/${BUILD_DIR}/"

# The script may run in an "ssh -t -t" environment, that won't exit on its own
set +e
exit
