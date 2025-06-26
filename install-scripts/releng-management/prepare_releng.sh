#!/bin/bash
set -euo pipefail

inject-into-zlogin() {
    echo "Injecting custom install command into .zlogin..."

    # Go up two directories
    cd ../..

    # Backup the file
    cp releng/airootfs/root/.zlogin releng/airootfs/root/.zlogin.bak

    # Append or overwrite text into .zlogin
    cat <<EOF >> releng/airootfs/root/.zlogin
    /root/start-install.sh
    EOF
    echo ".zlogin modified successfully."
}
echo-in-start-install-script() {
    cd ../..
    cat <<EOF >> releng/airootfs/root/start-install.sh
    <thewholefile>
    EOF
}

inject_zlogin
