#!/bin/bash

# Generate a token there: https://github.com/settings/tokens
TOKEN=$1
ORGANIZATION=$2

# Get the list of OpenXT repos
repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/$ORGANIZATION/repos?page=1&per_page=100" | jq '.[].name' | cut -d '"' -f 2`
repos+=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/$ORGANIZATION/repos?page=2&per_page=100" | jq '.[].name' | cut -d '"' -f 2`
repos+=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/$ORGANIZATION/repos?page=3&per_page=100" | jq '.[].name' | cut -d '"' -f 2`

for i in $repos;
do
	echo "Cloning $i..."
	git clone git://github.com/$ORGANIZATION/$i $i.git
done
