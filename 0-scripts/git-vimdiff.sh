#!/bin/bash

#!/bin/bash

# gitdiff.sh
# Compares the current version of a file with a historical version using vimdiff.
# Includes logic to follow file renames in history.
# Usage: gitdiff.sh <filename> <HEAD-ref_number>
# Example: gitdiff.sh myscript.sh 3  (Compares myscript.sh with HEAD~3 version)

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BG_RED='\033[41m'    # Red Background
BG_GREEN='\033[42m'  # Green Background
BG_CYAN='\033[46m'   # Cyan Background
NC='\033[0m'         # No Color

# --- Input Validation ---

# Check if exactly two arguments are provided
if [ "$#" -ne 2 ]; then
    echo
    echo "Compare a current file with a previous version from its git history. In git syntax,"
    echo "HEAD~1 is the last committed version of the script (not just the last commit in general"
    echo "but the last time that this file was committed). HEAD~3 is 3rd commit ago, etc."
    echo
    echo -e "Usage: ${GREEN}${0##*/} <filename> <HEAD-ref_number>${NC}"   # Use ${0##*/} instead of $(basename $0) as basename not always present
    echo
    echo -e "Example: ${GREEN}${0##*/} myscript.sh 3${NC}   # Compare the latest with the 3rd most recent commit"
    echo
    echo "The following is used to get a list of all commit hashes in the history that"
    echo "affected the given \$filename, following renames with a 40% similarity threshold:"
    echo -e "${GREEN}git log --follow --find-renames=40% --pretty=format:\"%H\" -- \"\$filename\"${NC}"
    echo "By taking the Nth commit hash from this list (where N is your head_ref_num), we get the"
    echo "precise commit hash where the file was in its HEAD~N state relative to its own history."
    echo
    exit 1
fi

filename="$1"
head_ref_num="$2"
git_ref="HEAD~$head_ref_num" # Construct the initial Git reference string

# --- Git Repository Check ---

# Check if the current directory is inside a Git repository
git_toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Not in a Git repository."
    exit 1
fi

# --- File Information (Current) ---

