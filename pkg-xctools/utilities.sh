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

# Detect Linux distro: rhel (for RHEL, CentOS) or debian (for Debian, Ubuntu)
detect_distro()
{
        if [ -r /etc/redhat-release ] ; then
                DISTRO=rhel
        else
                DISTRO=debian
        fi
}

# Check for prerequisites
prerequisite_check()
{
        # Check for root user
        if [ "x$(id -u)" != "x0" ]; then
                warning "This script must be run as root."
        fi

        # On Debian/Ubuntu, check if we have gdebi
        if [ "$DISTRO" = debian ] ; then
                if ! command -v gdebi >/dev/null 2>&1; then
                        warning "\
gdebi tools are required for this installation.
Please install them using:

 $ sudo apt-get install gdebi-core"
                fi
        fi

        # FIXME: dkms? (but not for switcher?)
}

# Install a package
install_deb()
{
	local package="${1}"
	local deb_path="${2}"

	set -e
        
	echo "removing previous ${package}"
        dpkg --purge "${package}"

        echo "installing ${package}"
        gdebi --non-interactive $deb_path

        # check install succeeded, gdebi can exit 0 on failure
        if ! dpkg -s "${package}" > /dev/null 2>&1; then
                exit 1
        fi
}
