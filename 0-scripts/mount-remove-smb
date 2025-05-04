#!/bin/bash
# Discover SAMBA/CIFS disk shares from a server
# Input servername, username, and password as arguments
# - Samba is the software (on Linux/Unix) that implements the SMB/CIFS protocol.
# - SMB (Server Message Block) is the protocol family. CIFS (Common Internet File System) is a dialect of SMB, primarily used in older versions (like SMB1).
# - Modern usage often just says "SMB share" to be protocol-neutral and up-to-date, especially since CIFS is considered legacy.
# - mount.cifs is the name of the userspace mount helper for SMB shares, and despite its name, it supports modern SMB dialects (SMB2, SMB3), not just CIFS (SMB1).
#   The underlying kernel module is also called cifs.ko, even though it speaks newer SMB dialects.
# TROUBLESHOOTING WINDOWS:
# If your main Windows account is a Microsoft account (i.e. "someusername@hotmail.com", truncated to 5-char "someu" in Windows):
# - Make sure File and Printer Sharing is enabled on Windows
#     Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
# - It might be possible to connect from Linux with the below, but these are both unlikely (various other settings have to be in place)
#     smbclient -L servername -U "servername\\someusername@hotmail.com"   # Note \\ to escape the \ in bash
#     smbclient -L servername -U "someusername@hotmail.com%password"
#   It's usually best to create a separate user and use that for sharing:   net user smbuser mypass
#     sudo mount -t cifs //white/d /mnt/test -o user=boss,vers=3.0   # Remember that /mnt/test folder must exist before running this
# Check the share's permissions: Right-click the shared folder → Properties → Sharing → Advanced Sharing → Permissions.
# https://chatgpt.com/share/6816ee6d-a774-8006-a7eb-9876f8142547

# --- Adjust PATH to include sbin directories ---
# This helps find commands like mount.cifs that might not be in a user's default PATH
PATH="/sbin:/usr/sbin:$PATH"

# --- Input Variables ---
SERVER_NAME="$1"
USERNAME="$2"
PASSWORD="$3"

# Set the base directory where shares will be mounted
BASE_MOUNT_DIR="/mnt/$SERVER_NAME"

