#!/bin/bash

# Install and configure Python and working with venv and pipx

# Define text formatting for output
GREEN='\033[0;32m'
YELLOW='\033[0;93m'
NC='\033[0m' # No color
# # To view color code samples
# colors=(30 31 32 33 34 35 36 37 90 91 92 93 94 95 96 97)
# for color in "${colors[@]}"; do
#   echo -e "\033[${color}mSample Text in Color ${color}\033[0m"
# done

# Introduction
echo -e "${YELLOW}This script will guide you through setting up and using Python's venv and pipx tools.${NC}"
echo "Python virtual environments and pipx are essential for managing dependencies on Debian systems."
echo "They prevent system-wide issues and help isolate projects."
echo "Press Enter to continue or CTRL+C to exit."
read

# Step 1: Why venv and pipx?
echo -e "${YELLOW}Step 1: Understanding venv and pipx.${NC}"
echo "Debian enforces the use of venv and pipx to prevent dependency conflicts and protect the system's managed Python environment."
echo -e "${GREEN}venv:${NC} Creates isolated environments for Python projects."
echo -e "${GREEN}pipx:${NC} Manages Python-based tools globally in isolated environments."
echo "This ensures clean, conflict-free development."
echo "Press Enter to continue."
read

# Step 2: Installing Required Tools
echo -e "${YELLOW}Step 2: Installing venv and pipx.${NC}"
echo "First, ensure Python3 and pip are installed."
echo -e "Running: ${GREEN}sudo apt update && sudo apt install -y python3 python3-pip python3-venv pipx${NC}"
sudo apt update && sudo apt install -y python3 python3-pip python3-venv pipx

# Confirm installation
echo -e "${GREEN}Installed venv and pipx successfully!${NC}"
echo

# Step 3: Setting Up a venv
echo -e "${YELLOW}Step 3: Creating and using a Python virtual environment (venv).${NC}"
echo "A venv isolates project dependencies. Let's create one."
echo "Enter a directory name for your venv (e.g., 'my_project_venv'):"
read venv_dir

# Create the venv
if [ -n "$venv_dir" ]; then
  echo -e "Running: ${GREEN}python3 -m venv $venv_dir${NC}"
  python3 -m venv "$venv_dir"
  echo -e "${GREEN}Virtual environment created in $venv_dir.${NC}"
else
  echo "Invalid directory name. Exiting."
  exit 1
fi

# Activate the venv
echo "To activate the venv, run:"
echo -e "${GREEN}source $venv_dir/bin/activate${NC}"
echo "Press Enter to activate the venv now."
read
source "$venv_dir/bin/activate"
echo -e "${GREEN}You are now in the virtual environment.${NC}"
echo

# Step 4: Installing Packages in the venv
echo -e "${YELLOW}Step 4: Installing packages in the venv.${NC}"
echo "Let's install a package (e.g., requests)."
echo -e "Running: ${GREEN}pip install requests${NC}"
pip install requests

echo -e "${GREEN}Package installed in the venv successfully!${NC}"
echo

# Step 5: Deactivating the venv
echo -e "${YELLOW}Step 5: Deactivating the venv.${NC}"
echo "To leave the virtual environment, use the command:"
echo -e "${GREEN}deactivate${NC}"
echo "Run the command now."
read -p "Press Enter to deactivate: "
deactivate
echo -e "${GREEN}You have left the virtual environment.${NC}"
echo

# Step 6: Managing Multiple venvs
echo -e "${YELLOW}Step 6: Managing multiple virtual environments.${NC}"
echo "You can create as many venvs as needed for different projects."
echo "For example, to create a new venv for another project:"
echo -e "${GREEN}python3 -m venv another_project_venv${NC}"
echo "Activate it using:"
echo -e "${GREEN}source another_project_venv/bin/activate${NC}"
echo "Deactivate using:"
echo -e "${GREEN}deactivate${NC}"
echo

# Step 7: Using pipx for Global Tools
echo -e "${YELLOW}Step 7: Using pipx for globally installed tools.${NC}"
echo "pipx allows you to install Python applications globally, but each in its own venv."
echo "For example, to install 'httpie' globally, use:"
echo -e "${GREEN}pipx install httpie${NC}"
echo "Try installing a tool now. Enter a tool name (or press Enter to skip):"
read tool_name
if [ -n "$tool_name" ]; then
  echo -e "Running: ${GREEN}pipx install $tool_name${NC}"
  pipx install "$tool_name"
  echo -e "${GREEN}Tool installed successfully!${NC}"
else
  echo "Skipping pipx installation."
fi

echo
# Summary
echo -e "${YELLOW}Summary:${NC}"
echo "- venv is used for project-specific environments."
echo "- pipx is used for global tools in isolated environments."
echo "- Both ensure clean and conflict-free dependency management."
echo -e "${GREEN}venv and pipx are setup on this system${NC}"

