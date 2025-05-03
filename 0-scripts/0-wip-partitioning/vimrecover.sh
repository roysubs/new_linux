#!/bin/bash

# Check if the input .swp file is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <file.swp>"
    exit 1
fi

SWP_FILE="$1"

# Ensure the file exists and is a .swp file
if [[ ! -f "$SWP_FILE" || "${SWP_FILE##*.}" != "swp" ]]; then
    echo "Error: Please provide a valid .swp file."
    exit 1
fi

# Extract the original filename from the .swp file
ORIGINAL_FILE=$(strings "$SWP_FILE" | grep -m 1 '^Vim:.*file:' | sed 's/^Vim:.*file: //')

if [[ -z "$ORIGINAL_FILE" ]]; then
    echo "Error: Unable to determine the original file from $SWP_FILE."
    exit 1
fi

# Generate the recovered filename
BASENAME=$(basename "$ORIGINAL_FILE")
RECOVERED_FILE="${BASENAME%.*}-recovered.${BASENAME##*.}"

# Perform recovery
vim -n -r "$SWP_FILE" -c "set nomodifiable" -c "w! $RECOVERED_FILE" -c "q" >/dev/null 2>&1

# Check if the recovery was successful
if [[ -f "$RECOVERED_FILE" ]]; then
    echo "Recovered file created: $RECOVERED_FILE"
    echo
    echo "To compare the files, you can use:"
    echo "  vimdiff $ORIGINAL_FILE $RECOVERED_FILE"
    echo "  diff $ORIGINAL_FILE $RECOVERED_FILE"
else
    echo "Error: Failed to recover the .swp file."
    exit 1
fi

