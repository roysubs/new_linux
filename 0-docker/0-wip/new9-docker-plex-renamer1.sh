#!/bin/bash

# Default values
COMMIT=false

# Help message
usage() {
    echo "Usage: $0 [-c]"
    echo "  -c   Perform renames (without this, it's a dry run)"
    exit 1
}

# Parse command-line options
while getopts "c" opt; do
    case "$opt" in
        c) COMMIT=true ;;
        *) usage ;;
    esac
done

# Path to Plex DB inside Docker volume
DB_PATH="/var/lib/docker/volumes/plex_data/_data/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

echo "[*] Checking Plex DB at:"
echo "    $DB_PATH"

# Check if it exists
if sudo test -f "$DB_PATH"; then
    echo "[*] Plex DB found."
else
    echo "[!] Plex DB not found or inaccessible."
    exit 1
fi

# SQL query
SQL="
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
"

# Fetch results
results=$(sudo sqlite3 -separator $'\t' "$DB_PATH" "$SQL")

echo
echo "[*] Rename preview:"
echo "--------------------------------------------------------"

# Process each line
while IFS=$'\t' read -r file_path title year release_date; do
    [ -z "$file_path" ] && continue

    # Fallbacks
    title="${title:-Unknown Title}"
    year="${year:-${release_date:0:4}}"

    dir=$(dirname "$file_path")
    ext="${file_path##*.}"

    # Clean title: remove odd characters, squeeze spaces
    clean_title=$(echo "$title" | tr -cd '[:alnum:] _.-' | sed -E 's/ +/ /g' | sed -E 's/[\._-]+$//')

    # Final name
    new_name="${clean_title} (${year}).${ext}"
    new_path="${dir}/${new_name}"

    echo "$file_path"
    echo " => $new_path"

    if $COMMIT; then
        sudo mv -v "$file_path" "$new_path"
    fi
done <<< "$results"

echo
if $COMMIT; then
    echo "[*] Rename complete."
else
    echo "[*] DRY RUN — no changes made."
    echo "    Rerun with -c to apply renames."
fi

