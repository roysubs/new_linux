#!/bin/bash
# This script updates changed files from /home/boss/new_linux_bak2 to /home/boss/new_linux_bak

mkdir -p "/home/boss/new_linux_bak/.git"
cp -f "/home/boss/new_linux_bak2/.git/config" "/home/boss/new_linux_bak/.git/config"
mkdir -p "/home/boss/new_linux_bak/.git"
cp -f "/home/boss/new_linux_bak2/.git/index" "/home/boss/new_linux_bak/.git/index"
mkdir -p "/home/boss/new_linux_bak/.git/logs"
cp -f "/home/boss/new_linux_bak2/.git/logs/HEAD" "/home/boss/new_linux_bak/.git/logs/HEAD"
mkdir -p "/home/boss/new_linux_bak/.git/logs/refs/heads"
cp -f "/home/boss/new_linux_bak2/.git/logs/refs/heads/main" "/home/boss/new_linux_bak/.git/logs/refs/heads/main"
mkdir -p "/home/boss/new_linux_bak/.git"
cp -f "/home/boss/new_linux_bak2/.git/packed-refs" "/home/boss/new_linux_bak/.git/packed-refs"
