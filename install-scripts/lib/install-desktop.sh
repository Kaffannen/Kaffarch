#!/bin/bash
# Desktop environment installation functions

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Install XFCE desktop environment
install_xfce() {
    log_info "Installing XFCE desktop environment"
    
    local xfce_packages="../pkg-lists/graphical-interfaces/xfce4-packages.txt"
    
    if [[ -f "$xfce_packages" ]]; then
        local packages
        mapfile -t packages < <(read_packages "$xfce_packages")
        
        arch-chroot /mnt pacman -S --noconfirm "${packages[@]}"
    else
        # Fallback to basic XFCE installation
        arch-chroot /mnt pacman -S --noconfirm \
            xorg-server xorg-xinit xf86-video-vesa \
            xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
    fi
    
    # Enable display manager
    arch-chroot /mnt systemctl enable lightdm.service
    
    log_info "XFCE installation completed"
}

# Install Sway (Wayland) desktop environment
install_sway() {
    log_info "Installing Sway desktop environment"
    
    local sway_packages="../pkg-lists/graphical-interfaces/sway-packages.txt"
    
    if [[ -f "$sway_packages" ]]; then
        local packages
        mapfile -t packages < <(read_packages "$sway_packages")
        
        arch-chroot /mnt pacman -S --noconfirm "${packages[@]}"
    else
        # Fallback to basic Sway installation
        arch-chroot /mnt pacman -S --noconfirm \
            sway wayland-utils xorg-xwayland \
            swaybg swayidle swaylock \
            sddm wayland-protocols \
            foot dmenu
    fi
    
    # Configure Sway
    arch-chroot /mnt /bin/bash -c "
        # Create system-wide Sway config directory
        mkdir -p /etc/sway/config.d
        
        # Configure keyboard layout
        cat > /etc/sway/config.d/keyboard.conf << 'EOF'
input * {
    xkb_layout $KEYMAP
    xkb_variant basic
}
EOF
        
        # Create basic Sway config
        cat > /etc/sway/config << 'EOF'
# Include keyboard config
include config.d/keyboard.conf

# Set wallpaper and basic config
exec swaybg -c \"#1e1e2e\"
exec swayidle -w timeout 300 'swaylock -f -c 000000' timeout 600 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"'

# Basic keybindings
bindsym Mod4+Return exec foot
bindsym Mod4+d exec dmenu_run
bindsym Mod4+Shift+q kill
EOF
    "
    
    # Enable display manager
    arch-chroot /mnt systemctl enable sddm.service
    
    log_info "Sway installation completed"
}

# Install KDE Plasma desktop environment
install_plasma() {
    log_info "Installing KDE Plasma desktop environment"
    
    local plasma_packages="../pkg-lists/graphical-interfaces/plasma-packages.txt"
    
    if [[ -f "$plasma_packages" ]]; then
        local packages
        mapfile -t packages < <(read_packages "$plasma_packages")
        
        arch-chroot /mnt pacman -S --noconfirm "${packages[@]}"
    else
        # Fallback to basic Plasma installation
        arch-chroot /mnt pacman -S --noconfirm \
            plasma-desktop sddm \
            konsole dolphin \
            xorg-xwayland wayland \
            kde-system-meta
    fi
    
    # Enable display manager
    arch-chroot /mnt systemctl enable sddm.service
    
    log_info "KDE Plasma installation completed"
}

# Show available functions
show_functions() {
    echo "Available desktop environment functions:"
    echo "  install_xfce - Install XFCE desktop environment"
    echo "  install_sway - Install Sway desktop environment"
    echo "  install_plasma - Install KDE Plasma desktop environment"
}

# Command dispatcher (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "This is a library file containing desktop environment functions."
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