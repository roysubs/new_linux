#!/bin/bash

set -e

VIMRC="$HOME/.vimrc"
PLUG_LINE="Plug 'airblade/vim-gitgutter'"
VIM_PLUGGED_DIR="$HOME/.vim/plugged/vim-gitgutter"
PLUG_VIM="$HOME/.vim/autoload/plug.vim"

install_vim_plug_if_missing() {
    if [ ! -f "$PLUG_VIM" ]; then
        echo "vim-plug not found. Installing it..."
        curl -fLo "$PLUG_VIM" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        echo "✅ vim-plug installed."
    else
        echo "vim-plug already installed."
    fi

    # Ensure plug#begin/end exists in .vimrc
    if ! grep -q 'call plug#begin' "$VIMRC"; then
        echo "Adding plug#begin()/end() block to .vimrc..."
        {
            echo ""
            echo "call plug#begin('~/.vim/plugged')"
            echo "call plug#end()"
        } >> "$VIMRC"
    fi
}

echo

if [ -d "$VIM_PLUGGED_DIR" ]; then
    echo "GitGutter appears to be INSTALLED (found at $VIM_PLUGGED_DIR)"
    echo -n "Do you want to uninstall GitGutter? [y/N]: "
    read -r ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        echo "Removing GitGutter from .vimrc and cleaning up..."
        sed -i.bak "/vim-gitgutter/d" "$VIMRC"
        echo "Running PlugClean to remove plugin files..."
        vim +PlugClean! +qall
        echo "✅ GitGutter has been uninstalled."
    else
        echo "Aborted. GitGutter remains installed."
    fi
else
    echo "GitGutter appears to be NOT installed."
    echo -n "Do you want to install GitGutter? [y/N]: "
    read -r ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        install_vim_plug_if_missing

        if grep -q "$PLUG_LINE" "$VIMRC"; then
            echo "GitGutter already declared in .vimrc, skipping .vimrc edit."
        else
            echo "Adding GitGutter to .vimrc..."
            sed -i.bak "/call plug#begin/a\\
$PLUG_LINE" "$VIMRC"
        fi

        echo "Installing GitGutter via vim-plug..."
        vim +PlugInstall +qall
        echo
        echo "✅ GitGutter installed!"

        echo
        echo "👉 To activate GitGutter in Vim:"
        echo "   - Open any Git-tracked file"
        echo "   - You'll see '+', '~', or '_' in the left sign column"
        echo
        echo "Optional: add these to your .vimrc for symbols and column:"
        echo "   let g:gitgutter_sign_added = '+'"
        echo "   let g:gitgutter_sign_modified = '~'"
        echo "   let g:gitgutter_sign_removed = '_'"
        echo "   set signcolumn=yes"
    else
        echo "Aborted. GitGutter not installed."
    fi
fi

