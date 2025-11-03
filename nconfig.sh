#!/bin/bash

rm -f .config
cat arch/arm64/configs/defconfig ../../my-add.txt > .config
#cat ../../overlay/my-add.txt arch/arm64/configs/defconfig ../../overlay/my-add.txt > .config
#cat arch/arm64/configs/defconfig ../../overlay/my-add.txt ../../overlay/hd-audio-config > .config

{
	sleep 15
	echo '6'
	sleep 5
	echo "\n"
	sleep 5
	echo "\n"
	echo '9'
	echo "\n"
} | make nconfig

	cp .config ../../1-config.txt
