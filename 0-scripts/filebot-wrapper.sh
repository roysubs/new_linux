#!/bin/bash

# === Enhanced FileBot Media Renamer ===
# Description: This script uses FileBot to rename media files (movies or TV shows)
#              based on metadata from online databases. It can perform a dry run
#              to show planned changes or commit the renames.
#
# === USAGE ===
# ./filebot-mymedia.sh <path_to_file_or_folder> [-tv | -film] [-commit] [-lang <language_code>]
#
# Examples:
#   Dry run for a TV show folder: ./filebot-mymedia.sh "/path/to/tv_shows_folder" -tv
#   Commit renames for a movie file: ./filebot-mymedia.sh "/path/to/movie.mkv" -film -commit
#   Dry run for movies in French: ./filebot-mymedia.sh "/path/to/movies_folder" -film -lang fr
#   Process current directory for films: ./filebot-mymedia.sh . -film

# --- Configuration ---
# Default language for metadata lookup (e.g., en, de, fr)
DEFAULT_LANG="en"

# --- Helper Functions ---
print_usage() {
  echo "USAGE: $0 <path_to_file_or_folder> [-tv | -film] [-commit] [-lang <language_code>]"
  echo "Options:"
  echo "  -tv           Set mode to TV shows (uses TheTVDB)."
  echo "  -film         Set mode to films/movies (uses TheMovieDB). Default."
  echo "  -commit       Actually rename/move files. Default is dry run."
  echo "  -lang <xx>    Specify language code for metadata (e.g., 'en', 'fr'). Default: '${DEFAULT_LANG}'."
  echo "Example:"
  echo "  $0 \"/path/to/your/media\" -tv -commit -lang en"
}

check_filebot() {
  if ! command -v filebot &> /dev/null; then
    echo "Error: FileBot command not found."
    echo "Please install FileBot and ensure it's in your system's PATH."
    echo "You can download FileBot from https://www.filebot.net/"
    exit 1
  fi
}

# --- Initial Checks ---
check_filebot

# --- Default Settings ---
MODE="film"       # Default to film mode
DRY_RUN=true      # Default to dry run
LANGUAGE="${DEFAULT_LANG}"
INPUT_PATH=""

# --- Parse Command-Line Arguments ---
if [[ -z "$1" ]]; then
  echo "Error: No input path specified."
  print_usage
  exit 1
fi
INPUT_PATH="$1"
shift # Remove the path from arguments, process options next

while [[ $# -gt 0 ]]; do
  case "$1" in
    -tv)
      MODE="tv"
      shift
      ;;
    -film)
      MODE="film"
      shift
      ;;
    -commit)
      DRY_RUN=false
      shift
      ;;
    -lang)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: -lang option requires a language code (e.g., 'en', 'fr')."
        print_usage
        exit 1
      fi
      LANGUAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# --- Validate Input Path and Resolve to Absolute Path ---
ORIGINAL_INPUT_PATH="$INPUT_PATH" # Keep original for messages

# Check initial existence
if [[ ! -e "$INPUT_PATH" ]]; then
  echo "Error: Initial input path '$INPUT_PATH' does not exist."
  exit 1
fi

