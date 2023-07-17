#!/bin/bash
set -ex
BUILD_NUMBER=$1

script_dir=$(dirname "$0")
cd ${script_dir}/..


buildtimestamp=`date -u +%Y%m%d-%H%M%S`
hostname=`hostname`
echo "build machine=${hostname}"
echo "build time=${buildtimestamp}"

debian_revision=`git log --oneline | wc -l | tr -d ' '`
echo "debian_revision=$debian_revision"

# use sed to add -Wno-maybe-uninitialized -Wno-stringop-truncation
# to fix cc warning to not halt the compile
sed -i 's|cflags="-g -O2 -Wall -Werror"|cflags="-g -O2 -Wall -Werror -Wno-maybe-uninitialized -Wno-stringop-truncation"|g' deps/openpbs/ci/etc/build-pbs-packages.sh

# add "--bump $debian_revision" to "alien" command,
# to add git build revision to version number
sed -i "s|fakeroot alien --bump [0-9]*|fakeroot alien --bump $debian_revision|g" deps/openpbs/ci/etc/build-pbs-packages.sh  # if --bump have already been inserted before
sed -i "s|fakeroot alien --to-deb|fakeroot alien --bump $debian_revision --to-deb|g" deps/openpbs/ci/etc/build-pbs-packages.sh  # if --bump has not been inserted previously

# fix apt warning
sed -i "s\wget -qO - https://package.perforce.com/perforce.pubkey | apt-key add -\wget -qO - https://package.perforce.com/perforce.pubkey | gpg --dearmour --yes -o /etc/apt/keyrings/perforce.gpg\g" deps/openpbs/ci/etc/install-system-packages
sed -i "s\echo 'deb http://package.perforce.com/apt/ubuntu/ bionic release' >/etc/apt/sources.list.d/perforce.list\echo 'deb [signed-by=/etc/apt/keyrings/perforce.gpg] http://package.perforce.com/apt/ubuntu/ bionic release' > /etc/apt/sources.list.d/perforce.list\g" deps/openpbs/ci/etc/install-system-packages

# switch perforce apt repo to jammy
sed -i "s\bionic\jammy\g" deps/openpbs/ci/etc/install-system-packages

# Fixing error:
#/workspace/etc/install-system-packages: line 182: python: command not found
#+ cpanm -n --no-wget --no-lwp --curl IO::Pty IPC::Run IPC::Cmd Class::Accessor #Module::Build Pod::Usage Getopt::Long DateTime Date::Parse
# Proc::ProcessTable Test::More Unix::Process Time::HiRes File::FcntlLock File::Remote
sed -i "s\python \python3 \g" deps/openpbs/ci/etc/install-system-packages

cwd=$(pwd)
cd deps/openpbs/ci/
# from: https://github.com/openpbs/openpbs/pull/2562
./ci --params 'os=ubuntu:jammy' --build-pkgs
cd $cwd

md5sum deps/openpbs/ci/packages/*.deb
