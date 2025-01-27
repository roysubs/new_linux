#!/bin/bash

# Script to invoke and run the script at ~/new_linux/0-new-system/myhelp.sh

# Define the path to the target script
TARGET_SCRIPT=../0-new-system/new2-update-markdown-help-files.sh

# Check if the target script exists and is executable
if [[ -x "$TARGET_SCRIPT" ]]; then
    # Run the target script
    "$TARGET_SCRIPT"
else
    echo "Error: $TARGET_SCRIPT does not exist or is not executable." >&2
    exit 1
fi

