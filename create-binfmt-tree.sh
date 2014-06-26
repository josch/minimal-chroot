#!/bin/sh -ex

usage() {
	echo "Usage: $0 arch suite rootdir [mirror]"
}

MIRROR="http://127.0.0.1:3142/ftp.de.debian.org/debian"

[ "$#" -ne 3 ] && [ "$#" -ne 4 ] && { usage; exit; }

ARCH="$1"
SUITE="$2"
ROOTDIR="$3"
MIRROR=${4:-$MIRROR}

[ -e "$ROOTDIR" ] && { echo "root directory still exists"; exit; }

mkdir "$ROOTDIR"

ROOTDIR=`realpath "$ROOTDIR"`

# apt options
APT_OPTS="-y"
APT_OPTS=$APT_OPTS" -o Apt::Architecture=$ARCH"
APT_OPTS=$APT_OPTS" -o Dir::Etc::TrustedParts=$ROOTDIR/etc/apt/trusted.gpg.d"
APT_OPTS=$APT_OPTS" -o Dir::Etc::Trusted=$ROOTDIR/etc/apt/trusted.gpg"
APT_OPTS=$APT_OPTS" -o Apt::Get::AllowUnauthenticated=true"
APT_OPTS=$APT_OPTS" -o Apt::Get::Download-Only=true"
APT_OPTS=$APT_OPTS" -o Apt::Install-Recommends=false"
APT_OPTS=$APT_OPTS" -o Dir=$ROOTDIR/"
APT_OPTS=$APT_OPTS" -o Dir::Etc=$ROOTDIR/etc/apt/"
APT_OPTS=$APT_OPTS" -o Dir::Etc::SourceList=$ROOTDIR/etc/apt/sources.list"
APT_OPTS=$APT_OPTS" -o Dir::State=$ROOTDIR/var/lib/apt/"
APT_OPTS=$APT_OPTS" -o Dir::State::Status=$ROOTDIR/var/lib/dpkg/status"
APT_OPTS=$APT_OPTS" -o Dir::Cache=$ROOTDIR/var/cache/apt/"

# initial setup for apt and dpkg to work properly
mkdir -p $ROOTDIR
mkdir -p $ROOTDIR/etc/apt/
mkdir -p $ROOTDIR/etc/apt/sources.list.d/
mkdir -p $ROOTDIR/etc/apt/preferences.d/
mkdir -p $ROOTDIR/var/lib/apt/
mkdir -p $ROOTDIR/var/lib/apt/lists/partial/
mkdir -p $ROOTDIR/var/lib/dpkg/
mkdir -p $ROOTDIR/var/cache/apt/
touch $ROOTDIR/var/lib/dpkg/status

# fill sources.list
echo deb $MIRROR $SUITE main > $ROOTDIR/etc/apt/sources.list

# update and install git and ruby
apt-get $APT_OPTS update
apt-get $APT_OPTS install libc6 libselinux1 libacl1 man-db libstdc++6

# unpack downloaded archives
for deb in $ROOTDIR/var/cache/apt/archives/*.deb; do
	dpkg -x $deb $ROOTDIR
done
