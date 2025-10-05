#!/bin/bash

	sudo apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
qemu-user-static qemu-system-arm qemu-efi-aarch64 binfmt-support \
debootstrap flex libssl-dev bc rsync kmod cpio xz-utils fakeroot parted \
udev dosfstools uuid-runtime git-lfs device-tree-compiler python3 \
python-is-python3 fdisk bc debhelper python3-pyelftools python3-setuptools \
python3-pkg-resources swig libfdt-dev libpython3-dev gawk \
git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex \
libelf-dev bison libgnutls28-dev

	rm -rf arm64
	mkdir arm64
mem_size=`free --giga|grep Mem|awk '{print $2}'`
if [ $mem_size -gt 2 ]; then
        sudo mount -t tmpfs -o size=1G tmpfs arm64
fi
	cd arm64

		git clone --depth 1 https://github.com/rockchip-linux/rkbin
		DDR=`ls rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz*.bin`
		BL31=`ls rkbin/bin/rk35/rk3588_bl31*.elf`
echo ""
echo "export ROCKCHIP_TPL=../$DDR"
echo "export BL31=../$BL31"
echo ""

		git clone --depth 1 https://github.com/u-boot/u-boot.git -b v2025.$2
		cd u-boot
		if [ ! -f configs/$1 ]; then
			echo "$1 not found in configs"
			cd ..
			exit 1
		fi
	export BL31=../$BL31
	export ROCKCHIP_TPL="../$DDR"

	sed -i 's/scsi //' include/configs/rockchip-common.h
	sed -i 's/mmc1/scsi mmc1/' include/configs/rockchip-common.h
	sed -i 's/#ifndef CONFIG_XPL_BUILD/#ifndef CONFIG_XPL_BUILD\n\n# define BOOT_TARGET_DEVICES_SCSI(func)	func(SCSI, scsi, 0, 0, 1) func(SCSI, scsi, 0, 0, 2) func(SCSI, scsi, 0, 0, 3)/' include/configs/rockchip-common.h

		make $1
		make
		cp u-boot-rockchip.bin ../..
	echo "dd if=u-boot-rockchip.bin of=/dev/sdX seek=1 bs=32k conv=fsync"
	cd ../..
echo "DISK usage"
df arm64
if [ $mem_size -gt 2 ]; then
        sudo umount arm64
	sleep 2
fi 
exit 0

