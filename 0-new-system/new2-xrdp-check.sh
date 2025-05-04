#!/bin/bash

# Troubleshooting steps overview
steps=(
  "Check if D-Bus service is running and restart if necessary."
  "Restart the MATE and xrdp services."
  "Check and fix permissions for the D-Bus session configuration."
  "Set up MATE as the default desktop environment for xrdp sessions."
  "Ensure xrdp.ini is correctly configured to start MATE."
  "Check logs for xrdp and D-Bus for detailed errors."
  "Debug with a new user session."
  "Ensure all required dependencies for MATE and xrdp are installed."
)

# Function to pause for user confirmation
run_step() {
    echo -e "\n$1"
    read -p "Do you want to run this step? (y/n): " choice
    [[ "$choice" == "y" ]] && eval "$2"
}

# Step 1: Check if D-Bus service is running
run_step "${steps[0]}" "
sudo systemctl status dbus || {
    echo 'D-Bus is not running. Starting D-Bus...';
    sudo systemctl start dbus;
    sudo systemctl enable dbus;
    echo 'D-Bus has been started and enabled.';
}
"

# Step 2: Restart MATE and xrdp services
run_step "${steps[1]}" "
echo 'Restarting MATE and xrdp services...';
sudo systemctl restart xrdp;
"

# Step 3: Check and fix D-Bus permissions
run_step "${steps[2]}" "
echo 'Checking D-Bus session configuration...';
if grep -q '<deny' /etc/dbus-1/session.conf; then
    echo 'Warning: D-Bus configuration contains deny rules. Consider adjusting them.';
    echo 'Manually inspect /etc/dbus-1/session.conf.';
else
    echo 'D-Bus session configuration looks fine.';
fi
"

# Step 4: Set up MATE as the default desktop environment
run_step "${steps[3]}" "
echo 'Configuring .xsession to use MATE...';
echo 'mate-session' > ~/.xsession;
chmod +x ~/.xsession;
echo '.xsession configured and made executable.';
"

# Step 5: Ensure xrdp.ini is correctly configured
run_step "${steps[4]}" "
echo 'Ensuring xrdp.ini is correctly configured...';
if grep -q 'exec startmate' /etc/xrdp/xrdp.ini; then
    echo 'xrdp.ini is already correctly configured.';
else
    sudo bash -c 'echo -e \"\\nexec startmate\" >> /etc/xrdp/xrdp.ini';
    echo 'Added exec startmate to xrdp.ini.';
fi
"

# Step 6: Check logs for errors
run_step "${steps[5]}" "
echo 'Checking logs for xrdp and D-Bus...';
sudo journalctl -u xrdp --no-pager | tail -20;
sudo journalctl -u dbus --no-pager | tail -20;
echo 'Logs displayed. Check above for errors.';
"

# Step 7: Debug with a new user session
run_step "${steps[6]}" "
echo 'Creating a new user for debugging...';
read -p 'Enter username for the new user: ' new_user;
sudo adduser \$new_user;
echo 'New user \$new_user created. Try logging in with this user to test.';
"

# Step 8: Ensure all required dependencies are installed
run_step "${steps[7]}" "
echo 'Installing required dependencies...';
sudo apt update;
sudo apt install -y mate-desktop-environment xrdp dbus-x11;
echo 'Dependencies installed.';
"

echo -e "\nTroubleshooting steps completed. Reattempt connecting via RDP to your MATE desktop."

