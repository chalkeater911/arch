#!/bin/sh

# full disk path to install to, eg: "/dev/sdX"
disk=""

# format as Continent/City, eg: "Australia/Melbourne"
timezone=""

# format as language_COUNTRY, eg: "en_AU", "es_CL", "pt_BR"
locale=""

# name for non-root wheel group user (leave blank to skip)
user=""

# specify computer name (leave blank for default name)
hostname=""

# iso should be booted in uefi mode if enabled
efi=0

# will create a swapfile at / of desired size in GiB (0 to disable)
swapsize=0

# rootfs luks encryption
encrypt=0

# overwrite disk data with zeroes
zerodisk=0

#####################################################################

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
    parted "$disk" --script name 1 boot
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
    encryptuuid=$(blkid -s UUID -o value "$rootpart")
else
    mkfs.ext4 "$rootpart"
    mount "$rootpart" /mnt
fi

mkdir -p /mnt/boot
mount "$bootpart" /mnt/boot

sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacstrap /mnt base base-devel linux linux-firmware grub vim networkmanager efibootmgr openssh git bash-completion tmux wget man-db
genfstab -U /mnt > /mnt/etc/fstab

if ! [ -z "$swapsize" ]; then
    fallocate -l ${swapsize}GiB /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
    echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
fi

if ! [ -z "$hostname" ]; then
    echo "$hostname" > /mnt/etc/hostname
fi

ln -sf /usr/share/zoneinfo/${timezone} /mnt/etc/timezone
echo "LANG=${locale}.UTF-8" > /mnt/etc/locale.conf
sed -i "/^#${locale}/s/^#//" /mnt/etc/locale.gen
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /mnt/etc/pacman.conf
sed -i "s/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" /mnt/etc/sudoers

mv chroot.sh /mnt/
echo -e "user=${user}\nefi=${efi}\nencrypt=${encrypt}\ndisk=${disk}\nencryptuuid=${encryptuuid}\ntimezone=${timezone}" > /mnt/tmp.sh
chmod +x /mnt/*.sh
arch-chroot /mnt /chroot.sh
