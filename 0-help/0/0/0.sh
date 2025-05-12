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

  # Use awk to skip everything up to and including the first "| mdcat |" line
  awk 'found {print} /\| mdcat \|/ {found=1}' "$file" > "$tmpfile.body"

  # Only proceed if "| mdcat |" was found
  if [[ -s "$tmpfile.body" ]]; then
    {
      printf "%s" "$header"
      cat "$tmpfile.body"
    } > "$tmpfile"

    mv "$tmpfile" "$file"
    chmod +x "$file"
  else
    echo "Skipping $file — no '| mdcat |' found"
    rm -f "$tmpfile" "$tmpfile.body"
  fi
done

