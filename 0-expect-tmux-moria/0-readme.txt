This script demonstrates an automation technique with tmux and expect.
- Start Moria in an isolated tmux session.
- Get to the dice roller screen ready to automate.
- Detach from the tmux session.
- Run the expect script which will manipulate the tmux session
  until it rolls at least 18/20 in INT, when it will stop.
- You can monitor the progress of the session while in progress.

