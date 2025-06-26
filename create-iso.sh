#!/usr/bin/env bash
set -euo pipefail

# Remove existing build artifacts
echo "Cleaning up old build directories..."
rm -rf work out

#Update releng directory
./install-scripts/releng-preparation.sh

# Run archiso
echo "Starting ISO build..."
mkarchiso -v -o /media/sf_ArchIsos .
