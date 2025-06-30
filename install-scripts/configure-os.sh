#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Load configuration and logging
load_config "$SCRIPT_DIR/config.conf"
init_logging

check_base_system() {
    if ! mountpoint -q /mnt || [[ ! -f /mnt/etc/fstab ]]; then
        log_error "Base system not ready at /mnt. Run configure-drives.sh first."
        exit 1
    fi
    log_info "Base system verified at /mnt"
}

configure_os() {
    log_info "Configuring base OS settings..."

    arch-chroot /mnt /bin/bash -euo pipefail <<'EOF'
# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Configure locale
sed -i "s/^#\($LOCALE\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set console keymap
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Enable multilib if requested
if [[ "$ENABLE_MULTILIB" == "true" ]]; then
    sed -i '/^\[multilib\]/,/^Include/ s/^#//' /etc/pacman.conf
fi

# Set pacman parallel downloads
sed -i "s/^#ParallelDownloads = .*/ParallelDownloads = $PARALLEL_DOWNLOADS/" /etc/pacman.conf

# Sync package databases
pacman -Sy

# Setup firewall if enabled
if [[ "$ENABLE_FIREWALL" == "true" ]]; then
    pacman -S --noconfirm ufw
    systemctl enable ufw
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
fi

# Secure SSH if requested
if [[ "$SECURE_SSH" == "true" && -x /usr/bin/sshd ]]; then
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl enable sshd
fi

# Lock root account if requested
if [[ "$LOCK_ROOT_ACCOUNT" == "true" ]]; then
    passwd -l root
fi
EOF

    log_info "Base OS configuration complete."
}

final_cleanup() {
    log_info "Cleaning up system..."

    arch-chroot /mnt pacman -Sc --noconfirm
    arch-chroot /mnt updatedb 2>/dev/null || true

    log_info "Cleanup done."
}

finish_installation() {
    log_info "Finalizing installation..."

    swapoff "/dev/$VG_NAME/swap" 2>/dev/null || true
    umount -R /mnt 2>/dev/null || true

    log_info "Kaffarch OS base setup completed successfully!"
    log_info "Log file: $LOG_FILE"
}

main() {
    log_info "Starting Kaffarch base OS setup..."
    check_prerequisites
    check_base_system
    configure_os
    final_cleanup
    finish_installation
}

main
