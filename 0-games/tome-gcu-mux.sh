#!/bin/bash

if ! command tome-gcu; then
    sudo apt install tome-gcu
fi

echo "
ToMe can alter screen colours that affect the console session, particularly
if connected over SSH. This might not affect all sessions, but if it happens, the
only fix is to quit the terminal. Using tome-gcu-mux.sh gets around this by isolating
tome-gcu inside a dedicated tmux session.

'set-option status off' suppresses the green tmux status bar when in game.
'-g status' would suppress the tmux bar globally for all tmux sessions.
"
echo -n "Press any key to continue..."
read -n 1 -s   # Wait for a single character (-n 1) and do not echo it (-s)

# Create a new tmux session
SESSION_NAME="tome-gcu_session"

# Start a new tmux session, suppressing the status bar for this session and running tome-gcu
# Note: Removed -g from set-option to make it session-local.
tmux new-session -d -s "$SESSION_NAME" "set-option status off; tome-gcu; exit"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
