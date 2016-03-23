#!/bin/bash

[ $# -eq 3 ] || exit 1

# Generate a token there: https://github.com/settings/tokens
TOKEN="$1"
REPO="$2"
COMMIT="$3"

total=`curl -I -H "Authorization: token $TOKEN" -s "https://api.github.com/repos/openxt/${REPO}/pulls?state=closed" 2>&1 | grep ^Link | sed 's/.*page=\([0-9]\+\)>; rel="last".*/\1/'`
[ -z $total ] && total=1

page=1
pull_requests=""
while [ $page -le $total ]; do
    pull_requests="$pull_requests `curl -H "Authorization: token $TOKEN" -s "https://api.github.com/repos/openxt/${REPO}/pulls?state=closed&page=$page" | jq '.[].number'`"
    page=$(( $page + 1 ))
done

for pr in $pull_requests; do
# Filtering out rejected pull requests would make sense
# However it makes everything slower and uses twice as many requests
# Uncomment if needed
#    merged=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/repos/openxt/${REPO}/pulls/${pr}" | jq '.merged'`
#    [ "x$merged" != "xtrue" ] && continue
    commits="`curl -H "Authorization: token $TOKEN" -s https://api.github.com/repos/openxt/${REPO}/pulls/${pr}/commits | jq '.[].sha'`"
    if [ "$commits" != "" ]; then
        for commit in $commits; do
	    sha=`echo $commit | cut -d '"' -f 2`
            if [[ ${sha} == ${COMMIT}* ]]; then
		echo "https://github.com/OpenXT/${REPO}/pull/${pr}"
		exit 0
	    fi
        done
    fi
done

echo "Not found"
exit 1
