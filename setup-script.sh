#!/bin/bash
set -x

	sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' /etc/adduser.conf
	sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' /etc/adduser.conf
	echo -n "rootwait rw console=ttyS2,1500000 console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline
	echo -n " quiet splash plymouth.ignore-serial-consoles" >> /etc/kernel/cmdline
	# Override u-boot-menu config 
	mkdir -p /usr/share/u-boot-menu/conf.d
	cat << 'EOF' > /usr/share/u-boot-menu/conf.d/ubuntu.conf
	U_BOOT_UPDATE="true"
	U_BOOT_PROMPT="1"
	U_BOOT_PARAMETERS="$(cat /etc/kernel/cmdline)"
	U_BOOT_TIMEOUT="20" 
EOF
	rm -f /var/lib/dbus/machine-id
	true > /etc/machine-id
	touch /var/log/syslog
	chown syslog:adm /var/log/syslog
	ssh-keygen -A
	pam="$(grep pam_pwquality.so /etc/pam.d/common-password | awk '{ print $3 }')"
	if [ $pam == "pam_pwquality.so" ]; then
        sed -i 's/pam_pwquality.so retry=3/pam_pwquality.so dictcheck=0 retry=3/' $1/etc/pam.d/common-password
    fi


	dpkg -i kernel/*
	cd / && rm -rf kernel
	apt-get -y purge cloud-init flash-kernel fwupd ufw grub-efi-arm64
	apt-get -y autoremove
	apt-get  clean
	
