#!/bin/bash

# Script to cycle through Vim themes for a given file.

# --- Configuration ---
: "${VIM_EXECUTABLE:=vim}"
DELAY_SECONDS=3
VIM_SERVER_NAME="THEME_CYCLER_$$"

# --- Functions ---
get_vim_themes() {
  local rtp_output
  local vim_cmd_path

  vim_cmd_path=$(command -v "$VIM_EXECUTABLE")
  if [ -z "$vim_cmd_path" ]; then
    echo "Error: Vim executable '$VIM_EXECUTABLE' not found in get_vim_themes." >&2
    return 1
  fi

  rtp_output=$("$vim_cmd_path" -T dumb --clean -es -c "echo &rtp" -c "quitall!" 2>/dev/null)
  if ! echo "$rtp_output" | grep -qE '(^|,)[\./~]'; then
      rtp_output=$("$vim_cmd_path" -T dumb --clean -es --cmd "set rtp?" -c "quitall!" 2>/dev/null | grep '^runtimepath=')
      rtp_output=$(echo "$rtp_output" | sed 's/^runtimepath=//')
  fi

  if [ -z "$rtp_output" ]; then
    echo "Warning: Could not reliably determine Vim's runtime path. Using fallback search." >&2
    local common_paths=(
      "$HOME/.vim" "$HOME/.config/nvim" "/usr/share/vim/vimfiles"
    )
    local vim_runtimes=$(find /usr/share/vim -maxdepth 1 -type d -name "vim[0-9][0-9]" 2>/dev/null)
    common_paths+=($vim_runtimes)
    local found_themes=""
    for p_base in "${common_paths[@]}"; do
      local p_colors="$p_base/colors"
      if [ -d "$p_colors" ]; then
        found_themes+=$(find "$p_colors" -maxdepth 1 -name "*.vim" -type f -printf "%f\n" 2>/dev/null | sed 's/\.vim$//')
        found_themes+=$'\n'
      elif [ -d "$p_base" ] && [[ "$p_base" == */colors ]]; then
         found_themes+=$(find "$p_base" -maxdepth 1 -name "*.vim" -type f -printf "%f\n" 2>/dev/null | sed 's/\.vim$//')
         found_themes+=$'\n'
      fi
    done
    echo "$found_themes" | sort -u | grep -Ev '^\s*$'
    return
  fi

  echo "$rtp_output" | tr ',' '\n' | while IFS= read -r path_entry; do
    local cleaned_path=$(echo "$path_entry" | xargs)
    if [ -n "$cleaned_path" ] && [ -d "$cleaned_path/colors" ]; then
      find "$cleaned_path/colors" -maxdepth 1 -name "*.vim" -type f -printf "%f\n" 2>/dev/null | sed 's/\.vim$//'
    fi
  done | sort -u | grep -Ev '^\s*$'
}

# --- Main Script ---
# set -x # Uncomment for extreme debugging

if [ -z "$1" ]; then
  echo "Usage: $0 <file_to_preview>"
  exit 1
fi

TARGET_FILE="$1"
VIM_CMD_PATH=$(command -v "$VIM_EXECUTABLE")
VIM_SERVER_LOG="/tmp/vim_server_startup_${VIM_SERVER_NAME}.log"
VIM_LAUNCH_PID="" # Initialize

rm -f "$VIM_SERVER_LOG"

if [ ! -f "$TARGET_FILE" ]; then echo "Error: File '$TARGET_FILE' not found."; exit 1; fi
if [ -z "$VIM_CMD_PATH" ]; then echo "Error: Vim executable '$VIM_EXECUTABLE' not found."; exit 1; fi

echo "Checking for Vim features in '$VIM_CMD_PATH'..."
VERSION_OUTPUT=$("$VIM_CMD_PATH" --version)
if ! echo "$VERSION_OUTPUT" | grep -q '+clientserver'; then
  echo "Error: Your Vim ('$VIM_CMD_PATH') is not compiled with +clientserver."; exit 1;
fi
echo "'+clientserver' feature found."

HAS_DAEMON_FEATURE=false
if echo "$VERSION_OUTPUT" | grep -q '+daemon'; then
  HAS_DAEMON_FEATURE=true
  echo "'+daemon' feature found."
else
  echo "'+daemon' feature NOT found. Will use fallback launch method."
fi

echo "🔍 Finding available Vim themes using '$VIM_CMD_PATH'..."
themes=$(get_vim_themes)
if [ -z "$themes" ]; then echo "🚫 No Vim themes found."; exit 1; fi
echo "🎨 Available themes:"
echo "$themes"
echo ""
echo "🚀 Starting Vim theme cycler for '$TARGET_FILE'..."
echo "   Vim server name: $VIM_SERVER_NAME"
echo "   Vim executable: $VIM_CMD_PATH"
echo "   Output from Vim startup attempt will be logged to: $VIM_SERVER_LOG"

if [ "$HAS_DAEMON_FEATURE" = true ]; then
  echo "Attempting to start Vim with --daemon option..."
  # For --daemon, Vim handles backgrounding itself. The initial process might exit.
  "$VIM_CMD_PATH" --daemon --servername "$VIM_SERVER_NAME" "$TARGET_FILE" > "$VIM_SERVER_LOG" 2>&1
  # VIM_LAUNCH_PID is not reliable here as the daemon is a different process.
  # Brief pause for daemon to potentially log initial errors and fork.
  sleep 1
