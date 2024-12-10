#!/bin/bash

# Need to fully log on as root one time until add
# the current user into the 'sudo' group

# Check if a username argument is provided
if [[ -z "$1" ]]; then
    echo -e "\nError: A valid username must be provided as a parameter. Exiting." >&2
    exit 1
fi

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\nError: This script must be run as root.\nTry 'su -' then rerun this script.\nExiting." >&2
    exit 1
fi
USERNAME="$1"

# # Must be run via sudo
# if [[ -z "$SUDO_USER" ]]; then
#     echo -e "\nError: This script must be run with sudo. Exiting." >&2
#     exit 1
# fi
# USERNAME="$SUDO_USER"

# Explain Debian's default behavior
echo -e "\nOn Debian systems:
- The root account is used for administrative tasks by default.
- The 'sudo' group is not always enabled by default.
- Some systems use the 'admin' group for sudo privileges."

# Check if the 'sudo' group exists
if getent group sudo &>/dev/null; then
    echo -e "\nThe 'sudo' group exists on your system."
else
    echo -e "\nThe 'sudo' group does not exist. Creating it now..."
    sudo groupadd sudo
    if [[ $? -eq 0 ]]; then
        echo "The 'sudo' group has been successfully created."
    else
        echo "Failed to create the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi

# Check if 'sudo' is enabled in /etc/sudoers
echo -e "\nChecking the /etc/sudoers file for 'sudo' group configuration..."
if sudo grep -q "^%sudo\s*ALL=(ALL:ALL) ALL" /etc/sudoers; then
    echo "The 'sudo' group is correctly configured in /etc/sudoers."
else
    echo "The 'sudo' group is not configured in /etc/sudoers. Fixing it now..."
    echo "%sudo   ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
    if [[ $? -eq 0 ]]; then
        echo "The 'sudo' group has been successfully configured in /etc/sudoers."
    else
        echo "Failed to configure the 'sudo' group in /etc/sudoers. Exiting." >&2
        exit 1
    fi
fi

# Check if the user is in the 'sudo' group
echo -e "\nChecking if user '$USERNAME' is a member of the 'sudo' group..."
if groups "$USERNAME" | grep -qw "sudo"; then
    echo "User '$USERNAME' is already a member of the 'sudo' group."
else
    echo "User '$USERNAME' is not a member of the 'sudo' group. Adding now..."
    sudo usermod -aG sudo "$USERNAME"
    if [[ $? -eq 0 ]]; then
        echo "User '$USERNAME' has been added to the 'sudo' group."
        echo "Please log out and log back in for the changes to take effect."
    else
        echo "Failed to add user '$USERNAME' to the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi

# Final advice
echo -e "\nConfiguration completed successfully."
echo -e "\nSummary:"
echo "- The 'sudo' group exists and is configured in /etc/sudoers."
echo "- The user '$USERNAME' has been added to the 'sudo' group (if they were not already a member)."
echo "- Please log out and log back in for group membership changes to take effect."

echo -e "\nCommon group membership commands:"
echo "  sudo usermod -aG <group_name> <username>   # Add a user to a group"
echo "  sudo usermod -aG sudo boss"
echo "  sudo gpasswd -d <username> <group_name>    # Delete a user from a group"
echo "  sudo gpasswd -d boss sudo"
echo "  getent group <group_name>                  # View members of a group"
echo "  getent group sudo"
echo "  members <group_name>                       # Alternative way to view members of a group"
echo "  members sudo"

echo -e "\nIf you encounter issues, ensure that the /etc/sudoers file has no syntax errors using 'sudo visudo'."

