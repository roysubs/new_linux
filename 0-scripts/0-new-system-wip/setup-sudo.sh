#!/bin/bash

echo "This script effectively acts as 'sudo without sudo' by running"
echo "root commands using 'su' (the root password must be known of course)."
echo "When prompted for a password, the root password is required here."

# Get the current username
USERNAME=$(whoami)

# Run all root-required commands in a single `su` session
su - <<EOF
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
    groupadd sudo
    if [[ $? -eq 0 ]]; then
        echo "The 'sudo' group has been successfully created."
    else
        echo "Failed to create the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi

# Check if the '%sudo' line is already in the /etc/sudoers file
echo -e "\nChecking /etc/sudoers for 'sudo' group configuration..."
if ! grep -q '^%sudo\s*ALL=(ALL:ALL) ALL' /etc/sudoers; then
    echo -e "\n'%sudo' line not found in /etc/sudoers, adding it now..."
    echo '%sudo   ALL=(ALL:ALL) ALL' >> /etc/sudoers
    if [[ $? -eq 0 ]]; then
        echo "The '%sudo' line has been added successfully."
    else
        echo "Failed to add the '%sudo' line to /etc/sudoers. Exiting." >&2
        exit 1
    fi
else
    echo -e "\n'%sudo' line already exists in /etc/sudoers, skipping addition."
fi

# Remove duplicate %sudo line if present
echo -e "\nRemoving any duplicate '%sudo' lines from /etc/sudoers..."
grep -n "^%sudo\s*ALL=(ALL:ALL) ALL" /etc/sudoers | awk -F: 'NR > 1 {print \$1}' | xargs -I{} sed -i '{}d' /etc/sudoers

# Add the user to the 'sudo' group
if groups "$USERNAME" | grep -qw "sudo"; then
    echo "User '$USERNAME' is already a member of the 'sudo' group."
else
    echo "User '$USERNAME' is not a member of the 'sudo' group. Adding now..."
    /usr/sbin/usermod -aG sudo "$USERNAME"
    if [[ $? -eq 0 ]]; then
        echo "User '$USERNAME' has been added to the 'sudo' group."
    else
        echo "Failed to add user '$USERNAME' to the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi
EOF

echo -e "\nAll tasks are complete. Please log out and log back in for changes to take effect."

