#!/bin/sh -ex

# check for fakeroot
if [ "$LOGNAME" = "root" ] \
|| [ "$USER" = "root" ] \
|| [ "$USERNAME" = "root" ] \
|| [ "$SUDO_COMMAND" != "" ] \
|| [ "$SUDO_USER" != "" ] \
|| [ "$SUDO_UID" != "" ] \
|| [ "$SUDO_GID" != "" ]; then
        echo "don't run this script as root - there is no need to"
        exit
fi

# modify these
ARCH="amd64"
DIST="squeeze"
MIRROR="http://127.0.0.1:3142/ftp.de.debian.org/debian"
DIRECTORY="`pwd`/debian-$DIST-$ARCH-ministrap"

# re-execute script in fakeroot
if [ "$FAKEROOTKEY" = "" ]; then
        echo "re-executing script inside fakeroot"
        fakeroot $0;
	rsync -Phaze ssh $DIRECTORY/ mister-muffin.de:/var/www/
	ssh mister-muffin.de "chown -R www-data:www-data /var/www/dudle.mister-muffin.de/"
        exit
fi

# apt options
APT_OPTS="-y"
APT_OPTS=$APT_OPTS" -o Apt::Architecture=$ARCH"
APT_OPTS=$APT_OPTS" -o Dir::Etc::TrustedParts=$DIRECTORY/etc/apt/trusted.gpg.d"
APT_OPTS=$APT_OPTS" -o Dir::Etc::Trusted=$DIRECTORY/etc/apt/trusted.gpg"
APT_OPTS=$APT_OPTS" -o Apt::Get::AllowUnauthenticated=true"
APT_OPTS=$APT_OPTS" -o Apt::Get::Download-Only=true"
APT_OPTS=$APT_OPTS" -o Apt::Install-Recommends=false"
APT_OPTS=$APT_OPTS" -o Dir=$DIRECTORY/"
APT_OPTS=$APT_OPTS" -o Dir::Etc=$DIRECTORY/etc/apt/"
APT_OPTS=$APT_OPTS" -o Dir::Etc::SourceList=$DIRECTORY/etc/apt/sources.list"
APT_OPTS=$APT_OPTS" -o Dir::State=$DIRECTORY/var/lib/apt/"
APT_OPTS=$APT_OPTS" -o Dir::State::Status=$DIRECTORY/var/lib/dpkg/status"
APT_OPTS=$APT_OPTS" -o Dir::Cache=$DIRECTORY/var/cache/apt/"

# clean root directory
rm -rf $DIRECTORY

# initial setup for apt to work properly
mkdir -p $DIRECTORY
mkdir -p $DIRECTORY/etc/apt/
mkdir -p $DIRECTORY/etc/apt/sources.list.d/
mkdir -p $DIRECTORY/etc/apt/preferences.d/
mkdir -p $DIRECTORY/var/lib/apt/
mkdir -p $DIRECTORY/var/lib/apt/lists/partial/
mkdir -p $DIRECTORY/var/lib/dpkg/
mkdir -p $DIRECTORY/var/cache/apt/
# apt somehow needs this file to be present
touch $DIRECTORY/var/lib/dpkg/status

# fill sources.list
echo deb $MIRROR $DIST main > $DIRECTORY/etc/apt/sources.list

# update and install git and ruby
apt-get $APT_OPTS update
apt-get $APT_OPTS install ruby git-core libgettext-ruby1.8 libjson-ruby1.8

# unpack downloaded archives
for deb in $DIRECTORY/var/cache/apt/archives/*.deb; do
	dpkg -x $deb $DIRECTORY
done

# delete obsolete directories
rm -rf $DIRECTORY/usr/share/
rm -rf $DIRECTORY/usr/lib/perl/
rm -rf $DIRECTORY/usr/lib/gconv/
rm -rf $DIRECTORY/usr/lib/git-core/
rm -rf $DIRECTORY/usr/sbin/
rm -rf $DIRECTORY/var/
rm -rf $DIRECTORY/bin/
rm -rf $DIRECTORY/sbin/
rm -rf $DIRECTORY/selinux/
rm -rf $DIRECTORY/etc/*

# delete all setuid programs
find $DIRECTORY -perm -4000 -delete

# delete all binaries except for "git" and "ruby"
find $DIRECTORY/usr/bin/ -type f -o -type l | egrep -v "ruby|git$" | xargs rm -rf

# git needs /etc/passwd otherwise git says: "You dont't exist, go away!"
cat > $DIRECTORY/etc/passwd << __END__
www-data:x:33:33:www-data:/var/www:/bin/sh
__END__

# dont forget to create /tmp directory for dudle
mkdir -m 777 $DIRECTORY/tmp

# get latest dudle
bzr branch https://dudle.inf.tu-dresden.de/unstable/ $DIRECTORY/dudle.mister-muffin.de
( cd $DIRECTORY/dudle.mister-muffin.de; make; )
bzr branch https://dudle.inf.tu-dresden.de/unstable/extensions/dc-net/ $DIRECTORY/dudle.mister-muffin.de/extensions/dc-net/
( cd $DIRECTORY/dudle.mister-muffin.de/extensions/dc-net/; make; )

# fix shebang
find $DIRECTORY/dudle.mister-muffin.de/ -type f -regex ".*\.cgi\|.*\.rb" \
	| xargs sed -i 's/#!\/usr\/bin\/env ruby/#!\/usr\/bin\/ruby/'

#wget https://dudle.inf.tu-dresden.de/doc/0-register.ogv https://dudle.inf.tu-dresden.de/doc/1-setup.ogv https://dudle.inf.tu-dresden.de/doc/2-participate.ogv
#mv 0-register.ogv 1-setup.ogv 2-participate.ogv $DIRECTORY/dudle.mister-muffin.de/
