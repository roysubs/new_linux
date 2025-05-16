#!/bin/bash

# create-share-smb.sh: Script to create a Samba share

# --- Configuration ---
SAMBA_CONF="/etc/samba/smb.conf"
SAMBA_USER_DB="/var/lib/samba/private/passdb.tdb" # Common location, might vary

# --- Functions ---

# Function to check if a package is installed
package_installed() {
  dpkg -s "$1" &> /dev/null || rpm -q "$1" &> /dev/null
}

# Function to install Samba
install_samba() {
  echo "Samba not found. Attempting to install..."
  if [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt install -y samba samba-common-bin acl
  elif [ -f /etc/redhat-release ]; then
    sudo yum clean all && sudo yum install -y samba samba-common samba-client
  else
    echo "Unsupported distribution. Please install Samba manually."
    exit 1
  fi
  if [ $? -eq 0 ]; then
    echo "Samba installed successfully."
  else
    echo "Failed to install Samba. Please install it manually."
    exit 1
  fi
}

# Function to add a Samba user
add_samba_user() {
  local user="$1"
  # Check if the system user exists
  if ! id "$user" &> /dev/null; then
    echo "System user '$user' does not exist. Please create it first."
    exit 1
  fi
  echo "Adding Samba user '$user'."
  sudo smbpasswd -a "$user"
  if [ $? -eq 0 ]; then
    echo "Samba user '$user' added."
  else
    echo "Failed to add Samba user '$user'. Aborting."
    exit 1
  fi
}

# Function to configure the Samba share
configure_share() {
  local share_name="$1"
  local share_path="$2"
  local writable="$3"
  local guest_ok="$4"
  local valid_users="$5"

  echo "Configuring Samba share '$share_name' for path '$share_path'."

  # Ensure the directory exists
  if [ ! -d "$share_path" ]; then
    echo "Creating directory '$share_path'."
    sudo mkdir -p "$share_path"
    if [ $? -ne 0 ]; then
      echo "Failed to create directory '$share_path'. Aborting."
      exit 1
    fi
  fi

  # Set appropriate permissions (adjust as needed for your use case)
  # This example gives ownership to nobody:nogroup for simplicity with guest access,
  # or the user for authenticated access. You might need more granular permissions.
  if [ "$guest_ok" = "yes" ]; then
    sudo chown -R nobody:nogroup "$share_path"
    sudo chmod -R 0777 "$share_path" # Be cautious with 777 in production
  elif [ -n "$valid_users" ]; then
    # Assuming the first user in the list will own the directory for simplicity
    local owner_user=$(echo "$valid_users" | cut -d',' -f1)
    if id "$owner_user" &> /dev/null; then
      sudo chown -R "$owner_user":"$owner_user" "$share_path"
      sudo chmod -R 0770 "$share_path"
    else
      echo "Warning: Owner user '$owner_user' not found. Directory permissions may need manual adjustment."
       sudo chmod -R 0770 "$share_path" # Still set restrictive permissions initially
    fi
  else
     sudo chmod -R 0700 "$share_path" # Default to restrictive if no guest and no users
  fi


  # Add the share definition to smb.conf
  echo "" | sudo tee -a "$SAMBA_CONF"
  echo "[$share_name]" | sudo tee -a "$SAMBA_CONF"
  echo "  comment = Samba share for $share_path" | sudo tee -a "$SAMBA_CONF"
  echo "  path = $share_path" | sudo tee -a "$SAMBA_CONF"
  echo "  browseable = yes" | sudo tee -a "$SAMBA_CONF"

  if [ "$writable" = "yes" ]; then
    echo "  read only = no" | sudo tee -a "$SAMBA_CONF"
    echo "  writable = yes" | sudo tee -a "$SAMBA_CONF"
  else
    echo "  read only = yes" | sudo tee -a "$SAMBA_CONF"
    echo "  writable = no" | sudo tee -a "$SAMBA_CONF"
  fi

  if [ "$guest_ok" = "yes" ]; then
    echo "  guest ok = yes" | sudo tee -a "$SAMBA_CONF"
  else
    echo "  guest ok = no" | sudo tee -a "$SAMBA_CONF"
  fi

  if [ -n "$valid_users" ]; then
    echo "  valid users = $valid_users" | sudo tee -a "$SAMBA_CONF"
  fi

  echo "Samba configuration for '$share_name' added to $SAMBA_CONF."
}

# Function to test Samba configuration
test_samba_config() {
  echo "Testing Samba configuration..."
  testparm -s "$SAMBA_CONF"
  if [ $? -eq 0 ]; then
    echo "Samba configuration is OK."
  else
    echo "Samba configuration has errors. Please check $SAMBA_CONF."
    exit 1
  fi
}

# Function to restart Samba service
restart_samba() {
  echo "Restarting Samba service..."
  if systemctl is-active smbd &> /dev/null; then
    sudo systemctl restart smbd nmbd
  elif service smbd status &> /dev/null; then
    sudo service smbd restart && sudo service nmbd restart
  else
    echo "Could not determine Samba service name or status. Please restart Samba manually."
    exit 1
  fi

  if [ $? -eq 0 ]; then
    echo "Samba service restarted successfully."
  else
    echo "Failed to restart Samba service. Please restart it manually."
    exit 1
  fi
}

# --- Main Script ---

# Parse command-line options
SHARE_PATH=""
SHARE_NAME=""
WRITABLE="no"
GUEST_OK="no"
VALID_USERS=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--path) SHARE_PATH="$2"; shift ;;
        -n|--name) SHARE_NAME="$2"; shift ;;
        -w|--writable) WRITABLE="yes" ;;
        -g|--guest) GUEST_OK="yes" ;;
        -u|--users) VALID_USERS="$2"; shift ;;
        -h|--help)
            echo "Usage: create-share-smb.sh [OPTIONS]"
            echo "Options:"
            echo "  -p, --path <path>     : Absolute path to the directory to share (required)"
            echo "  -n, --name <name>     : Name of the Samba share (defaults to the last part of the path)"
            echo "  -w, --writable        : Allow writing to the share (default is read-only)"
            echo "  -g, --guest           : Allow guest access without a password"
            echo "  -u, --users <user1,user2,...>: Comma-separated list of valid users for authenticated access"
            echo "  -h, --help            : Show this help message"
            exit 0
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate required options
if [ -z "$SHARE_PATH" ]; then
  echo "Error: Share path is required. Use -p or --path."
  exit 1
