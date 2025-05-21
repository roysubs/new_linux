#!/bin/bash

# -----------------------------------------------------------------------------
# media-clean-file.sh - Clean media filenames by removing junk text
# -----------------------------------------------------------------------------

# Default configuration
DRY_RUN=true
RECURSIVE=false
VERBOSE=false

# List of supported media file extensions
media_extensions=("mkv" "avi" "mp3" "mp4" "cbr" "cbz" "mov" "flv" "wmv" "webm" 
                 "mpg" "mpeg" "jpg" "png" "gif" "m4v" "m4a" "ogg" "flac" "wav")

# Common junk patterns to strip from filenames
junk_pattern='\b(HDRip|HDCAM|BluRay|WEBRip|WEB[- ]DL|DVDRip|x264|XviD|TGx|YIFY|RARBG|PROPER|REPACK|EXTENDED|UNRATED|REMUX|IMAX|NF|Galaxytv|720p|1080p|2160p|4K|HECV|x265-ELiTE|x265|AAC|AC3|AMZN|DD5\.1|HDTV)\b'

# Get script directory and prepare paths
script_path="$(realpath "$0")"
script_dir="$(dirname "$script_path")"
script_name="$(basename "$script_path")"
script_base="${script_name%.*}"
junk_db="$script_dir/${script_base}.db"

# Create DB file if it doesn't exist
if [[ ! -f "$junk_db" ]]; then
    echo "# Junk terms database - one term per line" > "$junk_db"
    echo "# Lines starting with # are comments" >> "$junk_db"
    echo "# Example:" >> "$junk_db"
    echo "EVO" >> "$junk_db"
    echo "ettv" >> "$junk_db"
    echo "EZTV" >> "$junk_db"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Function definitions
# -----------------------------------------------------------------------------

# Display help message
show_help() {
    echo -e "${BLUE}Media Filename Cleaner${NC}"
    echo -e "Automatically renames media files to remove junk text and format properly.\n"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $(basename "$0") [options] <file-or-directory> [junk_term1 junk_term2 ...]\n"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -h, --help      Show this help message"
    echo -e "  -c, --commit    Actually perform rename operations (default: dry-run)"
    echo -e "  -r, --recurse   Process directories recursively"
    echo -e "  -v, --verbose   Show detailed information\n"
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  # Show what would be renamed (dry run):"
    echo -e "  $(basename "$0") ./my.video.file.mkv"
    echo -e "  $(basename "$0") ~/Downloads/Movies\n"
    echo -e "  # Actually rename files:"
    echo -e "  $(basename "$0") -c ./movie.folder/\n"
    echo -e "  # Process all media files in directory tree:"
    echo -e "  $(basename "$0") -c -r ~/Downloads/Series\n"
    echo -e "  # Add terms to junk database and process files:"
    echo -e "  $(basename "$0") ~/Videos JoeBobGroup release.group\n"
    echo -e "${YELLOW}Notes:${NC}"
    echo -e "  - Each junk term provided after the file/dir is added to the DB"
    echo -e "  - Junk DB location: ${junk_db}"
    exit 0
}

# Check if a file has a media extension
is_media_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}" # Convert to lowercase
    
    for media_ext in "${media_extensions[@]}"; do
        if [[ "$ext" == "$media_ext" ]]; then
            return 0
        fi
    done
    return 1
}

# Clean a filename
clean_name() {
    local input_path="$1"
    local dir=$(dirname "$input_path")
    local fname=$(basename "$input_path")
    local base_name="${fname%.*}"
    local ext="${fname##*.}"
    ext="${ext,,}" # Convert to lowercase
    
    # Replace dots, underscores, and hyphens with spaces
    local cleaned="${base_name//./ }"
    cleaned="${cleaned//_/ }"
    cleaned="${cleaned//-/ }"
    
    # Remove hardcoded junk tags
    cleaned=$(echo "$cleaned" | sed -E "s/$junk_pattern//gi")
    
    # Remove user-defined junk terms from DB
    for junk in "${junk_terms[@]}"; do
        [[ -z "$junk" ]] && continue
        cleaned=$(echo "$cleaned" | sed -E "s/\b$junk\b//gi")
    done
    
    # Format season/episode to uppercase: s01e02 -> S01E02
    cleaned=$(echo "$cleaned" | sed -E 's/\b([sS])([0-9]{1,2})[eE]([0-9]{1,2})\b/\U\1\2E\3/g')
    
    # Convert to Title Case
    cleaned=$(echo "$cleaned" | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)); print}')
    
    # Format year if present: Show Name 2022 -> Show Name (2022)
    if [[ $cleaned =~ ([12][0-9]{3}) ]]; then
        local year="${BASH_REMATCH[1]}"
        # Only format if the year is a standalone component
        if [[ $cleaned =~ ([[:space:]]|^)$year([[:space:]]|$) ]]; then
            cleaned=$(echo "$cleaned" | sed -E "s/\b$year\b/($year)/g")
        fi
    fi
    
    # Remove multiple spaces and trim
    cleaned=$(echo "$cleaned" | sed -E 's/[ ]+/ /g' | sed -E 's/^[ ]+|[ ]+$//g')
    
    # Construct the final filename
    local final_name="$cleaned.$ext"
    
    # Handle case where final name already exists
    if [[ -e "$dir/$final_name" && "$fname" != "$final_name" ]]; then
        local counter=1
        while [[ -e "$dir/$cleaned $counter.$ext" ]]; do
            ((counter++))
        done
        final_name="$cleaned $counter.$ext"
    fi
    
    # Return the rename information
    if [[ "$fname" != "$final_name" ]]; then
        if $VERBOSE; then
            echo -e "${input_path} ${YELLOW}=>${NC} ${final_name}"
        else
            echo -e "${input_path} ${YELLOW}=>${NC} ${final_name}"
        fi
        
        # Perform the rename if not in dry-run mode
        if ! $DRY_RUN; then
            if mv -- "$input_path" "$dir/$final_name"; then
                if $VERBOSE; then
                    echo -e "${GREEN}✓ Renamed${NC}"
                fi
            else
                echo -e "${RED}✗ Failed to rename${NC}"
                return 1
            fi
        fi
        return 0
    else
        if $VERBOSE; then
            echo -e "${BLUE}No changes needed:${NC} $input_path"
        fi
        return 1
    fi
}

