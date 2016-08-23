#!/bin/sh
#
# Generates a XenClient installer iso image.

usage()
{
    cat <<EOF >&2
Usage: $(basename $0) ISO_DIR ISO_IMAGE ISO_LABEL
  e.g. $(basename $0) installer installer.iso XC_installer

Generates a XenClient installer iso image ISO_IMAGE from the contents of the
directory ISO_DIR.
EOF
}

die()
{
    echo "$(basename $0): $*" >&2
    exit 1
}

if [ $# -ne 3 ] ; then
    usage
    exit 1
fi

ISO_DIR="$1"
ISO_IMAGE="$2"
ISO_LABEL="$3"

genisoimage -o "${ISO_IMAGE}" \
        -b "isolinux/isolinux.bin" \
        -c "isolinux/boot.cat" \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -r \
        -J \
        -l \
        -V "${ISO_LABEL}" \
        -quiet \
        "${ISO_DIR}" || die "genisoimage failed"

"${ISO_DIR}/isolinux/isohybrid" "${ISO_IMAGE}" || die "isohybrid failed"
