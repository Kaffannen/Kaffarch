#!/bin/bash
set -euo pipefail

# Variables (adjust as needed)
USERNAME="user"
PASSWORD="pass"  # Set securely or prompt for it in real use
HOSTNAME="archlinux"
TIMEZONE="Europe/Oslo"
LOCALE="en_US.UTF-8"

configure_os() {
    echo "Mounting virtual filesystems..."
    mount --types proc /proc /mnt/proc
    mount --rbind /sys /mnt/sys
    mount --make-rslave /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --make-rslave /mnt/dev
    mount --rbind /run /mnt/run
    mount --make-rslave /mnt/run

    echo "Configuring OS settings inside chroot..."

    # Run commands inside chroot one at a time
    arch-chroot /mnt bash -c "
        set -euo pipefail

        ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
        hwclock --systohc

        sed -i \"s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/\" /etc/locale.gen
        locale-gen
        echo LANG=${LOCALE} > /etc/locale.conf

        echo ${HOSTNAME} > /etc/hostname

        echo '127.0.0.1   localhost' > /etc/hosts
        echo '::1         localhost' >> /etc/hosts
        echo \"127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}\" >> /etc/hosts

        useradd -m -G wheel -s /bin/bash ${USERNAME}
        echo \"${USERNAME}:${PASSWORD}\" | chpasswd

        cp /etc/sudoers /etc/sudoers.bak

        echo \"%wheel ALL=(ALL) ALL\" >> /etc/sudoers
    "

    # Check sudoers file inside the chroot after the changes
    arch-chroot /mnt visudo -c
    if [[ $? -ne 0 ]]; then
        echo "Sudoers syntax error! Restoring backup."
        arch-chroot /mnt cp /etc/sudoers.bak /etc/sudoers
        exit 1
    else
        echo "Sudoers file updated and validated."
    fi

    echo "Unmounting virtual filesystems..."
    umount -R /mnt/proc
    umount -R /mnt/sys
    umount -R /mnt/dev
    umount -R /mnt/run

    echo "OS configuration complete."
}

install_xfce() {
  arch-chroot /mnt /bin/bash -c "
    set -euo pipefail

    # Install Xorg, drivers, XFCE, and SDDM Display Manager
    pacman -Sy --noconfirm xorg-server xorg-xinit xf86-video-vesa xfce4 xfce4-goodies sddm

    # Enable SDDM service
    systemctl enable sddm.service

    # Show available desktop sessions for confirmation
    echo 'Available sessions:'
    ls /usr/share/xsessions/
  "
}

install_sway() {
  arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

# Update package databases and install Sway and related packages
pacman -Sy --noconfirm \
  sway wayland-utils xorg-xwayland \
  swaybg swayidle swaylock \
  sddm \
  wayland-protocols

# Enable SDDM display manager
systemctl enable sddm.service

# Configure locale (assuming en_US.UTF-8)
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set keyboard layout for Wayland (example: Norwegian layout)
cat <<KEYCONF > /etc/sway/config.d/keyboard.conf
input * {
    xkb_layout no
    xkb_variant basic
}
KEYCONF

# Create Sway config directory if not exist
mkdir -p /etc/sway/config.d

# Create a minimal Sway config file to include keyboard config
cat <<SWAYCFG > /etc/sway/config
# Load keyboard config
include config.d/keyboard.conf

# Set wallpaper and basic config
exec swaybg -i /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png -m fill
exec swayidle -w timeout 300 'swaylock -f' timeout 600 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"'
exec swaylock -f

# Your basic keybindings can be added here or user-specific config
SWAYCFG

echo "Sway installed, SDDM enabled, keyboard and locale configured."

# Show available Wayland sessions
ls /usr/share/wayland-sessions/ 2>/dev/null || true
EOF
}

install_plasma() {
  arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

# Update package databases and install KDE Plasma and essential packages
pacman -Sy --noconfirm \
  plasma-desktop \
  sddm \
  konsole \
  dolphin \
  xorg-xwayland \
  wayland \
  kde-system-meta

# Enable SDDM display manager
systemctl enable sddm.service

# Configure locale (assuming en_US.UTF-8)
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "KDE Plasma installed and SDDM enabled."
EOF
}


configure_os
#install_xfce
#install_sway
install_plasma