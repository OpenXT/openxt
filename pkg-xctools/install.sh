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
	# Install xc-tools
	case "${DISTRO}" in
		"ubuntu"|"debian")
                        # Avoid "Failed to satisfy all dependencies (broken
                        # cache)" by removing xc-switcher first in any case.
	                if dpkg -l xc-switcher > /dev/null 2>&1; then
                                dpkg --purge xc-switcher
                        fi
			gdebi_install "${INSTALLER_PATH}/xenclient-linuxtools.deb" xc-tools
			;;
		"centos"|"fedora")
			rpm_install "${INSTALLER_PATH}"/xc-tools-*.rpm xc-tools
			;;
		*)
			warning "Unsupported distribution: \`${DISTRO} ${DISTRO_VERSION}\'"
			;;
	esac
	# Install xc-switcher from its standalone script.
        ${INSTALLER_PATH}/install_switcher.sh
)
exit_code=$?

if [ $exit_code -ne 0 ]; then
	pretty_print "XenClient Linux tools install failed.
Re-running the install may fix the problem."
else
	pretty_print "XenClient Linux tools successfully installed."
fi

exit $exit_code
