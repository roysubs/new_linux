#!/bin/bash

# create-share-smb.sh: Enhanced script to create a Samba share step-by-step

# --- Configuration ---
SAMBA_CONF="/etc/samba/smb.conf"
LOG_FILE="$HOME/.config/create-share-smb.log"
CONFIG_DIR=$(dirname "$LOG_FILE")

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
ASSUME_YES="no" # Default, can be overridden by -y

# --- Helper Functions ---

# Ensure config directory exists for the log file
mkdir -p "$CONFIG_DIR" || { echo -e "${RED}ERROR: Could not create log directory $CONFIG_DIR. Aborting.${NC}"; exit 1; }

# Initialize log file with script start time
echo "----------------------------------------------------------------------" >> "$LOG_FILE"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] --- Script execution started ---" >> "$LOG_FILE"
echo "----------------------------------------------------------------------" >> "$LOG_FILE"


# Function to print a message to console and log it
log_message() {
    local type="$1" # e.g., INFO, WARN, ERROR, STEP
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color=$BLUE # Default for INFO

    case "$type" in
        STEP) color=$YELLOW ;;
        WARN) color=$YELLOW ;;
        ERROR) color=$RED ;;
        SUCCESS) color=$GREEN ;;
    esac

    echo -e "${color}${type}:${NC} $message"
    echo "[$timestamp] ${type}: $message" >> "$LOG_FILE"
}

# Function to print a command to be executed, and log its intent.
# The actual execution happens separately.
log_command_intent() {
    local cmd_string="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}COMMAND INTENT:${NC} $cmd_string"
    echo "[$timestamp] COMMAND_INTENT: $cmd_string" >> "$LOG_FILE"
}

# Function to log actual execution of a command (use after log_command_intent if needed)
log_command_execution() {
    local cmd_string="$1"
    local exit_code="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$exit_code" -eq 0 ]; then
        echo "[$timestamp] EXECUTED_SUCCESS: $cmd_string (Exit Code: $exit_code)" >> "$LOG_FILE"
    else
        echo "[$timestamp] EXECUTED_FAILURE: $cmd_string (Exit Code: $exit_code)" >> "$LOG_FILE"
    fi
}


# Function to ask a yes/no question
# Returns 0 for yes, 1 for no.
ask_yes_no() {
    local question="$1"
    if [ "$ASSUME_YES" = "yes" ]; then
        log_message "INFO" "Assuming 'yes' due to -y flag for: $question"
        return 0
    fi
    while true; do
        read -p "$(echo -e "${YELLOW}PROMPT:${NC} $question (y/n): ")" -n 1 -r REPLY
        echo "" # Newline
        log_message "USER_INPUT" "Prompt: '$question' User replied: '$REPLY'"
        case $REPLY in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo -e "${RED}Please answer yes (y) or no (n).${NC}";;
        esac
    done
}

# Function to check if a package is installed
package_installed() {
 dpkg -s "$1" &> /dev/null || rpm -q "$1" &> /dev/null
}

# Function to install Samba
install_samba() {
    log_message "STEP" "Checking and installing Samba packages..."
    if package_installed samba; then
        log_message "INFO" "Samba appears to be already installed."
        return 0
    fi

    log_message "INFO" "Samba not found."
    if ask_yes_no "Samba is not installed. Do you want to install it now?"; then
        if [ -f /etc/debian_version ]; then
            log_message "INFO" "Detected Debian/Ubuntu based system."
            log_command_intent "sudo apt update"
            sudo apt update
            local exit_code=$?
            log_command_execution "sudo apt update" $exit_code
            if [ $exit_code -ne 0 ]; then log_message "ERROR" "'sudo apt update' failed. Please check your package manager."; return 1; fi

            log_command_intent "sudo apt install -y samba samba-common-bin acl"
            sudo apt install -y samba samba-common-bin acl
            exit_code=$?
            log_command_execution "sudo apt install -y samba samba-common-bin acl" $exit_code
        elif [ -f /etc/redhat-release ]; then
            log_message "INFO" "Detected Red Hat/CentOS/Fedora based system."
            log_command_intent "sudo yum clean all"
            sudo yum clean all
            local exit_code=$?
            log_command_execution "sudo yum clean all" $exit_code # yum clean all might not be critical to fail script

            log_command_intent "sudo yum install -y samba samba-common samba-client"
            sudo yum install -y samba samba-common samba-client
            exit_code=$?
            log_command_execution "sudo yum install -y samba samba-common samba-client" $exit_code
        else
            log_message "ERROR" "Unsupported distribution. Please install Samba manually."
            return 1
        fi

        if [ $exit_code -eq 0 ]; then
            log_message "SUCCESS" "Samba installed successfully."
        else
            log_message "ERROR" "Failed to install Samba. Please install it manually."
            return 1
        fi
    else
        log_message "WARN" "Samba installation skipped by user. Samba is required to create a share."
        return 1
    fi
    return 0
}

