#!/bin/bash

# Function to install Samba
install_samba() {
    echo "Installing Samba..."
    sudo apt update
    sudo apt install -y samba
    echo "Samba installed successfully!"
}

# Function to create a Samba share
create_samba_share() {
    SHARE_NAME=$(dialog --inputbox "Enter the name for the new Samba share:" 10 50 3>&1 1>&2 2>&3)
    SHARE_PATH=$(dialog --inputbox "Enter the full path to the directory to share:" 10 50 3>&1 1>&2 2>&3)
    
    # Ensure the directory exists
    if [ ! -d "$SHARE_PATH" ]; then
        echo "Directory does not exist, creating directory: $SHARE_PATH"
        mkdir -p "$SHARE_PATH"
    fi

    # Add the share configuration to smb.conf
    echo -e "\n[$SHARE_NAME]\n    path = $SHARE_PATH\n    read only = no\n    guest ok = yes" | sudo tee -a /etc/samba/smb.conf > /dev/null

    # Restart Samba service to apply changes
    sudo systemctl restart smbd
    echo "Samba share '$SHARE_NAME' created and Samba service restarted."
}

# Function to show existing Samba shares
show_samba_shares() {
    echo "Existing Samba shares:"
    testparm -s | grep "^\[" | cut -d "[" -f2 | cut -d "]" -f1
}

# Main menu with options
while true; do
    CHOICE=$(dialog --menu "Samba Management" 15 50 4 \
        1 "Install Samba" \
        2 "Create Samba Share" \
        3 "Show Existing Samba Shares" \
        4 "Exit" 2>&1 >/dev/tty)
    
    case $CHOICE in
        1)
            install_samba
            ;;
        2)
            create_samba_share
            ;;
        3)
            show_samba_shares
            ;;
        4)
            clear
            echo "Exiting Samba Management Script."
            exit 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
done

