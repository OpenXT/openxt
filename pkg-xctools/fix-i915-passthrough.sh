#!/bin/bash

set -e

die() {
	echo "ERROR: $1" 1>&2
	exit 1
}

export PATH="/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin"
cd "$( dirname "${BASH_SOURCE[0]}" )"

SRC_DIR="/usr/src/xc-i915-fix"
LINUX_DIR=""

#try to determine the newest kernel
KSUFFIX=$(uname -r | sed -n -re 's/.*[0-9](\-[^ 0-9]+)$/\1/p')
apt-get -q -y update
apt-get -y install make gcc
apt-get -y install "linux-headers${KSUFFIX}"
KERNEL=$(apt-cache depends "linux-headers${KSUFFIX}" | sed -n -re 's/^(.*Depends.*linux-headers-)([^ \t]+)$/\2/p')
[[ -z "${KERNEL}" ]] && KERNEL=$(uname -r)


KERNEL_MOD_DIR="/lib/modules/${KERNEL}"
[[ -d "${SRC_DIR}" ]] && rm -rf --one-file-system "${SRC_DIR}"
mkdir -p "${SRC_DIR}"
pushd "${SRC_DIR}"
	apt-get -y install linux-headers-${KERNEL}
	apt-get -y install linux-image-${KERNEL}
	apt-get -y install make gcc
	apt-get -y source linux-image-${KERNEL}
	LINUX_DIR="$(find . -maxdepth 1 -type d -name 'linux*')"
	[[ -z "${LINUX_DIR}" ]] && die "cannot find the linux kernel source dir"
	[[ -d "${LINUX_DIR}/drivers/gpu/drm/i915/" ]] || die "cannot find the i915 driver source dir"
popd

cp xc-i915-passthrough.patch "${SRC_DIR}/${LINUX_DIR}/"
pushd "${SRC_DIR}/${LINUX_DIR}/"
	patch -p1 < xc-i915-passthrough.patch
	pushd drivers/gpu/drm/i915/
		make -C "/usr/src/linux-headers-${KERNEL}" M="$(pwd)" modules
		find "${KERNEL_MOD_DIR}" -type f -name 'i915.ko' -not \( -path "${KERNEL_MOD_DIR}/build" -prune \) -exec cp ./i915.ko '{}' ';'
		depmod ${KERNEL}
		update-initramfs -u -k ${KERNEL}
	popd
popd

echo
echo "The i915 driver has been updated."
echo
exit 0
