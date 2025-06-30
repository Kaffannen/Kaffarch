#!/bin/bash
# Disk management functions for Kaffarch installation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Discover storage devices
discover_storage_devices() {
    local device_type="${1:-disk}"  # disk, ssd, nvme
    
    case "$device_type" in
        "ssd")
            # Discover SSDs specifically
            lsblk -dpno NAME,TYPE,RM,ROTA | awk '$2 == "disk" && $3 == 0 && $4 == 0 {print $1}'
            ;;
        "nvme")
            # Discover NVMe devices
            lsblk -dpno NAME,TYPE | awk '$2 == "disk" && $1 ~ /nvme/ {print $1}'
            ;;
        *)
            # Discover all non-removable disks
            lsblk -dpno NAME,TYPE,RM | awk '$2 == "disk" && $3 == 0 {print $1}'
            ;;
    esac
}

# Display disk information
show_disk_info() {
    local disks=("$@")
    
    log_info "Available disks:"
    for disk in "${disks[@]}"; do
        local size model
        size=$(lsblk -no SIZE "$disk" | head -1)
        model=$(lsblk -no MODEL "$disk" | head -1)
        log_info "  $disk - $size - $model"
    done
}

# Safely tear down existing LVM setup
teardown_lvm() {
    local vg_name="$1"
    
    log_info "Tearing down existing LVM setup for VG: $vg_name"
    
    # Check if VG exists
    if ! vgs "$vg_name" >/dev/null 2>&1; then
        log_info "Volume group $vg_name does not exist, skipping teardown"
        return 0
    fi
    
    # Deactivate volume group
    log_debug "Deactivating volume group $vg_name"
    vgchange -a n "$vg_name" || true
    
    # Remove logical volumes
    for lv in $(lvs --noheadings -o lv_name "$vg_name" 2>/dev/null | tr -d ' '); do
        log_debug "Removing logical volume $lv"
        lvremove -y "/dev/$vg_name/$lv" || true
    done
    
    # Remove volume group
    log_debug "Removing volume group $vg_name"
    vgremove -y "$vg_name" || true
    
    # Remove physical volumes
    for pv in $(pvs --noheadings -o pv_name 2>/dev/null | tr -d ' '); do
        if pvs "$pv" | grep -q "$vg_name"; then
            log_debug "Removing physical volume $pv"
            pvremove -y "$pv" || true
        fi
    done
    
    log_info "LVM teardown completed"
}

# Wipe disk signatures
wipe_disks() {
    local disks=("$@")
    
    log_info "Wiping disk signatures..."
    for disk in "${disks[@]}"; do
        log_debug "Wiping signatures on $disk"
        wipefs -a "$disk"
        dd if=/dev/zero of="$disk" bs=1M count=10 2>/dev/null || true
    done
    
    # Update kernel partition table
    partprobe "${disks[@]}"
    udevadm settle
    
    log_info "Disk wiping completed"
}

# Create partitions on primary disk (EFI + LVM)
partition_primary_disk() {
    local disk="$1"
    local efi_size="$2"
    
    log_info "Partitioning primary disk $disk"
    
    # Create GPT partition table
    parted -s "$disk" mklabel gpt
    
    # Create EFI system partition
    parted -s "$disk" mkpart ESP fat32 1MiB "$efi_size"
    parted -s "$disk" set 1 esp on
    
    # Create LVM partition
    parted -s "$disk" mkpart primary "${efi_size}" 100%
    
    # Set LVM type
    parted -s "$disk" set 2 lvm on
    
    log_debug "Primary disk partitioning completed"
}

# Create partitions on secondary disks (LVM only)
partition_secondary_disks() {
    local disks=("$@")
    
    for disk in "${disks[@]}"; do
        log_info "Partitioning secondary disk $disk"
        
        # Create GPT partition table
        parted -s "$disk" mklabel gpt
        
        # Create single LVM partition
        parted -s "$disk" mkpart primary 1MiB 100%
        parted -s "$disk" set 1 lvm on
        
        log_debug "Secondary disk $disk partitioning completed"
    done
}

# Main partitioning function
partition_drives() {
    local primary_disk="$1"
    shift
    local secondary_disks=("$@")
    local all_disks=("$primary_disk" "${secondary_disks[@]}")
    
    show_progress 1 6 "Validating disks"
    validate_disks "${all_disks[@]}"
    
    show_progress 2 6 "Confirming disk operations"
    confirm_operation "This will DESTROY ALL DATA on: ${all_disks[*]}"
    
    show_progress 3 6 "Tearing down existing LVM"
    teardown_lvm "$VG_NAME"
    
    show_progress 4 6 "Wiping disk signatures"
    wipe_disks "${all_disks[@]}"
    
    show_progress 5 6 "Partitioning primary disk"
    partition_primary_disk "$primary_disk" "$EFI_SIZE"
    
    if [[ ${#secondary_disks[@]} -gt 0 ]]; then
        show_progress 6 6 "Partitioning secondary disks"
        partition_secondary_disks "${secondary_disks[@]}"
    fi
    
    # Final partition table update
    partprobe "${all_disks[@]}"
    udevadm settle
    sleep 2  # Give kernel time to recognize partitions
    
    log_info "All disk partitioning completed successfully"
}

# Show available functions
show_functions() {
    echo "Available functions in lib/disk.sh:"
    echo "  discover_storage_devices - Discover storage devices [type: disk|ssd|nvme]"
    echo "  show_disk_info          - Display disk information [disk1] [disk2...]"
    echo "  teardown_lvm            - Safely tear down LVM setup [vg_name]"
    echo "  wipe_disks              - Wipe disk signatures [disk1] [disk2...]"
    echo "  partition_primary_disk  - Partition primary disk [disk] [efi_size]"
    echo "  partition_secondary_disks - Partition secondary disks [disk1] [disk2...]"
    echo "  partition_drives        - Complete disk partitioning [primary] [secondary...]"
    echo "  show_functions          - Show this help"
    echo ""
    echo "Note: This is a library file, functions are meant to be sourced."
    echo "Usage: $0 [function_name] [arguments...]"
}

# Command dispatcher (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "This is a library file containing disk management functions."
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
