#!/bin/bash

# Get the directory where the script itself is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Get the script's filename without path
SCRIPT_FILENAME_WITH_EXT="${0##*/}"

# Remove the extension to get the base name
SCRIPT_BASENAME="${SCRIPT_FILENAME_WITH_EXT%.*}"

# Construct the full path to the .md file, assuming it's in the same dir as the script
MARKDOWN_FILE_PATH="${SCRIPT_DIR}/${SCRIPT_BASENAME}.md"

# --- Your existing mdcat setup ---
# Ensure mdcat-get.sh is also called relative to script dir if needed
command -v mdcat &>/dev/null || "${SCRIPT_DIR}/mdcat-get.sh"; hash -r # Assuming mdcat-get.sh is with README.sh
command -v mdcat &>/dev/null || { echo "Error: mdcat required but not available." >&2; exit 1; }
WIDTH=$(if [ $(tput cols) -ge 105 ]; then echo 100; else echo $(( $(tput cols) - 5 )); fi)

# --- Check if the markdown file exists ---
if [[ ! -f "${MARKDOWN_FILE_PATH}" ]]; then
    echo "Error: Markdown file not found at ${MARKDOWN_FILE_PATH}" >&2
    # You can add a 'pwd' here for more debugging if you want:
    # echo "Current working directory: $(pwd)" >&2
    exit 1
fi

# --- Use the robust path to the markdown file ---
mdcat --columns="$WIDTH" <(cat "${MARKDOWN_FILE_PATH}") | less -R
