#!/bin/bash

# Only run this script if it is sourced
(return 0 2>/dev/null) || { echo "Only run this script sourced (i.e., '. ./set-emacs-mode.sh' to change to emacs mode)"; exit 1; }

echo
echo "set -o emacs"
set -o emacs
echo -e "\nTo switch back to vi mode, use:   set -o vi\n"
