# Ensure the script is sourced
(return 0 2>/dev/null) || {
  echo "⚠️  This script must be sourced: use 'source ./new1-bashrc-docker-aliases.sh'"
  return 1 2>/dev/null || exit 1
}

# Detect shell and config file
if [ -n "$ZSH_VERSION" ]; then
  SHELL_TYPE="zsh"
  SHELL_RC="$HOME/.zshrc"
else
  SHELL_TYPE="bash"
  SHELL_RC="$HOME/.bashrc"
fi

# Add some color helpers
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_BLUE=$(tput setaf 4)
COLOR_RESET=$(tput sgr0)

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dstats='docker stats'
alias ddf='docker system df'
alias dimages='docker images'
alias drmi='docker rmi'
alias dlogs='docker logs -f'
alias dstart='docker start'
alias dstop='docker stop'
alias drm='docker rm'
alias dip='docker inspect -f "{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
alias dexec='docker exec -it'

# Autocompletion hints
complete -W "$(docker ps -a --format '{{.Names}}')" dexec dstop dstart drm dip dlogs 2>/dev/null

# Run ENTRYPOINT or CMD
dentry() {
  local img="$1"
  if [ -z "$img" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dentry <image>"
    return 1
  fi
  docker run -it --rm "$img"
}

# Smart shell attach (bash or fallback to sh)
dshell() {
  local cid="$1"
  if [ -z "$cid" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dshell <container>"
    return 1
  fi
  docker exec -it "$cid" /bin/bash 2>/dev/null || docker exec -it "$cid" /bin/sh
}

# Inspect image for ENTRYPOINT and CMD
dimageinfo() {
  local img="$1"
  if [ -z "$img" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dimageinfo <image>"
    return 1
  fi
  docker inspect --format='Image: {{.RepoTags}}  
CMD: {{.Config.Cmd}}  
ENTRYPOINT: {{.Config.Entrypoint}}' "$img"
}

# Save/load images
dsave() {
  local img="$1"
  local file="$2"
  if [ -z "$img" ] || [ -z "$file" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dsave <image> <output.tar>"
    return 1
  fi
  docker save "$img" -o "$file"
}

dload() {
  local file="$1"
  if [ -z "$file" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dload <input.tar>"
    return 1
  fi
  docker load -i "$file"
}

# Reconstruct a Dockerfile
dreconstruct() {
  local img="$1"
  if [ -z "$img" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dreconstruct <image>"
    return 1
  fi
  docker history --no-trunc "$img" | tac | awk 'NR>1 {print $5}' | grep -v '<missing>' | sed 's/^/RUN /'
}

# Print IP address of a container
dipaddr() {
  local cid="$1"
  if [ -z "$cid" ]; then
    echo "${COLOR_YELLOW}Usage:${COLOR_RESET} dipaddr <container>"
    return 1
  fi
  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid"
}

# Auto-prune function (with confirmation)
dclean() {
  echo -e "${COLOR_YELLOW}⚠️  This will remove all stopped containers, unused images, volumes, and networks.${COLOR_RESET}"
  read -p "Continue? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker system prune -a --volumes
    echo "${COLOR_GREEN}✅ Docker system pruned.${COLOR_RESET}"
  else
    echo "${COLOR_BLUE}ℹ️  Aborted.${COLOR_RESET}"
  fi
}

# Save this script to ~/.bashrc-docker.sh if not already
SELF_PATH="${BASH_SOURCE[0]:-${(%):-%x}}"
BASENAME="$(basename "$SELF_PATH")"
TARGET="$HOME/.bashrc-docker.sh"

if [[ "$BASENAME" != ".bashrc-docker.sh" ]]; then
  if [ -f "$TARGET" ]; then
    read -p "❓ ~/.bashrc-docker.sh already exists. Overwrite? [y/N]: " overwrite
    if [[ "$overwrite" =~ ^[Yy]$ ]]; then
      cp "$SELF_PATH" "$TARGET"
      echo "${COLOR_GREEN}✅ Copied to ~/.bashrc-docker.sh${COLOR_RESET}"
    else
      echo "${COLOR_BLUE}ℹ️  Skipped copy to ~/.bashrc-docker.sh${COLOR_RESET}"
    fi
  else
    cp "$SELF_PATH" "$TARGET"
    echo "${COLOR_GREEN}✅ Copied to ~/.bashrc-docker.sh${COLOR_RESET}"
  fi
fi

# Add source line to shell config file
if ! grep -qF "source ~/.bashrc-docker.sh" "$SHELL_RC"; then
  echo -e "\n# Load Docker aliases if present" >> "$SHELL_RC"
  echo "if [ -f ~/.bashrc-docker.sh ]; then" >> "$SHELL_RC"
  echo "  source ~/.bashrc-docker.sh" >> "$SHELL_RC"
  echo "fi" >> "$SHELL_RC"
  echo "${COLOR_GREEN}✅ Added sourcing to $SHELL_RC${COLOR_RESET}"
fi

