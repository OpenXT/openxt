#!/bin/bash

[ $# -ge 1 ] || exit 1

SHORT=
if [ "$1" = "-s" ]; then
    SHORT=1
    shift
fi

[ $# -eq 1 ] || exit 2

# Generate a token there: https://github.com/settings/tokens
TOKEN="$1"

# Get the list of OpenXT repos
repos=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/users/openxt/repos?per_page=100" | jq '.[].name' | cut -d '"' -f 2`

total=0
for i in $repos;
do
    # Get the json list of pull requests
    PULLS="`curl -H "Authorization: token $TOKEN" -s https://api.github.com/repos/openxt/$i/pulls`"
    # Get the list of pull request numbers
    PRS="`echo $PULLS | jq '.[].number'`"
    OIFS=$IFS
    IFS=$'\n'
    TITLES=(`echo $PULLS | jq '.[].title'`)
    LOGINS=(`echo $PULLS | jq '.[].user.login' | tr -d '"'`)
    [ -z $SHORT ] && BRANCHES=(`echo $PULLS | jq '.[].head.ref' | tr -d '"'`)
    IFS=$OIFS
    if [ "$PRS" != "" ]; then
        echo "Repository: $i  -- Open pull requests:"
        n=0
        for PR in $PRS; do
            if [ -z $SHORT ]; then
                echo "  ## ${TITLES[$n]} ##"
                echo "       PR URL:   https://github.com/OpenXT/$i/pull/$PR"
                echo "       Buildbot: github.com/${LOGINS[$n]}:${BRANCHES[$n]}"
                echo "       Code:     https://github.com/${LOGINS[$n]}/$i/tree/${BRANCHES[$n]}"
            else
                echo -n "https://github.com/OpenXT/$i/pull/$PR"
                echo " - ${TITLES[$n]} (${LOGINS[$n]})"
            fi
            n=$(( $n + 1 ))
        done
        total=$(( $total + $n ))
        echo
    fi
done

echo "TOTAL: $total open pull requests"