# Function to check and manage Samba services (smbd, nmbd)
manage_samba_services() {
    log_message "STEP" "Checking Samba service status (smbd and nmbd)..."
    local services_ok=1
    for service in smbd nmbd; do
        log_message "INFO" "Checking status of $service service..."
        if systemctl list-units --type=service --state=active | grep -q "${service}.service"; then
            log_message "INFO" "$service service is active (running)."
            if ! systemctl is-enabled "${service}.service" &>/dev/null; then
                 log_message "WARN" "$service service is running but not enabled to start on boot."
                 if ask_yes_no "Enable $service to start on boot?"; then
                    log_command_intent "sudo systemctl enable $service"
                    sudo systemctl enable "$service"
                    log_command_execution "sudo systemctl enable $service" $?
                 fi
            else
                log_message "INFO" "$service service is enabled to start on boot."
            fi
        else # systemctl check failed or service not active
            log_message "WARN" "$service service does not appear to be active (running) via systemctl."
            # Fallback for older systems or different init systems if systemctl fails broadly
            if command -v service >/dev/null ; then
                log_command_intent "sudo service $service status"
                if sudo service "$service" status &>/dev/null; then
                    log_message "INFO" "$service service is active (running) via 'service' command."
                    # Cannot easily check 'enabled' status with 'service' command universally
                else
                    log_message "WARN" "$service service does not appear to be active (running) via 'service' command either."
                    services_ok=0
                fi
            else
                 services_ok=0 # If no service command, assume not running if systemctl failed
            fi

            if [ "$services_ok" -eq 0 ]; then
                if ask_yes_no "$service service is not running. Attempt to start and enable it?"; then
                    log_command_intent "sudo systemctl enable $service"
                    sudo systemctl enable "$service"
                    log_command_execution "sudo systemctl enable $service" $?

                    log_command_intent "sudo systemctl start $service"
                    sudo systemctl start "$service"
                    log_command_execution "sudo systemctl start $service" $?
                    
                    # Verify start
                    if systemctl is-active "${service}.service" &>/dev/null; then
                        log_message "SUCCESS" "$service started successfully."
                    else
                        log_message "ERROR" "Failed to start $service. Please check service logs."
                        return 1
                    fi
                else
                    log_message "WARN" "User chose not to start/enable $service. It is required for Samba functionality."
                    return 1
                fi
            fi
        fi
    done
    log_message "SUCCESS" "Samba services checked."
    return 0
}


# Function to check firewall status
check_firewall() {
    log_message "STEP" "Checking Firewall Status..."
    local firewall_action_needed=0
    local ufw_status=""
    local firewalld_status=""

    # Define Samba ports
    local samba_ports_tcp="139,445"
    local samba_ports_udp="137,138"
    log_message "INFO" "Samba requires TCP ports $samba_ports_tcp and UDP ports $samba_ports_udp to be open."

    if command -v ufw &> /dev/null; then
        log_command_intent "sudo ufw status verbose"
        ufw_status_output=$(sudo ufw status verbose)
        log_command_execution "sudo ufw status verbose" $?
        echo "$ufw_status_output" # Show full status to user

        ufw_status=$(echo "$ufw_status_output" | grep -i '^Status:' | awk '{print $2}')
        log_message "INFO" "UFW status: $ufw_status"

        if [[ "$ufw_status" == "active" ]]; then
            # Check for 'samba' profile or individual ports
            if echo "$ufw_status_output" | grep -qE 'ALLOW IN.*Samba|ALLOW IN.*samba' || \
               (echo "$ufw_status_output" | grep '137/udp' | grep -q 'ALLOW IN') && \
               (echo "$ufw_status_output" | grep '138/udp' | grep -q 'ALLOW IN') && \
               (echo "$ufw_status_output" | grep '139/tcp' | grep -q 'ALLOW IN') && \
               (echo "$ufw_status_output" | grep '445/tcp' | grep -q 'ALLOW IN'); then
                log_message "SUCCESS" "UFW is active and Samba ports/profile appear to be allowed."
            else
                log_message "WARN" "UFW is active, but Samba ports/profile might be blocked or not explicitly allowed."
                firewall_action_needed=1
            fi
        else
            log_message "INFO" "UFW is installed but not active. Traffic might be unrestricted or managed by another firewall."
        fi
    elif command -v firewall-cmd &> /dev/null; then
        log_command_intent "sudo systemctl is-active firewalld"
        firewalld_status=$(sudo systemctl is-active firewalld)
        log_command_execution "sudo systemctl is-active firewalld" $?
        log_message "INFO" "Firewalld status: $firewalld_status"

        if [[ "$firewalld_status" == "active" ]]; then
            log_message "INFO" "Checking firewalld rules for Samba..."
            log_command_intent "sudo firewall-cmd --list-all" # Shows current zone and services
            sudo firewall-cmd --list-all
            log_command_execution "sudo firewall-cmd --list-all" $?

            # Check if samba service is allowed in any active zone (common: public, trusted, home, work)
            # A more robust check might iterate through active zones. For simplicity, check for service directly.
            log_command_intent "sudo firewall-cmd --query-service=samba --permanent"
            if sudo firewall-cmd --query-service=samba --permanent &> /dev/null; then
                 log_message "SUCCESS" "Firewalld is active and Samba service appears to be permanently allowed in a zone."
                 log_message "INFO" "Note: Ensure the zone where Samba is allowed is applied to your active network interface(s)."
            else
                 log_message "WARN" "Firewalld is active, but Samba service is not listed as permanently allowed."
                 firewall_action_needed=1
            fi
        else
            log_message "INFO" "Firewalld is installed but not active. Traffic might be unrestricted or managed by another firewall."
        fi
    else
        log_message "INFO" "Neither UFW nor Firewalld found. Firewall rules might be managed directly by iptables/nftables."
        log_message "WARN" "Please manually verify your iptables/nftables rules."
        log_command_intent "sudo iptables -L -v -n" # Show current iptables rules
        sudo iptables -L -v -n
        log_command_execution "sudo iptables -L -v -n" $?
        log_command_intent "sudo nft list ruleset" # Show current nftables rules
        sudo nft list ruleset
        log_command_execution "sudo nft list ruleset" $?
    fi

    if [ "$firewall_action_needed" -eq 1 ]; then
        if ask_yes_no "Samba ports/service may be blocked. Would you like the script to attempt to open them?"; then
            if command -v ufw &> /dev/null && [[ "$ufw_status" == "active" ]]; then
                log_message "INFO" "Attempting to allow Samba through UFW..."
                log_command_intent "sudo ufw allow samba"
                sudo ufw allow samba
                log_command_execution "sudo ufw allow samba" $?
                log_command_intent "sudo ufw reload"
                sudo ufw reload
                log_command_execution "sudo ufw reload" $?
                log_message "INFO" "UFW rules updated. Verifying..."
                log_command_intent "sudo ufw status verbose"
                sudo ufw status verbose
            elif command -v firewall-cmd &> /dev/null && [[ "$firewalld_status" == "active" ]]; then
                log_message "INFO" "Attempting to allow Samba service through Firewalld (permanently, in public zone)..."
                # Add to public zone by default. User might need to adjust if using a different zone.
                log_command_intent "sudo firewall-cmd --permanent --add-service=samba --zone=public"
                sudo firewall-cmd --permanent --add-service=samba --zone=public
                log_command_execution "sudo firewall-cmd --permanent --add-service=samba --zone=public" $?
                log_command_intent "sudo firewall-cmd --reload"
                sudo firewall-cmd --reload
                log_command_execution "sudo firewall-cmd --reload" $?
                log_message "INFO" "Firewalld rules updated. Verifying..."
                log_command_intent "sudo firewall-cmd --list-services --zone=public --permanent"
                sudo firewall-cmd --list-services --zone=public --permanent
            else
                log_message "ERROR" "Could not automatically update firewall rules. No recognized active firewall manager (UFW/Firewalld) or it's inactive."
            fi
        else
            log_message "WARN" "User chose not to modify firewall rules. Please ensure Samba traffic is allowed manually."
        fi
    fi
    log_message "SUCCESS" "Firewall check completed."
}


