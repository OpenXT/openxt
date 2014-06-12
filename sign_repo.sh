#!/bin/sh
#
# Generates the XC-SIGNATURE metadata file for a XenClient repository.

parse_args()
{
    if [ $# -ne 3 ] ; then
        usage
        exit 1
    fi

    CERTIFICATE="$1"
    PRIVATE_KEY="$2"
    REPOSITORY_DIR="$3"

    REPOSITORY_FILE="${REPOSITORY_DIR}/XC-REPOSITORY"
    SIGNATURE_FILE="${REPOSITORY_DIR}/XC-SIGNATURE"
}

usage()
{
    cat <<EOF
Usage: $(basename $0) CERTIFICATE PRIVATE_KEY REPOSITORY_DIR

Signs a XenClient repository: uses the supplied certificate and private key
to generate a signature of the XC-REPOSITORY file and writes it to the
XC-SIGNATURE file.
EOF
}

generate_signature()
{
    local PASSPHRASE_ARG

    [ "${PASSPHRASE}" ] && PASSPHRASE_ARG="-passin env:PASSPHRASE"

    openssl smime -sign \
                  -aes256 \
                  -binary \
                  -in "${REPOSITORY_FILE}" \
                  -out "${SIGNATURE_FILE}" \
                  -outform PEM \
                  -signer "${CERTIFICATE}" \
                  -inkey "${PRIVATE_KEY}" \
                  ${PASSPHRASE_ARG} ||
        die "error generating signature"
}

die()
{
    echo "$(basename $0): $*" >&2
    exit 1
}

parse_args "$@"

generate_signature
