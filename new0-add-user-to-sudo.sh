#!/bin/bash

# Add current user to sudo group (without requiring sudo), and update /etc/sudoers

echo "This script acts as 'sudo without using sudo' by running root"
echo "commands using 'su -c' (the root password must be known of course)."
echo "Use the root password when prompted below."

# Get the current username
USERNAME=$(whoami)

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
    echo "Please use the root password in the below."
    su -c 'groupadd sudo'
    if [[ $? -eq 0 ]]; then
        echo "The 'sudo' group has been successfully created."
    else
        echo "Failed to create the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi

# Check if the '%sudo' line is already in the /etc/sudoers file
# The user running is not root and not in the sudo group so we have to
# use 'su -c' also to do the grep test on /etc/sudoers
echo -e "\nChecking /etc/sudoers for 'sudo' group configuration..."
echo "Please use the root password in the below."
if ! su -c "grep -q '^%sudo\s*ALL=(ALL:ALL) ALL' /etc/sudoers"; then
    echo -e "\n'%sudo' line not found in /etc/sudoers, adding it now..."
    echo "Please use the root password in the below."
    su -c "echo '%sudo   ALL=(ALL:ALL) ALL' >> /etc/sudoers"
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
echo "Please use the root password in the below."
su -c "grep -n \"^%sudo\s*ALL=(ALL:ALL) ALL\" /etc/sudoers | awk -F: 'NR > 1 {print \$1}' | xargs -I{} sed -i '{}d' /etc/sudoers"

# Check if the user is in the 'sudo' group
echo -e "\nChecking if user '$USERNAME' is a member of the 'sudo' group..."
if groups "$USERNAME" | grep -qw "sudo"; then
    echo "User '$USERNAME' is already a member of the 'sudo' group."
else
    echo "User '$USERNAME' is not a member of the 'sudo' group. Adding now..."
    echo "Please use the root password in the below."
    su -c "/usr/sbin/usermod -aG sudo '$USERNAME'"
    if [[ $? -eq 0 ]]; then
        echo "User '$USERNAME' has been added to the 'sudo' group."
        echo "Please log out and log back in for the changes to take effect."
    else
        echo "Failed to add user '$USERNAME' to the 'sudo' group. Exiting." >&2
        exit 1
    fi
fi

echo "
Configuration complete.
Remember that group membership changes normally only take effect in new sessions.
Restart the session to enable 'sudo' access.

The 'sudo' group exists and is configured in /etc/sudoers.
- The user '$USERNAME' has been added to the 'sudo' group (if they were not already a member).

Common group membership commands:
  sudo adduser bert --ingroup sudo  # Create user bert and add him to a group (sudo)
  sudo usermod -aG sudo bert        # Add an already-created user to a group (sudo)
  sudo gpasswd -d bert sudo         # Delete bert from a group (sudo)
  getent group sudo                 # View members of a group (sudo)
  members sudo                      # Alternative tool to view members of a group

If you encounter issues, ensure that the /etc/sudoers file has no syntax errors using 'sudo visudo'.
"
