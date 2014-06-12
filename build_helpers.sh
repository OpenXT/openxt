die()
{
        echo "$1" 1>&2
        exit 1
}



git_clone()
{
        local path="$1"
        local url="$2"
        local tag="$3"
        local allow_switch_branch_fail="$4"

        rm -rf "$path.tmp"
	if [ $VERBOSE -eq 0 ]; then
	    ex="-q"
	fi
        git clone $ex -n "$url" "$path.tmp" && mkdir -p "$path" && rsync -lr "$path.tmp/" "$path/"
        rm -rf "$path.tmp"
        set +e
        (cd "$path" && git checkout $ex $tag || git checkout $ex -b $tag origin/$tag)
        if [ -z "$allow_switch_branch_fail" -a $? -ne 0 ]; then
                die "Switching to $tag failed while checking out $url, terminating. You can enforce fallback to default branch by setting ALLOW_SWITCH_BRANCH_FAIL in config"
        fi
        current_branch=`( cd "$path" && git branch) | grep -e ^* | cut -d ' ' -f2-`
        if [ "$current_branch" != "$tag" ]; then
                (cd "$path" && git checkout -b $tag)
        fi
        set -e
}
