#!/bin/bash
set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

#set -x

cleanup_loopdev() {
    local loop="$1"

    sync --file-system
    sync

    sleep 1

    if [ -b "${loop}" ]; then
        for part in "${loop}"p*; do
            if mnt=$(findmnt -n -o target -S "$part"); then
                umount "${mnt}"
            fi
        done
        losetup -d "${loop}"
    fi
}

wait_loopdev() {
    local loop="$1"
    local seconds="$2"

    until test $((seconds--)) -eq 0 -o -b "${loop}"; do sleep 1; done

    ((++seconds))

    ls -l "${loop}" &> /dev/null
}

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

export  LC_ALL=C 
export  LC_CTYPE=C
export  LANGUAGE=C
export  LANG=C

if [ ! -f ./overlay/rootfs ]; then 
	exit 1 
fi

. ./overlay/rootfs
. ./overlay/kernel_version

rootfs="$(readlink -f "$rootfs")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

# Create an empty disk image
img="./ubuntu-${kernel_version}-$2.img"
size="$(( $(wc -c < "${rootfs}" ) / 1024 / 1024 ))"
truncate -s "$(( size + 512 ))M" "${img}"

# Create loop device for disk image
loop="$(losetup -f)"
losetup -P "${loop}" "${img}"
disk="${loop}"

# Cleanup loopdev on early exit
trap 'cleanup_loopdev ${loop}' EXIT

