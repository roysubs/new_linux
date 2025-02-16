#!/bin/bash
set -e

# echo "$(basename $0)"
echo "Update a Git repository directory so that all files match the timestamps on the remote."
echo "A default 'git clone' will set all files to the same current timestamp instead of the"
echo "last modified timestamp on the remote repository."

# Ensure we are in the root of a Git project
if [[ ! -d .git ]]; then
  echo
  echo "Error: This script must be run in the root of a Git repository."
  exit 1
fi

# Check if the local repo differs from the remote
REMOTE_STATUS=$(git remote update >/dev/null 2>&1 && git status -uno --porcelain=v2)

if [[ -n "$REMOTE_STATUS" ]]; then
  echo "Warning: Your local repository differs from the remote."
  echo "Changes:"
  git status -s
  echo
  read -p "Do you want to continue updating timestamps? (y/n) " -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  fi
fi

# Restore timestamps
echo "Updating file timestamps..."
git ls-files -z | while IFS= read -r -d '' file; do
  touch -d "$(git log -1 --format="@%ct" -- "$file")" "$file"
done

echo "Timestamps updated successfully."

