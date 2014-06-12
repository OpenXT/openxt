#! /bin/bash 

set -e

REPO="/home/xc_source/git/xenclient"
BRANCH="master"
NEW_BRANCH=""

usage()
{
        echo "$0: [-N] [-b BRANCH] [-r REPO] -n NEW_BRANCH"
}

unset NOACTION
while [ "$#" -ne 0 ]; do
        case "$1" in
                -b) BRANCH="$2"; shift 2 ;;
                -n) NEW_BRANCH="$2"; shift 2;;
                -r) REPO="$2"; shift 2;;
                -N) NOACTION=-n; shift;;
                --) shift ; break ;;
                *) usage ; exit 1;;
        esac
done

if [ "x$REPO" == "x" -o "x$BRANCH" == "x" -o "x$NEW_BRANCH" == "x" ]
then
        usage
        exit 1
fi


log() { "$@" ; }

for i in "$REPO"/*.git
do
        dir="`basename "${i%.git}"`"
        branch="$BRANCH"

        if [ ! -d "$dir" ]; then
                rm -rf "$dir.tmp"
                log git clone -n "$i" "$dir.tmp"
                mv "$dir.tmp" "$dir"
        fi

	    branches=$(cd $dir && git branch -a)
    	if [ "x${branches}" == "x" ]; then
                echo "NOTE: no branches in $dir"
                continue
	    fi

        (
                cd $dir
                if ! git show-ref $branch ; then
                        headbranch="`cat .git/HEAD | cut -d'/' -f3`"
                        echo "Branch $branch doesn't exist, use ${headbranch} for $dir"
                        branch=${headbranch}
                fi
		git checkout ${branch}
        
                git branch ${NEW_BRANCH} ${branch}
                sudo git push ${NOACTION} origin ${NEW_BRANCH}
        )
done