# Function to add and enable a Samba user
add_and_enable_samba_user() {
    local user="$1"
    log_message "STEP" "Managing Samba user '$user'..."

    # Check if the system user exists
    log_message "INFO" "Checking if system user '$user' exists..."
    if ! id "$user" &> /dev/null; then
        log_message "ERROR" "System user '$user' does not exist. Please create the system user first."
        return 1
    fi
    log_message "INFO" "System user '$user' exists."

    log_message "INFO" "Checking Samba user database for '$user'..."
    log_command_intent "sudo pdbedit -L -v" # -v for more details, though we only grep name
    samba_user_list_output=$(sudo pdbedit -L -v 2>/dev/null)
    log_command_execution "sudo pdbedit -L -v" $?
    # echo "Full pdbedit -L output:" # For debugging if needed
    # echo "$samba_user_list_output"

    local user_details=$(echo "$samba_user_list_output" | grep "^$user:")
    
    if [ -z "$user_details" ]; then
        log_message "WARN" "Samba user '$user' not found in Samba database."
        if ask_yes_no "Add '$user' to Samba? (You will be prompted for a new Samba password)"; then
            log_command_intent "sudo smbpasswd -a '$user'"
            sudo smbpasswd -a "$user"
            local exit_code=$?
            log_command_execution "sudo smbpasswd -a '$user'" $exit_code
            if [ $exit_code -eq 0 ]; then
                log_message "SUCCESS" "Samba user '$user' added and enabled."
                return 0
            else
                log_message "ERROR" "Failed to add Samba user '$user'."
                return 1
            fi
        else
            log_message "WARN" "Samba user '$user' not added by choice. Authenticated access for this user will fail."
            return 1 # Critical if this user was intended for the share
        fi
    else
        log_message "INFO" "Samba user '$user' found in Samba database."
        echo "Details: $user_details" # Show the line from pdbedit

        # Check if user is disabled (flags like [UD], [D])
        # Common disable flags: U (user), D (disabled account)
        if echo "$user_details" | grep -qE '\[.*D.*\]'; then # D flag indicates disabled
            log_message "WARN" "Samba user '$user' is currently disabled."
            if ask_yes_no "Enable Samba user '$user'?"; then
                log_command_intent "sudo smbpasswd -e '$user'"
                sudo smbpasswd -e "$user"
                local exit_code=$?
                log_command_execution "sudo smbpasswd -e '$user'" $exit_code
                if [ $exit_code -eq 0 ]; then
                    log_message "SUCCESS" "Samba user '$user' enabled."
                else
                    log_message "ERROR" "Failed to enable Samba user '$user'."
                    return 1
                fi
            else
                log_message "WARN" "Samba user '$user' remains disabled."
                return 1
            fi
        else
            log_message "INFO" "Samba user '$user' appears to be enabled."
        fi
        
        if ask_yes_no "Samba user '$user' exists. Do you want to change/reset their Samba password?"; then
            log_command_intent "sudo smbpasswd '$user'"
            sudo smbpasswd "$user"
            local exit_code=$?
            log_command_execution "sudo smbpasswd '$user'" $exit_code
            if [ $exit_code -eq 0 ]; then
                log_message "SUCCESS" "Samba password for '$user' updated."
            else
                log_message "ERROR" "Failed to change Samba password for '$user'."
                # Not returning 1 here as it's an optional step if user already exists and enabled
            fi
        fi
    fi
    log_message "SUCCESS" "Samba user '$user' management completed."
    return 0
}


