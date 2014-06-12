#!/bin/sh
# Script for installing/upgrading XenClient switcher

INSTALLER_PATH=`dirname $0`

if [ -r /etc/redhat-release ] ; then
    DISTRO=rhel
else
    DISTRO=debian
fi

# Include utils
. "${INSTALLER_PATH}/utilities.sh"

# Check for prerequisites
prerequisite_check

# Install switcher
if [ "${DISTRO}" = debian ] ; then
    install_deb "xc-switcher" "${INSTALLER_PATH}/xenclient-switcher.deb"
else
    yum -y install "${INSTALLER_PATH}"/xc-switcher-*.rpm
fi
exit_code=$?

if [ $exit_code -ne 0 ]; then
	pretty_print "XenClient switcher install failed.
Re-running the install may fix the problem."
else
	pretty_print "XenClient switcher successfully installed."
fi

exit $exit_code
