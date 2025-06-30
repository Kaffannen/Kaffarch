#!/bin/bash
# System installation and configuration functions

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Configure pacman
configure_pacman() {
    log_info "Configuring pacman"
    
    # Enable multilib if requested
    if [[ "$ENABLE_MULTILIB" == "true" ]]; then
        log_debug "Enabling multilib repository"
        sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    fi
    
    # Set parallel downloads
    sed -i "s/^#ParallelDownloads = .*/ParallelDownloads = $PARALLEL_DOWNLOADS/" /etc/pacman.conf
    
    # Update pacman database
    pacman -Sy
}

# Setup reflector for faster mirrors
setup_reflector() {
    if [[ "$ENABLE_REFLECTOR" != "true" ]]; then
        return 0
    fi
    
    log_info "Setting up reflector for optimal mirrors"
    
    pacman -S --noconfirm reflector
    
    # Backup original mirrorlist
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Update mirrorlist with reflector
    reflector --country "$REFLECTOR_COUNTRY" \
              --protocol https \
              --latest 10 \
              --sort rate \
              --save /etc/pacman.d/mirrorlist
    
    log_info "Mirrorlist updated with reflector"
}

# Install base system
install_base_system() {
    log_info "Installing base system"
    
    # Initialize pacman keys
    pacman-key --init
    pacman-key --populate archlinux
    
    # Setup optimal mirrors first
    setup_reflector
    
    # Configure pacman
    configure_pacman
    
    # Read packages from file
    local packages
    mapfile -t packages < <(read_packages "$PACSTRAP_PACKAGES")
    
    log_info "Installing ${#packages[@]} packages: ${packages[*]}"
    
    # Install base system
    pacstrap /mnt "${packages[@]}"
    
    log_info "Base system installation completed"
}

# Generate fstab
generate_fstab() {
    log_info "Generating fstab"
    
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Show generated fstab for verification
    log_debug "Generated fstab:"
    cat /mnt/etc/fstab >> "$LOG_FILE"
    
    log_info "fstab generated successfully"
}

# Configure system basics in chroot
configure_system_basics() {
    log_info "Configuring system basics"
    
    arch-chroot /mnt /bin/bash -c "
        set -euo pipefail
        
        # Set timezone
        ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
        hwclock --systohc
        
        # Configure locale
        sed -i 's/^#$LOCALE UTF-8/$LOCALE UTF-8/' /etc/locale.gen
        locale-gen
        echo 'LANG=$LOCALE' > /etc/locale.conf
        
        # Set hostname
        echo '$HOSTNAME' > /etc/hostname
        
        # Configure hosts file
        cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
        
        # Configure mkinitcpio for LVM
        sed -i '/^HOOKS=/s/block filesystems/block lvm2 filesystems/' /etc/mkinitcpio.conf
        mkinitcpio -P
        
        # Enable NetworkManager
        systemctl enable NetworkManager.service
    "
    
    log_info "System basics configured"
}

# Configure user account
configure_user_account() {
    log_info "Configuring user account"
    
    # Prompt for password if not set
    prompt_password
    
    arch-chroot /mnt /bin/bash -c "
        set -euo pipefail
        
        # Create user account
        useradd -m -G wheel -s /bin/bash '$USERNAME'
        echo '$USERNAME:$PASSWORD' | chpasswd
        
        # Configure sudo
        echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
        chmod 440 /etc/sudoers.d/wheel
        
        # Lock root account if requested
        if [[ '$LOCK_ROOT_ACCOUNT' == 'true' ]]; then
            passwd -l root
        fi
    "
    
    log_info "User account configured"
}

# Install and configure bootloader
configure_bootloader() {
    log_info "Installing and configuring GRUB bootloader"
    
    arch-chroot /mnt /bin/bash -c "
        set -euo pipefail
        
        # Install GRUB for EFI
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
        
        # Generate GRUB configuration
        grub-mkconfig -o /boot/grub/grub.cfg
    "
    
    log_info "Bootloader configured"
}

# Install additional packages from chroot list
install_additional_packages() {
    if [[ ! -f "$CHROOT_PACKAGES" ]]; then
        log_warn "Additional packages file not found: $CHROOT_PACKAGES"
        return 0
    fi
    
    local packages
    mapfile -t packages < <(read_packages "$CHROOT_PACKAGES")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_info "No additional packages to install"
        return 0
    fi
    
    log_info "Installing additional packages: ${packages[*]}"
    
    arch-chroot /mnt pacman -S --noconfirm "${packages[@]}"
    
    log_info "Additional packages installed"
}

# Main system configuration function
configure_system() {
    show_progress 1 6 "Installing base system"
    install_base_system
    
    show_progress 2 6 "Generating fstab"
    generate_fstab
    
    show_progress 3 6 "Configuring system basics"
    configure_system_basics
    
    show_progress 4 6 "Configuring user account"
    configure_user_account
    
    show_progress 5 6 "Installing additional packages"
    install_additional_packages
    
    show_progress 6 6 "Configuring bootloader"
    configure_bootloader
    
    log_info "System configuration completed successfully"
}

# Show available functions
show_functions() {
    echo "Available functions in lib/system.sh:"
    echo "  configure_pacman        - Configure pacman settings"
    echo "  setup_reflector         - Setup reflector for optimal mirrors"
    echo "  install_base_system     - Install base system packages"
    echo "  generate_fstab          - Generate filesystem table"
    echo "  configure_system_basics - Configure timezone, locale, hostname"
    echo "  configure_user_account  - Create and configure user account"
    echo "  install_additional_packages - Install additional packages from list"
    echo "  configure_bootloader    - Configure GRUB bootloader"
    echo "  configure_system        - Complete system configuration"
    echo "  show_functions          - Show this help"
    echo ""
    echo "Note: This is a library file, functions are meant to be sourced."
    echo "Usage: $0 [function_name] [arguments...]"
}

# Command dispatcher (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "This is a library file containing system configuration functions."
        show_functions
    else
        # Check if function exists
        if declare -f "$1" > /dev/null; then
            # Function exists, call it with remaining arguments
            "$@"
        else
            echo "Error: Function '$1' not found"
            show_functions
            exit 1
        fi
    fi
fi
