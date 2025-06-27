#!/bin/bash

# Function to fetch and run a script from the repository
run_script() {
  baseurl="https://raw.githubusercontent.com/Kaffannen/ArchLaptop/kaffannen/scripts/"

  local filename="$1"
  local url="${baseurl}${filename}"

  if curl --fail --silent --show-error "$url" | bash; then
    echo "'$filename' executed successfully."
  else
    echo "Failed to fetch or execute '$filename'"
    exit 1
  fi
}