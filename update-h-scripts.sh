#!/bin/bash
# Wrapper script to invoke new2-update-h-scripts.sh

SCRIPT_PATH="$HOME/new_linux/0-new-system/new2-update-h-scripts.sh"

if [ -x "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH"
else
    echo "Error: Script $SCRIPT_PATH not found or not executable."
    exit 1
fi

