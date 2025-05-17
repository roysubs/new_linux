#!/usr/bin/env bash
# shell-conflicts.sh - Scan for shell command conflicts under ~/new_linux

set -euo pipefail
shopt -s nullglob

SEARCH_DIR="${1:-$HOME/new_linux}"
echo "🔍 Scanning directory: $SEARCH_DIR"

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

# Collect all candidate scripts
mapfile -t script_files < <(find "$SEARCH_DIR" -type f -executable -o -name '*.sh')

printf "\n%-10s | %-20s | %s\n" "STATUS" "COMMAND" "SOURCE"
printf -- "-----------|----------------------|------------------------------\n"

for script in "${script_files[@]}"; do
  cmdname="$(basename "$script")"

  # Only test plausible shell commands (no extensions or very long names)
  [[ "$cmdname" =~ ^[a-zA-Z0-9_-]{1,20}$ ]] || continue

  status=""
  where=""
  # Use type -a to look for all instances
  mapfile -t matches < <(type -a "$cmdname" 2>/dev/null || true)

  if [[ ${#matches[@]} -eq 0 ]]; then
    status="${GREEN}SAFE${RESET}"
    where="not found in shell"
  else
    # Check if it's something problematic
    for m in "${matches[@]}"; do
      if [[ "$m" == *"is a shell builtin"* ]]; then
        status="${RED}BUILTIN${RESET}"
        where="$m"
        break
      elif [[ "$m" == *"is a function"* ]]; then
        status="${YELLOW}FUNCTION${RESET}"
        where="$m"
        break
      elif [[ "$m" == *"is an alias"* ]]; then
        status="${YELLOW}ALIAS${RESET}"
        where="$m"
        break
      elif [[ "$m" == *"$script"* ]]; then
        status="${GREEN}OK (yours)${RESET}"
        where="already resolved to your script"
        break
      else
        status="${RED}CLASH${RESET}"
        where="$m"
        break
      fi
    done
  fi

  printf "%-10s | %-20s | %s\n" "$status" "$cmdname" "$where"
done

