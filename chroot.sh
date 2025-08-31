#!/bin/sh

source /setup
rm /setup

locale-gen
systemctl enable NetworkManager

if [ "$sshd" -eq 1 ]; then
    systemctl enable sshd
fi

if [ "$encrypt" -eq 1 ]; then
    sed -i "s|^GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${encryptuuid}:root root=/dev/mapper/root\"|" /etc/default/grub
    sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)|" /etc/mkinitcpio.conf
    mkinitcpio -p linux
fi

if [ "$efi" -eq 1 ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot
else
    grub-install "$disk"
fi

grub-mkconfig -o /boot/grub/grub.cfg

timedatectl set-timezone "$timezone"
ln `which vim` /usr/bin/vi

echo "root password"
passwd root

if ! [ -z "$user" ]; then
    useradd -m -G users,wheel,video,audio -s /bin/bash "$user"
    echo "$user password"
    passwd $user
fi
