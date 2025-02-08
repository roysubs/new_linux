#!/bin/bash

# Check if there are enough arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <filename-pattern> <text-to-replace> <replacement-text>"
    exit 1
fi

# Get the input parameters
pattern="$1"
text_to_replace="$2"
replacement_text="$3"

# Use find to locate files matching the pattern, preserving spaces in filenames
files=$(find . -type f -name "$pattern" -print0)

# Check if any files were found
if [[ -z "$files" ]]; then
    echo "No files found matching pattern '$pattern'"
    exit 1
fi

# Iterate over the matched files, using -print0 and while loop with read -d to handle spaces
while IFS= read -r -d '' file; do
    # Check if the filename contains the text to replace
    if [[ "$file" == *"$text_to_replace"* ]]; then
        # Generate the new filename by replacing the text in the file
        new_file=$(echo "$file" | sed "s/$text_to_replace/$replacement_text/g")
        
        # Ensure the new file name is not the same as the old one
        if [[ "$file" != "$new_file" ]]; then
            echo "Renaming '$file' -> '$new_file'"
            mv -v -- "$file" "$new_file"
        fi
    else
        echo "No match found in '$file'"
    fi
done <<< "$files"

