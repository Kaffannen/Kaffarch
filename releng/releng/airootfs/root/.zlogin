# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh
#!/bin/bash

check_internet() {
  ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
  echo "Unblocking Wi-Fi..."
  rfkill unblock wifi
  sleep 1

  echo "Bringing up wlan0 interface..."
  ip link set wlan0 up

  echo "Generating wpa_supplicant config..."
  wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Starting wpa_supplicant..."
  pkill wpa_supplicant 2>/dev/null || true
  wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Getting IP via DHCP..."
  dhcpcd wlan0

  echo "Waiting for connection to establish..."
  sleep 5

  ip addr show wlan0 | grep inet && echo "Wi-Fi connected." || echo "Wi-Fi connection failed."
}

if check_internet; then
  echo "Internet Access"
else
  echo "No internet or DNS issue. Attempting Wi-Fi connection..."
  connect_wifi

  if check_internet; then
    echo "Wi-Fi connected, Internet Access"
  else
    echo "Wi-Fi connection failed or no internet"
    exit 1
  fi
fi

bash <(curl -fsSL https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh)
#!/bin/bash

check_internet() {
  ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
  echo "Unblocking Wi-Fi..."
  rfkill unblock wifi
  sleep 1

  echo "Bringing up wlan0 interface..."
  ip link set wlan0 up

  echo "Generating wpa_supplicant config..."
  wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Starting wpa_supplicant..."
  pkill wpa_supplicant 2>/dev/null || true
  wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Getting IP via DHCP..."
  dhcpcd wlan0

  echo "Waiting for connection to establish..."
  sleep 5

  ip addr show wlan0 | grep inet && echo "Wi-Fi connected." || echo "Wi-Fi connection failed."
}

if check_internet; then
  echo "Internet Access"
else
  echo "No internet or DNS issue. Attempting Wi-Fi connection..."
  connect_wifi

  if check_internet; then
    echo "Wi-Fi connected, Internet Access"
  else
    echo "Wi-Fi connection failed or no internet"
    exit 1
  fi
fi

bash <(curl -fsSL https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh)
#!/bin/bash

check_internet() {
  ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
  echo "Unblocking Wi-Fi..."
  rfkill unblock wifi
  sleep 1

  echo "Bringing up wlan0 interface..."
  ip link set wlan0 up

  echo "Generating wpa_supplicant config..."
  wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Starting wpa_supplicant..."
  pkill wpa_supplicant 2>/dev/null || true
  wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Getting IP via DHCP..."
  dhcpcd wlan0

  echo "Waiting for connection to establish..."
  sleep 5

  ip addr show wlan0 | grep inet && echo "Wi-Fi connected." || echo "Wi-Fi connection failed."
}

if check_internet; then
  echo "Internet Access"
else
  echo "No internet or DNS issue. Attempting Wi-Fi connection..."
  connect_wifi

  if check_internet; then
    echo "Wi-Fi connected, Internet Access"
  else
    echo "Wi-Fi connection failed or no internet"
    exit 1
  fi
fi

bash <(curl -fsSL https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh)
#!/bin/bash

check_internet() {
  ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
  echo "Unblocking Wi-Fi..."
  rfkill unblock wifi
  sleep 1

  echo "Bringing up wlan0 interface..."
  ip link set wlan0 up

  echo "Generating wpa_supplicant config..."
  wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Starting wpa_supplicant..."
  pkill wpa_supplicant 2>/dev/null || true
  wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Getting IP via DHCP..."
  dhcpcd wlan0

  echo "Waiting for connection to establish..."
  sleep 5

  ip addr show wlan0 | grep inet && echo "Wi-Fi connected." || echo "Wi-Fi connection failed."
}

if check_internet; then
  echo "Internet Access"
else
  echo "No internet or DNS issue. Attempting Wi-Fi connection..."
  connect_wifi

  if check_internet; then
    echo "Wi-Fi connected, Internet Access"
  else
    echo "Wi-Fi connection failed or no internet"
    exit 1
  fi
fi

bash <(curl -fsSL https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh)
#!/bin/bash

check_internet() {
  ping -c 1 -W 2 google.com > /dev/null 2>&1
}

connect_wifi() {
  echo "Unblocking Wi-Fi..."
  rfkill unblock wifi
  sleep 1

  echo "Bringing up wlan0 interface..."
  ip link set wlan0 up

  echo "Generating wpa_supplicant config..."
  wpa_passphrase "Altibox610052_2.4GHz" "i7gQXu2p" > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Starting wpa_supplicant..."
  pkill wpa_supplicant 2>/dev/null || true
  wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

  echo "Getting IP via DHCP..."
  dhcpcd wlan0

  echo "Waiting for connection to establish..."
  sleep 5

  ip addr show wlan0 | grep inet && echo "Wi-Fi connected." || echo "Wi-Fi connection failed."
}

if check_internet; then
  echo "Internet Access"
else
  echo "No internet or DNS issue. Attempting Wi-Fi connection..."
  connect_wifi

  if check_internet; then
    echo "Wi-Fi connected, Internet Access"
  else
    echo "Wi-Fi connection failed or no internet"
    exit 1
  fi
fi

bash <(curl -fsSL https://raw.githubusercontent.com/Kaffannen/ArchLaptop/refs/heads/kaffannen/scripts/main.sh)
/root/wifi-connect.sh
