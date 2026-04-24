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
if [ $mem_size -gt 4 ]; then
	sudo mount -t tmpfs -o size=4G tmpfs $linux_dir
fi

cd $linux_dir

if [ ! -f ../tmp_var.txt ]; then
	echo "../tmp_var.txt not found"
	exit 1
fi

. ../tmp_var.txt
secnd=`echo $tmp_var | sed 's/rockchip//'`
echo "secnd=$secnd"
secnd="${secnd}1_arm64"
echo "secnd=$secnd"

# 解凍
mkdir -p temp_deb
cp ../linux-image-${tmp_var}_${secnd}.deb .
dpkg-deb -x linux-image-${tmp_var}_${secnd}.deb temp_deb
dpkg-deb -e linux-image-${tmp_var}_${secnd}.deb temp_deb/DEBIAN

# ディレクトリ移動
NEW_PATH="temp_deb/lib/firmware/$tmp_var/device-tree"
mkdir -p "$NEW_PATH"
mv temp_deb/usr/lib/linux-image-$tmp_var/* "$NEW_PATH"
rm -rf temp_deb/usr/lib/linux-image-${tmp_var}

# 再パッケージ
rm linux-image-${tmp_var}_${secnd}.deb
dpkg-deb -b temp_deb linux-image-${tmp_var}_${secnd}.deb
cp linux-image-${tmp_var}_${secnd}.deb ..


# Exit trap is no longer needed
trap '' EXIT
cd ..

echo "DISK usage"
pwd
df $1
if [ $mem_size -gt 4 ]; then
	sudo umount $linux_dir
	sleep 2
fi
exit 0
