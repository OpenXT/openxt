#!/bin/bash

# Generate a token there: https://github.com/settings/tokens
TOKEN=$1

# Get the list of OpenXT repos
repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/openxt/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2`

for i in $repos;
do
	echo $i
done
