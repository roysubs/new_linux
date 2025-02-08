#!/bin/bash

# List of supported media file extensions
media_extensions=("mkv" "avi" "mp3" "mp4" "cbr" "cbz" "mov" "flv" "wmv" "webm" "mpg" "mpeg" "jpg" "png" "gif")

# Function to check if the file has a media extension
is_media_file() {
    local ext="${1##*.}"
    for media_ext in "${media_extensions[@]}"; do
        if [[ "$ext" == "$media_ext" ]]; then
            return 0  # File has a media extension
        fi
    done
    return 1  # Not a media file
}

# Clean file name
clean_name() {
    local input_name="$1"
    local base_name="${input_name%.*}"  # Filename without extension
    local ext="${input_name##*.}"       # File extension

    # Replace common separators with spaces
    local cleaned="${base_name//./ }"
    cleaned="${cleaned//_/ }"
    cleaned="${cleaned//-/ }"

    # Remove common junk tags
    cleaned=$(echo "$cleaned" | sed -E 's/\b(HDRip|HDCAM|BluRay|WEBRip|WEB-DL|DVDRip|x264|XviD|TGx|YIFY|RARBG|PROPER|REPACK|EXTENDED|UNRATED|REMUX|IMAX|NF|Galaxytv|720p|1080p|2160p|4K)\b//gi')

    # Detect TV show format (SXXEYY) and enforce uppercase
    if [[ $cleaned =~ (S[0-9]{2}E[0-9]{2}) ]]; then
        local episode_code="${BASH_REMATCH[1]}"
        cleaned="${cleaned%%$episode_code*}$episode_code"  # Keep everything before SXXEYY + SXXEYY
        cleaned=$(echo "$cleaned" | sed -E 's/(S[0-9]{2})e([0-9]{2})/\1E\2/')  # Force uppercase E
    else
        # Identify year and format it properly for movies
        if [[ $cleaned =~ ([12][0-9]{3}) ]]; then
            local year="${BASH_REMATCH[1]}"
            cleaned="${cleaned%%$year*}($year)" # Keep everything before the year and format it
        fi
    fi

    # Convert to Title Case (capitalize first letter of each word)
    cleaned=$(echo "$cleaned" | awk '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')

    # Trim extra spaces
    cleaned=$(echo "$cleaned" | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')

    # Construct final filename
    local final_name="$cleaned.$ext"

    # Ensure uniqueness by appending a counter if necessary
    local counter=1
    local dir=$(dirname "$input_name")
    local parent_dir=$(dirname "$dir")
    while [[ -e "$parent_dir/$final_name" ]]; do
        final_name="$cleaned $counter.$ext"
        ((counter++))
    done

    # Move the renamed file up one level
    mv -v -- "$input_name" "$parent_dir/$final_name"
}

# Process folder with media files
process_folder() {
    local folder="$1"
    local parent_folder=$(dirname "$folder")

    # Ensure it's a directory
    if [[ ! -d "$folder" ]]; then
        echo "Error: $folder is not a directory."
        return
    fi

    # Process all files inside the folder
    find "$folder" -type f | while read -r file; do
        if is_media_file "$file"; then
            clean_name "$file"
        else
            echo "Skipping non-media file: $file"
        fi
    done

    # Try to remove the folder if empty
    rmdir "$folder" 2>/dev/null && echo "Deleted empty folder: $folder"
}

# Process each argument
all_files=false  # Flag for -all switch
for item in "$@"; do
    if [[ "$item" == "-all" ]]; then
        all_files=true
        continue
    fi

    if [[ -f "$item" ]]; then
        if $all_files || is_media_file "$item"; then
            clean_name "$item"
        else
            echo "Skipping non-media file: $item"
        fi
    elif [[ -d "$item" ]]; then
        process_folder "$item"
    else
        echo "Skipping: $item (not a valid file or folder)"
    fi
done

