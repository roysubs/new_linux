#!/bin/bash

# Guide for Using Windows Terminal with SSH, WSL, and Clipboard Integration

clear

echo "Welcome to the Windows Terminal SSH and WSL Guide!"
echo "This guide will walk you through using Windows Terminal to connect to Linux via SSH, using splits, managing the clipboard, and more."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 1: Introduction to Windows Terminal ==="
echo "Windows Terminal is a powerful tool for managing multiple shell sessions in a single window. It supports tabs, split panes, and customization."
echo "It's particularly useful for connecting to Linux systems via SSH and running WSL for Linux environments directly on Windows."
echo "To open Windows Terminal, press 'Win' and type 'Windows Terminal', then press Enter."
echo "You can open new tabs by pressing 'Ctrl + Shift + T'."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 2: Opening WSL (Windows Subsystem for Linux) ==="
echo "To open a new tab in Windows Terminal, use 'Ctrl + Shift + T'."
echo "To launch WSL (if installed), type 'wsl' and press Enter."
echo "You should now see a Linux prompt (e.g., Ubuntu)."
echo "To launch a specific WSL distro, type 'wsl -d <DistroName>' (e.g., 'wsl -d Ubuntu')."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 3: Opening SSH Connections to a Linux System ==="
echo "1. Open a new tab in Windows Terminal using 'Ctrl + Shift + T'."
echo "2. To SSH into a Linux machine, use the command:"
echo "   ssh username@hostname_or_ip"
echo "   - Replace 'username' with the appropriate username and 'hostname_or_ip' with the server's IP or domain name."
echo "3. You'll be prompted for your password after entering the SSH command."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 4: Split Panes in Windows Terminal ==="
echo "Windows Terminal allows you to split your window into multiple panes for multitasking."
echo "To split the window horizontally, use: 'Alt + Shift + -'"
echo "To split the window vertically, use: 'Alt + Shift + +'"
echo "To navigate between panes, use 'Alt + Left Arrow' or 'Alt + Right Arrow'."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 5: Managing Clipboard Between Linux (SSH) and Windows ==="
echo "To copy text from the Linux SSH session into the Windows clipboard, use:"
echo "   cat filename | clip"
echo "   - This will copy the contents of the file to the clipboard."
echo "To copy text from Windows into your Linux session, use:"
echo "   echo 'Text' | ssh username@hostname_or_ip 'cat > filename'"
echo "   - This will send the text to the remote Linux machine."
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 6: Configuring Clipboard Integration (Optional) ==="
echo "You can enable clipboard integration between WSL and Windows using the following:"
echo "1. To copy from WSL to Windows, use 'clip.exe' from within WSL."
echo "   Example: echo 'Hello from WSL' | clip.exe"
echo "2. To paste from Windows clipboard to WSL, you can use the command:"
echo "   powershell.exe Get-Clipboard"
echo "   Example: powershell.exe Get-Clipboard | wsl 'cat > filename'"
echo "Press any key to continue..."
read -n 1

clear

echo "=== Pane 7: Final Notes and Tips ==="
echo "Windows Terminal supports various customizations via its settings file. You can adjust your colors, fonts, and keybindings to suit your preferences."
echo "You can also configure specific profiles for different shell environments (e.g., PowerShell, WSL, CMD, SSH)."
echo "For more advanced configurations, visit the Windows Terminal GitHub page or access the settings via the dropdown menu in the terminal window."
echo "Press any key to exit the guide..."
read -n 1

clear

echo "Thank you for using the Windows Terminal SSH and WSL guide! Have a great day!"
exit 0

