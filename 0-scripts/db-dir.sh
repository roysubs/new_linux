#!/bin/bash

# Ensure the script is run with an input folder
if [ -z "$1" ]; then
  echo "Usage:  $(basename "$0") <input_folder>"
  exit 1
fi

INPUT_FOLDER="$1"
INPUT_FOLDER_NAME="$(basename "$(realpath "$INPUT_FOLDER")")"
DB_NAME="$(basename "$0" | sed 's/\.[^.]*$//')-$INPUT_FOLDER_NAME-$(date '+%Y-%m-%d_%H-%M-%S').db"
BATCH_SIZE=1000
START_TIME=$(date +%s.%N)

# Install sqlite3 if not already installed
if ! command -v sqlite3 &> /dev/null; then
  echo "sqlite3 is not installed. Installing..."
  sudo apt update && sudo apt install -y sqlite3
fi

# Create SQLite database and table
sqlite3 "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fullpath TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  path TEXT NOT NULL,
  filesize INTEGER NOT NULL,
  attributes TEXT NOT NULL,
  timestamp TEXT NOT NULL
);
EOF

# Enable batch processing in SQLite to improve performance
sqlite3 "$DB_NAME" "PRAGMA synchronous = OFF;"
sqlite3 "$DB_NAME" "BEGIN TRANSACTION;"

# Temporary file to accumulate SQL insert queries
temp_file=$(mktemp)

# Process find output, handle ' characters before parsing into SQL
find "$INPUT_FOLDER" -type f -ls | sed "s/'/''/g" | awk '{print $11 "|" $7 "|" $3 "|" $8 " " $9 " " $10}' | while IFS="|" read -r fullpath filesize attributes timestamp; do
  filename=$(basename "$fullpath")
  dir_path=$(dirname "$fullpath")

  # Build insert query for current file and append it to the temporary file
  echo "INSERT OR REPLACE INTO files (fullpath, filename, path, filesize, attributes, timestamp) VALUES ('$fullpath', '$filename', '$dir_path', $filesize, '$attributes', '$timestamp');" >> "$temp_file"

  ((counter++))

  # If batch size is reached, process the batch
  if (( counter % BATCH_SIZE == 0 )); then
    cat "$temp_file" | sqlite3 "$DB_NAME"
    > "$temp_file"  # Clear the temporary file for the next batch
  fi
done

# Commit any remaining records in the temporary file
if [ -s "$temp_file" ]; then
  cat "$temp_file" | sqlite3 "$DB_NAME"
fi

# Commit the transaction
sqlite3 "$DB_NAME" "COMMIT;"

# Clean up the temporary file
rm "$temp_file"

# Calculate elapsed time in seconds (including fractional part)
END_TIME=$(date +%s.%N)
ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc)
ELAPSED_MINUTES=$(echo "$ELAPSED_TIME / 60" | bc)   # Full minutes
REMAINING_SECONDS=$(echo "$ELAPSED_TIME - ($ELAPSED_MINUTES * 60)" | bc) #
REMAINING_SECONDS=$(printf "%.2f" $REMAINING_SECONDS)  # Round to 2 decimal places

# Output the results
echo "Database creation completed."
echo "Start Time: $(date -d @$START_TIME '+%Y-%m-%d %H:%M:%S')"
echo "End Time:   $(date -d @$END_TIME '+%Y-%m-%d %H:%M:%S')"
echo "Total Time: $ELAPSED_MINUTES minutes and $REMAINING_SECONDS seconds."
echo "Database saved as $DB_NAME."

