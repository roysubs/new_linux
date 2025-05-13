#!/bin/bash

# Source video: https://www.youtube.com/shorts/PL1EoKjy4iM

#!/bin/bash

TMUX_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_RUN_LINE="run '$TPM_DIR/tpm'"

echo "--- Tmux Plugin Setup Script ---"

# --- Step 1: Install TPM ---
echo "Checking for TPM installation..."
if [ -d "$TPM_DIR" ]; then
  echo "TPM is already installed in $TPM_DIR."
else
  echo "TPM not found. Cloning TPM into $TPM_DIR..."
  if git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
    echo "TPM cloned successfully."
  else
    echo "Error: Failed to clone TPM. Please check your internet connection and git."
    exit 1
  fi
fi
echo "" # Add a newline for readability

# --- Step 2: Configure .tmux.conf ---
echo "Checking $TMUX_CONF for TPM configuration..."

# Create the file if it doesn't exist
if [ ! -f "$TMUX_CONF" ]; then
  echo "$TMUX_CONF not found. Creating it..."
  touch "$TMUX_CONF"
fi

# Check if the essential TPM run line is in the conf file
if grep -qF "$TPM_RUN_LINE" "$TMUX_CONF"; then
  echo "$TPM_RUN_LINE already exists in $TMUX_CONF."
  echo "Assuming plugin list is also present or will be added manually."
else
  echo "$TPM_RUN_LINE not found. Appending basic plugin list and TPM run line to $TMUX_CONF..."
  cat << EOF >> "$TMUX_CONF"

# Added by tmux plugin setup script
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'dracula/tmux'

# Add other plugins here:
# set -g @plugin 'tmux-plugins/tmux-resurrect' # Example

# Keep this line at the very bottom of tmux.conf
$TPM_RUN_LINE
EOF
  echo "Basic TPM configuration added to $TMUX_CONF."
  echo "You can edit $TMUX_CONF to add more plugins under the '# List of plugins' section."
fi
echo "" # Add a newline for readability


# --- Final Instructions ---
echo "--- Setup Complete (outside tmux) ---"
echo "To finish the plugin installation:"
echo "1. Start a new tmux session or source your .tmux.conf:"
echo "   Inside tmux, press your prefix (usually Ctrl+b or Ctrl+s), then type:"
echo "   :source-file ~/.tmux.conf"
echo "   Press Enter."
echo ""
echo "2. Install the plugins listed in .tmux.conf:"
echo "   Inside tmux, press your prefix, then press I (capital I)."
echo "   TPM will download and install the plugins."
echo ""
echo "Once installation is complete, the Dracula theme and sensible defaults should be active."

# # Refresh the configuration
# leader r
# 
# # Change leader key to ctrl + s
# set -g prefix C-s
# unbind C-b
# bind C-s send-prefix
# 
# # Vim keymaps for pane switching
# bind h select-pane -L
# bind j select-pane -D
# bind k select-pane -U
# bind l select-pane -R
# 
# # TPM (tmux plugin manager) - Requires installation
# set -g @plugin 'tmux-plugins/tpm'
# set -g @plugin 'tmux-plugins/tmux-sensible'
# 
# # Dracula Theme - Requires installation via TPM
# set -g @plugin 'dracula/tmux'
# set -g @dracula-plugins "git cpu-usage ram-usage gpu-usage weather time"
# set -g @dracula-show-fahrenheit false
# set -g @dracula-show-location false
# 
# # Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf!)
# run '~/.tmux/plugins/tpm/tpm'
# 
##########
# Please note that the exact syntax for some settings (like changing the leader
# key or setting up keymaps and plugins) might vary slightly depending on the
# user's specific tmux version and existing configuration. The comments reflect
# the functionality as described in the video. To use TPM and themes like Dracula,
# you would typically need to install TPM and then list the plugins in your
# .tmux.conf file, followed by the initialization line.
##########