# If not an absolute path, resolve it
if ! [[ "$INPUT_PATH" = /* ]]; then
    # Use readlink -f to get the canonical, absolute path.
    # This handles '.', '..', symlinks, and relative paths robustly.
    RESOLVED_PATH=$(readlink -f "$INPUT_PATH")
    if [[ $? -eq 0 && -n "$RESOLVED_PATH" && -e "$RESOLVED_PATH" ]]; then # Check command success, non-empty output, and existence
        INPUT_PATH="$RESOLVED_PATH"
    else
        # Fallback if readlink -f fails or resolved path doesn't exist (e.g. broken symlink)
        echo "Warning: 'readlink -f' failed or could not resolve '$ORIGINAL_INPUT_PATH' to an existing absolute path. Attempting simpler fallback."
        if [[ "$ORIGINAL_INPUT_PATH" == "." ]]; then
            INPUT_PATH="$(pwd)"
        elif [[ "$ORIGINAL_INPUT_PATH" == ".." ]]; then
            INPUT_PATH="$(cd ".." && pwd)"
        elif [[ -d "$ORIGINAL_INPUT_PATH" ]]; then # If it's a directory
            INPUT_PATH="$(cd "$ORIGINAL_INPUT_PATH" && pwd)"
        elif [[ -f "$ORIGINAL_INPUT_PATH" ]]; then # If it's a file
            ABS_DIR="$(cd "$(dirname "$ORIGINAL_INPUT_PATH")" && pwd)"
            FILENAME="$(basename "$ORIGINAL_INPUT_PATH")"
            INPUT_PATH="$ABS_DIR/$FILENAME"
        else
            echo "Error: Could not resolve relative path '$ORIGINAL_INPUT_PATH' to an absolute path via fallback."
            echo "Please ensure the path is correct or 'readlink -f' is available and works."
            exit 1
        fi
    fi
fi

# After attempting to resolve, re-check existence of the final INPUT_PATH.
if [[ ! -e "$INPUT_PATH" ]]; then
  echo "Error: Resolved input path '$INPUT_PATH' (from original '$ORIGINAL_INPUT_PATH') does not exist or is invalid."
  exit 1
fi


# --- Determine Metadata Database and Naming Format ---
# For more format options, see: https://www.filebot.net/naming.html
if [[ "$MODE" == "tv" ]]; then
  DB="TheTVDB"
  # Example TV Show Format: Show Name/Season 01/Show Name - S01E01 - Episode Title.ext
  FORMAT="{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}"
else # film mode
  DB="TheMovieDB"
  # Example Movie Format: Movie Name (Year)/Movie Name (Year).ext
  # For a flatter structure, just use "{n} ({y})"
  FORMAT="{n} ({y})/{n} ({y})"
fi

# --- Determine FileBot Action ---
ACTION="test" # Default to test (dry run)
ACTION_DESC="[DRY RUN]"
if [[ "$DRY_RUN" == false ]]; then
  ACTION="move" # Use 'move' for renaming and organizing
  ACTION_DESC="[COMMIT MODE]"
fi

# --- Display Operation Summary ---
echo "-------------------------------------"
echo " FileBot Media Renamer"
echo "-------------------------------------"
echo "Mode: ${MODE}"
echo "Action: ${ACTION_DESC}"
echo "Input Path (Original): ${ORIGINAL_INPUT_PATH}"
echo "Input Path (Resolved): ${INPUT_PATH}"
echo "Language: ${LANGUAGE}"
echo "Database: ${DB}"
echo "Format: ${FORMAT}"
echo "-------------------------------------"

# --- Confirmation for Commit Mode ---
if [[ "$DRY_RUN" == false ]]; then
  read -r -p "You are in COMMIT mode. Files will be renamed/moved. Continue? (yes/no): " CONFIRMATION
  if [[ "${CONFIRMATION,,}" != "yes" ]]; then # Convert to lowercase for case-insensitive comparison
    echo "Operation cancelled by user."
    exit 0
  fi
  echo "Proceeding with renaming..."
else
  echo "This is a DRY RUN. No files will be changed."
  echo "Showing planned renames only..."
fi

# --- Build and Execute FileBot Command ---
# Common options:
# -rename       : The primary action for renaming files.
# --db          : Specifies the database (TheTVDB, TheMovieDB, AniDB, etc.).
# --format      : Defines the output naming scheme.
# --action      : 'test' (dry run), 'move' (rename and move), 'copy', 'symlink', etc.
# -non-strict   : Enables more lenient matching of files.
# --lang        : Sets the preferred language for metadata.
# --output      : Defines the output directory. If renaming within the same structure,
#                 this is often the same as the input directory for folders.
# --conflict    : 'auto' (default, skip), 'override', 'fail'. Consider 'skip' or 'override'.
# -r or --recursive : FileBot processes directories recursively by default for -rename.

# Base FileBot command
FILEBOT_CMD=(
  filebot -rename
  "${INPUT_PATH}" # Now using the resolved, absolute path
  --db "${DB}"
  --format "${FORMAT}"
  --action "${ACTION}"
  --lang "${LANGUAGE}"
  -non-strict
  --conflict auto # Automatically skip if files conflict, or use 'override'
)

# If input is a directory, specify output to keep it organized.
# If the resolved INPUT_PATH is a directory, FileBot will create subdirectories
# within this INPUT_PATH based on the format string.
if [[ -d "$INPUT_PATH" ]]; then
  FILEBOT_CMD+=(--output "${INPUT_PATH}")
fi

# Execute the command
echo "Executing FileBot command:"
# Print the command for debugging, ensuring proper quoting
printf "%q " "${FILEBOT_CMD[@]}"
echo # Newline
echo "-------------------------------------"

"${FILEBOT_CMD[@]}"

# --- Completion Message ---
echo "-------------------------------------"
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run complete. Review the output above to see what changes would be made."
else
  echo "FileBot operation complete."
  echo "Please check your files in '${INPUT_PATH}' (originally '${ORIGINAL_INPUT_PATH}')."
fi
echo "-------------------------------------"

exit 0

