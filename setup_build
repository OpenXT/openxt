#!/bin/sh
# OpenXT git repo setup file.

die() {
	echo "$1" 1>&2
	exit 1
}

#######################################################################
# checkout_git_branch                                                 #
# param1: Path to the git repo                                        #
# param2: Preferred branch to checkout.  Fallback will be to master.  #
#                                                                     #
# Checks out the branch specified in param2 for the repo located at   #
# the file path in param1.  If the branch is not part of the git repo #
# the master branch is checked out instead.                           #
#######################################################################
checkout_git_branch() {
	local path="$1"
	local branch="$2"

	cd $path
	git checkout "$branch" 2>/dev/null|| git checkout -b "$branch" origin/$branch 2>/dev/null || { echo "The value $branch does not exist as a branch or HEAD position. Falling back to the master branch."; git checkout master 2>/dev/null; }
	cd $OLDPWD
}

#######################################################################
# fetch_git_repo                                                      #
# param1: Path (absolute) to place the repo                           #
# param2: Git url to fetch                                            #
#                                                                     #
# Fetches the repo specified by param2 into the directory specified   #
# by param1.                                                          #
#######################################################################
fetch_git_repo() {
	local path="$1"
	local repo="$2"

	echo "Fetching $repo..."
	set +e
	git clone -q -n $repo "$path" || die "Clone of git repo failed: $repo"
	set -e
}

process_git_repo() {
	local path="$1"
	local repo="$2"
	local branch="$3"

	# Remove the directory if it's empty
	[ -d $path ] && [ -z "`ls -A1 $path | head -1`" ] && rmdir $path

	if [ ! -d $path ]; then
		# The path does not exist.  Proceed.
		fetch_git_repo $path $repo $branch
		checkout_git_branch $path $branch
	fi
}

OE_XENCLIENT_DIR=`pwd`
REPOS=$OE_XENCLIENT_DIR/repos
OE_PARENT_DIR=$(dirname $OE_XENCLIENT_DIR)

# Load our config
[ -f "$OE_PARENT_DIR/.config" ] && . "$OE_PARENT_DIR/.config"

mkdir -p $REPOS || die "Could not create local build dir"

# Pull down the OpenXT repos
process_git_repo $REPOS/xenclient-oe $XENCLIENT_REPO $XENCLIENT_TAG
process_git_repo $REPOS/bitbake $BITBAKE_REPO $BB_BRANCH
for repo in openembedded-core meta-openembedded meta-java meta-selinux meta-intel meta-openxt-ocaml-platform meta-openxt-haskell-platform meta-virtualization; do
    repo_var=`echo $repo | sed -e 's/openembedded/oe/' -e 's/-/_/g' | tr '[a-z]' '[A-Z]'`
    git_var="${repo_var}_REPO"
    git=${!git_var}
    tag_var="${repo_var}_TAG"
    tag=${!tag_var}
    [ -z ${tag} ] && tag=$OE_BRANCH
    process_git_repo $REPOS/$repo $git $tag
done

if [ ! -e $OE_XENCLIENT_DIR/conf/local.conf ]; then
  ln -s $OE_XENCLIENT_DIR/conf/local.conf-dist \
      $OE_XENCLIENT_DIR/conf/local.conf
fi

BBPATH=$OE_XENCLIENT_DIR/oe/xenclient:$REPOS/openembedded:$OE_XENCLIENT_DIR/oe-addons
if [ ! -z "$EXTRA_DIR" ]; then
  BBPATH=$REPOS/$EXTRA_DIR:$BBPATH
fi

cat > oeenv <<EOF 
OE_XENCLIENT_DIR=$OE_XENCLIENT_DIR
PATH=$OE_XENCLIENT_DIR/repos/bitbake/bin:\$PATH
BBPATH=$BBPATH
BB_ENV_EXTRAWHITE="OE_XENCLIENT_DIR MACHINE GIT_AUTHOR_NAME EMAIL"

export OE_XENCLIENT_DIR PATH BBPATH BB_ENV_EXTRAWHITE
EOF
