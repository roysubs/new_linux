#!/bin/bash

set -e  # Exit on error

# ---- 🛠️ Config ----
TARGET_PATH="$1"

if [[ -z "$TARGET_PATH" ]]; then
    echo "
Usage: $(basename $0) <path-to-remove-from-history>

This will remove large objects (files or dirs) from git history as these will
bloat the size of the .git dir in the project root.

To view largest objects in history:

git rev-list --objects --all | \\
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \\
  grep '^blob' | \\
  sort -k3 -n -r | \\
  head -n 20 | \\
  awk '{printf \"%.2f MB\\t%s\\t%s\\n\", \$3/1048576, \$2, \$4}'
"
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