else
  echo "Attempting to start Vim with -f (foreground) and -s /dev/null (no script from stdin)..."
  # -f: run in foreground (Vim's perspective), shell backgrounds with '&'
  # -s /dev/null: explicitly tell Vim to read Ex commands from /dev/null (i.e., none).
  # This is to prevent "Error reading input, exiting..."
  "$VIM_CMD_PATH" -f -s /dev/null --servername "$VIM_SERVER_NAME" "$TARGET_FILE" > "$VIM_SERVER_LOG" 2>&1 &
  VIM_LAUNCH_PID=$!
  echo "Vim backgrounded with PID: $VIM_LAUNCH_PID."
fi

echo "Waiting for Vim server to register (10 seconds)..."
sleep 10

# Check if the PID is set and if the process is running (only for non-daemon method)
if [ -n "$VIM_LAUNCH_PID" ]; then
  if ! kill -0 $VIM_LAUNCH_PID 2>/dev/null; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Error: The Vim process (PID $VIM_LAUNCH_PID) for server '$VIM_SERVER_NAME' is NO LONGER RUNNING."
    echo "Vim likely exited or crashed. Please check the log: $VIM_SERVER_LOG"
    echo "--- Log Start ---"; cat "$VIM_SERVER_LOG"; echo "--- Log End ---"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
  echo "Vim process PID $VIM_LAUNCH_PID is still running."
fi

echo "Checking server list for '$VIM_SERVER_NAME'..."
echo "--- Output of '$VIM_CMD_PATH --serverlist' ---"
SERVER_LIST_OUTPUT=$("$VIM_CMD_PATH" --serverlist)
echo "${SERVER_LIST_OUTPUT}"
echo "--- End Server List Output ---"
echo "Expected server name to find: $VIM_SERVER_NAME"

if ! echo "${SERVER_LIST_OUTPUT}" | grep -qFx "$VIM_SERVER_NAME"; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "Error: Vim server '$VIM_SERVER_NAME' was NOT FOUND in the server list."
  if [ -n "$VIM_LAUNCH_PID" ]; then
      echo "The Vim process (PID $VIM_LAUNCH_PID) might be running but failed to register as a server."
  elif [ "$HAS_DAEMON_FEATURE" = true ]; then
      echo "Vim was launched with --daemon. The daemon process might have failed to start/register."
  fi
  echo "Please check the log for more details: $VIM_SERVER_LOG"
  echo "--- Log Start ---"; cat "$VIM_SERVER_LOG"; echo "--- Log End ---"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  if [ -n "$VIM_LAUNCH_PID" ]; then kill $VIM_LAUNCH_PID 2>/dev/null; fi
  exit 1
fi

echo "✅ Vim server '$VIM_SERVER_NAME' detected successfully."
# If we used --daemon, we don't have VIM_LAUNCH_PID of the actual daemon easily.
# If we didn't, VIM_LAUNCH_PID is the one. We need a PID to kill at the end if non-daemon.
# For now, the trap and final :qall! will attempt to close the server.

trap 'echo "🛑 Cycler interrupted. Vim server $VIM_SERVER_NAME may still be running."; exit 1' INT TERM

echo "$themes" | while IFS= read -r theme; do
  if [ -z "$theme" ]; then continue; fi
  echo "Applying theme: $theme (press Ctrl+C here to stop)"
  "$VIM_CMD_PATH" --servername "$VIM_SERVER_NAME" --remote-send "<C-\><C-N>:silent! colorscheme $theme<CR>"
  "$VIM_CMD_PATH" --servername "$VIM_SERVER_NAME" --remote-send "<C-\><C-N>:redraw!<CR>"
  "$VIM_CMD_PATH" --servername "$VIM_SERVER_NAME" --remote-send "<C-\><C-N>:echo 'Theme: $theme'<CR>"

  if ! "$VIM_CMD_PATH" --serverlist | grep -qFx "$VIM_SERVER_NAME"; then
    echo "ℹ️ Vim server '$VIM_SERVER_NAME' disappeared. Exiting."
    exit 1
  fi
  sleep "$DELAY_SECONDS"
done

echo ""
echo "✅ Theme cycling complete."
echo "   Closing Vim server '$VIM_SERVER_NAME'..."
"$VIM_CMD_PATH" --servername "$VIM_SERVER_NAME" --remote-send "<C-\><C-N>:qall!<CR>"
sleep 1 # Give Vim a moment to process quit

# If we have a PID from the -f launch method, try to ensure it's gone.
# For --daemon, this PID won't be the daemon, so :qall! is the main method.
if [ -n "$VIM_LAUNCH_PID" ]; then
    if kill -0 $VIM_LAUNCH_PID 2>/dev/null; then
        echo "Vim process $VIM_LAUNCH_PID still alive after qall, attempting kill..."
        kill $VIM_LAUNCH_PID 2>/dev/null
    fi
fi

rm -f "$VIM_SERVER_LOG"
exit 0
