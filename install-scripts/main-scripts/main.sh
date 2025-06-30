#!/bin/bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load run-script utility for remote execution
source "$SCRIPT_DIR/run-script.sh"

# Full installation workflow
main() {
    echo "=== Kaffarch Full Installation Started ==="
    
    echo "Step 1: Configure drives and install base system..."
    run_script "configure-drives.sh"
    
    echo "Step 2: Configure OS and install desktop environment..."
    run_script "configure-os.sh"
    
    echo "=== Kaffarch Full Installation Completed ==="
}



# Command dispatcher
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        # No arguments, run main function
        main
    else
        # Check if function exists
        if declare -f "$1" > /dev/null; then
            # Function exists, call it with remaining arguments
            "$@"
        else
            echo "Error: Function '$1' not found"
            echo "Available functions: main"
            exit 1
        fi
    fi
fi