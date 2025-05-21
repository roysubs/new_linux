#!/bin/bash

# Dwarf Fortress Classic Setup Script for Debian/Ubuntu-based Systems (Console Mode)
# Author: Roy Wiseman
# Date: 2025-05-10 (Revised)
#
# This script aims to set up Dwarf Fortress Classic (32-bit Linux version)
# to run in console (TEXT) mode on Debian or Ubuntu and derived distributions.
# It addresses common issues:
# 1. Missing 32-bit libraries.
# 2. Conflicts with bundled libraries (libstdc++.so.6, libgcc_s.so.1).
# 3. Ensuring the correct graphics mode (PRINT_MODE:TEXT).
# 4. Creating a wrapper script for easy launching from anywhere (fixing relative path issues).
# This version is designed to be more robust and idempotent.

# --- Configuration ---
# Path to your Dwarf Fortress installation folder
# IMPORTANT: Modify this variable to the actual path where you extracted DF.
DF_PATH="/opt/dwarf_fortress"

# Path to the Dwarf Fortress init.txt file
# This should be located within the 'data/init' subdirectory of your DF_PATH.
DF_INIT_FILE="$DF_PATH/data/init/init.txt"

# Path for the wrapper script/command link
WRAPPER_PATH="/usr/local/bin/dwarf"
# ---------------------

# --- Functions ---

# Function to handle 32-bit library installation
# Dwarf Fortress Classic is a 32-bit application, requiring 32-bit versions of system libraries.
install_32bit_libraries() {
    echo "--- Installing required 32-bit libraries ---"
    echo "Updating package lists..."
    sudo apt-get update

    echo "Installing 32-bit SDL, GCC, and standard libraries..."
    # --no-install-recommends prevents pulling in potentially unnecessary packages.
    if sudo apt-get install -y --no-install-recommends \
        libsdl1.2debian:i386 \
        libsdl-image1.2:i386 \
        libsdl-ttf2.0-0:i386 \
        gcc-multilib \
        g++-multilib \
        libgcc-s1:i386 \
        libstdc++6:i386 \
        libncurses5:i386 libtinfo5:i386; then # Explicitly include ncurses/tinfo
        echo "32-bit libraries installation complete!"
    else
        echo "Error installing 32-bit libraries. Please check package names/repositories."
        echo "DF may not run correctly without these libraries."
    fi
    echo ""
}

# Function to fix conflicts with bundled libraries
# Renames bundled libstdc++.so.6 and libgcc_s.so.1 if they exist and haven't been backed up.
fix_bundled_libraries() {
    echo "--- Fixing bundled library conflicts ---"
    local libstdc_bundled="$DF_PATH/libs/libstdc++.so.6"
    local libgcc_bundled="$DF_PATH/libs/libgcc_s.so.1"

    # Fix libstdc++.so.6 conflict (Idempotent)
    if [ -f "$libstdc_bundled" ]; then
        if [ ! -f "${libstdc_bundled}.backup" ]; then
            echo "Found bundled libstdc++.so.6 at $libstdc_bundled."
            echo "Renaming it to avoid conflicts..."
            if sudo mv -f "$libstdc_bundled" "${libstdc_bundled}.backup"; then
                echo "Renamed $libstdc_bundled successfully."
            else
                echo "Error renaming bundled libstdc++.so.6. Check permissions."
            fi
        else
            echo "Bundled libstdc++.so.6 already renamed to ${libstdc_bundled}.backup. No action needed."
            # Ensure the original is removed if backup exists but original somehow reappeared
            if [ -f "$libstdc_bundled" ]; then
                 echo "Warning: Bundled libstdc++.so.6 exists alongside its backup. Removing original."
                 sudo rm -f "$libstdc_bundled"
            fi
        fi
    else
        echo "Bundled libstdc++.so.6 not found at $libstdc_bundled. No action needed."
    fi

    # Fix libgcc_s.so.1 conflict (Idempotent)
    if [ -f "$libgcc_bundled" ]; then
        if [ ! -f "${libgcc_bundled}.backup" ]; then
            echo "Found bundled libgcc_s.so.1 at $libgcc_bundled."
            echo "Renaming it to avoid conflicts..."
             if sudo mv -f "$libgcc_bundled" "${libgcc_bundled}.backup"; then
                 echo "Renamed $libgcc_bundled successfully."
             else
                 echo "Error renaming bundled libgcc_s.so.1. Check permissions."
             fi
         else
             echo "Bundled libgcc_s.so.1 already renamed to ${libgcc_bundled}.backup. No action needed."
             # Ensure the original is removed if backup exists but original somehow reappeared
             if [ -f "$libgcc_bundled" ]; then
                  echo "Warning: Bundled libgcc_s.so.1 exists alongside its backup. Removing original."
                  sudo rm -f "$libgcc_bundled"
             fi
        fi
    else
        echo "Bundled libgcc_s.so.1 not found at $libgcc_bundled. No action needed."
    fi

    echo ""
}