# Function to configure the Samba share
configure_share() {
    local share_name="$1"
    local share_path="$2"
    local writable="$3"
    local guest_ok="$4"
    local valid_users="$5"

    log_message "STEP" "Configuring Samba Share '$share_name'..."
    log_message "INFO" "Share Details: Path='$share_path', Writable='$writable', GuestOK='$guest_ok', ValidUsers='$valid_users'"

    # Ensure the directory exists
    log_message "INFO" "Checking share directory: '$share_path'..."
    if [ ! -d "$share_path" ]; then
        log_message "WARN" "Directory '$share_path' does not exist."
        if ask_yes_no "Create directory '$share_path'?"; then
            log_command_intent "sudo mkdir -p '$share_path'"
            sudo mkdir -p "$share_path"
            local exit_code=$?
            log_command_execution "sudo mkdir -p '$share_path'" $exit_code
            if [ $exit_code -ne 0 ]; then
                log_message "ERROR" "Failed to create directory '$share_path'. Aborting."
                return 1
            fi
            log_message "SUCCESS" "Directory '$share_path' created."
        else
            log_message "ERROR" "Share directory '$share_path' does not exist and creation was skipped. Aborting."
            return 1
        fi
    else
        log_message "INFO" "Directory '$share_path' already exists."
    fi

    # --- Check and Set Directory Permissions ---
    log_message "INFO" "Checking permissions for '$share_path'..."
    log_command_intent "ls -ld '$share_path'"
    current_perms_details=$(ls -ld "$share_path")
    log_command_execution "ls -ld '$share_path'" $?
    echo "Current details: $current_perms_details"
    
    local current_permissions=$(stat -c "%a" "$share_path")
    local current_owner=$(stat -c "%U" "$share_path")
    local current_group=$(stat -c "%G" "$share_path")
    log_message "INFO" "Parsed - Current permissions: $current_permissions, Owner: $current_owner, Group: $current_group"

    local set_perms_cmd=""
    local set_owner_cmd=""
    local perm_explanation=""

    if [ "$guest_ok" = "yes" ]; then
        perm_explanation="For guest access, 'nobody:nogroup' (or your configured guest user) needs appropriate access. "
        if [ "$writable" = "yes" ];
        then
            perm_explanation+="Recommended for guest writable: Owner 'nobody:nogroup', Permissions '0777' (world rwx) or '1777' (sticky bit). This is very open."
            set_owner_cmd="sudo chown -R nobody:nogroup '$share_path'"
            set_perms_cmd="sudo chmod -R 0777 '$share_path'" # Or 1777 for sticky bit
        else
            perm_explanation+="Recommended for guest read-only: Owner 'nobody:nogroup', Permissions '0755' (world rx)."
            set_owner_cmd="sudo chown -R nobody:nogroup '$share_path'"
            set_perms_cmd="sudo chmod -R 0755 '$share_path'"
        fi
    elif [ -n "$valid_users" ]; then
        local first_user=$(echo "$valid_users" | cut -d',' -f1)
        local first_user_group
        first_user_group=$(id -gn "$first_user" 2>/dev/null) || first_user_group=$first_user # Fallback if group not found easily

        perm_explanation="For authenticated access by '$valid_users', the user(s) need appropriate rights. "
        if [ "$writable" = "yes" ]; then
            perm_explanation+="Recommended: Owner '$first_user:$first_user_group', Permissions '0770' (user rwx, group rwx, others no access). Ensure all valid users are in group '$first_user_group' if group write is desired."
            set_owner_cmd="sudo chown -R '$first_user:$first_user_group' '$share_path'"
            set_perms_cmd="sudo chmod -R 0770 '$share_path'"
            # For multi-user write, consider chmod 2770 (setgid) and ensuring users are in the group.
        else # Read-only for valid users
            perm_explanation+="Recommended: Owner '$first_user:$first_user_group', Permissions '0750' (user rwx, group rx, others no access)."
            set_owner_cmd="sudo chown -R '$first_user:$first_user_group' '$share_path'"
            set_perms_cmd="sudo chmod -R 0750 '$share_path'"
        fi
    else
        log_message "WARN" "No guest access and no specific valid users. File system permissions will heavily dictate access based on global Samba settings (e.g. 'force user'). Manual permission review is critical."
        perm_explanation="Permissions are highly dependent on your global Samba config and how users connect."
    fi

    log_message "INFO" "$perm_explanation"
    if [[ -n "$set_owner_cmd" || -n "$set_perms_cmd" ]]; then
        if ask_yes_no "Attempt to set recommended ownership/permissions as described above?"; then
            if [ -n "$set_owner_cmd" ]; then
                log_command_intent "$set_owner_cmd"
                eval "$set_owner_cmd" # eval to handle variables in command string
                log_command_execution "$set_owner_cmd" $?
            fi
            if [ -n "$set_perms_cmd" ]; then
                log_command_intent "$set_perms_cmd"
                eval "$set_perms_cmd"
                log_command_execution "$set_perms_cmd" $?
            fi
            log_message "SUCCESS" "Ownership/permissions updated for '$share_path'."
            log_message "INFO" "Verifying new permissions:"
            log_command_intent "ls -ld '$share_path'"
            ls -ld "$share_path"
            log_command_execution "ls -ld '$share_path'" $?
        else
            log_message "WARN" "Permissions not automatically set. Please ensure they are correct manually."
        fi
    fi

    # Add the share definition to smb.conf
    log_message "INFO" "Preparing to append share configuration to $SAMBA_CONF."
    
    # Construct the configuration block
    # Using a temporary file for the block is cleaner for tee
    local temp_conf_block_file
    temp_conf_block_file=$(mktemp)

    cat <<EOF > "$temp_conf_block_file"

; --- Share '$share_name' created by $0 on $(date) ---
[$share_name]
    comment = Samba share for $share_path
    path = $share_path
    browseable = yes
EOF

    if [ "$writable" = "yes" ]; then
        echo "    read only = no" >> "$temp_conf_block_file"
        echo "    writable = yes" >> "$temp_conf_block_file"
        echo "    create mask = 0664" >> "$temp_conf_block_file" # Default file perms
        echo "    directory mask = 0775" >> "$temp_conf_block_file" # Default dir perms
    else
        echo "    read only = yes" >> "$temp_conf_block_file"
        echo "    writable = no" >> "$temp_conf_block_file"
    fi

    if [ "$guest_ok" = "yes" ]; then
        echo "    guest ok = yes" >> "$temp_conf_block_file"
        echo "    guest account = nobody" >> "$temp_conf_block_file" # Common guest account
    else
        echo "    guest ok = no" >> "$temp_conf_block_file"
    fi

    if [ -n "$valid_users" ]; then
        echo "    valid users = $valid_users" >> "$temp_conf_block_file"
        if [ "$writable" = "yes" ]; then
            echo "    write list = $valid_users" >> "$temp_conf_block_file"
            # If multiple users, forcing group can simplify permissions
            local first_user_for_group=$(echo "$valid_users" | cut -d',' -f1)
            local group_to_force=$(id -gn "$first_user_for_group" 2>/dev/null)
            if [ -n "$group_to_force" ]; then
                echo "    force group = $group_to_force" >> "$temp_conf_block_file"
                log_message "INFO" "Added 'force group = $group_to_force'. Ensure all valid users are members of this group for consistent write access if using group permissions on the filesystem."
            fi
        fi
    fi
    echo "; --- End of Share '$share_name' configuration ---" >> "$temp_conf_block_file"

    log_message "INFO" "The following configuration block will be appended to $SAMBA_CONF:"
    cat "$temp_conf_block_file" # Show the user what will be added
    echo "" # Newline for readability

    if ask_yes_no "Proceed with appending this configuration to $SAMBA_CONF?"; then
        # Backup smb.conf before modification
        SAMBA_CONF_BACKUP="${SAMBA_CONF}.$(date +%Y%m%d%H%M%S).bak"
        log_message "INFO" "Backing up current Samba configuration to $SAMBA_CONF_BACKUP"
        log_command_intent "sudo cp '$SAMBA_CONF' '$SAMBA_CONF_BACKUP'"
        sudo cp "$SAMBA_CONF" "$SAMBA_CONF_BACKUP"
        local exit_code=$?
        log_command_execution "sudo cp '$SAMBA_CONF' '$SAMBA_CONF_BACKUP'" $exit_code
        if [ $exit_code -ne 0 ]; then
            log_message "ERROR" "Failed to backup $SAMBA_CONF. Aborting share configuration to prevent data loss."
            rm "$temp_conf_block_file"
            return 1
        fi

        log_command_intent "sudo tee -a '$SAMBA_CONF' < '$temp_conf_block_file'"
        sudo tee -a "$SAMBA_CONF" < "$temp_conf_block_file" > /dev/null # Suppress tee's stdout of the block
        exit_code=$?
        log_command_execution "sudo tee -a '$SAMBA_CONF' < '$temp_conf_block_file'" $exit_code
        rm "$temp_conf_block_file" # Clean up temp file

        if [ $exit_code -eq 0 ]; then
            log_message "SUCCESS" "Samba configuration for '$share_name' appended to $SAMBA_CONF."
        else
            log_message "ERROR" "Failed to append configuration to $SAMBA_CONF."
            log_message "INFO" "Original configuration is backed up at $SAMBA_CONF_BACKUP. You may need to restore it manually."
            return 1
        fi
    else
        log_message "WARN" "Configuration not appended to $SAMBA_CONF by user choice."
        rm "$temp_conf_block_file"
        return 1 # If not configured, share won't work
    fi
    return 0
}

