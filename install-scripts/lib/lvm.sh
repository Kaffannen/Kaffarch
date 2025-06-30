#!/bin/bash
# LVM management functions for Kaffarch installation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Calculate optimal swap size
calculate_swap_size() {
    local ram_mib
    ram_mib=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
    
    log_info "Detected RAM: ${ram_mib} MiB"
    
    # Calculate swap size based on RAM
    local swap_mib
    if [[ $ram_mib -le 2048 ]]; then
        # <= 2GB RAM: 2x RAM
        swap_mib=$((ram_mib * 2))
    elif [[ $ram_mib -le 8192 ]]; then
        # 2-8GB RAM: 1x RAM + extra
        swap_mib=$((ram_mib + SWAP_EXTRA_MIB))
    else
        # > 8GB RAM: 4GB + extra
        swap_mib=$((4096 + SWAP_EXTRA_MIB))
    fi
    
    log_info "Calculated swap size: ${swap_mib} MiB"
    echo "$swap_mib"
}

# Create LVM physical volumes
create_physical_volumes() {
    local primary_disk="$1"
    shift
    local secondary_disks=("$@")
    
    local pv_list=()
    
    # Add primary disk partition
    local primary_part
    primary_part=$(get_partition_name "$primary_disk" 2)
    wait_for_device "$primary_part"
    pv_list+=("$primary_part")
    
    # Add secondary disk partitions
    for disk in "${secondary_disks[@]}"; do
        local secondary_part
        secondary_part=$(get_partition_name "$disk" 1)
        wait_for_device "$secondary_part"
        pv_list+=("$secondary_part")
    done
    
    log_info "Creating physical volumes: ${pv_list[*]}"
    
    # Create physical volumes
    pvcreate -y -ff "${pv_list[@]}"
    
    # Create volume group
    vgcreate -ff "$VG_NAME" "${pv_list[@]}"
    
    log_info "Volume group $VG_NAME created with ${#pv_list[@]} physical volumes"
    echo "${#pv_list[@]}"  # Return number of PVs for striping
}

# Create logical volumes
create_logical_volumes() {
    local num_pvs="$1"
    
    log_info "Creating logical volumes in VG: $VG_NAME"
    
    # Calculate swap size
    local swap_mib
    swap_mib=$(calculate_swap_size)
    local swap_extents
    swap_extents=$((swap_mib / 4))  # Assuming 4MB extents
    
    # Create swap logical volume
    log_info "Creating swap LV with ${swap_extents} extents"
    lvcreate -y -l "$swap_extents" -n swap "$VG_NAME"
    
    # Get remaining free extents
    local free_extents
    free_extents=$(vgs --noheadings -o vg_free_count "$VG_NAME" | tr -d ' ')
    log_info "Free extents available: $free_extents"
    
    # Reserve some extents for safety
    local root_extents
    root_extents=$((free_extents - RESERVE_EXTENTS))
    
    if [[ $root_extents -le 0 ]]; then
        log_error "Not enough free extents for root LV after reserving $RESERVE_EXTENTS extents"
        exit 1
    fi
    
    log_info "Creating root LV with ${root_extents} extents (striped across $num_pvs PVs)"
    
    # Create striped root logical volume if multiple PVs
    if [[ $num_pvs -gt 1 ]]; then
        lvcreate -y -l "$root_extents" -i "$num_pvs" -I "$LVM_STRIPE_SIZE" -n root "$VG_NAME"
    else
        lvcreate -y -l "$root_extents" -n root "$VG_NAME"
    fi
    
    log_info "Logical volumes created successfully"
}

# Format filesystems
format_filesystems() {
    local primary_disk="$1"
    
    log_info "Formatting filesystems"
    
    # Format EFI partition
    local efi_part
    efi_part=$(get_partition_name "$primary_disk" 1)
    log_info "Formatting EFI partition: $efi_part"
    mkfs.vfat -F32 -n "EFI" "$efi_part"
    
    # Format root filesystem
    log_info "Formatting root filesystem: /dev/$VG_NAME/root"
    mkfs.ext4 -L "root" "/dev/$VG_NAME/root"
    
    # Format swap
    log_info "Formatting swap: /dev/$VG_NAME/swap"
    mkswap -L "swap" "/dev/$VG_NAME/swap"
    
    log_info "Filesystem formatting completed"
}

# Mount filesystems
mount_filesystems() {
    local primary_disk="$1"
    
    log_info "Mounting filesystems"
    
    # Mount root filesystem
    log_info "Mounting root filesystem"
    mount "/dev/$VG_NAME/root" /mnt
    
    # Create and mount EFI directory
    mkdir -p /mnt/boot
    local efi_part
    efi_part=$(get_partition_name "$primary_disk" 1)
    log_info "Mounting EFI partition: $efi_part"
    mount "$efi_part" /mnt/boot
    
    # Enable swap
    log_info "Enabling swap"
    swapon "/dev/$VG_NAME/swap"
    
    log_info "All filesystems mounted successfully"
}

# Main LVM setup function
setup_lvm() {
    local primary_disk="$1"
    shift
    local secondary_disks=("$@")
    
    show_progress 1 4 "Creating LVM physical volumes"
    local num_pvs
    num_pvs=$(create_physical_volumes "$primary_disk" "${secondary_disks[@]}")
    
    show_progress 2 4 "Creating logical volumes"
    create_logical_volumes "$num_pvs"
    
    show_progress 3 4 "Formatting filesystems"
    format_filesystems "$primary_disk"
    
    show_progress 4 4 "Mounting filesystems"
    mount_filesystems "$primary_disk"
    
    log_info "LVM setup completed successfully"
}

# Show available functions
show_functions() {
    echo "Available functions in lib/lvm.sh:"
    echo "  calculate_swap_size     - Calculate optimal swap size"
    echo "  create_physical_volumes - Create LVM physical volumes [primary] [secondary...]"
    echo "  create_logical_volumes  - Create logical volumes [num_pvs]"
    echo "  format_filesystems      - Format filesystems [primary_disk]"
    echo "  mount_filesystems       - Mount filesystems [primary_disk]"
    echo "  setup_lvm               - Complete LVM setup [primary] [secondary...]"
    echo "  show_functions          - Show this help"
    echo ""
    echo "Note: This is a library file, functions are meant to be sourced."
    echo "Usage: $0 [function_name] [arguments...]"
}

# Command dispatcher (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "This is a library file containing LVM management functions."
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
