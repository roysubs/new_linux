#!/bin/bash

check_and_install_packages() {
    local packages=("$@"); local failed=false
    echo "Checking for required packages..."
    for pkg in "${packages[@]}"; do
        echo -n "Checking for '$pkg'... "
        if command -v "$pkg" &> /dev/null; then
            echo "Found."
        elif command -v apt &> /dev/null; then
            echo "Not found. Attempting install with apt..."
            if sudo apt update > /dev/null 2>&1 && sudo apt install -y "$pkg" > /dev/null 2>&1; then
                echo "Installed successfully."
            else
                echo "Failed to install. Please install '$pkg' manually."
                failed=true
            fi
        else
            echo "Not found, and apt not available. Please install '$pkg' manually."
            failed=true
        fi
    done
    if [ "$failed" = true ]; then
        echo "One or more required packages are missing or failed to install. Exiting."
        exit 1
    else
        echo "All required packages are present."
    fi
}

# --- Example Usage ---
# Define the array of required packages
required_packages=("ffmpeg" "yt-dlp") # Add or remove packages as needed

# Call the function with the array
check_and_install_packages "${required_packages[@]}"

# If the script reaches here, all packages were found or installed successfully
echo "Script can now proceed."

# Add the rest of your script logic here...