fi

# Set default share name if not provided
if [ -z "$SHARE_NAME" ]; then
  SHARE_NAME=$(basename "$SHARE_PATH")
  echo "Share name not provided, using '$SHARE_NAME' derived from the path."
fi

# Check for conflicting options
if [ "$GUEST_OK" = "yes" ] && [ -n "$VALID_USERS" ]; then
  echo "Error: Cannot have both guest access and valid users defined. Choose one or the other."
  exit 1
fi

# Check if Samba is installed, install if not
if ! package_installed samba; then
  install_samba
fi

# Add Samba users if specified
if [ -n "$VALID_USERS" ]; then
  IFS=',' read -ra USERS_ARRAY <<< "$VALID_USERS"
  for user in "${USERS_ARRAY[@]}"; do
    add_samba_user "$user"
  done
fi

# Configure the share in smb.conf
configure_share "$SHARE_NAME" "$SHARE_PATH" "$WRITABLE" "$GUEST_OK" "$VALID_USERS"

# Test the Samba configuration
test_samba_config

# Restart Samba service
restart_samba

echo "Samba share '$SHARE_NAME' at path '$SHARE_PATH' created and configured."
echo "You should now be able to connect from a remote system."
if [ "$GUEST_OK" = "yes" ]; then
  echo "Access is allowed for guests."
elif [ -n "$VALID_USERS" ]; then
  echo "Access is restricted to users: $VALID_USERS."
fi
echo "Remember to configure your firewall to allow Samba traffic (usually UDP/137, UDP/138, TCP/139, TCP/445)."

exit 0
