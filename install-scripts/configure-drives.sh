#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common functions and configuration
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/disk.sh"
source "$SCRIPT_DIR/lib/lvm.sh"
source "$SCRIPT_DIR/lib/system.sh"

# Load configuration and initialize logging
load_config "$SCRIPT_DIR/config.conf"
init_logging

main() {
    log_info "=== Kaffarch Drive Configuration Started ==="
    
    # Check prerequisites
    check_prerequisites
    
    # Discover storage devices
    log_info "Discovering storage devices..."
    mapfile -t available_disks < <(discover_storage_devices "ssd")
    
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        log_warn "No SSDs found, falling back to all available disks"
        mapfile -t available_disks < <(discover_storage_devices "disk")
    fi

    if [[ ${#available_disks[@]} -lt 2 ]]; then
        log_error "Need at least 2 disks for striped LVM setup"
        log_error "Available disks: ${#available_disks[@]}"
        exit 1
    fi

    # Show and select disks
    show_disk_info "${available_disks[@]}"
    local primary_disk="${available_disks[0]}"
    local secondary_disks=("${available_disks[@]:1}")
    
    log_info "Selected primary disk: $primary_disk"
    log_info "Selected secondary disks: ${secondary_disks[*]}"
    
    # Partition and configure drives
    log_info "=== Starting Disk Partitioning ==="
    partition_drives "$primary_disk" "${secondary_disks[@]}"

    log_info "=== Starting LVM Setup ==="
    setup_lvm "$primary_disk" "${secondary_disks[@]}"

    log_info "=== Starting System Configuration ==="
    configure_system

    log_info "=== Drive configuration completed successfully ==="
    log_info "Log file available at: $LOG_FILE"
    log_info "You can now run configure-os.sh to complete the installation"
}

main
