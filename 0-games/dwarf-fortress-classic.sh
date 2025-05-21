#!/bin/bash

# Dwarf Fortress Classic Setup Script for Debian/Ubuntu-based Systems (Console Mode)
# Author: Roy Wiseman
# Date: 2025-04-23
#
# This script aims to set up Dwarf Fortress Classic (32-bit Linux version)
# to run in console (TEXT) mode on Debian or Ubuntu and derived distributions.
# It addresses common issues like missing 32-bit libraries, library conflicts,
# and graphics mode configuration. It also creates a wrapper script for easy launching.

# --- Configuration ---
# Path to your Dwarf Fortress installation folder
# IMPORTANT: Modify this variable to the actual path where you extracted DF.
DF_PATH="/opt/dwarf_fortress"

# Path to the Dwarf Fortress init.txt file
# This should be located within the 'data/init' subdirectory of your DF_PATH.
DF_INIT_FILE="$DF_PATH/data/init/init.txt"
# ---------------------

# Function to handle 32-bit library installation
# Dwarf Fortress Classic is a 32-bit application, so it requires 32-bit versions
# of certain system libraries, even on a 64-bit Linux system.
install_32bit_libraries() {
    echo "--- Installing required 32-bit libraries ---"

    # First, update the package list to ensure we can find the latest package information.
    echo "Updating package lists..."
    sudo apt-get update

    # Install required 32-bit libraries for Debian/Ubuntu.
    # Package names often end with ':i386' to specify the 32-bit architecture.
    # - libsdl1.2debian:i386: Core SDL (Simple DirectMedia Layer) library for graphics/input.
    # - libsdl-image1.2:i386: SDL add-on for loading various image formats (like PNG, BMP).
    # - libsdl-ttf2.0-0:i32: SDL add-on for TrueType font rendering. NOTE: Corrected package name for ttf
    # - gcc-multilib, g++-multilib: Required to compile and link 32-bit applications or
    #   provide necessary 32-bit runtime components for existing binaries.
    # - libgcc-s1:i386, libstdc++6:i386: Standard GNU C and C++ runtime libraries.
    #   These provide fundamental functions needed by most C/C++ programs, including DF.
    echo "Installing 32-bit SDL, GCC, and standard libraries..."
    if sudo apt-get install -y \
        libsdl1.2debian:i386 \
        libsdl-image1.2:i386 \
        libsdl-ttf2.0-0:i386 \
        gcc-multilib \
        g++-multilib \
        libgcc-s1:i386 \
        libstdc++6:i386; then
        echo "32-bit libraries installation complete!"
    else
        echo "Error installing 32-bit libraries."
        echo "This is often due to incorrect package names for your specific distribution version,"
        echo "or issues with your system's repositories (e.g., missing 'multiverse' on Ubuntu)."
        echo "DF may not run correctly without these libraries."
        # Note: Script continues to attempt other fixes, but this is a critical step.
    fi
    echo "" # Add a blank line for readability
}

# Function to fix conflicts with bundled libraries
# Older software like DF sometimes includes its own copies of standard libraries
# (like libstdc++.so.6) within its installation directory (e.g., ./libs).
# This can cause conflicts with the newer, system-provided versions that other
# system libraries (like graphics drivers) might require.
# Renaming the bundled library forces the system to use the correct, installed version.
fix_bundled_libraries() {
    echo "--- Fixing bundled library conflicts ---"
    local bundled_lib="$DF_PATH/libs/libstdc++.so.6"

    if [ -f "$bundled_lib" ]; then
        echo "Found bundled libstdc++.so.6 at $bundled_lib."
        echo "Renaming it to avoid conflicts with the system library..."
        # Use sudo tee to write to the file as root, overcoming potential permission issues with standard redirection
        if sudo mv "$bundled_lib" "${bundled_lib}.backup"; then
            echo "Renamed $bundled_lib to ${bundled_lib}.backup successfully."
            echo "Dwarf Fortress will now use the system's libstdc++.so.6."
        else
            echo "Error renaming bundled libstdc++.so.6."
            echo "Please check permissions in the $DF_PATH/libs directory."
        fi
    else
        echo "Bundled libstdc++.so.6 not found at $bundled_lib. No action needed."
    fi
    echo "" # Add a blank line for readability
}