# Function to test Samba configuration
test_samba_config() {
    log_message "STEP" "Testing Samba Configuration..."
    log_command_intent "testparm -s '$SAMBA_CONF'"
    # testparm output can be verbose, capture and log, then print
    testparm_output=$(testparm -s "$SAMBA_CONF" 2>&1) # Capture stdout and stderr
    local exit_code=$?
    log_command_execution "testparm -s '$SAMBA_CONF'" $exit_code
    
    echo "--- testparm output ---"
    echo "$testparm_output"
    echo "--- end of testparm output ---"

    if [ $exit_code -eq 0 ]; then
        # testparm returns 0 even for some warnings, check output for "Loaded services file OK"
        if echo "$testparm_output" | grep -q "Loaded services file OK."; then
            log_message "SUCCESS" "Samba configuration test (testparm) passed."
            return 0
        else
            log_message "WARN" "testparm reported success (exit code 0) but 'Loaded services file OK.' not found. Please review output carefully."
            # Potentially still okay, but warrants a warning.
            return 0 # Treat as success for script flow, but user should check.
        fi
    else
        log_message "ERROR" "Samba configuration has errors (testparm failed). Please check $SAMBA_CONF and the output above."
        return 1
    fi
}

# Function to restart Samba service
restart_samba() {
    log_message "STEP" "Restarting Samba Services..."
    local restart_ok=0
    for service in smbd nmbd; do
        log_message "INFO" "Attempting to restart $service..."
        if command -v systemctl &> /dev/null; then
            log_command_intent "sudo systemctl restart $service"
            sudo systemctl restart "$service"
            local exit_code=$?
            log_command_execution "sudo systemctl restart $service" $exit_code
            if [ $exit_code -eq 0 ]; then
                log_message "SUCCESS" "$service restarted successfully via systemctl."
                restart_ok=1
            else
                log_message "ERROR" "Failed to restart $service via systemctl."
                restart_ok=0; break # Stop if one fails
            fi
        elif command -v service &> /dev/null; then # Fallback for older systems
            log_command_intent "sudo service $service restart"
            sudo service "$service" restart
            local exit_code=$?
            log_command_execution "sudo service $service restart" $exit_code
             if [ $exit_code -eq 0 ]; then
                log_message "SUCCESS" "$service restarted successfully via service command."
                restart_ok=1
            else
                log_message "ERROR" "Failed to restart $service via service command."
                restart_ok=0; break # Stop if one fails
            fi
        else
            log_message "ERROR" "Cannot determine how to restart Samba services (no systemctl or service command found)."
            return 1
        fi
    done

    if [ "$restart_ok" -eq 1 ]; then
        log_message "SUCCESS" "Samba services restarted."
        return 0
    else
        log_message "ERROR" "Failed to restart one or more Samba services. Please check service logs and restart manually."
        return 1
    fi
}

