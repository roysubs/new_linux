#!/bin/bash

echo "
Due to how zangband alters screen colours, after exiting, that can affect the
console session, particularly if connected over SSH. This might not affect all
sessions, but if it happens, the only fix is to quit the terminal. Instead, use
this script to prevent any odd colour changes when leaving zangband by completely
containing it inside a dedicated tmux session.

'set-option status off' also suppresses the green tmux status bar when in the game.
'set-option -g status off would set that globally for all tmux sessions
"
echo -n "Press any key to continue..."
read -n 1 -s   # Wait for a single character (-n 1) and do not echo it (-s)

# Create a new tmux session
SESSION_NAME="zangband_session"

# Start a new tmux session, suppressing the status bar for this session and running zangband
# Note: Removed -g from set-option to make it session-local.
tmux new-session -d -s "$SESSION_NAME" "set-option status off; zangband; exit"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
