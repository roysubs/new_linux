#!/bin/bash

# Collect the array definition between `declare -A packages=(` and `)`
array_definition=$(awk '/declare -A packages=\(/ {capture=1} capture {print} /^\)$/ {capture=0}' ~/new-6-essential-tools.sh)

# Verify if the array definition was successfully captured
if [[ -n "$array_definition" ]]; then
    echo "Extracted array definition successfully."
    echo "$array_definition" # Debugging output

    # Remove null bytes if any
    array_definition=$(echo "$array_definition" | tr -d '\0')

    # Evaluate the array definition
    eval "$array_definition" || { echo "Failed to evaluate array definition."; exit 1; }
else
    echo "Failed to extract associative array from the script."
    exit 1
fi

# Check if the array is loaded correctly
if [[ ${#packages[@]} -eq 0 ]]; then
    echo "Array is empty or not loaded correctly."
    exit 1
fi

# Variables for total install size
total_install_size=0

# Loop through each package and get the install size
for package in "${!packages[@]}"; do
    echo "Package: $package"

    # Get package information using apt show
    package_info=$(apt show "$package" 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Extract install size
        install_size=$(echo "$package_info" | grep -i "Installed-Size" | awk '{print $2}')

        # Handle missing install size
        if [ -z "$install_size" ]; then
            install_size="N/A"
            install_size_bytes=0
        else
            install_size_bytes=$(echo "$install_size" | sed 's/[^0-9]*//g')
        fi

        # Show sizes
        echo "  Estimated install size: $install_size KB"

        # Update total install size
        total_install_size=$((total_install_size + install_size_bytes))
    else
        echo "  Package $package not found or could not be retrieved."
    fi

    echo ""
done

# Convert total size to MB for better readability
total_install_size_mb=$(echo "scale=2; $total_install_size / 1024" | bc)

# Show total install size
echo "Total estimated install size: $total_install_size_mb MB"

