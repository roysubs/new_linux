#!/bin/bash
set -e

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <repository-url> [destination]"
  exit 1
fi

# Clone the repository
git clone "$@"

# Determine the target directory
TARGET_DIR="${@: -1}"  # Last argument
[[ ! -d "$TARGET_DIR/.git" ]] && TARGET_DIR=$(basename "$1" .git)

# Ensure it's a Git repo
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  echo "Error: $TARGET_DIR is not a Git repository."
  exit 1
fi

# Change to the repo directory
cd "$TARGET_DIR"

# Restore timestamps
git ls-files -z | while IFS= read -r -d '' file; do
  touch -d "$(git log -1 --format="@%ct" -- "$file")" "$file"
done

echo "Timestamps updated in $TARGET_DIR."

