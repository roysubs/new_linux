#!/bin/bash

set -e  # Exit on error

# ---- 🛠️ Config ----
TARGET_PATH="$1"

if [[ -z "$TARGET_PATH" ]]; then
    echo "
Usage: $(basename $0) <path-to-remove-from-history>

Sometimes, junk or personal files will get trapped in the git history. These will
bloat the size of .git in the project root. This script will prune any unwanted
large files from the repository history and so help to manage the size of the .git
dir in the project root.

To view largest objects in history:

git rev-list --objects --all | \\
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \\
  grep '^blob' | \\
  sort -k3 -n -r | \\
  head -n 20 | \\
  awk '{printf \"%.2f MB\\t%s\\t%s\\n\", \$3/1048576, \$2, \$4}'

To view blobs that contain 'string' in the name of the file:

function git_search_name_history() { echo \"Searching history for filename: '\$1'...\"; git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' | awk -v search_string=\"\$1\" '/^blob/ && \$3 ~ search_string { print \"Found in path: \" \$3 \" Blob hash: \" \$2 }'; echo \"Search complete.\"; }

To view blobs that contain 'string' in the contents of the file:

function git_search_content_history() { echo "Searching history for content: '$1' \(This may take a while\)..."; git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' | grep '^blob' | while read type hash path; do if git cat-file -p \"\$hash\" | grep -q \"\$1\"; then echo \"Found in blob: \$hash Path(s): \$path\"; fi; done; echo \"Search complete.\"; }

"

# function git_search_name_history() { echo "Searching history for filename: '$1'..."; git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' | awk -v search_string="$1" '/^blob/ && $3 ~ search_string { print "Found in path: " $3 " Blob hash: " $2 }'; echo "Search complete."; }

# function git_search_content_history() { echo "Searching history for content: '$1' (This may take a while)..."; git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' | grep '^blob' | while read type hash path; do if git cat-file -p "$hash" | grep -q "$1"; then echo "Found in blob: $hash Path(s): $path"; fi; done; echo "Search complete."; }

    exit 1
fi

if ! command -v git-filter-repo &> /dev/null; then
    echo "❌ git-filter-repo is not installed."
    echo "Install it via: sudo apt install git-filter-repo"
    exit 1
fi

if [ ! -d .git ]; then
    echo "❌ This is not a Git repository."
    exit 1
fi

# ---- 📦 Backup Git config ----
echo "📦 Backing up .git/config..."
cp .git/config .git/config.backup

# ---- 🧼 Remove path from history ----
echo "🧹 Removing '$TARGET_PATH' from Git history..."
git filter-repo --path "$TARGET_PATH" --invert-paths

# ---- 🔄 Restore remote config ----
echo "♻️ Restoring Git remote config..."
cp .git/config.backup .git/config

# ---- 🧽 Cleanup ----
echo "🧽 Cleaning up reflog and garbage..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# ---- ☁️ Force Push ----
echo "🚀 Force pushing to remote..."
git push origin --force --all
git push origin --force --tags

echo "✅ Done. '$TARGET_PATH' has been removed from Git history."

