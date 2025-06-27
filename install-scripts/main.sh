#!/bin/bash

set -euo pipefail
source ./run-script.sh

echo "Running scripts..."

run_script "configure-drives.sh"
run_script "configure-os.sh"