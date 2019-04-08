#!/bin/bash

# Generate a token there: https://github.com/settings/tokens

usage()
{
    echo "./list_merges.sh <token> <github user> <month: YYYY-MM>"
    exit $1
}

[ $# -eq 3 ] || usage 1

# Generate a token there: https://github.com/settings/tokens
if [ -e "$1" ]; then
    TOKEN=$(cat $1)
else
    TOKEN="$1"
fi
USER="$2"
DATE="$3"

# Get the list of OpenXT repos
repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/openxt/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2`

for i in $repos;
do
    # Get the json list of commits
    declare -a "commits=(`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/repos/openxt/$i/commits?author=$USER&since=${DATE}-01&until=${DATE}-31" | jq '.[].commit.message'`)"
    for commit in "${commits[@]}"; do
	echo $commit | grep "^Merge pull request" >/dev/null 2>&1 || continue
	id=`echo $commit | sed 's/Merge pull request #\([0-9]\+\).*/\1/'`
	echo "https://github.com/OpenXT/$i/pull/$id"
    done
done