# Process a directory
process_directory() {
    local dir="$1"
    local count_processed=0
    local count_renamed=0
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Error: '$dir' is not a directory${NC}"
        return 1
    fi
    
    if $VERBOSE; then
        echo -e "${BLUE}Processing directory:${NC} $dir"
    fi
    
    # Find command differs based on recursion setting
    if $RECURSIVE; then
        find_cmd=("find" "$dir" "-type" "f")
    else
        find_cmd=("find" "$dir" "-maxdepth" "1" "-type" "f")
    fi
    
    # Process files
    while IFS= read -r file; do
        if is_media_file "$file"; then
            ((count_processed++))
            clean_name "$file" && ((count_renamed++))
        elif $VERBOSE; then
            echo -e "${BLUE}Skipping non-media file:${NC} $file"
        fi
    done < <("${find_cmd[@]}" | sort)
    
    if $VERBOSE; then
        echo -e "${BLUE}Directory summary:${NC} Processed $count_processed files, $count_renamed need renaming"
    fi
    
    return 0
}

# Handle a single file
process_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: '$file' is not a file${NC}"
        return 1
    fi
    
    if is_media_file "$file"; then
        clean_name "$file"
    elif $VERBOSE; then
        echo -e "${BLUE}Skipping non-media file:${NC} $file"
    else
        echo -e "${YELLOW}Skipping non-media file:${NC} $file"
    fi
    
    return 0
}

# Add terms to junk database
add_junk_terms() {
    local terms=("$@")
    local added=0
    
    for term in "${terms[@]}"; do
        if [[ -z "$term" ]]; then
            continue
        fi
        
        # Check if term already exists in db
        if grep -q "^$term$" "$junk_db" 2>/dev/null; then
            echo -e "${BLUE}Term already in database:${NC} $term"
        else
            echo "$term" >> "$junk_db"
            echo -e "${GREEN}Added to junk database:${NC} $term"
            ((added++))
        fi
    done
    
    if [[ $added -gt 0 ]]; then
        echo -e "${GREEN}Added $added terms to:${NC} $junk_db"
    fi
}

# -----------------------------------------------------------------------------
# Main script execution
# -----------------------------------------------------------------------------

# Parse command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -c|--commit)
            DRY_RUN=false
            shift
            ;;
        -r|--recurse)
            RECURSIVE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option:${NC} $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"

# Check if we have at least one argument
if [[ $# -eq 0 ]]; then
    show_help
fi

# Extract target path
target_path="$1"
shift

# Expand path if it starts with ~ (home directory)
if [[ "$target_path" == "~/"* ]]; then
    target_path="${HOME}${target_path:1}"
fi

# Handle paths like ./ or ../
target_path=$(realpath -m "$target_path")

# Process any junk terms provided
if [[ $# -gt 0 ]]; then
    add_junk_terms "$@"
fi

# Load junk terms from database
readarray -t junk_terms < <(grep -v '^#' "$junk_db" 2>/dev/null)

# Display mode information
if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN MODE${NC} - No files will be renamed"
    echo -e "Use ${GREEN}-c${NC} or ${GREEN}--commit${NC} to perform actual renames\n"
else
    echo -e "${GREEN}COMMIT MODE${NC} - Files will be renamed\n"
fi

# Process the target path
if [[ -f "$target_path" ]]; then
    process_file "$target_path"
elif [[ -d "$target_path" ]]; then
    process_directory "$target_path"
else
    echo -e "${RED}Error:${NC} '$target_path' is not a valid file or directory"
    exit 1
fi

# Final summary
if $DRY_RUN; then
    echo -e "\n${YELLOW}Dry run complete.${NC} Use ${GREEN}-c${NC} or ${GREEN}--commit${NC} to perform actual renames"
else
    echo -e "\n${GREEN}Rename operations complete.${NC}"
fi

exit 0
