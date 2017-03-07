#!/bin/bash -ex

source ${BUILD_SCRIPTS}/build_helpers.sh
source ${BUILD_SCRIPTS}/version

make_bundle_xcswitcher()
{
    local path=`cd "$1"; pwd`
    local out_dir="$2"
    local deb="${out_dir}/xenclient-switcher.deb"
    local deb_tmp="${path}/xcswitcher/deb-tmp"
    local deb_data="${deb_tmp}/data"
    local deb_control="${deb_tmp}/control"
    local rpm_tmp="${path}/xctools/rpm-tmp"

    rm -rf ${deb_tmp} ${rpm_tmp} git-tmp
    mkdir -p ${rpm_tmp}/{,RPMS,SOURCES,SPECS,SRPMS}
    mkdir -p ${deb_control} ${deb_data}/usr/src
    # Default control files for the bundle.
    cp -rTf ${BUILD_SCRIPTS}/pkg-xcswitcher/control ${deb_control}
    mkdir -p git-tmp
    git_clone "git-tmp" "${OPENXT_GIT_PROTOCOL}://${OPENXT_GIT_MIRROR}/xctools.git" "${BRANCH}" "$ALLOW_SWITCH_BRANCH_FAIL"
    cp -rT git-tmp/xc-switcher ${deb_data}/usr/src/xc-switcher-1.0
    rm -rf git-tmp
    mkdir -p  ${deb_data}/usr/share/xc-switcher/
    ( cd ${deb_data}/usr/src/xc-switcher-1.0 && mv icons ${deb_data}/usr/share/xc-switcher/ )

    # Deal with control stuff
    pushd ${deb_tmp}
        local size=`du -s ${deb_data} | cut -f1`
        sed -e "s/@SIZE@/${size}/" -i ${deb_control}/control

        mkdir -p ${deb_data}/usr/share/lintian/overrides
        cat - > ${deb_data}/usr/share/lintian/overrides/xc-switcher <<!
xc-switcher: extended-description-is-empty
xc-switcher: changelog-file-missing-in-native-package
xc-switcher: copyright-file-is-symlink
xc-switcher: copyright-without-copyright-notice
xc-switcher: no-copyright-file
xc-switcher: extra-license-file
xc-switcher: unknown-section
xc-switcher: debian-changelog-file-missing
xc-switcher: no-copyright-file
xc-switcher: maintainer-script-ignores-errors
!
        find ${deb_data} \( -name '*.a' -o -name '*.o' -o -name '*.so' -o -name '.*' -o -name '*~' \) -a -exec rm -rf {} \;
        pushd ${deb_data}
            [ -d etc ] && find etc -type f | sed -e 's/^/\//' > ${deb_control}/conffiles
            find * -type f -exec md5sum {} \; > ${deb_control}/md5sums
            tar cz --owner=root --group=root -f ${deb_tmp}/data.tar.gz * --exclude=.#* --exclude=*~ --exclude=#*# --exclude-vcs
	    cp ${deb_tmp}/data.tar.gz ${rpm_tmp}/SOURCES/xc-switcher.tar.gz
        popd
            local XENCLIENT_TOOLS="$XC_TOOLS_MAJOR.$XC_TOOLS_MINOR.$XC_TOOLS_MICRO.$XC_TOOLS_BUILD"
        pushd ${deb_control}
	    sed -e "s/@XENCLIENT_TOOLS@/${XENCLIENT_TOOLS}/" -i postinst
            chmod 755 post*
            tar -cz --owner=root --group=root -f ${deb_tmp}/control.tar.gz * --exclude=.#* --exclude=*~ --exclude=#*# --exclude-vcs
        popd
    popd
    echo "2.0" > ${deb_tmp}/debian-binary
    ar rcD ${deb} ${deb_tmp}/debian-binary ${deb_tmp}/control.tar.gz ${deb_tmp}/data.tar.gz

    if which lintian 2>/dev/null && ! lintian ${deb}; then
        echo Xenclient Linux switcher package fails sanity check
    fi
    rm -rf ${deb_tmp}

    # I'm so sorry :(
    pushd ${rpm_tmp}/SPECS
        cp ${BUILD_SCRIPTS}/sync-xt/*.inc .
        cp ${BUILD_SCRIPTS}/pkg-xcswitcher/xc-switcher.spec .

        for i in postinst postrm ; do
            sed "s/@XENCLIENT_TOOLS@/${XENCLIENT_TOOLS}/" \
                ${BUILD_SCRIPTS}/pkg-xcswitcher/control/${i} > xc-switcher-${i}.inc
        done

        rpmbuild --define "_topdir ${rpm_tmp}" \
                 --define "xc_build ${BRANCH}" \
                 --define "xc_release ${RELEASE}" -bb xc-switcher.spec

    popd

    cp ${rpm_tmp}/RPMS/noarch/*.rpm ${out_dir}
    rm -rf ${rpm_tmp}
}

make_bundle_xcswitcher "$1" xc-tools-tmp/linux
