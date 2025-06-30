#!/bin/bash
set -euo pipefail

# Configuration variables
WIFI_SSID="Altibox610052_2.4GHz"
WIFI_PASSWORD="i7gQXu2p"
WIFI_INTERFACE="wlan0"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/Kaffannen/Kaffarch/refs/heads/main/install-scripts/menuscript.sh"
REFLECTOR_COUNTRIES="Norway,Sweden,Denmark"

add_wifi_permission_to_profiledef() {
  local f=releng/profiledef.sh
  local k='/root/wifi-connect.sh'
  local v='0:0:755'

  if grep -q "\[\"$k\"\]" "$f"; then
    # Update existing entry
    sed -i "s|\[\"$k\"\] *= *\"[^\"]*\"|[\"$k\"]=\"$v\"|" "$f"
  else
    # Remove the last ')' line
    sed -i '$d' "$f"
    # Add our entry and the closing ')'
    echo "  [\"$k\"]=\"$v\"" >> "$f"
    echo ")" >> "$f"
  fi
}


# Create Wi-Fi connection script and update .zlogin
setup_wifi_script() {
    echo "Creating Wi-Fi connection script and updating .zlogin..."

    # Create the Wi-Fi connection script
    cat <<EOF > releng/airootfs/root/wifi-connect.sh
#!/bin/bash
# Kaffarch Wi-Fi Connection Script
# Automatically connects to Wi-Fi and downloads the main installation script

check_internet() {
    ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
    echo "Unblocking Wi-Fi..."
    rfkill unblock wifi
    sleep 1

    echo "Bringing up interface: $WIFI_INTERFACE"
    ip link set "$WIFI_INTERFACE" up
    sleep 1

    echo "Scanning for Wi-Fi networks..."
    if iw dev "$WIFI_INTERFACE" scan | grep -qi "$WIFI_SSID"; then
        echo "✅ SSID '$WIFI_SSID' found."
    else
        echo "❌ SSID '$WIFI_SSID' not found. Aborting Wi-Fi connection."
        return 1
    fi

    echo "Creating wpa_supplicant config..."
    wpa_passphrase "$WIFI_SSID" "$WIFI_PASSWORD" > /etc/wpa_supplicant/wpa_supplicant.conf

    echo "Stopping any existing wpa_supplicant instance..."
    pkill wpa_supplicant 2>/dev/null || true

    echo "Starting wpa_supplicant..."
    wpa_supplicant -B -i "$WIFI_INTERFACE" -c /etc/wpa_supplicant/wpa_supplicant.conf

    echo "Requesting IP address via DHCP..."
    dhcpcd "$WIFI_INTERFACE" || {
        echo "❌ DHCP failed"
        return 1
    }

    echo "Waiting for connection..."
    sleep 5

    if ip addr show "$WIFI_INTERFACE" | grep -q inet; then
        echo "✅ Wi-Fi connected to '$WIFI_SSID' on $WIFI_INTERFACE"
        return 0
    else
        echo "❌ Wi-Fi connection failed."
        return 1
    fi
}

main() {
    echo "=== Kaffarch Wi-Fi Setup ==="
    
    if check_internet; then
        echo "Internet Access already available"
    else
        echo "No internet or DNS issue. Attempting Wi-Fi connection..."
        connect_wifi

        if check_internet; then
            echo "Wi-Fi connected, Internet Access established"
        else
            echo "Wi-Fi connection failed or no internet"
            exit 1
        fi
    fi

    echo "Downloading and running main installation script..."
    echo "Remote script URL: $REMOTE_SCRIPT_URL"
    bash <(curl -fsSL "$REMOTE_SCRIPT_URL")
}

# Run main function
main "\$@"
EOF

    chmod +x releng/airootfs/root/wifi-connect.sh

    # Append to .zlogin only if not already present
    if ! grep -qxF '/root/wifi-connect.sh' releng/airootfs/root/.zlogin 2>/dev/null; then
        echo '/root/wifi-connect.sh' >> releng/airootfs/root/.zlogin
    fi

    echo "Wi-Fi script created and .zlogin updated successfully."
}

# Function to consolidate all package lists into releng packages file
consolidate_package_lists() {
    local releng_packages_file="releng/packages.x86_64"
    local pkg_lists_dir="pkg-lists"
    local temp_file
    temp_file=$(mktemp)
    
    echo "Consolidating package lists into $releng_packages_file..."
    
    # Start with existing packages file as base
    if [[ -f "$releng_packages_file" ]]; then
        echo "# Base packages from original packages.x86_64" > "$temp_file"
        cat "$releng_packages_file" >> "$temp_file"
        echo "" >> "$temp_file"
    fi
    
    # Add packages from all txt files in pkg-lists directory (recursively)
    find "$pkg_lists_dir" -name "*.txt" -type f | sort | while read -r package_file; do
        if [[ -f "$package_file" ]]; then
            local rel_path
            rel_path=$(realpath --relative-to="$pkg_lists_dir" "$package_file")
            
            echo "# Packages from $rel_path" >> "$temp_file"
            
            while IFS= read -r line; do
                if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                    local package
                    package=$(echo "$line" | sed 's/#.*$//' | tr -d '[:space:]')
                    if [[ -n "$package" ]]; then
                        echo "$package" >> "$temp_file"
                    fi
                fi
            done < "$package_file"
            
            echo "" >> "$temp_file"
        fi
    done
    
    # Remove duplicates while preserving order and comments
    local final_temp
    final_temp=$(mktemp)
    local seen_packages
    seen_packages=$(mktemp)
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            echo "$line" >> "$final_temp"
        else
            if ! grep -Fxq "$line" "$seen_packages" 2>/dev/null; then
                echo "$line" >> "$final_temp"
                echo "$line" >> "$seen_packages"
            fi
        fi
    done < "$temp_file"
    
    mv "$final_temp" "$releng_packages_file"
    rm -f "$temp_file" "$seen_packages"
    
    local total_packages
    total_packages=$(grep -v '^#' "$releng_packages_file" | grep -v '^[[:space:]]*$' | wc -l)
    echo "Package consolidation complete!"
    echo "Total unique packages: $total_packages"
    echo "Updated file: $releng_packages_file"
}

# Update mirrorlist with reflector
update_mirrorlist() {
    echo "Updating mirrorlist with reflector..."
    
    if ! command -v reflector >/dev/null 2>&1; then
        echo "Installing reflector..."
        pacman -S --noconfirm reflector
    fi
    
    echo "Running reflector to update mirrorlist..."
    reflector --country "$REFLECTOR_COUNTRIES" \
             --age 12 \
             --protocol https \
             --sort rate \
             --save /etc/pacman.d/mirrorlist
    
    echo "Mirrorlist updated successfully."
}

# Main function - run all preparation steps
main() {
    echo "=== Kaffarch Releng Preparation Started ==="
    
    add_wifi_permission_to_profiledef
    setup_wifi_script
    consolidate_package_lists
    
    echo "=== Releng preparation completed successfully ==="
}

main "$@"
