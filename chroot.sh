#!/bin/sh

source /tmp.sh
rm /tmp.sh

locale-gen
systemctl enable NetworkManager

if ! [ -z "$encrypt" ]; then
    sed -i "s/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${encryptuuid}:root root=\/dev\/mapper\/root\"/" /etc/default/grub
    sed -i "/^HOOKS=/s/.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/" /etc/mkinitcpio.conf
    mkinitcpio -p linux
fi

if ! [ -z "$efi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot
else
    grub-install "$disk"
fi

grub-mkconfig -o /boot/grub/grub.cfg
timedatectl set-timezone "$timezone"
passwd root

ln -sf `which vim` /usr/bin/vi

if ! [ -z "$user" ]; then
    useradd -m -G users,wheel,video,audio -s /bin/bash "$user"
    passwd $user
fi
