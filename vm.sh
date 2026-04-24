#!/bin/bash

# ==============================================================================
# ARCH LINUX INSTALLATION SCRIPT (Manual Commands Recreation)
# ==============================================================================

# 1. USER INPUT & VARIABLES
clear
echo "--- Arch Installation Configuration ---"
read -p "Enter Hostname: " MY_HOSTNAME
read -p "Enter Username: " MY_USER
read -s -p "Enter Password (Root & User): " MY_PASS
echo ""
read -p "Target Drive (e.g. /dev/sda or /dev/nvme0n1): " DRIVE
read -p "Timezone (e.g. America/New_York): " TIMEZONE

# Confirm Drive Partitioning
echo -e "\n!! WARNING: ALL DATA ON $DRIVE WILL BE DELETED !!"
read -p "Proceed? (y/N): " CONFIRM
[[ $CONFIRM != "y" ]] && exit

# ==============================================================================
# 2. PRE-INSTALLATION
# ==============================================================================

# Set the system clock
timedatectl set-ntp true

# Partitioning (GPT)
# Partition 1: EFI (512M) | Partition 2: Root (Remainder)
sgdisk --zap-all "$DRIVE"
sgdisk -n 1:0:+512M -t 1:ef00 "$DRIVE"
sgdisk -n 2:0:0 -t 2:8304 "$DRIVE"

# Identify partitions (handling NVMe 'p' suffix)
if [[ $DRIVE == *"nvme"* ]]; then
    PART_EFI="${DRIVE}p1"
    PART_ROOT="${DRIVE}p2"
else
    PART_EFI="${DRIVE}1"
    PART_ROOT="${DRIVE}2"
fi

# Format partitions
mkfs.fat -F 32 "$PART_EFI"
mkfs.ext4 "$PART_ROOT"

# Mount the file systems
mount "$PART_ROOT" /mnt
mount --mkdir "$PART_EFI" /mnt/boot

# ==============================================================================
# 3. INSTALLATION
# ==============================================================================

# Select mirrors (Reflector is often used in the TUI, but we'll stick to base)
# Install essential packages
pacstrap -K /mnt base linux linux-firmware nano vim networkmanager bluez bluez-utils sudo base-devel

# ==============================================================================
# 4. SYSTEM CONFIGURATION
# ==============================================================================

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system to run commands
arch-chroot /mnt /bin/bash <<EOF

# Timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "$MY_HOSTNAME" > /etc/hostname

# Users and Passwords
echo "root:$MY_PASS" | chpasswd
useradd -m -G wheel "$MY_USER"
echo "$MY_USER:$MY_PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Initramfs (usually handled by pacstrap, but forced for safety)
mkinitcpio -P

# Bootloader (Systemd-boot)
bootctl install
PARTUUID=\$(blkid -s PARTUUID -o value $PART_ROOT)
cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=\$PARTUUID rw
EOT
echo "default arch" > /boot/loader/loader.conf
echo "timeout 3" >> /boot/loader/loader.conf

# Enabling Services (Bluetooth and Networking)
systemctl enable NetworkManager
systemctl enable bluetooth

EOF

# ==============================================================================
# 5. EXIT
# ==============================================================================

umount -R /mnt
echo "-------------------------------------------------------"
echo "Done! Unmount the USB and type 'reboot'."