# --- Basic Input Validation ---
if [ $# -ne 3 ]; then
  echo "Discover non-admin SMB shares available from a server and mount them at /mnt/server_name/sharename"
  echo "Usage:   $(basename $0) <server_name> <username> <password>"
  echo "Example: $(basename $0) HPENVY boss YourPassword123"
  echo 
  exit 1
fi

# WARNING: Storing password directly in script arguments/variables is INSECURE for persistent use.
# Consider using a credentials file (see previous explanation) for better security,
# or configure smbclient/mount.cifs to read credentials from a secure location.
echo "Warning: Using password directly in arguments is insecure. Use credentials file for production."


# --- Prerequisite Checks ---
# Ensure cifs-utils is installed (provides mount.cifs)
# Now checks the adjusted PATH
if ! command -v mount.cifs &> /dev/null; then
    echo "Error: mount.cifs command not found even after adjusting PATH."
    echo "Please ensure cifs-utils package is correctly installed."
    exit 1
fi

# Ensure smbclient is installed
# smbclient is typically in /usr/bin, which is usually in the default PATH, but checking is good.
if ! command -v smbclient &> /dev/null; then
    echo "Error: smbclient command not found."
    echo "Please install it: sudo apt update && sudo apt install smbclient"
    exit 1
fi

# --- Find Shares ---
echo "Listing shares on $SERVER_NAME for user $USERNAME..."

# Use smbclient to list shares (-L), provide username and password directly
# Redirect stderr to /dev/null to suppress potential smbclient errors/warnings
# Use awk to filter lines: Type is "Disk", share name is not "IPC$", and share name does not end with "$"
echo "smbclient -L //\"$SERVER_NAME\" -U \"$USERNAME%$PASSWORD\" 2>/dev/null | awk '\$2 == \"Disk\" && \$1 != \"IPC$\" && \$1 !~ /\$$/ { print \$1 }')"
SHARE_LIST=$(smbclient -L //"$SERVER_NAME" -U "$USERNAME%$PASSWORD" 2>/dev/null | \
             awk '$2 == "Disk" && $1 != "IPC$" && $1 !~ /\$$/ { print $1 }')

# --- Check if any mountable shares were found ---
if [ -z "$SHARE_LIST" ]; then
  echo "No non-admin Disk shares found on $SERVER_NAME or failed to list shares with provided credentials."
  echo "Check server name, username, password, network connectivity, and Windows share permissions."
  exit 1
fi

# --- Prepare Base Mount Directory ---
echo "Ensuring base mount directory exists: $BASE_MOUNT_DIR"
# Use || { ...; exit 1; } for robust error handling on mkdir
sudo mkdir -p "$BASE_MOUNT_DIR" || { echo "Error creating base directory '$BASE_MOUNT_DIR'. Exiting."; exit 1; }


# --- List Found Shares ---
echo "-------------------------"
echo "Found mountable shares:"
# Convert the list to a readable format by adding a dash before each share name
echo "$SHARE_LIST" | sed 's/^/- /'
echo "-------------------------"


# --- Mount Shares ---
echo "Proceeding to process and mount shares under $BASE_MOUNT_DIR..."

# Arrays to track results for the summary
MOUNTED_SHARES=()
SKIPPED_SHARES=()
FAILED_MOUNTS=()

# Read the share list line by line
# 'while IFS= read -r' is the robust way to loop through a string containing newlines
while IFS= read -r SHARE_NAME; do
  # --- Clean Share Name ---
  # Replace characters not typically valid in Linux filenames (and spaces) with underscores.
  # Characters: \ / : * ? " < > | and space
  CLEAN_SHARE_NAME=$(echo "$SHARE_NAME" | sed 's/[\\/:*?"<>| ]/_/g')

  # Define the full local mount point path for this specific share
  MOUNT_POINT="$BASE_MOUNT_DIR/$CLEAN_SHARE_NAME"

  echo "--> Processing share: '${SHARE_NAME}' (Local path target: '${MOUNT_POINT}')"

  # --- Check if Local Mount Point Exists ---
  if [ -d "$MOUNT_POINT" ]; then
    echo "--> Skipping '${SHARE_NAME}': Mount point directory '${MOUNT_POINT}' already exists."
    SKIPPED_SHARES+=("${SHARE_NAME}") # Add original name to skipped list
    continue # Skip to the next share
  fi

  # --- Create Mount Point Directory ---
  echo "--> Creating mount point directory: ${MOUNT_POINT}"
  sudo mkdir -p "$MOUNT_POINT"
  # Check if directory creation was successful
  if [ $? -ne 0 ]; then
    echo "--> Error: Could not create mount point directory $MOUNT_POINT. Skipping ${SHARE_NAME}."
    FAILED_MOUNTS+=("${SHARE_NAME} (Mkdir Failed)") # Add original name to failed list
    continue # Skip to the next share
  fi

  # --- Attempt to Mount ---
  echo "--> Attempting to mount //${SERVER_NAME}/${SHARE_NAME} to ${MOUNT_POINT}..."
  # Mount the share using cifs, providing path, mount point, and options:
  # username/password, and setting ownership (uid/gid) to the current user
  sudo mount -t cifs //"$SERVER_NAME"/"$SHARE_NAME" "$MOUNT_POINT" \
    -o username="$USERNAME",password="$PASSWORD",uid=$(id -u),gid=$(id -g)

  # Check if the mount command was successful
  if [ $? -eq 0 ]; then
    echo "--> Successfully mounted '${SHARE_NAME}'."
    MOUNTED_SHARES+=("${SHARE_NAME}") # Add to mounted list
  else
    echo "--> Error mounting '${SHARE_NAME}' to '${MOUNT_POINT}'."
    echo "    Check network connectivity, credentials, or Windows share permissions."
    FAILED_MOUNTS+=("${SHARE_NAME} (Mount Failed)") # Add to failed list
  fi

done <<< "$SHARE_LIST" # Use process substitution to feed SHARE_LIST line by line into the loop

echo "--- Mounting Process Complete ---"

# --- Summary ---
echo "Summary of Operations:"
echo "---------------------------------"

if [ ${#SKIPPED_SHARES[@]} -gt 0 ]; then
  echo "Skipped Shares (Mount point directory existed):"
  for s in "${SKIPPED_SHARES[@]}"; do echo " - $s"; done
  echo "---------------------------------"
fi

if [ ${#FAILED_MOUNTS[@]} -gt 0 ]; then
  echo "Failed Shares (Errors during mkdir or mount):"
  for s in "${FAILED_MOUNTS[@]}"; do echo " - $s"; done
  echo "---------------------------------"
fi

if [ ${#MOUNTED_SHARES[@]} -gt 0 ]; then
  echo "Successfully Mounted Shares:"
  for s in "${MOUNTED_SHARES[@]}"; do echo " - $s"; done
else
  echo "No shares were successfully mounted."
fi
echo "---------------------------------"

