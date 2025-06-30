#!/bin/bash
# Common functions and utilities for Kaffarch installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging configuration
LOG_FILE="/tmp/kaffarch-install.log"

# Initialize logging
init_logging() {
    echo "=== Kaffarch Installation Started at $(date) ===" > "$LOG_FILE"
}

# Logging functions
log_debug() { [[ "$LOG_LEVEL" == "debug" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"; }
log_info() { [[ "$LOG_LEVEL" =~ ^(debug|info)$ ]] && echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
log_warn() { [[ "$LOG_LEVEL" =~ ^(debug|info|warn)$ ]] && echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; }

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    log_info "[$current/$total] ($percent%) $desc"
}

# Load configuration
load_config() {
    local config_file="${1:-./config.conf}"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    source "$config_file"
    log_info "Configuration loaded from $config_file"
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    for tool in parted lvm2 arch-chroot pacstrap genfstab; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Prompt for password securely
prompt_password() {
    if [[ -z "$PASSWORD" ]]; then
        echo -n "Enter password for user '$USERNAME': "
        read -s PASSWORD
        echo
        echo -n "Confirm password: "
        read -s password_confirm
        echo
        
        if [[ "$PASSWORD" != "$password_confirm" ]]; then
            log_error "Passwords do not match"
            exit 1
        fi
    fi
}

# Confirm destructive operation
confirm_operation() {
    local message="$1"
    local response
    
    echo -e "${YELLOW}WARNING:${NC} $message"
    echo -n "Continue? (yes/no): "
    read -r response
    
    if [[ "$response" != "yes" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# Read packages from file
read_packages() {
    local package_file="$1"
    local packages=()
    
    if [[ ! -f "$package_file" ]]; then
        log_error "Package list file not found: $package_file"
        exit 1
    fi
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            packages+=("$line")
        fi
    done < "$package_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages found in $package_file"
        exit 1
    fi
    
    printf '%s\n' "${packages[@]}"
}

# Cleanup function for trap
cleanup() {
    log_warn "Caught signal, performing cleanup..."
    
    # Unmount filesystems if mounted
    if mountpoint -q /mnt; then
        swapoff /dev/"$VG_NAME"/swap 2>/dev/null || true
        umount -R /mnt 2>/dev/null || true
    fi
    
    # Deactivate LVM if active
    vgchange -a n "$VG_NAME" 2>/dev/null || true
    
    log_info "Cleanup completed"
    exit 1
}

# Set up trap for cleanup
trap cleanup SIGINT SIGTERM

# Validate disk selection
validate_disks() {
    local disks=("$@")
    
    for disk in "${disks[@]}"; do
        if [[ ! -b "$disk" ]]; then
            log_error "Device $disk is not a valid block device"
            exit 1
        fi
        
        # Check if disk is mounted
        if lsblk -no MOUNTPOINT "$disk" | grep -q .; then
            log_error "Device $disk has mounted partitions"
            exit 1
        fi
        
        # Check minimum size (8GB)
        local size_bytes
        size_bytes=$(lsblk -bno SIZE "$disk" | head -1)
        local min_size=$((8 * 1024 * 1024 * 1024))  # 8GB in bytes
        
        if [[ $size_bytes -lt $min_size ]]; then
            log_error "Device $disk is too small (minimum 8GB required)"
            exit 1
        fi
    done
    
    log_info "All disks validated successfully"
}

# Get partition name for device
get_partition_name() {
    local device="$1"
    local partition_num="$2"
    
    if [[ "$device" =~ nvme|loop ]]; then
        echo "${device}p${partition_num}"
    else
        echo "${device}${partition_num}"
    fi
}

# Wait for device to be ready
wait_for_device() {
    local device="$1"
    local timeout=30
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if [[ -b "$device" ]]; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_error "Device $device not ready after ${timeout}s"
    return 1
}

# Show available functions
show_functions() {
    echo "Available functions in lib/common.sh:"
    echo "  init_logging         - Initialize logging system"
    echo "  log_debug/info/warn/error - Logging functions"
    echo "  show_progress        - Show progress indicator [current] [total] [desc]"
    echo "  load_config          - Load configuration file [file_path]"
    echo "  check_prerequisites  - Check required tools and permissions"
    echo "  get_user_input       - Get user input with prompt [prompt] [default]"
    echo "  validate_disks       - Validate disk selection [disk1] [disk2...]"
    echo "  get_partition_name   - Get partition name [device] [partition_num]"
    echo "  wait_for_device      - Wait for device to be ready [device]"
    echo "  show_functions       - Show this help"
    echo ""
    echo "Note: This is a library file, functions are meant to be sourced."
    echo "Usage: $0 [function_name] [arguments...]"
}

# Command dispatcher (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "This is a library file containing common functions."
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