# Get the path of the file relative to the Git toplevel directory
# This is needed for 'git show' to reference the file in history
git_file_path_current=$(git ls-files --full-name --error-unmatch "$filename" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: File '$filename' is not tracked by Git."
    exit 1
fi

# Determine the current status of the file (modified or unmodified)
# git diff --quiet exits with 0 if no changes, non-zero otherwise
if git diff --quiet "$filename"; then
    file_status="unmodified"
else
    file_status="modified"
fi

# Get the size of the current file in a human-readable format
file_size_current=$(du -h "$filename" | awk '{print $1}')

# --- File Information (Historical) ---

# Use git log --follow to find the name of the file at the historical commit,
# even if it was renamed.
# We get the commit hashes affecting the file in reverse chronological order,
# then pick the one corresponding to the requested HEAD~n.
# --find-renames=40% is a common threshold for detecting renames
# --format="%H" gets just the commit hash
# -- "$filename" ensures we only follow the history of this specific file path
historical_commit_hashes=($(git log --follow --find-renames=40% --pretty=format:"%H" -- "$filename" 2>/dev/null))

# Check if the requested HEAD~n is a valid index in the file's history
if [ "${#historical_commit_hashes[@]}" -le "$head_ref_num" ]; then
    echo "Error: The file '$filename' does not have $head_ref_num ancestor commits in its history."
    echo "It might not have existed or been tracked that far back."
    exit 1
fi

# Get the hash of the historical commit that affected this file
historical_commit_hash="${historical_commit_hashes[$head_ref_num]}"

# Get the path of the file at that specific historical commit
# Use git show --name-only --pretty="" <commit-hash> -- <current-filename>
# Git figures out the historical path based on the commit and the current path due to --follow in log
git_file_path_historical=$(git show --name-only --pretty="" "$historical_commit_hash" -- "$filename" 2>/dev/null | head -n 1)

# Get the size of the historical file
# Use git ls-tree -l to get size information for the historical commit and path
# ls-tree output format: <mode> <type> <object> <size> <path>
historical_file_info=$(git ls-tree -l "$historical_commit_hash" -- "$git_file_path_historical" 2>/dev/null)

# Check if historical_file_info is not empty before processing
if [ -n "$historical_file_info" ]; then
    file_size_historical_bytes=$(echo "$historical_file_info" | awk '{print $4}')
    # Check if the size is a valid number before trying to format
    if [[ "$file_size_historical_bytes" =~ ^[0-9]+$ ]]; then
        # Convert size to human-readable if possible, or just show bytes
        if command -v numfmt >/dev/null 2>&1; then
            file_size_historical=$(numfmt --to=iec-i --format="%8.1f" "$file_size_historical_bytes" | xargs)
        else
             file_size_historical="${file_size_historical_bytes} bytes"
        fi
    else
        file_size_historical="N/A (invalid size data)"
    fi
else
    # Fallback if ls-tree fails or returns no info
    file_size_historical="N/A (could not retrieve size)"
fi


# Get the commit date for the specified historical version of the file
# Use git show -s --format=%cd on the historical commit hash for reliability
commit_date=$(git show -s --format=%cd "$historical_commit_hash" 2>/dev/null)
# Format the date if successfully retrieved
if [ -z "$commit_date" ]; then
    # Fallback to git log if git show fails to get the date
    commit_date=$(git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S' "$historical_commit_hash" -- "$git_file_path_historical" 2>/dev/null)
    if [ -z "$commit_date" ]; then
        commit_date="N/A (could not retrieve date)"
    fi
fi


# --- Display Information ---

echo "\"$filename\" (current, $file_status) is $file_size_current"
echo "$git_ref \"$git_file_path_historical\" is $file_size_historical, committed on $commit_date"
echo "--------------------------------------------------"

# --- Prepare Diff Command ---

# Construct the vimdiff command using process substitution to get the historical file content
# 'eval' is used to correctly interpret the process substitution <(...)
# Use the historical commit hash and historical file path found via git log --follow
vimdiff_command="vimdiff \"$filename\" <(git show $historical_commit_hash:\"$git_file_path_historical\")"

# Print the command that will be executed in green
echo "Running command:"
echo -e "${GREEN}$vimdiff_command${NC}" # -e enables interpretation of backslash escapes
echo "--------------------------------------------------"

# --- Vimdiff Navigation Tips and Color Explanation ---

echo "Vimdiff Navigation Tips:"
echo -e "  ${YELLOW}Ctrl+w Ctrl+w${NC}: Switch focus between the left and right panes."
echo -e "  ${YELLOW}zj${NC}: Jump to the next change hunk (a block of changes)."
echo -e "  ${YELLOW}zk${NC}: Jump to the previous change hunk."
echo -e "  ${YELLOW}zo${NC}: Open (unfold) a folded section of text (where lines are identical)."
echo -e "  ${YELLOW}zc${NC}: Close (fold) a section of identical text."
echo -e "  ${YELLOW}zr${NC}: Reduce folding (unfold all hunks in the current window)."
echo -e "  ${YELLOW}zm${NC}: More folding (fold all hunks in the current window)."
echo -e "  ${YELLOW}]c${NC}: Jump to the next change (useful when diffing multiple files)."
echo -e "  ${YELLOW}[c${NC}: Jump to the previous change (useful when diffing multiple files)."
echo ""
echo "Vimdiff Color Explanation (Default):"
echo -e "  ${BG_RED} Red background${NC}: Lines that have been removed in one version compared to the other."
echo -e "  ${BG_GREEN} Green background${NC}: Lines that have been added in one version compared to the other."
echo -e "  ${BG_CYAN} Cyan background${NC}: Lines that are present in both versions but have been modified."
echo "  Highlighted text within cyan lines: The specific text that has changed within a modified line."
echo ""
echo "Advanced Tip: Compare with a different historical version *without* leaving Vim:"
echo "  1. In the historical version's pane (usually the left one)."
# Use the historical_commit_hash found earlier and the current file path for simplicity
echo "  2. Type the command: \`:e <new_git_ref>:<git_file_path>\`"
echo "     For example, to compare with HEAD~4: \`:e HEAD~4:$git_file_path_current\`"
echo "     (Note: Use the *current* git_file_path here for simplicity, Git is smart enough to find the historical version)"
echo "  3. In *both* windows, run \`:diffupdate\` to refresh the diff comparison."
echo "--------------------------------------------------"


# --- Run Diff ---

# Wait for user confirmation before opening vimdiff
read -p "Press Enter to view the diff..."

# Execute the constructed vimdiff command
eval "$vimdiff_command"

