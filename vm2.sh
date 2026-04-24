#!/bin/bash
set -e

# --- 1. USER INPUTS ---
clear
echo "==> ARCH + KDE PLASMA INSTALLER"
read -p "Hostname: " HOSTNAME
read -p "Username: " USER
read -s -p "Password: " PASS
echo ""
DISK="/dev/vda" 
TZ="UTC"

# --- 2. DISK PREPARATION ---
timedatectl set-ntp true
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0 -t 2:8304 "$DISK"

P1="${DISK}1"
P2="${DISK}2"

mkfs.fat -F 32 "$P1"
mkfs.ext4 -F "$P2"
mount "$P2" /mnt
mount --mkdir "$P1" /mnt/boot

# --- 3. BASE + KDE PACKAGES ---
# Added xorg and plasma-desktop essentials
pacstrap -K /mnt base linux linux-firmware networkmanager bluez bluez-utils sudo git \
xorg plasma-desktop sddm konsole dolphin breeze-gtk kde-gtk-config

genfstab -U /mnt >> /mnt/etc/fstab

# --- 4. CHROOT CONFIGURATION ---
arch-chroot /mnt /bin/bash <<EOF
set -e
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

echo "root:$PASS" | chpasswd
useradd -m -G wheel "$USER"
echo "$USER:$PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader
bootctl install
UUID=\$(blkid -s PARTUUID -o value $P2)
echo "default arch" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=PARTUUID=\$UUID rw" > /boot/loader/entries/arch.conf

# --- 5. ENABLE SERVICES (Crucial for KDE) ---
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sddm
EOF

# --- 6. CLEANUP ---
umount -R /mnt
echo "KDE Installation complete. Rebooting..."
sleep 3
reboot
