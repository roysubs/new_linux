#!/bin/bash

sudo apt install fortune cowsay toilet lolcat figlet
sudo apt install libaa-bin   # aafire
sudo snap install ponysay

echo "
Examples:

fortune | cowsay | lolcat
fortune | ponysay
echo "1234567890" | toilet | lolcat

"
