#!/bin/bash -e

usage() {
    echo "usage: pr_merger.sh <token> <repo> <PR1> [PR2 [PR3 [PR4 [...]]]]" >&2
    echo "  where PRX is the pull request number" >&2
    exit $1
}

[ $# -lt 3 ] && usage 1

# Generate a token there: https://github.com/settings/tokens
if [ -e "$1" ]; then
    TOKEN=$(cat $1)
else
    TOKEN="$1"
fi
REPO="$2"
shift 2

TEMPDIR=`mktemp -d`
TEMPFILE=`mktemp`

login=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/user" | jq '.login' | cut -d '"' -f 2`

cloned=0
branch=""
final="prs"

for pr in $@; do
    curl -H "Authorization: token ${TOKEN}" -s "https://api.github.com/repos/openxt/${REPO}/pulls/${pr}" > $TEMPFILE
    base_branch=`cat $TEMPFILE | jq '.base.ref' | cut -d '"' -f 2`
    if [ $cloned -eq 0 ]; then
	branch=$base_branch
	git clone -q -b $branch https://github.com/OpenXT/${REPO}.git ${TEMPDIR}/${REPO}
	cd ${TEMPDIR}/${REPO}
	git remote add $login git@github.com:${login}/${REPO}.git
	cloned=1
    fi
    if [ $base_branch != $branch ]; then
	echo "Branch mismatch" >&2
	exit 2
    fi
    head=`cat $TEMPFILE | jq '.head.repo.html_url' | cut -d '"' -f 2`
    head_branch=`cat $TEMPFILE | jq '.head.ref' | cut -d '"' -f 2`
    git remote add "pr${pr}" $head
    git fetch -q "pr${pr}"
    git merge -q --no-edit "pr${pr}/${head_branch}"
    final="${final}-${pr}"
done

git push -q $login $branch:$final

echo "Done!"
echo "URL: https://github.com/${login}/${REPO}/tree/${final}"
echo "BuildBot: github.com/${login}:${final}"

cd - >/dev/null
chmod -R +w ${TEMPDIR}
rm -rf ${TEMPDIR}
rm ${TEMPFILE}
