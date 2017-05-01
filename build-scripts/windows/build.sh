#!/bin/bash -e
#
# OpenXT setup script.
# This script sets up the build host (just installs packages and adds a user),
# and sets up LXC containers to build OpenXT.
#
# Copyright (c) 2016 Assured Information Security, Inc.
#
# Contributions by Jean-Edouard Lejosne
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

NUMBER=$1
BUILD_ID=$2
BRANCH=$3
BUILD_USER=$4
IP_PREFIX=$5
DEST=$6

IP=${IP_PREFIX}.1${NUMBER}

xmlfile=`mktemp`
cat xmls/xmlbuild | \
    sed -e "s|\%BUILD_ID\%|${BUILD_ID}|" \
        -e "s|\%BRANCH\%|${BRANCH}|" \
        -e "s|\%CERTIFICATE\%|developer|" \
        -e "s|\%IS_DEVELOPER\%|true|" \
        -e "s|\%RSYNC_DESTINATION\%|${BUILD_USER}@${IP_PREFIX}.1:${DEST}|" \
        -e "s|\%GIT_PATH\%|git://${IP_PREFIX}.1/${BUILD_USER}|" > $xmlfile
dobuild="curl -s --connect-timeout 5 -H \"Content-Type: text/xml\" --data @${xmlfile} http://${IP}:6288"

buildout=`mktemp`
$dobuild > $buildout

result=`xmllint --xpath 'string(methodResponse/params/param/value/string)' $buildout`

rm $xmlfile
rm $buildout

echo "Windows build result: ${result}"

[[ "x$result" = "xSUCCESS" ]]
