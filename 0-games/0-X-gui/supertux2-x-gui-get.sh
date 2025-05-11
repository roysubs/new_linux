#!/bin/bash

echo "Confusingly, the apt package is supertux, but the binary is supertux2"
echo "Works well with WSL in Windows (with WSLg)"

sudo apt install supertux
sudo ln -s /usr/games/supertux2 /usr/games/supertux
sudo ln -s /usr/games/supertux2 /usr/games/supertux2
