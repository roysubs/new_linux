#!/bin/bash

# Exit script on any error
set -e

# Define constants
REPO_URL="https://github.com/swarm-game/swarm.git"
CLONE_DIR="$HOME/swarm"

# Ensure required system dependencies are installed
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y libgmp-dev build-essential curl

# Install ghcup if not already installed
if ! command -v ghcup &> /dev/null; then
  echo "Installing ghcup..."
  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
  source "$HOME/.ghcup/env"
fi

# Install GHC and cabal if not already installed
echo "Ensuring GHC and cabal are installed..."
ghcup install ghc 9.8.2 --set
ghcup install cabal

# Clone the Swarm repository if not already cloned
if [[ ! -d "$CLONE_DIR" ]]; then
  echo "Cloning Swarm repository..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# Build and run Swarm
cd "$CLONE_DIR"
echo "Building Swarm..."
cabal update
cabal build -O0 swarm:exe:swarm

# Inform the user
echo "Swarm has been built successfully! To run the game, use the following command:"
echo "cabal run -O0 swarm:exe:swarm"

