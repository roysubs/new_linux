#!/bin/bash

# Check if the correct number of arguments is provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <file> <number_of_versions>"
    exit 1
fi

# Get the input file and number of versions to fetch
file=$1
num_versions=$2

# Ensure the file exists in the git repository
if [ ! -f "$file" ]; then
    echo "File $file does not exist in the repository!"
    exit 1
fi

# Fetch the commit hashes for the given number of versions (latest first)
commits=$(git log --format="%H" -n "$num_versions" "$file")

# Loop through the commits and create a backup with the timestamp
for commit in $commits; do
    # Get the commit date and time for the current commit (in UTC)
    timestamp=$(git show -s --format=%cd --date=iso-strict "$commit")
    
    # Convert the timestamp to yymmdd-hhmmss format (using UTC to avoid local timezone issues)
    timestamp_filename=$(date -d "$timestamp" -u +'%y%m%d-%H%M%S')
    
    # Checkout the file as it was at that commit (so we get the content)
    git checkout "$commit" -- "$file"

    # Create a copy of the file with the timestamp in the filename
    cp "$file" "${file}-${timestamp_filename}"

    # Optionally, restore the working directory to the latest commit after each extraction
    git checkout HEAD -- "$file"
    
    echo "Created backup: ${file}-${timestamp_filename}"
done

