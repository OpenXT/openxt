#!/bin/bash

[ $# -eq 1 ] || exit 1

# Generate a token there: https://github.com/settings/applications
TOKEN="$1"

repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/openxt/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2`

for i in $repos; 
do
    PRS="`curl -H "Authorization: token $TOKEN" -s https://api.github.com/repos/openxt/$i/pulls | jq '.[].number'`"
    if [ "$PRS" != "" ]; then
        echo "Repository: $i  -- Open pull requests:"
        for PR in $PRS; do
            echo "https://github.com/OpenXT/$i/pull/$PR"
        done
	echo
    fi
done
