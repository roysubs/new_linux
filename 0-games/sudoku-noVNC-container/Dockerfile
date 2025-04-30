# Use a publicly available Ubuntu Desktop VNC image with LXDE and noVNC
FROM dorowu/ubuntu-desktop-lxde-vnc:latest

# Switch to the root user for installation steps
USER root

# --- FIX: Remove the problematic Google Chrome repo source file ---
# The dorowu base image often includes a source for Google Chrome,
# which can cause apt update errors if the key isn't present/valid.
# We don't need it for this game, so we remove the source file to prevent issues.
RUN rm -f /etc/apt/sources.list.d/google-chrome.list

# Install the desired GUI game (gnome-sudoku)
# gnome-sudoku is available in the standard Ubuntu repositories
RUN apt-get update && apt-get install -y \
    gnome-sudoku \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Expose the noVNC web port (usually 6080 for this base image)
EXPOSE 6080

# Configure the game to start automatically within the LXDE desktop environment
# The base image's ENTRYPOINT starts the VNC server and LXDE desktop.
# We add a .desktop file to the default user's autostart directory to launch the game.

# Create a simple script to launch gnome-sudoku
# This script will be run by the desktop environment as the 'user' user.
# It now includes the chown command to fix ownership before launching the game.
RUN echo '#!/bin/bash' > /usr/local/bin/start_game.sh && \
    echo '# Wait for the X server (VNC) to be ready' >> /usr/local/bin/start_game.sh && \
    echo 'while ! pgrep Xtightvnc > /dev/null; do sleep 1; done' >> /usr/local/bin/start_game.sh && \
    echo '# Wait a bit more for the desktop environment to fully initialize' >> /usr/local/bin/start_game.sh && \
    echo 'sleep 5' >> /usr/local/bin/start_game.sh && \
    echo '# Fix ownership of the autostart directory and files (needed if created by root)' >> /usr/local/bin/start_game.sh && \
    echo 'chown -R user:user /home/user/.config' >> /usr/local/bin/start_game.sh && \
    echo '# Launch the game in the background on the correct display' >> /usr/local/bin/start_game.sh && \
    echo 'DISPLAY=:1 gnome-sudoku &' >> /usr/local/bin/start_game.sh && \
    chmod +x /usr/local/bin/start_game.sh

# Add a .desktop file to the LXDE autostart directory for the default 'user'
# This tells the desktop environment to run our start_game.sh script on startup.
# We create this as root during the build. Ownership will be fixed by the script itself.
RUN mkdir -p /home/user/.config/autostart/ && \
    echo '[Desktop Entry]' > /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Type=Application' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Exec=/usr/local/bin/start_game.sh' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Hidden=false' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'NoDisplay=false' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'X-GNOME-Autostart-enabled=true' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Name[en_US]=GNOME Sudoku' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Name=GNOME Sudoku' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Comment[en_US]=Start the GNOME Sudoku game' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Comment=Start the GNOME Sudoku game' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'StartupNotify=false' >> /home/user/.config/autostart/gnome-sudoku.desktop && \
    echo 'Terminal=false' >> /home/user/.config/autostart/gnome-sudoku.desktop # Removed chown from here

# The base image's ENTRYPOINT will automatically start the VNC server and LXDE desktop.
# Our .desktop file ensures start_game.sh runs within that desktop session,
# which then fixes ownership and launches gnome-sudoku.
# No CMD instruction is needed here.
