#!/bin/bash

HEADER='#!/bin/bash

if ! command -v mdcat >/dev/null 2>&1; then echo "Install mdcat to render markdown."; fi
WIDTH=$(if [ $(tput cols) -ge 105 ]; then echo 100; else echo $(($(tput cols) - 5)); fi)
mdcat --columns="$WIDTH" <(cat <<'"EOF"'
'

# Color codes
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

MODIFIED_FILES=()
PREVIEW_LINES=()

for file in ./h-*; do
    [[ -f "$file" ]] || continue
    lineno=$(grep -nF '| mdcat |' "$file" | cut -d: -f1 | head -n1)

    if [[ -n "$lineno" ]]; then
        echo -e "${RED}${file}${RESET}"
        echo -e "${YELLOW}--- Removing lines 1 to $lineno ---${RESET}"
        head -n "$lineno" "$file"

        MODIFIED_FILES+=("$file")
    else
        echo -e "${GREEN}${file} — no '| mdcat |' found${RESET}"
    fi
done

if [[ ${#MODIFIED_FILES[@]} -eq 0 ]]; then
    echo "No files to modify."
    exit 0
fi

echo
read -p "Apply these changes? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# Apply changes
for file in "${MODIFIED_FILES[@]}"; do
    lineno=$(grep -nF '| mdcat |' "$file" | cut -d: -f1 | head -n1)
    tail -n +"$((lineno + 1))" "$file" > "${file}.tmp"
    printf "%s\n" "$HEADER" > "$file"
    cat "${file}.tmp" >> "$file"
    rm -f "${file}.tmp"
done

echo "Modifications complete."

