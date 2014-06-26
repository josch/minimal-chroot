#!/bin/sh
#
# polystrap-binfmt - helps preparing the build host for running polystrap
#
# Copyright (C) 2011 by Geert Stappers <stappers@stappers.nl>
#
# Polystrap-binfmt is based upon the research of Josch Schauer
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal 
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM,OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

set -e

if [ $( id --user ) -eq 0 ] ; then
        :
else
        echo 1>&2 E: Run this script as root
        exit 1
fi

usage() {
        echo -e "Usage: $0: [-m mirror] architecture directory\n"
}

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        LC_ALL=C LANGUAGE=C LANG=C

while getopts m: opt; do
        case $opt in
        m) _MIRROR="$OPTARG";;
        ?) usage; exit 1;;
        esac
done
shift $(($OPTIND - 1))

[ "$#" -ne 2 ] && { echo 1>&2 "E: Two arguments required"; usage; exit 1; }

ARCH="$1"
TMPDIR="$2"

if [ -d "$TMPDIR" ] ; then
        TMPDIR="${TMPDIR}/polystrap-binfmt-$$"
        mkdir $TMPDIR
else
        echo 1>&2 "E: $TMPDIR not an existing directory"
        exit 1
fi
[ ! -d "$TMPDIR" ] && { echo 2>&1 "E: Could not create $TMPDIR"; exit 1; }

MIRROR="http://ftp.nl.debian.org/debian"
# overwrite default Debian archive by commandline option
MIRROR=${_MIRROR:-$MIRROR}

MTCNFG=$TMPDIR/multistrap.conf
cat << LastLine > $MTCNFG
# this is a temporary configuration file for multistrap
# it is created by $0
# and should also have been deleted by $0
#
[General]
arch=
directory=
cleanup=true
unpack=true
noauth=true
aptsources=Debian
bootstrap=BinfmtStuff
allowrecommends=false
addimportant=false
omitrequired=true

# shared libraries needed for executing package configuration scripts with qemu
# user mode emulation
#
# man-db       to configure man-db
# libfreetype6 to configure fontconfig
# libx11       to configure libgtk2.0-0
[BinfmtStuff]
packages=libc6 libselinux1 libacl1 man-db libstdc++6 libfreetype6 libx11-6
source=$MIRROR
suite=sid
omitdebsrc=true
# l l
LastLine

[ ! -r "$MTCNFG" ] && { echo 1>&2 "E: Creation of $MTCNFG failed"; exit 1; }

# download and extract packages with binfmt stuff
multistrap -a $ARCH -d $TMPDIR/binfmtroot -f $MTCNFG
RETVAL=$?
if [ $RETVAL -ne 0 ] ; then
        echo 1>&2 E: multistrap returned a non zero value
        echo I: no clean up of temporary files done, the multistrap command was 
        echo I:  multistrap -a $ARCH -d $TMPDIR/binfmtroot -f $MTCNFG
        exit 1
fi

# deduce binfmt architecture from architecture
if [ "$ARCH" = $( dpkg --print-architecture ) ]; then
        BINFMT_ARCH=$ARCH
        echo W: It is strange to $0 on a $ARCH host for a $BINFMT_ARCH target
else
        case $ARCH in
                alpha|amd64|arm|armeb|i386|m68k|mips|mipsel\
                |powerpc|ppc64|sh4|sh4eb|sparc|sparc64)
                        BINFMT_ARCH=$ARCH ;;
                armel)  BINFMT_ARCH=arm ;;
                lpia)   BINFMT_ARCH=i386 ;; # not yet verified FIXME
                *) echo "unknown architecture: $ARCH"; exit 1;;
        esac
fi

rm -rf                   /etc/qemu-binfmt/$BINFMT_ARCH
cp -r $TMPDIR/binfmtroot /etc/qemu-binfmt/$BINFMT_ARCH

# clean up
rm -rf $TMPDIR
