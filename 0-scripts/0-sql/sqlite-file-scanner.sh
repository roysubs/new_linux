#!/bin/bash

# Check for SQLite installation and install if not present
if ! command -v sqlite3 &> /dev/null; then
    echo "SQLite is not installed. Installing SQLite..."
    sudo apt update && sudo apt install -y sqlite3
fi

# Get current datetime
datetime=$(date +"%Y-%m-%d_%H-%M-%S")

# Get the original user's home directory
user_home=$(eval echo ~${SUDO_USER:-$USER})

# Create SQLite database
db_path="$user_home/.sqlite-home/home_files_$datetime.db"
mkdir -p "$user_home/.sqlite-home"
sqlite3 "$db_path" "CREATE TABLE IF NOT EXISTS files (inode INTEGER, permissions TEXT, links INTEGER, owner TEXT, grp TEXT, size INTEGER, modified TEXT, name TEXT, type TEXT);"
echo "Database and table created at: $db_path"

# Function to process each directory
process_directory() {
    local dir="$1"
    echo "Processing directory: $dir"
    ls -alFi --time-style=+"%Y-%m-%d %H:%M:%S" "$dir" | awk '
    NR > 1 && $1 != "total" {
        type = substr($9, length($9), 1);
        sub("[*/=>@|]$", "", $9);
        printf "INSERT INTO files (inode, permissions, links, owner, grp, size, modified, name, type) VALUES (%d, '\''%s'\'', %d, '\''%s'\'', '\''%s'\'', %d, '\''%s'\'', '\''%s'\'', '\''%s'\'');\n", $1, $2, $3, $4, $5, $6, $7 " " $8, $9, type;
    }' | sqlite3 "$db_path" ".read /dev/stdin"
}

# Start time
start_time=$(date +%s)

# Export process_directory function for use in subshells
export -f process_directory
export db_path

# Find all directories and process them, excluding specified ones
find "$user_home" \( \
  -path "$user_home/.sqlite-home" -o \
  -path "$user_home/backup*" -o \
  -path "$user_home/.backup*" -o \
  -path "$user_home/.cache" -o \
  -path "$user_home/.thumbnails" -o \
  -path "$user_home/.local/share/Trash" -o \
  -path "$user_home/venv" -o \
  -path "$user_home/.virtualenvs" -o \
  -path "$user_home/Downloads" -o \
  -path "$user_home/.mozilla" -o \
  -path "$user_home/.config/google-chrome" -o \
  -path "$user_home/.config/chromium" -o \
  -path "$user_home/.config" -o \
  -path "$user_home/.gnupg" -o \
  -path "$user_home/.ssh" \
\) -prune -o \
-type d -exec bash -c 'process_directory "$0"' {} \;

# End time and duration
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Script completed in $duration seconds."
echo "Database created at: $db_path"

