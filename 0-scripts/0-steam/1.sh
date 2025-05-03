#!/bin/bash

# Log in to SteamCMD with your username
./steamcmd.sh +login roysubs | tee steamcmd_output.txt

# List of AppIDs you want to check (add as many as you like)
APP_IDS=(354430 967081 497097)  # Example AppIDs, replace with your own

# Loop through each AppID and get its status
for app_id in "${APP_IDS[@]}"
do
    echo "Querying status for AppID: $app_id"
    
    # Query the app status and log the output to a file
    ./steamcmd.sh +app_status $app_id | tee -a steamcmd_output.txt
done

# Log out of SteamCMD
./steamcmd.sh +quit

