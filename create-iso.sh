#!/usr/bin/env bash
set -euo pipefail

main() {
    echo "=== Kaffarch ISO Creation Started ==="
    
    echo "Cleaning up old build directories..."
    rm -rf work out

    cp -r ./releng releng-backup

    ./prepare_releng.sh

    echo "Starting ISO build..."
    mkarchiso -v -o out releng

    rm -rf releng
    mv releng-backup releng

    rm -rf work 
    
    echo "=== Kaffarch ISO Creation Completed ==="
}

main