# --- Main Script ---

echo -e "${YELLOW}--- Samba Share Creation Script ---${NC}"
echo "This script will guide you through setting up a Samba share."
echo "All actions and commands will be logged to: ${GREEN}$LOG_FILE${NC}"
echo "You will be prompted for confirmation for major changes."
echo "Use the -y flag to automatically answer 'yes' to all prompts (use with caution)."
echo "Press Ctrl+C at any time to abort."
echo "-----------------------------------"
# sleep 2 # Give user a moment to read

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    log_message "WARN" "This script performs actions requiring root privileges (sudo)."
    log_message "WARN" "You may be prompted for your sudo password multiple times."
    if ! sudo -v; then # Validate sudo timestamp or prompt for password
        log_message "ERROR" "Sudo credentials failed or not provided. Aborting."
        exit 1
    fi
    log_message "INFO" "Sudo credentials appear to be valid."
fi


# Parse command-line options
SHARE_PATH=""
SHARE_NAME=""
WRITABLE="no" # read-only by default
GUEST_OK="no"
VALID_USERS=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--path) SHARE_PATH="$2"; shift ;;
        -n|--name) SHARE_NAME="$2"; shift ;;
        -w|--writable) WRITABLE="yes" ;;
        -g|--guest) GUEST_OK="yes" ;;
        -u|--users) VALID_USERS="$2"; shift ;;
        -y|--yes) ASSUME_YES="yes"; log_message "INFO" "'-y' flag detected. Will assume 'yes' for prompts." ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -p, --path <path>         : Absolute path to the directory to share (required)"
            echo "  -n, --name <name>         : Name of the Samba share (defaults to the last part of the path)"
            echo "  -w, --writable            : Allow writing to the share (default is read-only)"
            echo "  -g, --guest               : Allow guest access without a password"
            echo "  -u, --users <user1,...>   : Comma-separated list of valid system users for authenticated access"
            echo "  -y, --yes                 : Automatically answer yes to prompts (use with caution)"
            echo "  -h, --help                : Show this help message"
            exit 0
            ;;
        *) log_message "ERROR" "Unknown parameter passed: $1. Use -h or --help for usage."; exit 1 ;;
    esac
    shift
