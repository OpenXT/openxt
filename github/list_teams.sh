#!/bin/bash

[ $# -eq 1 ] || exit 1

# Generate a token there: https://github.com/settings/tokens
if [ -e "$1" ]; then
    TOKEN=$(cat $1)
else
    TOKEN="$1"
fi

# Get the list of OpenXT repos
teams_list=`curl -H "Authorization: token $TOKEN" -s "https://api.github.com/orgs/OpenXT/teams?per_page=100"`
declare -a "teams=(`echo $teams_list | jq '.[].name'`)"
declare -a "members=(`echo $teams_list | jq '.[].members_url' | sed 's/{.*}//g'`)"
declare -a "repositories=(`echo $teams_list | jq '.[].repositories_url'`)"

n=0
for team in "${teams[@]}";
do
    declare -a "mems=(`curl -H "Authorization: token $TOKEN" -s "${members[$n]}?per_page=100" | jq '.[].login'`)"
    declare -a "repos=(`curl -H "Authorization: token $TOKEN" -s "${repositories[$n]}?per_page=100" | jq '.[].name'`)"
    echo "Team: $team"
    echo "  Repositories:"
    for repo in "${repos[@]}"; do
	echo "    $repo"
    done
    echo "  Members:"
    for mem in "${mems[@]}"; do
	echo "    $mem"
    done
    echo
    n=$(( $n + 1 ))
done
