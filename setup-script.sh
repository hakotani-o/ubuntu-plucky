#!/bin/bash

	apt-get -y purge cloud-init flash-kernel fwupd
	apt-get -y autoremove
	apt-get  clean
	sed -i 's/#EXTRA_GROUPS=.*/EXTRA_GROUPS="video"/g' $1/etc/adduser.conf
	sed -i 's/#ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/g' $1/etc/adduser.conf
	/usr/sbin/useradd -d /home/oem -G adm,sudo,video -m -N -u 29999 oem
	/usr/sbin/oem-config-prepare --quiet
	touch "/var/lib/oem-config/run"
	echo -n "rootwait rw  console=tty1 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > /etc/kernel/cmdline
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

	/usr/sbin/useradd -d /home/oem -G adm,sudo,video -m -N -u 29999 oem
    /usr/sbin/oem-config-prepare --quiet
    touch "/var/lib/oem-config/run"

