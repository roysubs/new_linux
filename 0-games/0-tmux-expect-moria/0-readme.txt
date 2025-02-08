This script will demonstrate automating stat dice rolling to get a very high
INT for a character (i.e. for a mage) in Moria. The expect script will perform
the keypresses in the tmux session that will run in the background (like a VM
running in the background, though the tmux is a subshell of the current shell).
 
- Open a tmux session that will be used just to automate Moria.
- Get to the dice roller screen ready to automate.
- Detach from the tmux session.
- Run the expect script which will manipulate the tmux session
  until it rolls at least 18/20 in INT, when it will stop.
- You can monitor the progress of the session while in progress.

