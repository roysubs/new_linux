#!/bin/bash

# Function to check and install SQLite3 if not already installed
check_and_install_sqlite() {
    if ! command -v sqlite3 &>/dev/null; then
        echo "SQLite3 is not installed. Installing..."
        sudo apt update && sudo apt install -y sqlite3
        if [[ $? -ne 0 ]]; then
            echo "Failed to install SQLite3. Exiting."
            exit 1
        fi
    else
        echo "SQLite3 is already installed."
    fi
}

# Get current datetime as yyyy-mm-dd_hh-mm-ss
get_datetime() {
    echo $(date +"%Y-%m-%d_%H-%M-%S")
}

# Create SQLite database and populate it with file details
scan_and_populate_db() {
    local db_path="$HOME/.sqlite-home"
    local db_file="$db_path/files_$(get_datetime).db"

    # Create directory for SQLite database if it doesn't exist
    mkdir -p "$db_path"

    # Create database and table
    sqlite3 "$db_file" <<EOF
CREATE TABLE IF NOT EXISTS file_info (
    filename TEXT,
    path TEXT,
    size INTEGER,
    creationdatetime TEXT,
    lastupdatedatetime TEXT,
    permissions TEXT,
    owner TEXT
);
EOF

    # Scan files and populate the database
    echo "Scanning files..."
    local start_time=$(date +%s)

    find "$HOME" -path "$db_path" -prune -o -type f -print0 |\
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        path=$(dirname "$file")
        size=$(stat --format="%s" "$file")
        creationdatetime=$(stat --format="%w" "$file")
        lastupdatedatetime=$(stat --format="%y" "$file")
        permissions=$(stat --format="%A" "$file")
        owner=$(stat --format="%U" "$file")

        sqlite3 "$db_file" <<EOF
INSERT INTO file_info (filename, path, size, creationdatetime, lastupdatedatetime, permissions, owner)
VALUES ("$filename", "$path", $size, "$creationdatetime", "$lastupdatedatetime", "$permissions", "$owner");
EOF
    done

    local end_time=$(date +%s)
    echo "Database created at: $db_file"
    echo "Scan completed in $((end_time - start_time)) seconds."
}

# Main script execution
check_and_install_sqlite
scan_and_populate_db

