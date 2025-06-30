#!/bin/bash

# Function to run a script locally or fetch from repository
run_script() {
    local script_name="$1"
    shift || true
    local script_args=("$@")
    
    # Check if script exists locally
    if [[ -f "./$script_name" ]]; then
        echo "Running local script: $script_name ${script_args[*]}"
        if bash "./$script_name" "${script_args[@]}"; then
            echo "'$script_name' executed successfully."
        else
            echo "Failed to execute local '$script_name'"
            exit 1
        fi
    else
        # Fallback to remote execution
        run_remote_script "$script_name" "${script_args[@]}"
    fi
}

# Function to fetch and run a script from the repository
run_remote_script() {
    local script_name="$1"
    shift || true
    local script_args=("$@")
    
    local baseurl="https://raw.githubusercontent.com/Kaffannen/ArchLaptop/kaffannen/scripts/"
    local url="${baseurl}${script_name}"
    
    echo "Fetching and running remote script: $script_name ${script_args[*]}"
    
    if curl --fail --silent --show-error "$url" | bash -s -- "${script_args[@]}"; then
        echo "'$script_name' executed successfully."
    else
        echo "Failed to fetch or execute remote '$script_name'"
        exit 1
    fi
}

# Function to list available local scripts
list_local_scripts() {
    echo "Available local scripts:"
    for script in *.sh; do
        if [[ -f "$script" && "$script" != "run-script.sh" ]]; then
            echo "  $script"
        fi
    done
}

# Function to test script connectivity
test_remote_connectivity() {
    local baseurl="https://raw.githubusercontent.com/Kaffannen/ArchLaptop/kaffannen/scripts/"
    
    echo "Testing connectivity to remote repository..."
    if curl --fail --silent --head "$baseurl" >/dev/null 2>&1; then
        echo "Remote repository is accessible."
        return 0
    else
        echo "Remote repository is not accessible."
        return 1
    fi
}

# Show available functions
show_functions() {
    echo "Available functions in run-script.sh:"
    echo "  run_script              - Run script locally or remotely [script] [args...]"
    echo "  run_remote_script       - Force run script from remote repository [script] [args...]"
    echo "  list_local_scripts      - List available local scripts"
    echo "  test_remote_connectivity - Test connection to remote repository"
    echo "  show_functions          - Show this help"
    echo ""
    echo "Usage: $0 [function_name] [arguments...]"
}

# Command dispatcher
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, not sourced
    if [[ $# -eq 0 ]]; then
        echo "Error: No function specified"
        show_functions
        exit 1
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