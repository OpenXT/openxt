#!/bin/bash -ex

destdir="$1"

cp -p ${BUILD_SCRIPTS}/pkg-xctools/utilities.sh ${destdir}
cp -p ${BUILD_SCRIPTS}/pkg-xctools/install.sh ${destdir}
cp -p ${BUILD_SCRIPTS}/pkg-xctools/README ${destdir}
