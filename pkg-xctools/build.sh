#!/bin/bash -ex

source ${BUILD_SCRIPTS}/build_helpers.sh
source ${BUILD_SCRIPTS}/version

export AWK=/usr/bin/awk

make_bundle_pv_drivers()
{
    local PDST_DIR="${3}/usr/src/openxt-${1}-1.0"
    local PSRC_DIR="${2}/openxt-${1}"
    local PDOC_DIR="${3}/usr/share/doc/openxt-${1}"
    local PLIN_DIR="${3}/usr/share/lintian/overrides/openxt-${1}"
    pushd $PSRC_DIR
        install -m 0644 -D dkms/lintian ${PLIN_DIR}
        install -m 0755 -d ${PDOC_DIR}
        cp ../COPYING ${PDOC_DIR}/copyright
        rm -rf dkms
        mkdir -p $PDST_DIR
        cp -a . $PDST_DIR
    popd
}

# Usage: make_bundle_xctools <name.deb>
# 2011-07-14: TODO: This should be considered as a temporary solution.
# 2012-11-27: it definitely should have.
# 2015-06-24: I would like to echo that last sentiment also.
make_bundle_xctools()
{
    local path=`cd "$1"; pwd`
    local out_dir="$2"
    local deb="${out_dir}/xenclient-linuxtools.deb"
    local deb_tmp="${path}/xctools/deb-tmp"
    local deb_data="${deb_tmp}/data"
    local deb_control="${deb_tmp}/control"
    local rpm_tmp="${path}/xctools/rpm-tmp"

    rm -rf ${deb_tmp} ${rpm_tmp} git-tmp
    mkdir -p ${rpm_tmp}/{,RPMS,SOURCES,SPECS,SRPMS}
    mkdir -p ${deb_control} ${deb_data}/usr/src
    # Default control files for the bundle.
    cp -rTf ${BUILD_SCRIPTS}/pkg-xctools/control ${deb_control}
    cp -rTf ${BUILD_SCRIPTS}/pkg-xctools/data ${deb_data}

    # libv4v
    mkdir -p git-tmp
    git_clone "git-tmp" "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/v4v.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    cp -rT git-tmp/libv4v ${deb_data}/usr/src/libv4v-1.0
    mkdir -p ${deb_data}/usr/src/libv4v-1.0/src/linux/ && cp git-tmp/v4v/linux/v4v_dev.h ${deb_data}/usr/src/libv4v-1.0/src/linux/
    rm -rf git-tmp

    # pv-linux-drivers
    local PTMP_DIR="pv-linux-drivers"
    rm -rf $PTMP_DIR
    mkdir -p $PTMP_DIR
    git_clone $PTMP_DIR "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/pv-linux-drivers.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    for pvd in "v4v" "xenmou" "vusb"
    do
        make_bundle_pv_drivers $pvd $PTMP_DIR $deb_data 
    done
    rm -rf $PTMP_DIR
    mkdir -p ${deb_data}/lib/udev/rules.d
    ( cd ${BUILD_SCRIPTS}/pkg-xctools/udev-rules/ && cp *.rules ${deb_data}/lib/udev/rules.d/ )

    # xenstore-agent
    mkdir -p git-tmp
    git_clone "git-tmp" "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/manager.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    cp -rT git-tmp/linuxtools/xenstore-agent ${deb_data}/usr/src/xenstore-agent-1.0
    rm -rf git-tmp

    # xblanker
    rm -rf "${deb_data}/usr/src/xblanker-1.0"
    mkdir -p "${deb_data}/usr/src/xblanker-1.0"
    git_clone "${deb_data}/usr/src/xblanker-1.0" "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/xblanker.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    rm -rf "${deb_data}/usr/src/xblanker-1.0/.git"

    # xf86-video-vesa
    rm -rf "${deb_data}/usr/src/xf86-video-vesa-1.0"
    mkdir -p git-tmp
    git_clone "git-tmp" "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/xctools.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    cp -rT git-tmp/xf86-video-vesa-2.3.2 ${deb_data}/usr/src/xf86-video-vesa-1.0
    rm -rf git-tmp

    # Deal with control stuff
    pushd ${deb_tmp}
        local size=`du -s ${deb_data} | cut -f1`
        sed -e "s/@SIZE@/${size}/" -i ${deb_control}/control

        mkdir -p ${deb_data}/usr/share/lintian/overrides
        cat - > ${deb_data}/usr/share/lintian/overrides/xc-tools <<!
xc-tools: extended-description-is-empty
xc-tools: changelog-file-missing-in-native-package
xc-tools: copyright-file-is-symlink
xc-tools: copyright-without-copyright-notice
xc-tools: no-copyright-file
xc-tools: extra-license-file
xc-tools: unknown-section
!
        find ${deb_data} \( -name '*.a' -o -name '*.o' -o -name '*.so' -o -name '.*' -o -name '*~' \) -a -exec rm -rf {} \;
        pushd ${deb_data}
            [ -d etc ] && find etc -type f | sed -e 's/^/\//' > ${deb_control}/conffiles
            find * -type f -exec md5sum {} \; > ${deb_control}/md5sums
            tar cz --owner=root --group=root -f ${deb_tmp}/data.tar.gz * --exclude=.#* --exclude=*~ --exclude=#*# --exclude-vcs
            cp ${deb_tmp}/data.tar.gz ${rpm_tmp}/SOURCES/xc-tools.tar.gz
        popd
        pushd ${deb_control}
	    sed -e "s/@XENCLIENT_TOOLS@/${XENCLIENT_TOOLS}/" -i postinst
            chmod 755 post* pre*
            tar -cz --owner=root --group=root -f ${deb_tmp}/control.tar.gz * --exclude=.#* --exclude=*~ --exclude=#*# --exclude-vcs
        popd
    popd
    echo "2.0" > ${deb_tmp}/debian-binary
    ar rcD ${deb} ${deb_tmp}/debian-binary ${deb_tmp}/control.tar.gz ${deb_tmp}/data.tar.gz

    if which lintian 2>/dev/null && ! lintian ${deb}; then
        echo Xenclient Linux tools package fails sanity check
        rm ${deb}
    fi
    rm -rf ${deb_tmp}

    # I'm so sorry :(
    pushd ${rpm_tmp}/SPECS
        cp ${BUILD_SCRIPTS}/sync-xt/*.inc . 
        cp ${BUILD_SCRIPTS}/pkg-xctools/xc-tools.spec .
        (cd ${BUILD_SCRIPTS}/pkg-xctools && tar cz centos) > ../SOURCES/xc-tools-centos.tar.gz

        for i in postinst prerm postrm ; do
            sed "s/@XENCLIENT_TOOLS@/${XENCLIENT_TOOLS}/" \
                ${BUILD_SCRIPTS}/pkg-xctools/control/${i} > xc-tools-${i}.inc
        done

        rpmbuild --define "_topdir ${rpm_tmp}" \
                 --define "xc_build ${BRANCH}" \
                 --define "xc_release ${RELEASE}" -bb xc-tools.spec

    popd

    cp ${rpm_tmp}/RPMS/noarch/*.rpm ${out_dir}
    rm -rf ${rpm_tmp}
}

make_bundle_xctools "$1" xc-tools-tmp/linux

