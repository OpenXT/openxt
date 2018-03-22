#!/bin/sh
#
# Generates a XenClient installer iso image.

usage()
{
    cat <<EOF >&2
Usage: $(basename $0) ISO_DIR ISO_IMAGE ISO_LABEL ISO_HDPFX
  e.g. $(basename $0) installer installer.iso XC_installer isohdpfx.bin

Generates a XenClient installer iso image ISO_IMAGE from the contents of the
directory ISO_DIR.
EOF
}

die()
{
    echo "$(basename $0): $*" >&2
    exit 1
}

if [ $# -ne 4 ] ; then
    usage
    exit 1
fi

ISO_DIR="$1"
ISO_IMAGE="$2"
ISO_LABEL="$3"
ISO_HDPFX="$4"

xorriso -as mkisofs \
                -o "${ISO_IMAGE}" \
                -isohybrid-mbr "${ISO_HDPFX}" \
                -c "isolinux/boot.cat" \
                -b "isolinux/isolinux.bin" \
                -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table \
                -eltorito-alt-boot \
                -e "isolinux/efiboot.img" \
                -no-emul-boot \
                -isohybrid-gpt-basdat \
                -r \
                -J \
                -l \
                -V "${ISO_LABEL}" \
                -f \
                -quiet \
                "${ISO_DIR}" || die "xorriso failed"
