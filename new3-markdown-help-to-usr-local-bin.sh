#!/bin/bash

# Check if glow is installed
if ! command -v glow >/dev/null 2>&1; then
    # Create the directory for keyrings if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings

    # Add the Charm keyring
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg

    # Add the Charm repository
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list

    # Update package lists and install glow
    sudo apt update && sudo apt install -y glow
fi

# Copy files matching 'h-*' from ./0-help to /usr/local/bin
for file in ./0-help/h-*; do
    if [ -f "$file" ]; then
        sudo cp -f "$file" /usr/local/bin/
    fi
done

echo "Markdown help files installed to /usr/local/bin/ (which is in \$PATH)"
echo "Type h- then press Tab twice to see available markdown help files."

# We use /usr/local/bin becasue it is a standard directory used for user-installed executable programs.
# By convention, /usr/local/bin is used to store programs that the system administrator installs
# locally (manually) rather than through the package manager. This helps keep these programs separate
# from those installed by the system package manager. Also, it is a common location across almost all
# Linux distributions, so is a portable and consistent location for these help files
# User Permissions: It provides a clear distinction between system-managed binaries in /usr/bin and
# /bin, and locally-managed binaries in /usr/local/bin. This ensures that local changes do not
# interfere with system-managed software.