#!/bin/bash
set -euo pipefail

# Start KDE Plasma in live environment
start_plasma() {
    echo "Setting up KDE Plasma services..."
    
    # Enable and start display manager
    systemctl enable sddm
    systemctl start sddm
    
    echo "KDE Plasma login manager started"
}

# Start XFCE in live environment  
start_xfce() {
    echo "Setting up XFCE services..."
    
    # Enable and start display manager for XFCE
    systemctl enable lightdm
    systemctl start lightdm
    
    echo "XFCE login manager started"
}

# Start Sway in live environment
start_sway() {
    echo "Setting up Sway services..."
    
    # Enable and start display manager for Sway
    systemctl enable sddm
    systemctl start sddm
    
    echo "Sway login manager started"
}

# Command dispatcher
if [[ $# -eq 0 ]]; then
    echo "Available functions:"
    echo "  start_plasma - Start KDE Plasma services and login manager"
    echo "  start_xfce - Start XFCE services and login manager"
    echo "  start_sway - Start Sway services and login manager"
else
    case "$1" in
        start_plasma)
            start_plasma
            ;;
        start_xfce)
            start_xfce
            ;;
        start_sway)
            start_sway
            ;;
        *)
            echo "Available functions:"
            echo "  start_plasma - Start KDE Plasma services and login manager"
            echo "  start_xfce - Start XFCE services and login manager"
            echo "  start_sway - Start Sway services and login manager"
            exit 1
            ;;
    esac
fi