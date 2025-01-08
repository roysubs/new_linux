#!/bin/bash
cd /tmp 
wget https://github.com/cheat/cheat/releases/download/4.4.0/cheat-linux-amd64.gz 
gunzip cheat-linux-amd64.gz
chmod +x cheat-linux-amd64 
sudo mv cheat-linux-amd64 /usr/local/bin/cheat
