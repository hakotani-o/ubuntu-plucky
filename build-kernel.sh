#!/bin/bash

set -eE
trap 'echo Error: in $0 on line $LINENO' ERR

if [ $# -ne 1 ]; then
	echo "$0 linux_dir"
	exit 1
fi

linux_dir=$1

rm -rf $linux_dir && mkdir $linux_dir
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 8 ]; then
	sudo mount -t tmpfs -o size=8G tmpfs $linux_dir
fi

cd $linux_dir
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git -b linux-7.0.y

#git clone --depth 1 https://github.com/torvalds/linux.git

cd linux
make defconfig
./scripts/kconfig/merge_config.sh -m .config ../../my-add.txt

./scripts/config --set-val DEBUG_INFO_NONE y
./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --disable DEBUG_INFO_DWARF4
./scripts/config --disable DEBUG_INFO_DWARF5

make olddefconfig

fakeroot make -j$(nproc) LOCALVERSION="-rockchip" deb-pkg
tmp_var=$(make LOCALVERSION="-rockchip" -s kernelrelease)
echo "tmp_var=$tmp_var" > ../../tmp_var.txt

# Exit trap is no longer needed
trap '' EXIT
cd ..
cp *.deb ..
cd ..
echo "DISK usage"
df $1
if [ $mem_size -gt 4 ]; then
	sudo umount $linux_dir
	sleep 2
fi
exit 0
