#!/bin/sh
# Utility functions for XenClient linux install scripts

# Prettify a message
pretty_print()
{
	local message="$1"
	local h_border='='
	local v_border='|'
	local min_width=20
	local lines=''
	set -f
	IFS='
'
	for line in $message; do
		if [ ${#line} -gt $min_width ]; then
			min_width=${#line};
		fi
	done

	for line in $message; do
		pad_line=$(printf "%-$((min_width))s" "${line}")
		lines="${lines}
${v_border} ${pad_line} ${v_border}"
	done

	h_border=$(printf '%*s' "$((min_width+4))" '' | sed "s/ /${h_border}/g")
	echo "
${h_border}${lines}
${h_border}" 1>&2
}

# Print warning and exit
warning()
{
        pretty_print "$1"
        exit "${2:-1}"
}

# Use /etc/os-release to fetch distribution information.
# Rely on ID and VERSION_ID.
# Some distributions do not define VERISON_ID (Arch).
detect_distro()
{
        if [ -e /etc/os-release ]; then
                . /etc/os-release
        elif [ ! -e /usr/lib/os-release ]; then
                . /usr/lib/os-release
        fi

        if [ -z "$ID" -o -z "$VERSION_ID" ]; then
                warning "zould not detect distribution using /etc/os-release or /usr/lib/os-release."
        fi
        # Legacy env variable for this script.
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
}

# Check for prerequisites
prerequisite_check()
{
        # Check for root user
        if [ "$(id -u)" != "0" ]; then
                warning "This script must be run as root."
        fi

        # On Debian/Ubuntu, check if we have gdebi
        case "${DISTRO}" in
                "ubuntu"|"debian")
                        if ! command -v gdebi >/dev/null 2>&1; then
                                warning "\
gdebi tools are required for this installation.
Please install them using:

 $ sudo apt-get install gdebi-core"
                        fi
                        ;;
                "centos")
                        # CentOS does not package dkms by default.  dkms is in
                        # EPEL repo which can be added through the epel-release
                        # package. Make sure this is done.
                        if [ -z "`rpm -qa dkms`" -a -z "`rpm -qa epel-release`" ]; then 
                                if ! yum -y install epel-release; then
                                        warning "\
OpenXT tools require dkms which should be in EPEL repositories.
Installing epel-release failed, please see:
https://fedoraproject.org/wiki/EPEL
to add EPEL repository and install dkms.
"
                                fi
                        fi
                        ;;
                *) ;;
        esac
}

# Install a .deb with gdebi.
gdebi_install()
{
        local pkg="$1"
        local pkg_name="$2"

        set -e
        # Remove existing.
	if dpkg -l "${pkg_name}" > /dev/null 2>&1; then
                dpkg --purge --force-depends "${pkg_name}"
        fi
        gdebi --non-interactive "${pkg}"
        if ! dpkg -s "${pkg_name}"; then
                dpkg --purge ${pkg_name}
                pretty_print "${pkg_name} installation failed."
                return 1
        fi
}

# Install an rpm with yum.
rpm_install()
{
        local pkg="$1"
        local pkg_name="$2"

        set -e
        # Remove existing.
        if [ -n "`rpm -qa "${pkg_name}"`" ]; then 
                yum -y erase "${pkg_name}"
        fi
        # Install xc-tools.
        if ! yum -y install "${pkg}"; then
                yum -y erase "${pkg_name}"
                pretty_print "${pkg_name} installation failed."
                return 1
        fi
}
