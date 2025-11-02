#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ $# -ne 1 ]; then
	echo "$0 linux_dir"
	exit 1
fi

linux_dir=$1
suite=oracular
rm -rf $linux_dir && mkdir $linux_dir
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 8 ]; then
	sudo mount -t tmpfs -o size=8G tmpfs $linux_dir
fi

cd $linux_dir
#git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b linux-6.17.y

git clone --depth 1 https://github.com/torvalds/linux.git
head -5 linux/Makefile | sed 's# ##g' > ../overlay/tmp_var.txt
cd linux
. ../../overlay/tmp_var.txt


cp ../../overlay/nconfig.sh . && ./nconfig.sh

now=`date +"%Y%m%d"`
EXTRAVERSION="${EXTRAVERSION}-$now"

export PACKAGE_RELEASE="$VERSION.$PATCHLEVEL.${SUBLEVEL}$EXTRAVERSION-rockchip"
export DEBIAN_PACKAGE="kernel-${PACKAGE_RELEASE%%~*}"
export MAKE="make \
             KERNELVERSION=$PACKAGE_RELEASE \
             LOCALVERSION= \
             localver-extra= \
             PYTHON=python3"


$MAKE -j$(nproc)  all modules dtbs

export INSTALL_PATH="../${DEBIAN_PACKAGE}_arm64"
export KERNEL_BASE_PACKAGE="${DEBIAN_PACKAGE}_arm64"
rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
# header
export HEADER_DEBIAN_PACKAGE="linux-libc-dev-${PACKAGE_RELEASE%%~*}"
export HEADER_INSTALL_PATH="../${HEADER_DEBIAN_PACKAGE}_arm64"
export HEADER_BASE_PACKAGE="${HEADER_DEBIAN_PACKAGE}_arm64"
rm -rf $HEADER_INSTALL_PATH && mkdir -p $HEADER_INSTALL_PATH


$MAKE zinstall modules_install vdso_install dtbs_install INSTALL_MOD_STRIP=1 INSTALL_HDR_PATH=$INSTALL_PATH/usr/include INSTALL_MOD_PATH=$INSTALL_PATH INSTALL_FW_PATH=$INSTALL_PATH/lib/firmware/$PACKAGE_RELEASE INSTALL_DTBS_PATH=$INSTALL_PATH/boot/dtbs/$PACKAGE_RELEASE/device-tree
$MAKE headers_install INSTALL_HDR_PATH=$HEADER_INSTALL_PATH/usr/


mv $INSTALL_PATH/vmlinu?-$PACKAGE_RELEASE $INSTALL_PATH/boot
mv $INSTALL_PATH/config-$PACKAGE_RELEASE $INSTALL_PATH/boot
mv $INSTALL_PATH/System.map-$PACKAGE_RELEASE $INSTALL_PATH/boot

# Dummy kernel header directory
mkdir -p $INSTALL_PATH/usr/src/linux-headers-$PACKAGE_RELEASE
$MAKE headers_install INSTALL_HDR_PATH=$INSTALL_PATH/usr/src/linux-headers-$PACKAGE_RELEASE

# DEBIAN control
cd ..
mkdir -p $KERNEL_BASE_PACKAGE/DEBIAN

cat > $KERNEL_BASE_PACKAGE/DEBIAN/control << HEREDOC
Package: $DEBIAN_PACKAGE
Source: $DEBIAN_PACKAGE
Version: $PACKAGE_RELEASE
Section: main
Priority: standard
Architecture: arm64
Depends: kmod, linux-base (>= 4.5ubuntu1~16.04.1)
Rules-Requires-Root: no
Maintainer: none
Description: A experimental build package for ubuntu-desktop aarch64 running on opi-5.
HEREDOC

# HEADER
mkdir -p $HEADER_BASE_PACKAGE/DEBIAN

cat > $HEADER_BASE_PACKAGE/DEBIAN/control << HEREDOC
Package: linux-libc-dev
Source: linux
Version: $PACKAGE_RELEASE
Section: devel
Priority: standard
Architecture: arm64
Depends: kmod, linux-base (>= 4.5ubuntu1~16.04.1)
Rules-Requires-Root: no
Maintainer: None
Description: A experimental build package for ubuntu-desktop aarch64 running on opi-5.
HEREDOC


# A simple postinstall script
cat > $KERNEL_BASE_PACKAGE/DEBIAN/postinst << HEREDOC
run-parts --report --exit-on-error --arg=$PACKAGE_RELEASE --arg=/boot/vmlinuz-$PACKAGE_RELEASE /etc/kernel/postinst.d
HEREDOC

# Assign proper permission for the script
chmod 755 $KERNEL_BASE_PACKAGE/DEBIAN/postinst

# Build packaage
rm -rf ../kernel && mkdir ../kernel
fakeroot dpkg-deb -z 4 -Z xz -b $KERNEL_BASE_PACKAGE ..
fakeroot dpkg-deb -z 4 -Z xz -b $HEADER_BASE_PACKAGE ..

rm -f ../overlay/tmp_var.txt

# Exit trap is no longer needed
trap '' EXIT
cd ..
echo "DISK usage"
df $1
if [ $mem_size -gt 4 ]; then
	sudo umount $linux_dir
	sleep 2
fi
exit 0
