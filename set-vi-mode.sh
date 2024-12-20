#!/bin/bash

# Only run this script if it is sourced
(return 0 2>/dev/null) || { echo "Only run this script sourced (i.e., '. ./set-vi-mode.sh' to change to vi mode)"; exit 1; }

echo
echo "set -o vi"
set -o vi
echo "
To switch back to (the default) emacs mode, use:   set -o emacs

Using vi Mode:
Once vi mode is enabled, there are two command line modes:

Command Mode (Press Esc to enter):
In this mode, you can navigate through the command line with vi-like keys, such as:
h (move left), j (move down), k (move up), l (move right).
0 (move to the beginning of the line), $ (move to the end of the line).
w (move by word), b (move backward by word), e (move to the end of the current word).
dd (delete the current line), yy (yank/copy the current line).
p (paste), u (undo the last change), etc.

Insert Mode (Press i to enter from Command Mode):
In this mode, you can type freely like you would in a regular text editor.
Switching Between Modes:
To switch to Command Mode, press the Esc key.
To switch to Insert Mode, press the i key from Command Mode.
With vi mode enabled, your Bash editing will be more similar to working in the vi or vim editor.
This can be particularly helpful if you're comfortable with vi-like keybindings for command-line editing.

"
