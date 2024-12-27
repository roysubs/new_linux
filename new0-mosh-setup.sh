#!/bin/bash

sudo apt update -y
sudo apt install mosh -y

echo "
Mosh Operation
==========
Mosh uses SSH only for the initial setup—to authenticate and start a
process on the remote host. Once that's done, Mosh switches to its own
protocol, which runs over UDP. After the switch:

- Mosh no longer relies on the SSH connection.
- The ongoing communication between the client and the remote host happens
  via Mosh's custom UDP-based protocol, completely independent of SSH.
- This design makes Mosh much more resilient than SSH to network disruptions,
  changes in IP addresses, or server-side SSH issues after the initial connection.

Connect to Mosh from Windows
==========
Install Windows Subsystem for Linux (WSL) if you don't already have it.
Mosh requires a Unix-like environment.
Install a Linux distribution via the Microsoft Store (e.g., Ubuntu or Debian)
Open your WSL terminal and install Mosh
   sudo apt update && sudo apt install mosh
Install Mosh Server on the Remote Host
Ensure the remote host has the Mosh server installed. Run the following on the
remote host:
   sudo apt update && sudo apt install mosh
Use Mosh via WSL
After setup, connect to the remote host using the Mosh client in your WSL
terminal. For example:
   mosh username@remote-host
Optional: Integrate Mosh with PowerShell
To use Mosh more seamlessly from PowerShell:
Install a terminal like Windows Terminal that integrates both PowerShell
and WSL. Add WSL to your terminal profile for easy access.
Alternative via Native Windows. If you prefer to avoid WSL, you can use
mosh-client-win, a native Windows port of Mosh. However, its functionality
and reliability may vary.
"