# Function to fix graphics mode by setting PRINT_MODE to TEXT
# Dwarf Fortress needs a way to render its display. In console mode, it uses
# simple text output. The 'PRINT_MODE:TEXT' setting in init.txt ensures DF
# attempts to use this mode instead of graphics modes (like 2D, SDL, OpenGL)
# which might fail on systems without a display or with specific driver issues.
fix_print_mode() {
    echo "--- Configuring PRINT_MODE to TEXT ---"

    if [ ! -f "$DF_INIT_FILE" ]; then
        echo "Error: init.txt file not found at $DF_INIT_FILE."
        echo "Cannot set PRINT_MODE. Please verify the DF_INIT_FILE path in the script configuration."
        # Note: Script continues, but this is a critical step for console mode.
        return 1
    fi

    echo "Modifying init.txt to set PRINT_MODE to TEXT..."
    # Use sed to find the line starting with [PRINT_MODE:...], and replace the
    # content within the brackets with [PRINT_MODE:TEXT]. This is more robust
    # than matching the entire line, avoiding issues with trailing whitespace etc.
    # The -i flag edits the file in-place. We create a .bak backup automatically.
    # Corrected the sed command based on previous troubleshooting.
    if sudo sed -i.bak 's/\[PRINT_MODE:.*\]/\[PRINT_MODE:TEXT\]/' "$DF_INIT_FILE"; then
        echo "PRINT_MODE set to TEXT successfully."
        echo "Original init.txt backed up as ${DF_INIT_FILE}.bak."
    else
        echo "Error modifying init.txt."
        echo "Please check file permissions for $DF_INIT_FILE."
    fi
    echo "" # Add a blank line for readability
}

