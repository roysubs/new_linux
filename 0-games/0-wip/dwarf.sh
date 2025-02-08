#!/bin/bash

# Function to handle 32-bit library installation for Dwarf Fortress
install_32bit_libraries() {
    echo "Installing required 32-bit libraries..."

    # Step 1: Create directory for 32-bit libraries (if not exists)
    sudo mkdir -p /usr/lib32

    # Step 2: Install required 32-bit SDL libraries
    echo "Installing SDL libraries..."
    sudo apt-get install -y lib32-sdl1.2 lib32-sdl-image1.2 lib32-sdl-ttf2.0-0

    # Step 3: Install libgcc and related 32-bit libraries if necessary
    echo "Installing 32-bit libgcc libraries..."
    sudo apt-get install -y gcc-8-multilib g++-8-multilib libgcc1:i386 libstdc++6:i386

    echo "32-bit libraries installation complete!"
}

# Function to fix the 'Not found: /data/art/mouse.png' issue
fix_mouse_png_error() {
    echo "Fixing missing mouse.png error..."

    # Path to the Dwarf Fortress installation folder
    DF_PATH="/opt/dwarf_fortress"  # Modify to your actual DF path

    # Edit the mouse cursor file in the DF folder
    sudo sed -i 's/mouse.png/mouse.bmp/' "$DF_PATH/libs/Dwarf_Fortress"

    echo "Mouse cursor issue fixed!"
}

# Function to fix libGL error
fix_libgl_error() {
    echo "Fixing libGL error..."

    # Fix 1: Change PRINT_MODE in init.txt
    DF_INIT_PATH="$1"  # Path to the DF init.txt file (provide as argument)

    if [ ! -f "$DF_INIT_PATH" ]; then
        echo "init.txt file not found. Please provide the correct path."
        return 1
    fi

    # Modify PRINT_MODE to 2D modes or TEXT instead of OpenGL
    sudo sed -i 's/^PRINT_MODE=.*$/PRINT_MODE=TEXT/' "$DF_INIT_PATH"

    # Fix 2: Rename libgcc_s.so.1 to libgcc_s.so.1.bak to avoid conflicts
    sudo mv /usr/lib32/libgcc_s.so.1 /usr/lib32/libgcc_s.so.1.bak

    echo "libGL error fix completed!"
}

# Function to preload zlib for fixing PNG handling
preload_zlib() {
    echo "Preloading zlib to resolve PNG handling issues..."

    # Set LD_PRELOAD for 32-bit zlib
    export LD_PRELOAD=/usr/lib/libz.so.1

    echo "zlib preload completed!"
}

# Function to check and convert to BMP if PNG preload doesn't work
convert_png_to_bmp() {
    echo "Converting PNG to BMP..."

    DF_INIT_PATH="$1"  # Path to init.txt

    if [ ! -f "$DF_INIT_PATH" ]; then
        echo "init.txt file not found. Please provide the correct path."
        return 1
    fi

    # Change all PNG references to BMP in init.txt
    sudo sed -i 's/png/bmp/g' "$DF_INIT_PATH"

    echo "Conversion from PNG to BMP complete!"
}

# Main function that integrates all fixes
main() {
    # Path to your DF installation and init.txt
    DF_PATH="/opt/dwarf_fortress"  # Modify to your actual DF path
    DF_INIT_FILE="$DF_PATH/data/init/init.txt"  # Modify to the correct location of init.txt

    # Check if DF folder exists
    if [ ! -d "$DF_PATH" ]; then
        echo "Dwarf Fortress directory not found at $DF_PATH"
        exit 1
    fi

    # Install 32-bit libraries
    install_32bit_libraries

    # Fix the missing mouse cursor error
    fix_mouse_png_error

    # Fix libGL errors
    fix_libgl_error "$DF_INIT_FILE"

    # Optionally preload zlib
    preload_zlib

    # Optionally convert PNG to BMP if zlib preload doesn't work
    convert_png_to_bmp "$DF_INIT_FILE"

    echo "Dwarf Fortress setup completed successfully!"
}

# Call the main function
main

