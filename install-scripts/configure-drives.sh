#!/bin/bash
set -euo pipefail

# Discover all SSDs (adjust grep pattern if needed)
discover_ssds() {
  lsblk -dpno NAME,TYPE,RM | awk '$2 == "disk" && $3 == 0 {print $1}'
}

# Partition disks: first disk gets EFI + LVM, others LVM only
partition_drives() {
  local first_disk="$1"
  shift
  local disks=("$@")

  # Deactivate and remove LVM setup
  echo "Tearing down existing LVM..."
  vgchange -a n vg0 || true
  lvremove -y /dev/vg0/swap || true
  lvremove -y /dev/vg0/root || true
  yes | vgremove vg0 || true

  # Wipe disks
  echo "Wiping existing signatures..."
  for disk in "$first_disk" "${disks[@]}"; do
      wipefs -a "$disk"
  done

  echo "Partitioning $first_disk with EFI and LVM..."
  parted -s "$first_disk" mklabel gpt
  parted -s "$first_disk" mkpart ESP fat32 1MiB 513MiB
  parted -s "$first_disk" set 1 esp on
  parted -s "$first_disk" mkpart primary 513MiB 100%

  for disk in "${disks[@]}"; do
    echo "Partitioning $disk with LVM..."
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart primary 1MiB 100%
  done

  echo "Informing kernel of partition changes..."
  for disk in "$first_disk" "${disks[@]}"; do
    partprobe "$disk"
  done
  udevadm settle
  echo "Partitions created successfully."
}

# Setup LVM with striping, creating swap first
setup_lvm() {
  local first_disk="$1"
  shift
  local disks=("$@")

  echo "=== Creating LVM physical volumes ==="
  local lvm_parts=()

  # Correct partition suffix for nvme vs sdX devices
  if [[ "$first_disk" =~ nvme ]]; then
    echo "Detected NVMe device: $first_disk"
    lvm_parts+=("${first_disk}p2")
  else
    echo "Detected standard block device: $first_disk"
    lvm_parts+=("${first_disk}2")
  fi

  for disk in "${disks[@]}"; do
    if [[ "$disk" =~ nvme ]]; then
      echo "Detected NVMe device: $disk"
      lvm_parts+=("${disk}p1")
    else
      echo "Detected standard block device: $disk"
      lvm_parts+=("${disk}1")
    fi
  done

  echo "LVM partitions to use: ${lvm_parts[*]}"

  echo "Running: pvcreate -y -ff ${lvm_parts[*]}"
  pvcreate -y -ff "${lvm_parts[@]}"

  echo "Running: vgcreate -ff vg0 ${lvm_parts[*]}"
  vgcreate -ff vg0 "${lvm_parts[@]}"

  echo "=== Calculating swap size ==="
  local ram_mib
  ram_mib=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
  echo "Detected RAM size: ${ram_mib} MiB"

  local swap_mib=$(( ram_mib + 2048 ))
  local swap_extents=$(( swap_mib / 4 ))
  echo "Calculated swap size: ${swap_mib} MiB (${swap_extents} extents)"

  echo "Running: lvcreate -l ${swap_extents} -n swap vg0"
  lvcreate -y -v -l "${swap_extents}" -n swap vg0

  echo "=== Checking free extents in VG ==="
  vgs vg0
  local free_extents
  free_extents=$(vgs --noheadings -o vg_free_count vg0 | awk '{print $1}')
  echo "Free extents available: $free_extents"

  local reserve_extents=5
  local root_extents=$(( free_extents - reserve_extents ))
  echo "Reserving ${reserve_extents} extents for safety"
  echo "Extents allocated for root LV: ${root_extents}"

  if (( root_extents <= 0 )); then
    echo "ERROR: Not enough free extents to create root LV after reserving space."
    exit 1
  fi

  echo "Running: lvcreate -l ${root_extents} -i ${#lvm_parts[@]} -I 64 -n root vg0"
  lvcreate -y -v -l "$root_extents" -n root vg0

  echo "=== Formatting filesystems ==="

  echo "Running: mkfs.vfat -F32 ${first_disk}1"
  mkfs.vfat -F32 "${first_disk}p1"

  echo "Running: mkfs.ext4 /dev/vg0/root"
  mkfs.ext4 /dev/vg0/root

  echo "Running: mkswap /dev/vg0/swap"
  mkswap /dev/vg0/swap

  echo "=== LVM Setup Complete ==="
}

# Mount filesystems after LVM setup
mount_filesystems() {
  local first_disk="$1"
  echo "Mounting root filesystem..."
  mount /dev/vg0/root /mnt

  echo "Mounting EFI partition..."
  mkdir -p /mnt/boot
  mount "${first_disk}p1" /mnt/boot

  echo "Preparing necessary directories..."
  mkdir -p /mnt/proc /mnt/sys /mnt/dev /mnt/run

  echo "Enabling swap..."
  swapon /dev/vg0/swap
}

# Install base system
install_base_system() {
  echo "Installing base system..."
  pacman-key --init
  pacman-key --populate archlinux
  pacstrap /mnt base linux lvm2 mkinitcpio grub efibootmgr sudo networkmanager linux-firmware
}

# Generate fstab
generate_fstab() {
  echo "Generating fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab
}

chroot_config() {
  echo "Entering chroot to configure system..."
  arch-chroot /mnt /bin/bash -c "
    set -euo pipefail

    systemctl enable NetworkManager.service

    # Lock root account to disable password login
    passwd -l root

    # Configure mkinitcpio for LVM support
    sed -i '/^HOOKS=/s/block filesystems/block lvm2 filesystems/' /etc/mkinitcpio.conf
    mkinitcpio -P

    # Install and configure GRUB bootloader for EFI
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
  "
}

# Final cleanup before reboot
cleanup_and_reboot() {
  echo "Unmounting filesystems..."
  swapoff /dev/vg0/swap
  umount -R /mnt
  echo "OS Installation complete. Ready to setup."
}


# Main flow
echo "Discovering SSDs..."
ssds=($(discover_ssds))
if [[ ${#ssds[@]} -lt 2 ]]; then
  echo "Need at least 2 SSDs for striped LVM."
  exit 1
fi

first_disk="${ssds[0]}"
other_disks=("${ssds[@]:1}")

partition_drives "$first_disk" "${other_disks[@]}"
setup_lvm "$first_disk" "${other_disks[@]}"


echo "LVM and swap setup complete."

mount_filesystems "$first_disk"
install_base_system
generate_fstab
chroot_config
#cleanup_and_reboot