# Function to create a wrapper script for easy launching
# Instead of a direct symlink (which breaks relative paths), we create a
# small script that changes directory and then runs the DF executable.
create_wrapper_script() {
    echo "--- Creating 'dwarf' wrapper script for easy launching ---"
    local wrapper_path="/usr/local/bin/dwarf"
    local target_exec="$DF_PATH/df"

    # Check if the target executable exists
    if [ ! -x "$target_exec" ]; then
        echo "Error: Dwarf Fortress executable not found or not executable at $target_exec."
        echo "Cannot create wrapper script."
        echo "Please verify the DF_PATH in the script configuration."
        # Note: Script continues, but the wrapper won't be created.
        return 1
    fi

    echo "Creating wrapper script at $wrapper_path..."

    # Write the content of the wrapper script directly to the file
    # Use sudo tee to write to a system directory requiring root privileges
    if echo "#!/bin/bash
# Wrapper script for Dwarf Fortress Classic
# Created by setup_dwarf_fortress.sh

# Define the path to the Dwarf Fortress installation
# This must match the DF_PATH variable in the setup script!
DF_PATH=\"$DF_PATH\"

# Check if the DF directory exists
if [ ! -d \"\$DF_PATH\" ]; then
  echo \"Error: Dwarf Fortress directory not found at \$DF_PATH.\"
  echo \"Please verify the DF_PATH inside the wrapper script (\$wrapper_path).\"
  exit 1
fi

# Change to the Dwarf Fortress directory
cd \"\$DF_PATH\" || { echo \"Error: Could not change directory to \$DF_PATH. Check permissions.\"; exit 1; }

# Execute the Dwarf Fortress start script from within that directory
# Use 'exec' to replace the current process, which is slightly more efficient
# Pass any command-line arguments along (\$@)
exec ./df \"\$@\"
" | sudo tee "$wrapper_path" > /dev/null; then # > /dev/null suppresses tee's standard output

        # Make the wrapper script executable
        if sudo chmod +x "$wrapper_path"; then
             echo "Wrapper script 'dwarf' created successfully in /usr/local/bin."
             echo "You should now be able to run 'dwarf' from any terminal."
        else
             echo "Error making wrapper script executable."
             echo "Please check permissions for $wrapper_path."
        fi
    else
        echo "Error writing wrapper script to $wrapper_path."
        echo "Please check permissions for /usr/local/bin."
    fi
    echo "" # Add a blank line for readability
}

# Function to print a basic Dwarf Fortress intro for beginners
print_df_intro() {
    echo "--- Welcome to Dwarf Fortress! ---"
    echo "You have successfully set up Dwarf Fortress Classic in console mode."
    echo "Prepare yourself for a complex, emergent simulation!"
    echo ""
    echo "The primary mode is **Fortress Mode** (usually started by default)."
    echo "Your objective: Lead a group of dwarves to establish a new home,"
    echo "dig deep into the mountains, build a thriving civilization, and"
    echo "ultimately, survive the many dangers that lurk above and below."
    echo ""
    echo "--- Basic Console Controls ---"
    echo "Most navigation uses the keyboard."
    echo ""
    echo "  Arrow Keys / Numpad (Num Lock OFF): Move cursor/view, navigate menus."
    echo "  Enter / Space: Select item, confirm action, unpause game."
    echo "  Esc: Go back in menus, cancel action, pause game."
    echo "  k: Look mode (examine terrain, objects, units)."
    echo "  v: View units (examine dwarves and others)."
    echo "  d: Designations (Dig, Mine, Chop trees, Channel, etc.) - Your primary tool for shaping the fort."
    echo "  b: Build menu (Construct workshops, furniture, defenses, etc.)"
    echo "  i: Inventory menu (View items on the map)."
    echo "  t: Tasks / Work Details (Assign labor to dwarves - CRITICAL for efficiency!)"
    echo "  m: Military menu (Manage squads, alerts, training)."
    echo "  u: Units screen (List all units, assign burrows)."
    echo "  z: Status/Stocks/Health (Check fort status, resources, health of units)."
    echo "  o: Orders menu (Set general fort orders - foraging, hunting, etc.)"
    echo "  p: Nobles/Labor (Manage nobles, civilian alerts, set labor preferences - advanced!)"
    echo ""
    echo "  +: Scroll lists down"
    echo "  -: Scroll lists up"
    echo "  *: Scroll lists right (or adjust numbers up)"
    echo "  /: Scroll lists left (or adjust numbers down)"
    echo ""
    echo "  Esc -> s: Save the game."
    echo "  Esc -> q: Quit the game."
    echo ""
    echo "Dwarf Fortress has a steep learning curve. Don't be afraid to consult"
    echo "the Dwarf Fortress Wiki (unofficial, but essential!) for detailed information."
    echo "Losing is Fun! Embrace the chaos!"
    echo ""
    echo "----------------------------"
}


# --- Main Function ---
main() {
    echo "Starting Dwarf Fortress Classic automated setup..."
    echo "Ensuring DF_PATH '$DF_PATH' exists and is correct is CRITICAL!"
    echo ""

    # Check if DF folder exists
    if [ ! -d "$DF_PATH" ]; then
        echo "Error: Dwarf Fortress directory not found at $DF_PATH"
        echo "Please edit this script and set the correct DF_PATH variable."
        exit 1 # Exit script if the main DF directory isn't found
    fi

    # Step 1: Install required 32-bit libraries
    # This is done first as later steps assume libraries are available.
    install_32bit_libraries

    # Step 2: Fix conflicts with bundled libraries (like libstdc++.so.6)
    # This resolves 'version CXXABI_1.3.x not found' errors.
    fix_bundled_libraries

    # Step 3: Configure PRINT_MODE to TEXT in init.txt
    # This is essential for console-only operation and avoids graphics errors.
    fix_print_mode

    # Step 4: Create a wrapper script for easy launching
    # This fixes the './libs/Dwarf_Fortress: not found' error when using the 'dwarf' command.
    create_wrapper_script

    echo "Setup complete! Check the output above for any errors or warnings."
    echo ""

    # Print the beginner's intro to Dwarf Fortress
    print_df_intro

    echo "To start playing, open a NEW terminal window (or run 'source ~/.bashrc' or equivalent)"
    echo "to ensure your PATH is updated, and simply type 'dwarf'."
    echo "Good luck, and have fun losing!"
}

# Call the main function to start the setup process
main
