#!/bin/bash
set -euo pipefail

# Main menu function
show_main_menu() {
    clear
    echo "=================================="
    echo "       MAIN MENU TEMPLATE"
    echo "=================================="
    echo "1. Live Desktop Environment"
    echo "2. Install Arch with DE" 
    echo "3. Restart System"
    echo "4. Shutdown System"
    echo "=================================="
    echo -n "Please select an option (1-4): "
}

# Live Desktop Environment menu function
show_desktop_menu() {
    clear
    echo "=================================="
    echo "    LIVE DESKTOP ENVIRONMENT"
    echo "=================================="
    echo "1. KDE Plasma"
    echo "2. XFCE"
    echo "3. Sway"
    echo "4. Back to Main Menu"
    echo "=================================="
    echo -n "Please select an option (1-4): "
}

# Install Arch with DE menu function
show_install_menu() {
    clear
    echo "=================================="
    echo "    INSTALL ARCH WITH DE"
    echo "=================================="
    echo "1. Install Arch with KDE Plasma"
    echo "2. Install Arch with XFCE"
    echo "3. Install Arch with Sway"
    echo "4. Back to Main Menu"
    echo "=================================="
    echo -n "Please select an option (1-4): "
}

// ...existing code...
# Live Desktop Environment handler
handle_desktop_menu() {
    local choice
    while true; do
        show_desktop_menu
        read -r choice
        
        case $choice in
            1)
                echo "Loading KDE Plasma in live environment..."
                run_remote_script "/install-scripts/lib/install-live-desktop.sh" start_plasma
                read -p "Press Enter to continue..."
                ;;
            2)
                echo "Loading XFCE in live environment..."
                run_remote_script "/install-scripts/lib/install-live-desktop.sh" start_xfce
                read -p "Press Enter to continue..."
                ;;
            3)
                echo "Loading Sway in live environment..."
                run_remote_script "/install-scripts/lib/install-live-desktop.sh" start_sway
                read -p "Press Enter to continue..."
                ;;
            4)
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Install Arch with DE handler
handle_install_menu() {
    local choice
    while true; do
        show_install_menu
        read -r choice
        
        case $choice in
            1)
                echo "Starting Arch installation with KDE Plasma..."
                run_remote_script "/install-scripts/lib/install-desktop.sh" install_plasma
                read -p "Press Enter to continue..."
                ;;
            2)
                echo "Starting Arch installation with XFCE..."
                run_remote_script "/install-scripts/lib/install-desktop.sh" install_xfce
                read -p "Press Enter to continue..."
                ;;
            3)
                echo "Starting Arch installation with Sway..."
                run_remote_script "/install-scripts/lib/install-desktop.sh" install_sway
                read -p "Press Enter to continue..."
                ;;
            4)
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Main program function
main() {
    local choice
    
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1)
                handle_desktop_menu
                ;;
            2)
                handle_install_menu
                ;;
            3)
                echo "Restarting system..."
                sudo reboot
                ;;
            4)
                echo "Shutting down system..."
                sudo shutdown -h now
                ;;
            *)
                echo "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Command dispatcher
if [[ $# -eq 0 ]]; then
    main
else
    case "$1" in
        main)
            main
            ;;
        *)
            echo "Available functions:"
            echo "  main - Start the menu program"
            exit 1
            ;;
    esac
fi

# Function to fetch and run a script from the repository
run_remote_script() {
    local script_name="$1"
    shift || true
    local script_args=("$@")
    
    local baseurl="https://raw.githubusercontent.com/Kaffannen/Kaffarch/refs/heads/main"
    local url="${baseurl}${script_name}"
    
    if curl --fail --silent --show-error "$url" | bash -s -- "${script_args[@]}"; then
        echo "'$script_name' executed successfully."
    else
        echo "Failed to fetch or execute remote '$script_name'"
        exit 1
    fi
}