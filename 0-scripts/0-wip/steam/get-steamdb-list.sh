#!/bin/bash

# Log in to SteamCMD using your username (use +login with the correct username)
~/steamcmd/steamcmd.sh +login roysubs +force_install_dir ./steamcmd << EOF
# List of AppIDs you want to check (replace with your own)
APP_IDS=(354430 967081 497097)

# Loop through each AppID and get its status
for app_id in "${APP_IDS[@]}"
do
    echo "Querying status for AppID: $app_id"
    ./steamcmd.sh +app_status $app_id
done

# Exit SteamCMD after finishing
quit
EOF

