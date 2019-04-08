#!/bin/bash -e

# Generate a token there: https://github.com/settings/tokens

usage()
{
    echo "./release.sh <token> <branch> <tag>"
    exit $1
}

[ $# -eq 3 ] || usage 1

if [ -e "$1" ]; then
    TOKEN=$(cat $1)
else
    TOKEN="$1"
fi
BRANCH="$2"
TAG="$3"

# Get the list of OpenXT repos
repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/openxt/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2`

for i in $repos;
do
    # Release!
    curl -s -X POST "https://api.github.com/repos/openxt/${i}/releases"  \
    -H "Authorization: token $TOKEN"                                     \
    -H "Content-Type: application/json"                                  \
    -d "{\"tag_name\":\"${TAG}\",\"target_commitish\":\"${BRANCH}\",\"name\":\"OpenXT ${TAG}\",\"body\":\"\",\"draft\":false,\"prerelease\":false}"
done
