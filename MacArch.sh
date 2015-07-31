#!/usr/bin/zsh

######################################################
#                                                    #
#   MacBook Air Installation Script For ArchLinux    #
#                                                    #
#                Written by Xorgic                   #
#                                                    #
######################################################

# --- Global Standards ---

setopt SH_WORD_SPLIT

NAME=USERNAME
USER_PASSWORD=PASSWORD
ROOT_PASSWORD=PASSWORD
PASSPHRASE="PASSPHRASE"

CONTINENT=Europe
PLACE=Oslo
HOST=HOSTNAME
KEYMAP=no-latin1
packages_base="base base-devel grub efibootmgr alsa-utils alsa-firmware wicd mutt sshfs git vim mlocate aspell-en acpid dbus sudo openssh pm-utils zsh unrar unzip wget ranger"
packages_wm="xorg xorg-xinit slim awesome firefox mesa ttf-dejavu flashplugin rxvt-unicode urxvt-perls vicious slim-themes archlinux-themes-slim mplayer xscreensaver"

# --- Script --

function partition {
echo "\033[0;36m=> Partitioning: \033[0m"
(echo n; echo ; echo ; echo +100M; echo ef00; echo w; echo Y;) | gdisk /dev/sda > /dev/null 2>&1 &&
(echo n; echo ; echo ; echo +200M; echo 8300; echo w; echo Y;) | gdisk /dev/sda > /dev/null 2>&1 &&
(echo n; echo ; echo ; echo ; echo 8e00; echo w; echo Y;) | gdisk /dev/sda > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\033[0m"
else
	echo "\033[0;31mFailure\033[0m"
	exit 1;
fi

echo "\033[0;36m=> Encryption: \033[0m"
modprobe dm-crypt
(echo ${PASSPHRASE}; echo ${PASSPHRASE};) | cryptsetup --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random luksFormat /dev/sda3 > /dev/null 2>&1 &&
(echo ${PASSPHRASE}) | cryptsetup luksOpen /dev/sda3 cryptdisk > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\033[0m"
else
	echo "\033[0;31mFailure\033[0m"
	exit 1;
fi

echo "\033[0;36m=> Formatting: \033[0m"
mkfs.vfat -F32 -n EFI /dev/sda1 > /dev/null 2>&1 &&
(echo y;) | mkfs.ext2 /dev/sda2 > /dev/null 2>&1 &&
pvcreate /dev/mapper/cryptdisk > /dev/null 2>&1 &&
vgcreate vgroup /dev/mapper/cryptdisk > /dev/null 2>&1 &&
lvcreate --size 4G --name lvswap vgroup > /dev/null 2>&1 &&
lvcreate --extents +100%FREE --name lvroot vgroup > /dev/null 2>&1 &&
mkfs.ext4 /dev/mapper/vgroup-lvroot > /dev/null 2>&1 &&
mkswap /dev/mapper/vgroup-lvswap > /dev/null 2>&1 &&
swapon /dev/mapper/vgroup-lvswap > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\033[0m"
else
	echo "\033[0;31mFailure\033[0m"
	exit 1;
fi
}

function mounting {
echo "\033[0;36m=> Mounting: \033[0m"
mount /dev/mapper/vgroup-lvroot /mnt &&
mkdir /mnt/boot &&
mount /dev/sda2 /mnt/boot &&
mkdir /mnt/boot/efi &&
mount /dev/sda1 /mnt/boot/efi
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\033[0m"
else
	echo "\033[0;31mFailure\033[0m"
	exit 1;
fi
}

function installation {
echo "\033[0;36m=> Installing: \033[0m"
pacstrap /mnt ${packages_base} ${packages_wm} > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\033[0m"
else
	echo "\033[0;31mFailure\033[0m"
	exit 1;
fi
}

function post_installation {
echo "\033[0;36m=> Entering Chroot: \033[0m"
cat > /mnt/root/postscript.sh <<EOF
#!/usr/bin/zsh
echo "\033[0;36m=> Configuration: \033[0m"

echo "\033[0;36m==> Uncommenting Locales: \033[0m"
sed -i 's/#nb_NO.UTF-8/nb_NO.UTF-8/g' /etc/locale.gen &&
sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Setting Locales: \033[0m"
cat > /etc/locale.conf <<EO
LANG="en_US.UTF-8"
LC_COLLATE="C"
LC_TIME="nb_NO.UTF-8"
EO
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Activating Locales: \033[0m"
locale-gen > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi


echo "\033[0;36m==> Setting X11 Keyboard Options: \033[0m"
cat > /etc/X11/xorg.conf.d/10-keyboard.conf <<EOL
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "no"
				Option "Xkbmodel" "apple_laptop"
				Option "Xkbvariant" "mac_nodeadkeys"
				Option "XKBOPTIONS" "lv3:lalt_switch,terminate:ctrl_alt_bksp"
EndSection
EOL
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Misc X11 Settings: \033[0m"
sed -i 's/#set bell-style none/set bell-style none/g' /etc/inputrc &&
ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/ &&
sed -i 's/current_theme       default/current_theme archlinux-soft-grey/g' /etc/slim.conf
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Enable Systemd Services: \033[0m"
ln -s '/usr/lib/systemd/system/slim.service' '/etc/systemd/system/display-manager.service' &&
ln -s '/usr/lib/systemd/system/wicd.service' '/etc/systemd/system/dbus-org.wicd.daemon.service' &&
ln -s '/usr/lib/systemd/system/wicd.service' '/etc/systemd/system/multi-user.target.wants/wicd.service' &&
ln -s '/usr/lib/systemd/system/iptables.service' '/etc/systemd/system/multi-user.target.wants/iptables.service'
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Setting Timezone, Console Keymap & Hostname: \033[0m"
ln -s /usr/share/zoneinfo/$CONTINENT/$PLACE /etc/localtime &&
echo KEYMAP=$KEYMAP > /etc/vconsole.conf &&
cat > /etc/hostname <<EOL
$HOST
EOL
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Setting Simple IPTables Rules: \033[0m"
cp /etc/iptables/simple_firewall.rules /etc/iptables/iptables.rules
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Setting Initramfs and Grub: \033[0m"
sed -i 's/filesystems/encrypt lvm2 filesystems/g' /etc/mkinitcpio.conf &&
mkinitcpio -p linux > /dev/null 2>&1 &&
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=\/dev\/sda3:vgroup root=\/dev\/mapper\/vgroup-lvroot rw"/g' /etc/default/grub &&
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub > /dev/null 2>&1 &&
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi

echo "\033[0;36m==> Creating User Account & Window Manager: \033[0m"
useradd -m -g users -G lp,audio,power,disk,floppy,games,locate,network,optical,scanner,storage,video,wheel -s /bin/zsh $NAME &&
sed -i 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers &&
(echo $USER_PASSWORD; echo $USER_PASSWORD) | passwd $NAME &&
(echo $ROOT_PASSWORD; echo $ROOT_PASSWORD) | passwd root &&
cat > /home/$NAME/.xinitrc <<EOL
exec awesome
EOL
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi
EOF
chmod +x /mnt/root/postscript.sh &&
echo ./root/postscript.sh | arch-chroot /mnt
if [[ $? -eq 0 ]]; then
	echo "\033[0;32mSuccess\n\033[0m"
else
	echo "\033[0;31mFailure $?\n\033[0m"
fi
}

partition
mounting
installation
post_installation
