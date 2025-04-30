#!/bin/bash

# This script installs vim-plug for Unix/Linux/macOS using curl.
# For Windows users (using PowerShell), the equivalent command is:
# md ~\vimfiles\autoload; Invoke-WebRequest -Uri https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim -OutFile ~\vimfiles\autoload\plug.vim

echo "--- Installing vim-plug ---"

# Create the directory if it doesn't exist and download vim-plug
mkdir -p ~/.vim/autoload
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "vim-plug installed successfully to ~/.vim/autoload/plug.vim"
else
    echo "Error: Failed to install vim-plug."
    echo "Please ensure you have 'curl' installed and an active internet connection."
    exit 1
fi

echo ""
echo "--- Action Required: Modify your ~/.vimrc ---"
echo "You need to add the following line to your ~/.vimrc file:"
echo ""
echo "Plug 'hlissner/vim-multiple-cursors'"
echo ""
echo "IMPORTANT: This line must be placed *between* the 'call plug#begin(...)'"
echo "and 'call plug#end()' lines in your .vimrc for vim-plug to work correctly."
echo "If those lines don't exist, you'll need to add them:"
echo ""
echo "call plug#begin('~/.vim/plugged')"
echo "# Your plugins go here"
echo "Plug 'hlissner/vim-multiple-cursors'"
echo "# ... other Plug lines ..."
echo "call plug#end()"
echo ""
echo "--- Final Step: Run Plugin Install in Vim ---"
echo "After saving your modified ~/.vimrc, open Vim and run:"
echo ""
echo ":PlugInstall"
echo ""
echo "Wait for the installation to complete, then restart Vim."
