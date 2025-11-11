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

if [ ! -f ./rootfs ]; then 
	exit 1 
fi

. ./rootfs
. ./kernel_version

rootfs="$(readlink -f "$rootfs")"
if [[ "$(basename "${rootfs}")" != *".rootfs.tar" || ! -e "${rootfs}" ]]; then
    echo "Error: $(basename "${rootfs}") must be a rootfs tarfile"
    exit 1
fi

mkdir -p images

# Create an empty disk image
img="./Ubuntu-${kernel_version}-$2.img"
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
    mkpart primary ext4 16MiB 100%

    # Create partitions
    {
        echo "t"
        echo "1"
        echo "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
        echo "w"
    } | fdisk "${disk}" &> /dev/null || true

    partprobe "${disk}"

    partition_char="$(if [[ ${disk: -1} == [0-9] ]]; then echo p; fi)"

    sleep 1

    wait_loopdev "${disk}${partition_char}1" 60 || {
        echo "Failure to create ${disk}${partition_char}1 in time"
        exit 1
    }

    sleep 1

    # Generate random uuid for bootfs
    root_uuid=$(uuidgen)

    # Create filesystems on partitions
    dd if=/dev/zero of="${disk}${partition_char}1" bs=1KB count=10 > /dev/null
    mkfs.ext4 -U "${root_uuid}" -L desktop-rootfs "${disk}${partition_char}1"

    # Mount partitions
    mkdir -p ${mount_point}/writable
    mount "${disk}${partition_char}1" ${mount_point}/writable


# Copy the rootfs to root partition
tar -xpf "${rootfs}" -C ${mount_point}/writable
fdt_name="/device-tree/rockchip/$3.dtb"

dtbs_install_path="/boot/dtbs/${kernel_version}"

if [ ! -f ${mount_point}/writable${dtbs_install_path}${fdt_name} ]; then
	echo "$3.dtb not found"
	exit 1
fi



# Create fstab entries
echo "# <file system>     <mount point>  <type>  <options>   <dump>  <fsck>" > ${mount_point}/writable/etc/fstab
echo "UUID=${root_uuid,,} /              ext4    defaults,x-systemd.growfs    0       1" >> ${mount_point}/writable/etc/fstab


# Write bootloader to disk image
if [ -f "u-boot-rockchip.bin" ]; then
    dd if="u-boot-rockchip.bin" of="${loop}" seek=1 bs=32k conv=fsync
else
	echo "/u-boot-rockchip.bin not found"
	exit 1
fi

echo U_BOOT_FDT='"'"device-tree/rockchip/$3.dtb"'"' >> ${mount_point}/writable/etc/default/u-boot
echo U_BOOT_FDT_DIR='"/boot/dtbs/"' >> ${mount_point}/writable/etc/default/u-boot
echo U_BOOT_FDT_OVERLAYS_DIR='"/boot/dtbs/"' >> ${mount_point}/writable/etc/default/u-boot


mountpoint="${mount_point}/writable"
pam="$(grep pam_pwquality.so $mountpoint/etc/pam.d/common-password | awk '{ print $3 }')"
    if [ $pam == "pam_pwquality.so" ]; then
		   chmod +x pam-auth.sh
           cp pam-auth.sh $mountpoint
           chroot $mountpoint /pam-auth.sh
           rm $mountpoint/pam-auth.sh
    fi

mount dev-live -t devtmpfs "$mountpoint/dev"
mount devpts-live -t devpts -o nodev,nosuid "$mountpoint/dev/pts"
mount proc-live -t proc "$mountpoint/proc"
mount sysfs-live -t sysfs "$mountpoint/sys"
mount securityfs -t securityfs "$mountpoint/sys/kernel/security"

# u-boot-update 
chroot ${mount_point}/writable/ /bin/bash -c "u-boot-update"

# if can not login password length
#	chroot ${mount_point}/writable/ /bin/bash -c "pam-auth-update --force"

sync --file-system
sync

umount "$mountpoint/sys/kernel/security"
umount "$mountpoint/sys"
umount "$mountpoint/proc"
umount "$mountpoint/dev/pts"
umount "$mountpoint/dev"
umount "$mountpoint"

# Umount partitions

# Remove loop device
losetup -d "${loop}"

# Exit trap is no longer needed
trap '' EXIT

echo -e "\nCompressing $(basename "${img}.xz")\n"
xz -6 --force --keep --quiet --threads=0 "${img}"
#rm "${img}"
#cd ./images && sha256sum "$(basename "${img}.xz")" > "$(basename "${img}.xz.sha256")"
exit 0
