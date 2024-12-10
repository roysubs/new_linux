#!/bin/bash

# Finding All Disks:
# lsblk -o NAME,SIZE,TYPE,MOUNTPOINT: Lists block devices.
# lsblk -d -n -o NAME : get all block devices (disks) without partitions. Generate a report for each disk.
# lsblk /dev/disk: Detailed information about the specific disk.
# smartctl -a /dev/disk: Provides a SMART status report for the disk.
# nvme smart-log /dev/disk: Shows NVMe disk statistics (only for NVMe drives).
# hdparm -I /dev/disk: Provides detailed information about the disk.
# The results of each command are written to the report file, prefixed with the command that was run.
# lsblk is in the 'util-linux' package

HOME_DIR="$HOME"
TOOLS=("smartmontools" "nvme-cli" "hdparm" "util-linux")
# Ensure the script can find the necessary tools
export PATH=$PATH:/usr/sbin:/sbin

# Check if the packages are installed
for package in "${PACKAGES[@]}"; do
    if ! dpkg-query -l | grep -q "$package"; then
        echo "$package is not installed."
        missing_tools+=("$package")
    else
        echo "$package is already installed."
    fi
done

# If there are missing tools, install them
if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "The following tools/packages are missing: ${missing_tools[@]}"
    echo "Updating package lists and installing missing tools..."
    sudo apt-get update
    sudo apt-get install -y "${missing_tools[@]}"
else
    echo "All tools are already installed."
fi

# Function to generate report for each disk
generate_report() {
    local disk=$1
    local report_file="$HOME_DIR/diskreport-$disk.txt"

    echo "Generating report for $disk..."

    # Initialize the report file
    echo "Disk Report for $disk" > "$report_file"
    echo "=========================" >> "$report_file"

    # List the commands and outputs to include in the report
    commands=(
        "lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,MOUNTPOINT"
        "lsblk /dev/$disk"
        "sudo smartctl -a /dev/$disk"
        "sudo nvme smart-log /dev/$disk"
        "sudo hdparm -I /dev/$disk"
    )

    # Run each command and append to the report
    for cmd in "${commands[@]}"; do
        echo -e "\nRunning: $cmd\n" >> "$report_file"
        if eval "$cmd" >> "$report_file" 2>&1; then
            echo -e "\n*** Command executed successfully" >> "$report_file"
        else
            echo -e "\n*** Error executing $cmd" >> "$report_file"
            echo -e "*** Full error: $(eval $cmd 2>&1)" >> "$report_file"
        fi
        echo -e "\n=========================" >> "$report_file"
    done

    echo "Report saved as $report_file"
}

# Find all disks (excluding partitions) and generate reports
disks=$(lsblk -d -n -o NAME)

# Loop through each disk (e.g., sda, sdb, sdc)
for disk in $disks; do
    generate_report "$disk"
done

echo "All disk reports generated in $HOME_DIR"

