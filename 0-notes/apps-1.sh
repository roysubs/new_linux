
sudo apt update
sudo apt tmux
sudo apt net-tools   # ifconfig

# neofetch glances cpuinfo inxi 

sudo apt locate
sudo apt install -y btop  # top replacement
btop --version
sudo apt install -y duf   # du / df replacement
duf --version

sudo apt install -y python3 python3-pip
sudo pip install yazi     # file manager
yazi --version

# The below happens when trying to install python3-pip:
#
# Reading package lists... Done
# ^Cerror: externally-managed-environment
# × This environment is externally managed
# ╰─> To install Python packages system-wide, try apt install
#     python3-xyz, where xyz is the package you are trying to
#     install.
#     If you wish to install a non-Debian-packaged Python package,
#     create a virtual environment using python3 -m venv path/to/venv.
#     Then use path/to/venv/bin/python and path/to/venv/bin/pip. Make
#     sure you have python3-full installed.
#     If you wish to install a non-Debian packaged Python application,
#     it may be easiest to use pipx install xyz, which will manage a
#     virtual environment for you. Make sure you have pipx installed.
#     See /usr/Ashare/doc/python3.11/README.venv for more information.
#
# This is due to Debian's handling of system-wide Python package installations,
# where Python packages are often managed using apt to ensure compatibility with
# the system and avoid potential conflicts with system packages.
# 
# So we create a Python Virtual Environment:
# Using a virtual environment ensures that you can install Python packages locally
# without affecting system-wide packages.
#    sudo apt install python3-venv
# Create a new virtual environment:
# Navigate to the directory where you want to store your virtual environment, then run:
#    python3 -m venv myenv
# Activate the virtual environment:
#    source myenv/bin/activate
# You should now see (myenv) in your terminal prompt, indicating that the virtual
# environment is active.
# 
# With the virtual environment active, install Yazi:
#    pip install yazi
# Run Yazi: You can now run Yazi in this environment:
#    yazi --version
# When you're done, deactivate the virtual environment:
#    deactivate

# Use pipx:
# pipx is a tool that automatically manages virtual environments for Python applications. It's great for installing and running Python apps without affecting your system Python installation.
# Install pipx:
sudo apt install pipx
pipx install yazi
yazi --version

