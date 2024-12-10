#!/bin/bash

# Install required packages
sudo apt-get update
sudo apt-get install -y curl python3

# Function to get system information
get_system_info() {
    echo "<h1>System Information</h1>"
    echo "<h2>CPU Info</h2>"
    echo "<pre>$(lscpu)</pre>"

    echo "<h2>Memory Info</h2>"
    echo "<pre>$(free -h)</pre>"

    echo "<h2>Disk Info</h2>"
    echo "<pre>$(lsblk)</pre>"

    echo "<h2>Mounted Filesystems</h2>"
    echo "<pre>$(df -h)</pre>"

    echo "<h2>USB Devices</h2>"
    echo "<pre>$(lsusb)</pre>"

    echo "<h2>Logged-in Users</h2>"
    echo "<pre>$(who)</pre>"

    echo "<h2>Open Ports</h2>"
    echo "<pre>$(ss -tuln)</pre>"

    echo "<h2>Process List</h2>"
    echo "<pre>$(ps aux)</pre>"
}

# Create HTML content
create_html() {
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="60">
    <title>System Information</title>
</head>
<body>
    $(get_system_info)
</body>
</html>
EOF
}

# Serve the HTML content using Python's http.server
serve() {
    while true; do
        create_html > /tmp/system_info.html
        python3 -m http.server 8081 --bind 192.168.1.140 --directory /tmp
    done
}

# Start the server
serve

