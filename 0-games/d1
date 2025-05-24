#!/bin/bash

# --- Configuration ---
# Path to your Dwarf Fortress installation folder
DF_PATH="/opt/dwarf_fortress" # <-- MAKE SURE THIS IS YOUR CORRECT DF PATH!

# Path to the Dwarf Fortress init.txt file
DF_INIT_FILE="$DF_PATH/data/init/init.txt" # <-- MAKE SURE THIS IS THE CORRECT PATH TO init.txt!
# ---------------------

# Function to handle 32-bit library installation for Dwarf Fortress on Debian/Ubuntu-based systems
install_32bit_libraries() {
    echo "Installing required 32-bit libraries for Debian/Ubuntu..."

    # Update package list first
    sudo apt-get update

    # Install required 32-bit libraries
    # These are common names for SDL, GCC, and standard C++ libraries on Debian/Ubuntu
    # libsdl1.2debian is often the correct package name for sdl1.2:i386
    echo "Installing 32-bit SDL, GCC, and standard libraries..."
    sudo apt-get install -y \
        libsdl1.2debian:i386 \
        libsdl-image1.2:i386 \
        libsdl-ttf2.0-0:i386 \
        gcc-multilib \
        g++-multilib \
        libgcc-s1:i386 \
        libstdc++6:i386

    # Check if installation was successful
    if [ $? -eq 0 ]; then
        echo "32-bit libraries installation complete!"
    else
        echo "Error installing 32-bit libraries. Please check the package names and your repositories."
        echo "Attempting to continue with other fixes, but DF may not run without these."
    fi
}

# Function to fix potential graphics issues by setting PRINT_MODE to TEXT
fix_print_mode() {
    echo "Setting PRINT_MODE to TEXT in init.txt..."

    if [ ! -f "$DF_INIT_FILE" ]; then
        echo "Error: init.txt file not found at $DF_INIT_FILE."
        echo "Cannot set PRINT_MODE. Please verify the DF_INIT_FILE path."
        return 1
    fi

    # Modify PRINT_MODE to TEXT
    # Use a temporary file for safety during sed operation
    sudo sed -i.bak 's/^\[PRINT_MODE:.*\]$/\[PRINT_MODE:TEXT\]/' "$DF_INIT_FILE"

    # Check if sed command was successful (optional, but good practice)
    if [ $? -eq 0 ]; then
        echo "PRINT_MODE set to TEXT successfully. Original init.txt backed up as ${DF_INIT_FILE}.bak"
    else
        echo "Error modifying init.txt. Please check permissions and path."
    fi
}

# Main setup function
main() {
    echo "Starting Dwarf Fortress Classic setup for console mode..."

    # Check if DF folder exists
    if [ ! -d "$DF_PATH" ]; then
        echo "Error: Dwarf Fortress directory not found at $DF_PATH"
        echo "Please edit the script and set the correct DF_PATH."
        exit 1
    fi

    # Step 1: Install required 32-bit libraries
    install_32bit_libraries

    # Step 2: Fix graphics mode by setting PRINT_MODE to TEXT
    # This is crucial for console-only operation and avoids many graphics issues.
    fix_print_mode

    echo ""
    echo "Dwarf Fortress setup script finished."
    echo "Please check the output for any errors during library installation."
    echo ""
    echo "To run Dwarf Fortress, navigate to your DF directory and execute:"
    echo "cd \"$DF_PATH\""
    echo "./df"
    echo ""
    echo "If you encounter issues, verify your DF_PATH and DF_INIT_FILE in the script."
    echo "Also, ensure your system's repositories are configured correctly for 32-bit packages."
}

# Call the main function
main
