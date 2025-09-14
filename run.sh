#!/bin/sh

source ./setup

if ! [ -e "$disk" ]; then
    echo "specified disk does not exist"
    exit 1
fi

if ! [ -e "/usr/share/zoneinfo/$timezone" ]; then
    echo "specified timezone does not exit"
    exit 1
fi

wipefs -a "$disk"

if [ "$zerodisk" -eq 1 ]; then
    dd if=/dev/zero of="$disk" bs=4M status=progress
fi

if [ "$efi" -eq 1 ]; then
    parted -a optimal "$disk" --script mklabel gpt
    parted "$disk" --script mkpart primary 1MiB 1025MiB
else
    parted -a optimal "$disk" --script mklabel msdos
    parted "$disk" --script mkpart primary 1MiB 1025MiB
    parted "$disk" --script set 1 boot on
fi

parted "$disk" --script mkpart primary 1025MiB 100%

if echo "$disk" | grep -q "nvme"; then
    bootpart="${disk}p1"
    rootpart="${disk}p2"
else
    bootpart="${disk}1"
    rootpart="${disk}2"
fi

mkfs.vfat -F 32 "$bootpart"

if [ "$encrypt" -eq 1 ]; then
    cryptsetup luksFormat "$rootpart"
    cryptsetup open "$rootpart" root
    mkfs.ext4 /dev/mapper/root
    mount /dev/mapper/root /mnt
    echo encryptuuid=$(blkid -s UUID -o value "$rootpart") >> setup
else
    mkfs.ext4 "$rootpart"
    mount "$rootpart" /mnt
fi

mkdir -p /mnt/boot
mount "$bootpart" /mnt/boot

pacman -Sy --noconfirm --needed archlinux-keyring
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacstrap /mnt base base-devel linux linux-firmware grub vim networkmanager efibootmgr openssh ${packages}
genfstab -U /mnt > /mnt/etc/fstab

if [ "$swapsize" -gt 0 ]; then
    fallocate -l ${swapsize}GiB /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
    echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
fi

if ! [ -z "$hostname" ]; then
    echo "$hostname" > /mnt/etc/hostname
fi

ln -sf /usr/share/zoneinfo/${timezone} /mnt/etc/localtime
echo "LANG=${locale}.UTF-8" > /mnt/etc/locale.conf
sed -i "/^#${locale}/s/^#//" /mnt/etc/locale.gen
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /mnt/etc/pacman.conf
sed -i "s/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" /mnt/etc/sudoers

mv chroot.sh setup /mnt/
chmod +x /mnt/*.sh
arch-chroot /mnt /chroot.sh
rm /mnt/chroot.sh