# Ensure disk is not mounted
mount_point=/tmp/mnt
umount "${disk}"* 2> /dev/null || true
umount ${mount_point}/* 2> /dev/null || true
mkdir -p ${mount_point}

    # Setup partition table
    dd if=/dev/zero of="${disk}" count=4096 bs=512
    parted --script "${disk}" \
    mklabel gpt \
    mkpart primary fat32 16MiB 128MiB \
    mkpart primary ext4 128MiB 100%

    # Create partitions
    {
        echo "t"
        echo "1"
        echo "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
        echo "t"
        echo "2"
        echo "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
        echo "w"
    } | fdisk "${disk}" &> /dev/null || true

    partprobe "${disk}"

    partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

    sleep 1

    wait_loopdev "${disk}${partition_char}2" 60 || {
        echo "Failure to create ${disk}${partition_char}2 in time"
        exit 1
    }

    sleep 1

    wait_loopdev "${disk}${partition_char}1" 60 || {
        echo "Failure to create ${disk}${partition_char}1 in time"
        exit 1
    }

    sleep 1

    # Generate random uuid for bootfs
    boot_uuid=$(uuidgen | head -c8 )

    # Generate random uuid for rootfs
    root_uuid=$(uuidgen)

    # Create filesystems on partitions
    dd if=/dev/zero of="${disk}${partition_char}1" bs=1KB count=10 > /dev/null
    mkfs.vfat -i "${boot_uuid^^}" -F32 -n EFI "${disk}${partition_char}1"

    # Create filesystems on partitions
    dd if=/dev/zero of="${disk}${partition_char}2" bs=1KB count=10 > /dev/null
    mkfs.ext4 -U "${root_uuid}" -L desktop-rootfs "${disk}${partition_char}2"

    # Mount partitions
    mkdir -p ${mount_point}/{system-boot,writable} 
    mount "${disk}${partition_char}2" ${mount_point}/writable


# Copy the rootfs to root partition
tar -xpf "${rootfs}" -C ${mount_point}/writable
fdt_name="/device-tree/rockchip/$3.dtb"

dtbs_install_path="/lib/firmware/${kernel_version}"

if [ ! -f ${mount_point}/writable${dtbs_install_path}${fdt_name} ]; then
	echo "$3.dtb not found"
	exit 1
fi

fstab_boot_uuid="${boot_uuid:0:4}-${boot_uuid:4}"

# Create fstab entries
echo "# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>" > ${mount_point}/writable/etc/fstab
echo "UUID=${root_uuid,,} /              ext4    defaults,x-systemd.growfs    0       1" >> ${mount_point}/writable/etc/fstab
/bin/echo "UUID=${fstab_boot_uuid^^} /boot/efi vfat    defaults    0       2" >> ${mount_point}/writable/etc/fstab


# Write bootloader to disk image
if [ -f "u-boot-rockchip.bin" ]; then
    dd if="u-boot-rockchip.bin" of="${loop}" seek=1 bs=32k conv=fsync
else
	echo "u-boot-rockchip.bin not found"
	exit 1
fi

echo U_BOOT_FDT='"'"device-tree/rockchip/$3.dtb"'"' >> ${mount_point}/writable/etc/default/u-boot
echo U_BOOT_FDT_DIR='"/lib/firmware/"' >> ${mount_point}/writable/etc/default/u-boot
echo U_BOOT_FDT_OVERLAYS_DIR='"/lib/firmware/"' >> ${mount_point}/writable/etc/default/u-boot

mountpoint="${mount_point}/writable"
mkdir ${mountpoint}/boot/efi
mount "${disk}${partition_char}1" ${mountpoint}/boot/efi
mount dev-live -t devtmpfs "$mountpoint/dev"
mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
mount proc-live -t proc "$mountpoint/proc"
mount sysfs-live -t sysfs "$mountpoint/sys"
mount securityfs -t securityfs "$mountpoint/sys/kernel/security"

echo "GRUB_DISABLE_OS_PROBER=true" >> "$mountpoint/etc/default/grub"
echo "GRUB_DEFAULT_DTB=device-tree/rockchip/$3.dtb" >> $mountpoint/etc/default/grub
rm -f "$mountpoint/etc/default/grub.d/kdump-tools.cfg"

# u-boot-update 
chroot ${mount_point}/writable/ /bin/bash -c "u-boot-update"

#debug
#cp ${mount_point}/writable/boot/extlinux/extlinux.conf overlay
#cp ${mount_point}/writable/etc/default/u-boot overlay


chroot ${mountpoint} /bin/bash -c "grub-install --efi-directory=/boot/efi --target=arm64-efi"
chroot ${mountpoint} /bin/bash -c "update-grub"

linux_name_tmp=`ls ${mountpoint}/boot/vmlinu?-${kernel_version}`
linux_name="linux ${linux_name_tmp#"$mountpoint"}"
initrd_name="initrd /boot/initrd.img-${kernel_version}"
devicetree_name="devicetree ${dtbs_install_path}${fdt_name}"
. ${mountpoint}/etc/lsb-release

cat << EOF >> ${mountpoint}/boot/grub/custom.cfg
font="/usr/share/grub/unicode.pf2"
set menu_color_normal=white/black
set timeout=30

menuentry 'Select THIS' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option "gnulinux-simple-${root_uuid}" {
	insmod gzio
	insmod part_gpt
	insmod ext2
	set root='hd0,gpt2'
	if [ x$feature_platform_search_hint = xy ]; then
	  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gpt2 --hint-efi=hd0,gpt2 --hint-baremetal=ahci0,gpt2  ${root_uuid}
	else
	  search --no-floppy --fs-uuid --set=root ${root_uuid}
	fi
${linux_name} root=UUID=${root_uuid}
${initrd_name}
${devicetree_name}
}
EOF

initrd_name="initrd	/boot/initrd.img-${kernel_version}"
sed -i "s#$initrd_name#$initrd_name\n$devicetree_name#" ${mountpoint}/boot/grub/grub.cfg

sync --file-system
sync

umount "$mountpoint/sys/kernel/security"
umount "$mountpoint/sys"
umount "$mountpoint/proc"
umount "$mountpoint/dev/pts"
umount "$mountpoint/dev"
umount ${mountpoint}/boot/efi

# Umount partitions
umount "${disk}${partition_char}2" 2> /dev/null || true

# Remove loop device
losetup -d "${loop}"

# Exit trap is no longer needed
trap '' EXIT

#echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -6 --force --keep --quiet --threads=0 "${img}"
#rm "${img}"
#cd ./images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
exit 0

#if [ ! -d ${mountpoint}/boot/efi/EFI/boot ] && [ ! -d ${mountpoint}/boot/efi/EFI/BOOT ]; then
#	mkdir ${mountpoint}/boot/efi/EFI/BOOT
#	cp ${mountpoint}/boot/efi/EFI/debian/grubaa64.efi ${mountpoint}/boot/efi/EFI/BOOT/bootaa64.efi
#fi
