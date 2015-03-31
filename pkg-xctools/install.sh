#!/bin/sh
# Script for installing/upgrading XenClient Linux guest tools

INSTALLER_PATH=`dirname $0`

# Include utils
. "${INSTALLER_PATH}/utilities.sh"

# Detect Linux distro
detect_distro

# Check for prerequisites
prerequisite_check

# Installer
(
	set -e

        if [ "$DISTRO" = rhel ] ; then
                # Remove the packages first. This shouldn't be necessary,
                # but is done for consistency with Debian/Ubuntu.
                yum -y erase xc-switcher xc-tools

                # For dkms, we need to make sure that every installed kernel
                # RPM has a matching installed kernel-devel RPM.
                #
                # Unfortunately, we can't rely on the fact that the dkms RPM
                # depends on kernel-devel: yum will only check that some
                # kernel-devel RPM is installed, and if none is installed, it
                # picks the latest available.
                #
                # This would fail when the installed kernel RPM is not the
                # latest available (e.g. before installing updates) or if more
                # than one kernel RPM is installed (e.g. after installing
                # updates).
                KERNEL_DEVEL_RPMS=`\
                    rpm --queryformat \
                        "kernel-devel-%{VERSION}-%{RELEASE}.%{ARCH} " \
                        -q kernel`
                yum -y install "${INSTALLER_PATH}"/xc-tools-*.rpm \
                               "${INSTALLER_PATH}"/dkms-*.rpm \
                               ${KERNEL_DEVEL_RPMS}
                $INSTALLER_PATH/install_switcher.sh
        else
                # Remove switcher
                dpkg --purge xc-switcher

                # FIXME: see the debian package to know why we can't reinstall the package
                # gdebi must do it, but it fails. It can't find xenstore source

                # Install tools
                install_deb "xc-tools" "${INSTALLER_PATH}/xenclient-linuxtools.deb"

                # libappindicator was added in debian with Wheezy
                distrib=`lsb_release -is`
                codename=`lsb_release -rs`

                if [ \( "x$distrib" != "xDebian" \) -o \( "x$codename" = "xwheezy" \) ]; then
                        $INSTALLER_PATH/install_switcher.sh
                fi
        fi
)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	pretty_print "XenClient Linux tools install failed.
Re-running the install may fix the problem."
else
	pretty_print "XenClient Linux tools successfully installed."
fi

exit $exit_code
