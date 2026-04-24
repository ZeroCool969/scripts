#!/bin/bash
set -e

# --- 1. USER INPUTS ---
clear
echo "==> ARCH INSTALLER (VIRT-IO /VDA EDITION)"
read -p "Hostname: " HOSTNAME
read -p "Username: " USER
read -s -p "Password: " PASS
echo ""
DISK="/dev/vda" # Hardcoded for your VM
TZ="UTC"

# --- 2. DISK PREPARATION ---
timedatectl set-ntp true

# Wipe and create partitions: 512MB EFI (1) and rest for Root (2)
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0 -t 2:8304 "$DISK"

# Define partition paths for vda
P1="${DISK}1"
P2="${DISK}2"

# Format
mkfs.fat -F 32 "$P1"
mkfs.ext4 -F "$P2"

# Mount
mount "$P2" /mnt
mount --mkdir "$P1" /mnt/boot

# --- 3. BASE INSTALL ---
# Added 'git' and 'vim' just in case you need them later
pacstrap -K /mnt base linux linux-firmware networkmanager bluez bluez-utils sudo git

# Generate Fstab
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

# User/Root Passwords
echo "root:$PASS" | chpasswd
useradd -m -G wheel "$USER"
echo "$USER:$PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Systemd-boot Setup
bootctl install
UUID=\$(blkid -s PARTUUID -o value $P2)
echo "default arch" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf
echo -e "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions root=PARTUUID=\$UUID rw" > /boot/loader/entries/arch.conf

# Enable Services
systemctl enable NetworkManager
systemctl enable bluetooth
EOF

# --- 5. CLEANUP ---
umount -R /mnt
echo "Installation complete. Eject the ISO and reboot."
sleep 3
reboot
