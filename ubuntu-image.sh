#!/bin/bash

export LANGUAGE=C
export LC_ALL=C
export LANG=C

	 rm -rf build && mkdir build

	mem_size=`free --giga|grep Mem|awk '{print $2}'`
	if [ $mem_size -gt 15 ]; then
		 mount -t tmpfs -o size=13G tmpfs build
	fi

	 apt-get update
	 apt-get install git snapd qemu-user-static ubuntu-dev-tools
	 snap install --classic ubuntu-image
	 ubuntu-image --debug --workdir build classic image-definition.yaml

	 rm -rf build/chroot
	 cp setup-script.sh build/root/
	 chroot build/root /setup-script.sh
	 rm build/root/setup-script.sh
	rootfs="overlay/ubuntu.rootfs.tar"
	echo "rootfs=$rootfs" > ./rootfs
	kernel_version="`ls -1 build/root/boot/vmlinu?-*|sed 's#-# #' | sed 's#-generic##' | awk '{ print $2 }'`"
	echo "kernel_version=$kernel_version" > ./kernel_version

	cd build/root &&  tar -cvf ../../$rootfs --xattrs ./*
	cd ../..
	if [ $mem_size -gt 15 ]; then
		 umount build
		sleep 2
	fi  
	exit 0