# Function to ensure init.txt is valid and set to PRINT_MODE:TEXT
# Handles potentially corrupted init.txt files by restoring from backup or creating a new one.
fix_init_txt() {
    echo "--- Configuring init.txt for PRINT_MODE:TEXT ---"
    local init_backup="${DF_INIT_FILE}.full_backup" # Reference the known good backup

    # Check if init.txt is missing or looks corrupted (e.g., very small, indicating missing content)
    # A heuristic: check if file exists AND is smaller than a typical minimal init.txt (e.g., < 100 bytes)
    # or check for specific corruption patterns if known. For simplicity, let's prioritize the backup.
    if [ ! -f "$DF_INIT_FILE" ] || ! grep -q '\[PRINT_MODE:' "$DF_INIT_FILE"; then
         echo "init.txt is missing or does not contain a PRINT_MODE line."
         if [ -f "$init_backup" ]; then
              echo "Restoring init.txt from full backup: $init_backup"
              if sudo cp "$init_backup" "$DF_INIT_FILE"; then
                   echo "Restored init.txt successfully."
              else
                   echo "Error restoring init.txt from backup. Check permissions."
                   # Attempt to create minimal if restore fails
                   echo "Attempting to create a minimal init.txt instead."
                   if echo '[PRINT_MODE:TEXT]' | sudo tee "$DF_INIT_FILE" > /dev/null; then
                       echo "Created minimal init.txt."
                   else
                       echo "Fatal error: Cannot create or restore init.txt. Check permissions and disk space."
                       exit 1 # Exit if we can't even create a basic init.txt
                   fi
              fi
         else
              echo "init.txt missing/corrupt and no full backup found. Creating a minimal init.txt."
              if echo '[PRINT_MODE:TEXT]' | sudo tee "$DF_INIT_FILE" > /dev/null; then
                  echo "Created minimal init.txt."
              else
                  echo "Fatal error: Cannot create minimal init.txt. Check permissions and disk space."
                  exit 1 # Exit if we can't create minimal
              fi
         fi
    else
        echo "init.txt found. Ensuring PRINT_MODE is TEXT."
    fi

    # Now that we have a valid (or minimal) init.txt, ensure PRINT_MODE is TEXT
    # Use the robust sed command to find and replace the PRINT_MODE line.
    # This also handles cases where PRINT_MODE:TEXT might already be set.
    if sudo sed -i.bak 's/\[PRINT_MODE:.*\]/\[PRINT_MODE:TEXT\]/' "$DF_INIT_FILE"; then
        echo "PRINT_MODE set to TEXT successfully."
        echo "Original pre-sed init.txt backed up as ${DF_INIT_FILE}.bak."
    else
        echo "Error setting PRINT_MODE to TEXT using sed. Check permissions for $DF_INIT_FILE."
        echo "Attempting to proceed, but DF may not launch in text mode."
    fi

    # Optional: Set other common console-friendly options if they exist in the file
    # We'll use sed to modify them if the lines are present, without adding them if they aren't.
    echo "Setting recommended console-friendly options (if lines exist)..."
    sudo sed -i 's/\[SOUND:.*\]/\[SOUND:NO\]/' "$DF_INIT_FILE" 2>/dev/null || true # Ignore errors if line not found
    sudo sed -i 's/\[WINDOWED:.*\]/\[WINDOWED:NO\]/' "$DF_INIT_FILE" 2>/dev/null || true
    sudo sed -i 's/\[GRAPHICS:.*\]/\[GRAPHICS:NO\]/' "$DF_INIT_FILE" 2>/dev/null || true
    sudo sed -i 's/\[PARTIAL_PRINT_MODE:.*\]/\[PARTIAL_PRINT_MODE:NO\]/' "$DF_INIT_FILE" 2>/dev/null || true

    echo ""
}