done

# Validate required options
if [ -z "$SHARE_PATH" ]; then
    log_message "ERROR" "Share path is required. Use -p or --path."
    echo "Use -h or --help for usage information."
    exit 1
fi
# Ensure SHARE_PATH is absolute
if [[ "$SHARE_PATH" != /* ]]; then
    log_message "ERROR" "Share path must be an absolute path (e.g., /srv/myshare)."
    exit 1
fi


# Set default share name if not provided
if [ -z "$SHARE_NAME" ]; then
    SHARE_NAME=$(basename "$SHARE_PATH")
    log_message "INFO" "Share name not provided, using '$SHARE_NAME' derived from the path."
fi

# Check for conflicting options
if [ "$GUEST_OK" = "yes" ] && [ -n "$VALID_USERS" ]; then
    log_message "ERROR" "Cannot have both guest access (-g) and specific valid users (-u) defined. Choose one."
    exit 1
fi
if [ "$GUEST_OK" = "no" ] && [ -z "$VALID_USERS" ]; then
    log_message "WARN" "No guest access (-g) and no specific users (-u) defined. Access will depend on global Samba settings and file permissions. This might lead to unexpected access behavior."
fi


# --- Pre-configuration Steps ---
log_message "STEP" "Starting pre-configuration checks..."

if ! install_samba; then
    log_message "ERROR" "Samba installation failed or was skipped. Cannot proceed."
    exit 1
fi

if ! manage_samba_services; then
    log_message "ERROR" "Samba services (smbd/nmbd) are not running or could not be started. Cannot proceed."
    exit 1
fi

check_firewall # This function will log its own success/failure but script continues

if [ -n "$VALID_USERS" ]; then
    log_message "STEP" "Processing specified Samba users: $VALID_USERS"
    IFS=',' read -ra USERS_ARRAY <<< "$VALID_USERS"
    all_users_ok=1
    for user_to_check in "${USERS_ARRAY[@]}"; do
        if ! add_and_enable_samba_user "$user_to_check"; then
            log_message "ERROR" "Failed to setup Samba user '$user_to_check'. This user will not have access."
            all_users_ok=0
            # Decide if script should abort if one user fails. For now, continue but warn.
        fi
    done
    if [ "$all_users_ok" -eq 0 ]; then
        log_message "WARN" "One or more specified Samba users could not be fully configured. The share might not work as expected for them."
        if ! ask_yes_no "Continue with share configuration despite user setup issues?"; then
            log_message "INFO" "Aborting due to user request after Samba user setup issues."
            exit 1
        fi
    fi
    log_message "SUCCESS" "Specified Samba users processed."
fi


# --- Configuration Steps ---
log_message "STEP" "Starting main configuration steps..."

if ! configure_share "$SHARE_NAME" "$SHARE_PATH" "$WRITABLE" "$GUEST_OK" "$VALID_USERS"; then
    log_message "ERROR" "Failed to configure the Samba share in $SAMBA_CONF or set directory permissions. Aborting."
    exit 1
fi

if ! test_samba_config; then
    log_message "ERROR" "Samba configuration test (testparm) failed. Please review $SAMBA_CONF and fix errors."
    if ! ask_yes_no "testparm failed. Attempt to restart Samba anyway (NOT RECOMMENDED)?"; then
        log_message "INFO" "Aborting due to testparm failure and user choice."
        exit 1
    fi
    log_message "WARN" "Proceeding with Samba restart despite testparm failure, as per user request."
fi

if ! restart_samba; then
    log_message "ERROR" "Failed to restart Samba services. The new share may not be active. Please check service logs and restart manually."
    # Don't exit here, still provide summary and connection info
fi

# --- Post-configuration Information ---
log_message "STEP" "Share Creation Summary & Connection Info"
echo -e "\n${YELLOW}--- Share Creation Summary ---${NC}"
echo -e "Samba share ${GREEN}'$SHARE_NAME'${NC} for path ${GREEN}'$SHARE_PATH'${NC} has been configured."
echo "Access Type:"
if [ "$GUEST_OK" = "yes" ]; then
    echo -e "  ${GREEN}Guest access is enabled.${NC}"
    echo -e "  ${YELLOW}WARNING:${NC} Guest access, especially if writable with open permissions (e.g., 0777), can be a security risk."
elif [ -n "$VALID_USERS" ]; then
    echo -e "  Access is restricted to users: ${GREEN}$VALID_USERS${NC} (requires Samba password for each user)."
else
    echo -e "  ${YELLOW}Access is not explicitly defined for guests or specific users.${NC}"
    echo "  Access will depend on global Samba settings and filesystem permissions."
fi
echo -e "Writable: ${GREEN}$WRITABLE${NC}"

# Get server IP for connection examples
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_HOSTNAME=$(hostname -s) # Short hostname
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="<server_ip_address>" # Fallback
fi
if [ -z "$SERVER_HOSTNAME" ]; then
    SERVER_HOSTNAME="<server_hostname>"
fi


echo -e "\n${YELLOW}--- How to Connect ---${NC}"
echo "Replace placeholders like ${GREEN}<YourSambaUsername>${NC}, ${GREEN}<YourSambaPassword>${NC}, ${GREEN}/mnt/local_mount_point${NC} as needed."
echo ""
echo -e "${BLUE}From Windows Explorer:${NC}"
echo -e "  \\\\${GREEN}$SERVER_IP\\$SHARE_NAME${NC}"
echo -e "  or (if NetBIOS name resolution works): \\\\${GREEN}$SERVER_HOSTNAME\\$SHARE_NAME${NC}"
echo ""
echo -e "${BLUE}From Windows Command Prompt (net use):${NC}"
echo -e "  Example (map as drive Z:):"
if [ -n "$VALID_USERS" ]; then
    local first_example_user=$(echo "$VALID_USERS" | cut -d',' -f1)
    echo -e "  net use Z: \\\\${GREEN}$SERVER_IP\\$SHARE_NAME${NC} /user:${GREEN}$first_example_user${NC} *"
    echo "  (Enter password for '$first_example_user' when prompted. Or replace '*' with the password directly - less secure)"
elif [ "$GUEST_OK" = "yes" ]; then
     echo -e "  net use Z: \\\\${GREEN}$SERVER_IP\\$SHARE_NAME${NC}"
     echo "  (Should connect as guest if server allows anonymous login for the share)"
else
    echo -e "  net use Z: \\\\${GREEN}$SERVER_IP\\$SHARE_NAME${NC} /user:${GREEN}<YourSambaUsername>${NC} *"
fi
echo ""
echo -e "${BLUE}From Linux (mount command - run as root or with sudo):${NC}"
echo -e "  1. Create a mount point: sudo mkdir -p ${GREEN}/mnt/$SHARE_NAME${NC}"
if [ -n "$VALID_USERS" ]; then
    local first_example_user=$(echo "$VALID_USERS" | cut -d',' -f1)
    echo -e "  2. Mount command:"
    echo -e "     sudo mount -t cifs //${GREEN}$SERVER_IP/$SHARE_NAME${NC} ${GREEN}/mnt/$SHARE_NAME${NC} -o username=${GREEN}$first_example_user${NC},password=${GREEN}<YourSambaPassword>${NC},uid=$(id -u),gid=$(id -g)"
    echo -e "     (Consider using a credentials file for security instead of password on command line. See 'man mount.cifs')"
elif [ "$GUEST_OK" = "yes" ]; then
    echo -e "  2. Mount command (for guest access):"
    echo -e "     sudo mount -t cifs //${GREEN}$SERVER_IP/$SHARE_NAME${NC} ${GREEN}/mnt/$SHARE_NAME${NC} -o guest,uid=$(id -u),gid=$(id -g)"
else
    echo -e "  2. Mount command (if server requires authentication but not specified in script):"
    echo -e "     sudo mount -t cifs //${GREEN}$SERVER_IP/$SHARE_NAME${NC} ${GREEN}/mnt/$SHARE_NAME${NC} -o username=${GREEN}<YourSambaUsername>${NC},uid=$(id -u),gid=$(id -g)"
fi
echo ""
echo -e "${BLUE}From Linux File Manager (e.g., Nautilus, Dolphin, Thunar):${NC}"
echo -e "  Enter this in the address bar:"
echo -e "  smb://${GREEN}$SERVER_IP/$SHARE_NAME${NC}"
echo -e "  or (if name resolution works): smb://${GREEN}$SERVER_HOSTNAME/$SHARE_NAME${NC}"
echo "  You may be prompted for username and password if the share is not guest accessible."

echo -e "\n${YELLOW}--- Important Notes & Troubleshooting ---${NC}"
echo "1.  ${BLUE}Firewall:${NC} This script attempted to check/configure UFW/Firewalld. If connection fails, double-check that UDP ports 137, 138 and TCP ports 139, 445 are open on the server for your client's network."
echo "2.  ${BLUE}SELinux/AppArmor:${NC} If enabled, these security modules might block Samba. You may need to set appropriate contexts/policies (e.g., 'chcon -t samba_share_t $SHARE_PATH' for SELinux, or AppArmor profiles)."
echo "3.  ${BLUE}File Permissions:${NC} The script attempted to set permissions. Complex scenarios might need manual 'chown', 'chmod', or ACL adjustments on '$SHARE_PATH'."
echo "4.  ${BLUE}Samba Users:${NC} For authenticated access, system users must exist and be added to Samba with 'smbpasswd -a username'."
echo "5.  ${BLUE}Samba Logs:${NC} Check Samba logs for errors if connections fail. Common locations:"
echo "    - /var/log/samba/log.smbd"
echo "    - /var/log/samba/log.nmbd"
echo "    - /var/log/samba/log.<client_hostname_or_ip>"
echo "    Use 'sudo tail -f /var/log/samba/log.*' to monitor."
echo "6.  ${BLUE}Windows Credentials:${NC} Windows can aggressively cache credentials. If you change passwords or access types, you might need to clear cached credentials in Windows Credential Manager or restart the 'Workstation' service on the Windows client."
echo "7.  ${BLUE}Testparm:${NC} Review the output of 'testparm -s $SAMBA_CONF' for any warnings or misconfigurations."

echo -e "\n${GREEN}--- Script Finished ---${NC}"
log_message "INFO" "Script execution finished."
exit 0

