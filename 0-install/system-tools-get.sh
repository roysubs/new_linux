#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
INSTALL_DIR="/usr/local/bin"
TMP_DIR="/tmp/sys-tools-install"
mkdir -p "$TMP_DIR"
declare -A tools=(
  [punfetch]="ozwaldorf/punfetch|Minimalist system fetch tool with puns."
  [onefetch]="o2sh/onefetch|Git repository summary in your terminal."
  [gdu]="dundee/gdu|Fast disk usage analyzer."
  [dust]="bootandy/dust|More intuitive du.
"
  [bottom]="ClementTsang/bottom|Graphical process/system monitor."
  [procs]="dalance/procs|Improved ps command."
  [xh]="ducaale/xh|Friendlier curl replacement."
  [btop]="aristocratos/btop|Modern resource monitor."
)

# --- DEPENDENCY CHECK ---
echo "\n🔍 Checking required commands..."
for cmd in curl grep sed tar find sudo; do
  if ! command -v "$cmd" >/dev/null; then
    echo "❌ Required command '$cmd' not found. Aborting."
    exit 1
  fi
  echo "✔ $cmd found"
done

# --- FUNCTIONS ---
get_latest_version() {
  local repo="$1"
  local api_response
  api_response=$(curl -sL "https://api.github.com/repos/$repo/releases/latest") || return 1
  echo "$api_response" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/'
}

get_installed_version() {
  local tool="$1"
  if command -v "$tool" >/dev/null; then
    "$tool" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "0.0.0"
  else
    echo "none"
  fi
}

compare_versions() {
  # returns 0 if $1 is older than $2
  [ "$1" = "none" ] && return 0
  [ "$1" = "$2" ] && return 1
  [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$2" ] && return 1 || return 0
}

install_tool() {
  local tool="$1"
  local repo="$2"
  local latest_ver="$3"

  echo "⬇ Downloading $tool $latest_ver..."
  local url="https://github.com/$repo/releases/download/v$latest_ver/${tool}-${latest_ver}-x86_64.tar.gz"
  local archive="$TMP_DIR/$tool.tar.gz"

  if ! curl -fsSL "$url" -o "$archive"; then
    echo "⚠ Failed to download $url"
    return 1
  fi

  echo "📦 Extracting and installing $tool..."
  tar -xzf "$archive" -C "$TMP_DIR"
  local bin_path
  bin_path=$(find "$TMP_DIR" -type f -name "$tool" | head -n1)
  if [ -n "$bin_path" ]; then
    sudo mv "$bin_path" "$INSTALL_DIR/$tool"
    sudo chmod +x "$INSTALL_DIR/$tool"
    echo "✅ Installed $tool to $INSTALL_DIR"
  else
    echo "❌ Failed to find $tool binary after extraction"
  fi
}

# --- MAIN ---
echo -e "\n⚙ Installing/Updating tools...\n"
declare -A summary=()

for tool in "${!tools[@]}"; do
  IFS='|' read -r repo desc <<< "${tools[$tool]}"
  echo "🔧 Checking $tool..."
  latest_ver=$(get_latest_version "$repo") || {
    echo "⚠ Could not fetch version for $tool"
    summary[$tool]="❌ Failed to fetch version"
    continue
  }
  current_ver=$(get_installed_version "$tool")
  if compare_versions "$current_ver" "$latest_ver"; then
    install_tool "$tool" "$repo" "$latest_ver"
    summary[$tool]="✅ Installed/Updated to $latest_ver"
  else
    echo "⏩ $tool already up to date ($current_ver)"
    summary[$tool]="⏩ Already at $current_ver"
  fi
  echo
done

# --- SUMMARY ---
echo -e "\n📋 Summary:\n"
for tool in "${!summary[@]}"; do
  printf "%-10s: %s\n" "$tool" "${summary[$tool]}"
done
