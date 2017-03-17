#!/bin/sh
# Script for installing/upgrading XenClient switcher

INSTALLER_PATH=`dirname $0`

# Include utils
. "${INSTALLER_PATH}/utilities.sh"

# Detect distribution.
detect_distro

# Check for prerequisites
prerequisite_check

# Installer
(
	set -e

	# Install xc-switcher
	case "${DISTRO}" in
		"ubuntu"|"debian")
			gdebi_install "${INSTALLER_PATH}/xenclient-switcher.deb" xc-switcher
			;;
		"centos"|"fedora")
			rpm_install "${INSTALLER_PATH}"/xc-switcher-*.rpm xc-switcher
			;;
		*)
			warning "Unsupported distribution: \`${DISTRO} ${DISTRO_VERSION}\'"
			;;
	esac
)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	pretty_print "XenClient switcher install failed.
Re-running the install may fix the problem."
else
	pretty_print "XenClient switcher successfully installed."
fi

exit $exit_code
