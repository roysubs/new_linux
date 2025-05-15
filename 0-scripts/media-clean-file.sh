#!/bin/bash

echo "Auto-rename media files to remove junk text and format as a proper name."

# List of supported media file extensions
media_extensions=("mkv" "avi" "mp3" "mp4" "cbr" "cbz" "mov" "flv" "wmv" "webm" "mpg" "mpeg" "jpg" "png" "gif")
# Fast junk pattern list to strip from filenames (more specific terms go into the db file below)
junk_pattern='\b(HDRip|HDCAM|BluRay|WEBRip|WEB[- ]DL|DVDRip|x264|XviD|TGx|YIFY|RARBG|PROPER|REPACK|EXTENDED|UNRATED|REMUX|IMAX|NF|Galaxytv|720p|1080p|2160p|4K)\b'

# Path to junk terms database (next to script)
script_path="$(realpath "$0")"
script_dir="$(dirname "$script_path")"
script_name="$(basename "$script_path")"
script_base="${script_name%.*}"
junk_db="$script_dir/${script_base}.db"

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    echo -e "\nUsage: $(basename "$0") <file-or-dir> [junk_term1 junk_term2 ...]"
    echo -e "\nExamples:"
    echo "  $(basename "$0") my.video.file.mkv"
    echo "  $(basename "$0") show.s02e03.1080p.hdtv.mkv crapgroup"
    echo -e "\nEach junk term you provide is added to the DB for future removals."
    exit 1
fi

# Extract all junk terms (if more than 1 arg)
input_path="$1"
shift
if [[ $# -gt 0 ]]; then
    for junk_term in "$@"; do
        echo "$junk_term" >> "$junk_db"
        echo "Appended '$junk_term' to junk DB: $junk_db"
    done
fi

# Load junk terms from db
readarray -t junk_terms < <(grep -v '^#' "$junk_db" 2>/dev/null)

# Function to check if file has a media extension
is_media_file() {
    local ext="${1##*.}"
    ext="${ext,,}"
    for media_ext in "${media_extensions[@]}"; do
        if [[ "$ext" == "$media_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Clean filename
clean_name() {
    local input_name="$1"
    local dir=$(dirname "$input_name")
    local fname=$(basename "$input_name")
    local base_name="${fname%.*}"
    local ext="${fname##*.}"
    ext="${ext,,}"

    local cleaned="${base_name//./ }"
    cleaned="${cleaned//_/ }"
    cleaned="${cleaned//-/ }"

    # Remove hardcoded junk tags
    cleaned=$(echo "$cleaned" | sed -E "s/$junk_pattern//gi")

    # Remove user-defined junk terms from db file
    for junk in "${junk_terms[@]}"; do
        [[ -z "$junk" ]] && continue
        cleaned=$(echo "$cleaned" | sed -E "s/\b$junk\b//gi")
    done

    # Convert to Title Case
    cleaned=$(echo "$cleaned" | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')

    # Force SxxEyy to uppercase: S02e03 -> S02E03
    cleaned=$(echo "$cleaned" | sed -E 's/\b(S[0-9]{2})[eE]([0-9]{2})\b/\U\1E\2/g')

    # Format year if present
    if [[ $cleaned =~ ([12][0-9]{3}) ]]; then
        local year="${BASH_REMATCH[1]}"
        cleaned="${cleaned%%$year*}($year)"
    fi

    # Trim spaces
    cleaned=$(echo "$cleaned" | sed 's/  */ /g; s/^ *//; s/ *$//')

    # Final name
    local final_name="$cleaned.$ext"
    if [[ "$final_name" != "$fname" ]]; then
        if [[ -e "$dir/$final_name" ]]; then
            local counter=1
            while [[ -e "$dir/$cleaned $counter.$ext" ]]; do
                ((counter++))
            done
            final_name="$cleaned $counter.$ext"
        fi
        mv -v -- "$input_name" "$dir/$final_name"
    else
        echo "No rename needed: $fname"
    fi
}

# Process directory
process_folder() {
    local folder="$1"
    if [[ ! -d "$folder" ]]; then
        echo "Error: $folder is not a directory."
        return
    fi

    find "$folder" -type f | while IFS= read -r file; do
        if is_media_file "$file"; then
            clean_name "$file"
        else
            echo "Skipping non-media file: $file"
        fi
    done

    rmdir "$folder" 2>/dev/null && echo "Deleted empty folder: $folder"
}

# Process arguments
if [[ -f "$input_path" ]]; then
    if is_media_file "$input_path"; then
        clean_name "$input_path"
    else
        echo "Skipping non-media file: $input_path"
    fi
elif [[ -d "$input_path" ]]; then
    process_folder "$input_path"
else
    echo "Skipping: $input_path (not a valid file or folder)"
fi
