#!/bin/bash

# This script might not work well as the system will reboot after the restore completes
# so cannot capture the time

echo -e "Starting TimeShift restore at $(date)"

# Prompt for user confirmation before proceeding with the restore
echo "Are you sure you want to continue? This will restore the system back to a TimeShift snapshot."
read -p "Type 'yes' to continue: " confirmation

# Check if the user entered 'yes'
if [[ "$confirmation" != "yes" ]]; then
    echo "Restore aborted. You did not type 'yes'. Exiting..."
    exit 1
fi

# Start the timer
start_time=$(date +%s)

# Get the most recent snapshot name (modify as required)
#   sed '1,/^---------/d  deletes the part before the '---' (including the '---' line
#   awk '{print $3}'  get the 3rd column where the snapshot names are
#   grep -v '^$'  get every line except for any empty lines
#   tail -n 1  # show the bottom line (which will be the most recent snapshot)
snapshot_name=$(sudo timeshift --list | sed '1,/^---------/d' | awk '{print $3}' | grep -v '^$' | tail -n 1)

# Perform the restore directly using the snapshot name
echo "Restoring from snapshot: $snapshot_name"
sudo timeshift --restore --snapshot "$snapshot_name"

# End the timer
end_time=$(date +%s)

# Calculate and display the time elapsed
elapsed_time=$((end_time - start_time))
echo "Restore completed in $elapsed_time seconds."

