#!/bin/bash
#
# Builds the Synchronizer XT RPMs. This should be run on a 64-bit CentOS 6
# machine.

set -e

DEFAULT_REPOS="sync-database sync-cli sync-server sync-ui-helper"

parse_args()
{
    BUILD_ID="unknown"
    REPOS=
    VERBOSE=

    while getopts :i:r:v OPT; do
        case $OPT in
            i) BUILD_ID="$OPTARG " ;;
            r) REPOS="$REPOS$OPTARG " ;;
            v) VERBOSE="1" ;;
            *) usage ;;
        esac
    done

    shift $((OPTIND - 1))
    [ $# -eq 1 ] || usage

    BASE_DIR="$1"

    [ "$BASE_DIR" ] || usage
    [ "$REPOS" ] || REPOS="$DEFAULT_REPOS"
}

usage()
{
    cat <<EOF >&2
Usage: $(basename $0) [-i BUILD_ID] [-r REPO_NAME ...] [-v] BASE_DIR

Builds the Synchronizer XT RPMs.

Requires the relevant git repositories to be checked out in BASE_DIR/src.
Unless overridden with the -r option, these are:

EOF

    for REPO in $DEFAULT_REPOS ; do
        echo "    $REPO" >&2
    done

cat <<EOF >&2

Builds the RPMs under BASE_DIR/build and copies the result to BASE_DIR/out.
Should be run on a 64-bit CentOS 6 machine with the following installed:

    Oracle client
    python-argparse
    cx_Oracle

EOF

    exit 1
}

check_repos()
{
    echo "++++++++ Checking repositories ++++++++"

    for REPO in $REPOS ; do
        if [ ! -d src/$REPO ] ; then
            echo "Error: Need to check out $REPO in $BASE_DIR/src" >&2
            exit 1
        fi
    done
}

generate_source_tarballs()
{
    echo "++++++++ Generating source tarballs ++++++++"

    for REPO in $REPOS ; do
        if [ -e src/$REPO/FILTER ] ; then
            FILTER=
            while read LINE ; do
                FILTER="$FILTER$REPO/$LINE "
            done < src/$REPO/FILTER
        else
            FILTER=$REPO
        fi

        echo $REPO.tar.gz
        tar -czf build/SOURCES/$REPO.tar.gz -C src --exclude .git $FILTER
    done
}

build_rpms()
{
    cp "$OPENXT_DIR/sync-xt/"*.inc build/SPECS

    for REPO in $REPOS ; do
        for FILE in src/$REPO/*.spec src/$REPO/*.inc ; do
            if [ -e "$FILE" ] ; then
                cp "$FILE" build/SPECS
            fi
        done
    done

    BUILD_DIR="$(pwd)/build"

    (
        cd build/SPECS

        for SPEC in *.spec ; do
            echo "++++++++ Building $SPEC ++++++++"

            rm -rf ../BUILD
            mkdir ../BUILD

            rpmbuild --define "_topdir $BUILD_DIR" \
                     --define "xc_build $BUILD_ID" \
                     --define "xc_release $RELEASE" -bb "$SPEC"
        done
    )
}

copy_rpms_to_output_dir()
{
    echo "++++++++ Copying RPMs to output directory ++++++++"

    install -m 644 build/RPMS/*/*.rpm out/
    ls -1 out
}

parse_args "$@"

[ "$VERBOSE" ] && set -x

OPENXT_DIR="$(pwd)/$(dirname $0)"

cd "$BASE_DIR" || exit 1

check_repos

rm -rf build out
mkdir build/{,RPMS,SOURCES,SPECS,SRPMS} out

# Get RELEASE
. "$OPENXT_DIR/version"

generate_source_tarballs
build_rpms
copy_rpms_to_output_dir
