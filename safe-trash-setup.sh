#!/bin/bash

# Create safe function alternatives for rm, mv, cp
# trm
# tmv
# tcp

# Object: To make rm, mv, and cp commands compatible with trash-cli so
# that deleted or overwritten files can be recovered (until trash is emptied)
# you can use a combination of aliases and wrapper scripts. Here's how:

# For rm: Replace rm with a trash equivalent to send files to the trash instead of permanently deleting them.
# Add this alias to your shell configuration file (e.g., ~/.bashrc, ~/.zshrc):
# This ensures that whenever you use rm, the files are moved to the trash directory instead of being immediately deleted.
alias rm='trash-put'

# For mv:
# Intercept overwriting operations and move overwritten files to the trash.
# Create a wrapper script for mv, such as /usr/local/bin/mv:
# This script moves overwritten files to the trash instead of deleting them outright.

#!/bin/bash
for file in "$@"; do
    if [[ "$file" == "-i" || "$file" == "-f" || "$file" == "--" ]]; then
        continue
    fi
    if [[ -e "$file" && ! -d "$file" ]]; then
        trash-put "$file"
    fi
done
/usr/bin/mv "$@"

# Make it executable:
# sudo chmod +x /usr/local/bin/mv

# For cp:
# cp doesn’t delete files, but you can modify it to send overwritten files to the trash.
# Create a wrapper script for cp, such as /usr/local/bin/cp:

#!/bin/bash
while [[ "$1" == -* ]]; do
    shift
done
if [[ -f "$2" ]]; then
    trash-put "$2"
fi
/usr/bin/cp "$@"

# Make it executable:
# sudo chmod +x /usr/local/bin/cp

# Fallback for Safety:
# If you want a safer setup without replacing system-wide commands, you can:
# Use functions instead of scripts for aliases in your shell config.
# Use a special command prefix (e.g., tmove, tcopy) for trash-aware operations.
# Recovery:
# You can recover files using trash-cli commands like:
# trash-list: List trashed files.
# trash-restore: Restore files from trash.
# This setup ensures compatibility with trash-cli while maintaining safety during rm, mv, and cp operations.
