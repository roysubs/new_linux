#!/bin/bash

echo "📂 Scanning files in your home directory... (this may take a moment)"
before=$(mktemp)
after=$(mktemp)

find ~ -type f -printf '%T@ %p\n' 2>/dev/null | sort > "$before"

echo ""
echo "🕹️  Launching Angband now. Play a bit, then exit the game normally."
read -p "Press Enter to launch Angband..."
angband

echo ""
echo "🔍 Scanning again to detect new/changed files..."
find ~ -type f -printf '%T@ %p\n' 2>/dev/null | sort > "$after"

echo ""
echo "📄 Files created or modified since you started Angband:"
comm -13 "$before" "$after" | cut -d' ' -f2- | uniq

# Clean up
rm "$before" "$after"

