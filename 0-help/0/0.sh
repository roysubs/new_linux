#!/usr/bin/env bash

set -euo pipefail

header='#!/bin/bash

if ! command -v mdcat >/dev/null 2>&1; then echo "Install mdcat to render markdown."; fi
WIDTH=$(if [ $(tput cols) -ge 105 ]; then echo 100; else echo $(($(tput cols) - 5)); fi)
mdcat --columns="$WIDTH" <(cat <<'"EOF"'
'

for file in ./h-*; do
  [[ -f "$file" && -x "$file" ]] || continue

  tmpfile=$(mktemp)

  # Remove everything up to and including the first line exactly matching '| mdcat |'
  awk '/^\| mdcat \|$/ {found=1; next} !found {next} {print}' "$file" > "$tmpfile.body"

  # Prepend header
  {
    printf "%s" "$header"
    cat "$tmpfile.body"
  } > "$tmpfile"

  mv "$tmpfile" "$file"
  chmod +x "$file"
done

