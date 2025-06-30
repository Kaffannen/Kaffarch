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

    echo "Bringing up interface: wlan0"
    ip link set "wlan0" up
    sleep 1

    echo "Scanning for Wi-Fi networks..."
    if iw dev "wlan0" scan | grep -qi "Altibox610052_2.4GHz"; then
        echo "✅ SSID 'Altibox610052_2.4GHz' found."
    else
        echo "❌ SSID 'Altibox610052_2.4GHz' not found. Aborting Wi-Fi connection."
        return 1
    fi

    echo "Creating wpa_supplicant config..."
    wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

    echo "Stopping any existing wpa_supplicant instance..."
    pkill wpa_supplicant 2>/dev/null || true

    echo "Starting wpa_supplicant..."
    wpa_supplicant -B -i "wlan0" -c /etc/wpa_supplicant/wpa_supplicant.conf

    echo "Requesting IP address via DHCP..."
    dhcpcd "wlan0" || {
        echo "❌ DHCP failed"
        return 1
    }

    echo "Waiting for connection..."
    sleep 5

    if ip addr show "wlan0" | grep -q inet; then
        echo "✅ Wi-Fi connected to 'Altibox610052_2.4GHz' on wlan0"
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
    bash <(curl -fsSL "https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh")
}

# Run main function
main "$@"
