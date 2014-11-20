#!/bin/sh
#
# Copyright (c) 2012 Citrix Systems, Inc.
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

BDIR=`readlink -f \`dirname $0\``
REPOS="$BDIR/repos"

export BB_ENV_EXTRAWHITE="MACHINE BUILD_UID"
PATH="$REPOS/bitbake/bin:$PATH"

# allow to disble OE wrapper script
if [ "x$1" = "x--disable-wrapper" ];then
    shift
else
    PATH="$REPOS/openembedded-core/scripts:$PATH"
fi
export PATH

exec bitbake "$@"
