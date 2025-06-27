#!/usr/bin/env bash
set -euo pipefail

# Remove existing build artifacts
echo "Cleaning up old build directories..."
rm -rf work out

# Create backup copy of releng
cp -r ./releng releng-backup

# Update releng directory
./install-scripts/releng-management/prepare_releng.sh

# Run archiso to build ISO into /out
echo "Starting ISO build..."
# mkarchiso -v -o /media/sf_ArchIsos ./releng
mkarchiso -v -o out releng

# Restore original releng directory
rm -rf releng
mv releng-backup releng

# Delete work directory
rm -if work
