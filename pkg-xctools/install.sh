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
                [ -n "`rpm -qa xc-switcher`" ] && yum -y erase xc-switcher
                [ -n "`rpm -qa xc-tools`" ] && yum -y erase xc-tools

                # Install xc-tools.
                yum -y install "${INSTALLER_PATH}"/xc-tools-*.rpm
        else
	        dpkg -l xc-switcher > /dev/null 2>&1 && dpkg --purge xc-switcher
	        dpkg -l xc-tools > /dev/null 2>&1 && dpkg --purge xc-tools

                # Install tools
                install_deb "xc-tools" "${INSTALLER_PATH}/xenclient-linuxtools.deb"
        fi
        $INSTALLER_PATH/install_switcher.sh
)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	pretty_print "XenClient Linux tools install failed.
Re-running the install may fix the problem."
else
	pretty_print "XenClient Linux tools successfully installed."
fi

exit $exit_code
