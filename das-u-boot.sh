#!/bin/bash

sudo apt-get update && sudo apt-get -y install  build-essential gcc-aarch64-linux-gnu bison \
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
		git clone --depth 1 https://gitlab.com/u-boot/u-boot.git -b v2025.07
#        git clone --depth 1 https://source.denx.de/u-boot/custodians/u-boot-rockchip.git -b u-boot-rockchip-20251101 u-boot
		DDR=`ls rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v*.bin`
		BL31=`ls rkbin/bin/rk35/rk3588_bl31*.elf`
	export BL31=`pwd`/$BL31
	export ROCKCHIP_TPL=`pwd`/$DDR
echo ""
echo "export ROCKCHIP_TPL=$ROCKCHIP_TPL"
echo "export BL31=$BL31"
echo ""
		export PATH=`pwd`/tools/binman:$PATH
echo ""
echo "PATH=$PATH"
echo ""

		git clone --depth 1 https://gitlab.com/u-boot/u-boot.git -b v2025.$2
		cd u-boot
		if [ ! -f configs/$1 ]; then
			echo "$1 not found in configs"
			cd ..
			exit 1
		fi

	echo 'CONFIG_SYS_SOC="rk3588"' >> configs/$1
sed -i 's/#ifndef CONFIG_XPL_BUILD/#ifndef CONFIG_XPL_BUILD\n\n# define BOOT_TARGET_DEVICES_SCSI(func)	func(SCSI, scsi, 0, 0, 0) func(SCSI, scsi, 0, 0, 1)\n\n# define BOOT_TARGET_DEVICES_NVME(func)  func(NVME, nvme, 0, 0, 0) func(NVME, nvme, 0, 0, 1)\n\n/' include/configs/rockchip-common.h

		make clean $1
		make -j8
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

