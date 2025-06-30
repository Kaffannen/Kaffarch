#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/config.conf"

# Load common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Main user configuration function
main() {
    echo "=== Configuring User Account ==="
    
    create_user_account
    configure_user_groups
    setup_user_directories
    configure_user_shell
    configure_sudo_access
    
    if [[ "$LOCK_ROOT_ACCOUNT" == "true" ]]; then
        lock_root_account
    fi
    
    echo "User configuration completed successfully"
}

# Create user account with password
create_user_account() {
    echo "Creating user account: $USERNAME"
    
    # Create user with home directory
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "User $USERNAME created successfully"
    else
        echo "User $USERNAME already exists"
    fi
    
    # Set user password
    if [[ -n "$PASSWORD" ]]; then
        echo "Setting password for $USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
    else
        echo "Setting password for $USERNAME (interactive)"
        passwd "$USERNAME"
    fi
}

# Configure user groups and permissions
configure_user_groups() {
    echo "Configuring user groups for $USERNAME"
    
    # Essential groups for desktop user
    local groups=(
        "wheel"      # sudo access
        "audio"      # audio devices
        "video"      # video devices
        "storage"    # removable storage
        "optical"    # optical drives
        "network"    # network management
        "power"      # power management
        "scanner"    # scanner access
        "lp"         # printer access
    )
    
    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null; then
            usermod -a -G "$group" "$USERNAME"
            echo "Added $USERNAME to group: $group"
        else
            echo "Warning: Group $group does not exist, skipping"
        fi
    done
}

# Setup user directories and permissions
setup_user_directories() {
    echo "Setting up user directories for $USERNAME"
    
    local user_home="/home/$USERNAME"
    
    # Ensure proper ownership of home directory
    chown -R "$USERNAME:$USERNAME" "$user_home"
    chmod 755 "$user_home"
    
    # Create standard user directories
    local directories=(
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "Public"
        "Templates"
        ".config"
        ".local/share"
        ".local/bin"
    )
    
    for dir in "${directories[@]}"; do
        local full_path="$user_home/$dir"
        if [[ ! -d "$full_path" ]]; then
            sudo -u "$USERNAME" mkdir -p "$full_path"
            echo "Created directory: $dir"
        fi
    done
    
    # Set up .local/bin in PATH if not already there
    local bashrc="$user_home/.bashrc"
    if [[ -f "$bashrc" ]] && ! grep -q ".local/bin" "$bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
        echo "Added .local/bin to PATH in .bashrc"
    fi
}

# Configure user shell and environment
configure_user_shell() {
    echo "Configuring shell environment for $USERNAME"
    
    local user_home="/home/$USERNAME"
    local bashrc="$user_home/.bashrc"
    
    # Create basic .bashrc if it doesn't exist
    if [[ ! -f "$bashrc" ]]; then
        sudo -u "$USERNAME" touch "$bashrc"
    fi
    
    # Add useful aliases if not already present
    local aliases=(
        "alias ll='ls -alF'"
        "alias la='ls -A'"
        "alias l='ls -CF'"
        "alias grep='grep --color=auto'"
        "alias fgrep='fgrep --color=auto'"
        "alias egrep='egrep --color=auto'"
    )
    
    for alias_line in "${aliases[@]}"; do
        if ! grep -Fq "$alias_line" "$bashrc"; then
            echo "$alias_line" >> "$bashrc"
        fi
    done
    
    echo "Shell environment configured"
}

# Configure sudo access for wheel group
configure_sudo_access() {
    echo "Configuring sudo access for wheel group"
    
    # Ensure wheel group line is uncommented in sudoers
    if [[ -f /etc/sudoers ]]; then
        # Enable basic sudo access for wheel group
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        echo "Enabled sudo access for wheel group"
        
        # Enable passwordless sudo if configured
        if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
            # Check if passwordless sudo line already exists
            if ! grep -q "^%wheel ALL=(ALL:ALL) NOPASSWD: ALL" /etc/sudoers; then
                # Add passwordless sudo for wheel group
                echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
                echo "Enabled passwordless sudo for wheel group"
            else
                echo "Passwordless sudo already configured for wheel group"
            fi
        fi
    else
        echo "Warning: /etc/sudoers file not found"
    fi
}

# Lock root account for security
lock_root_account() {
    echo "Locking root account for security"
    
    # Lock the root account
    passwd -l root
    
    # Disable root login in SSH if sshd config exists
    if [[ -f /etc/ssh/sshd_config ]]; then
        if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "PermitRootLogin no" >> /etc/ssh/sshd_config
            echo "Disabled root SSH login"
        fi
    fi
    
    echo "Root account locked successfully"
}



# Command dispatcher
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        # No arguments, run main function
        main
    else
        # Check if function exists
        if declare -f "$1" > /dev/null; then
            # Function exists, call it with remaining arguments
            "$@"
        else
            echo "Error: Function '$1' not found"
            echo "Available functions:"
            echo "  main                    - Complete user configuration"
            echo "  create_user_account     - Create user account only"
            echo "  configure_user_groups   - Configure user groups only"
            echo "  setup_user_directories  - Setup user directories only"
            echo "  configure_sudo_access   - Configure sudo access"
            echo "  lock_root_account       - Lock root account for security"
            exit 1
        fi
    fi
fi
