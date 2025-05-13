#!/bin/bash

# Default values
COMMIT=false

# Help message
usage() {
    echo "Usage: $0 [-commit]"
    echo "  -commit   Perform renames (without this option, it's a dry run)"
    exit 1
}

# Parse command-line options
while getopts "c" opt; do
    case "$opt" in
        c) COMMIT=true ;;
        *) usage ;;
    esac
done

# Define the path to the Plex DB
DB_PATH="/var/lib/docker/volumes/plex_data/_data/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

# Debugging: Print the DB path to confirm it
echo "[*] Checking Plex DB at: $DB_PATH"

# Check if the Plex DB exists and if the user has permission to access it
if sudo test -f "$DB_PATH"; then
    echo "[*] Plex DB found at $DB_PATH"
else
    echo "[!] Plex DB not found or cannot access it at $DB_PATH"
    exit 1
fi

# SQLite query to get media file paths, titles, years, and release dates
SQL='
SELECT
    media_parts.file AS file_path,
    metadata_items.title AS title,
    metadata_items.year AS year,
    metadata_items.originally_available_at AS release_date
FROM
    media_items
JOIN
    metadata_items ON media_items.metadata_item_id = metadata_items.id
JOIN
    media_parts ON media_items.id = media_parts.media_item_id
ORDER BY
    metadata_items.title COLLATE NOCASE ASC;
'

# Run SQLite query and store the results
results=$(sudo sqlite3 -separator $'\t' "$DB_PATH" "$SQL")

echo
echo "[*] Renaming preview:"

# Process each result line
while IFS=$'\t' read -r file_path title year release_date; do
    # Skip empty lines
    [ -z "$file_path" ] && continue

    # Handle missing or empty title and year
    if [ -z "$title" ]; then
        title="Unknown Title"
    fi
    if [ -z "$year" ]; then
        year="${release_date:0:4}"  # Use the first four characters of the release date as the year
    fi

    # Extract directory and extension
    dir=$(dirname "$file_path")
    ext="${file_path##*.}"

    # Clean up the title and construct the new filename
    clean_title=$(echo "$title" | tr -cd '[:alnum:] ._-')  # Keep alphanumeric and some common characters
    clean_title=$(echo "$clean_title" | sed 's/\s\+/ /g')  # Replace multiple spaces with a single space
    new_name="${clean_title} (${year}).${ext}"
    new_path="${dir}/${new_name}"

    # Output the old and new paths
    echo "$file_path => $new_path"

    # If commit is true, perform the rename
    if $COMMIT; then
        echo "[+] Renaming..."
        sudo mv -v "$file_path" "$new_path"
    fi
done <<< "$results"

# Final message
if $COMMIT; then
    echo "[*] Renames completed."
else
    echo "[*] DRY RUN: No files were changed."
    echo "[!] Rerun with the -commit switch to perform renames."
fi