# Function to create a wrapper script for easy launching
# Creates a script at WRAPPER_PATH that changes directory and executes DF.
create_wrapper_script() {
    echo "--- Creating 'dwarf' wrapper script ---"
    local wrapper_content="#!/bin/bash
# Wrapper script for Dwarf Fortress Classic
# Created by setup_dwarf_fortress.sh

# Define the path to the Dwarf Fortress installation
# This must match the DF_PATH variable in the setup script!
DF_PATH=\"$DF_PATH\"

# Check if the DF directory exists
if [ ! -d \"\$DF_PATH\" ]; then
  echo \"Error: Dwarf Fortress directory not found at \$DF_PATH.\"
  echo \"Please verify the DF_PATH inside the wrapper script ($WRAPPER_PATH).\"
  exit 1
fi

# Change to the Dwarf Fortress directory
cd \"\$DF_PATH\" || { echo \"Error: Could not change directory to \$DF_PATH. Check permissions.\"; exit 1; }

# Execute the Dwarf Fortress start script from within that directory
# Use 'exec' to replace the current process, which is slightly more efficient
# Pass any command-line arguments along (\$@)
exec ./df \"\$@\"
"

    # Use sudo tee to write to a system directory requiring root privileges.
    # The '-p' option with tee is not standard, use 'mkdir -p' separately if directory might not exist.
    # /usr/local/bin should exist on most Linux systems.
    echo "Writing wrapper script to $WRAPPER_PATH..."
    if echo "$wrapper_content" | sudo tee "$WRAPPER_PATH" > /dev/null; then # > /dev/null suppresses tee's standard output

        # Make the wrapper script executable
        if sudo chmod +x "$WRAPPER_PATH"; then
             echo "Wrapper script '$WRAPPER_PATH' created successfully."
             echo "You should now be able to run 'dwarf' from any terminal."
        else
             echo "Error making wrapper script executable ($WRAPPER_PATH)."
             echo "Please check permissions."
             return 1
        fi
    else
        echo "Error writing wrapper script to $WRAPPER_PATH."
        echo "Please check permissions for /usr/local/bin."
        return 1
    fi
    echo ""
    # Remove any old symbolic link if it exists at the wrapper path
    if [ -L "$WRAPPER_PATH" ]; then
        echo "Removing old symbolic link at $WRAPPER_PATH..."
        sudo rm -f "$WRAPPER_PATH"
    fi
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

    # Step 2: Fix conflicts with bundled libraries (libstdc++.so.6 and libgcc_s.so.1)
    # This resolves 'version CXXABI_1.3.x not found' and libgcc issues found via ldd.
    fix_bundled_libraries

    # Step 3: Ensure init.txt is valid and configured for PRINT_MODE:TEXT
    # This addresses the corrupted init.txt issue and ensures text mode.
    fix_init_txt

    # Step 4: Create a wrapper script for easy launching
    # This fixes the './libs/Dwarf_Fortress: not found' error by handling relative paths.
    create_wrapper_script

    echo "Setup complete! Check the output above for any errors or warnings."
    echo ""

    # Print the beginner's intro to Dwarf Fortress
    print_df_intro

    echo "To start playing, open a NEW terminal window (or run 'source ~/.bashrc' or equivalent)"
    echo "to ensure your PATH includes /usr/local/bin, and simply type 'dwarf'."
    echo "Good luck, and have fun losing!"
}

# Call the main function to start the setup process
main
