# New Linux Project

This repository contains various scripts and utilities for managing and setting up a new Linux environment (mainly Debian).

Notable scripts to run on a new system:
- `new0-add-user-to-sudo.sh`
  *Without* using sudo, this will add the current user to the sudo group and enable it in `/etc/sudo/sudoers`
- `new-selector.py`
  Will display a menu to step through the various setup scripts.

## Directory Listing

### Scripts

- **0-notes**  
  Placeholder for any general notes or references.

- **apps-0.sh**  
  Script for installing common applications or utilities.

- **apps-1.sh**  
  Another application setup script, potentially for different tools.

- **apps-estimates.sh**  
  A script for estimating app installation times or dependencies.

- **apps-games-console.sh**  
  Script related to setting up console games.

- **apps-games-roguelike-1.sh**  
  Installation for roguelike games on Linux.

- **apps-games-roguelike-2.sh**  
  Additional setup for other roguelike games.

- **apps-games.sh**  
  General script for installing games on Linux.

- **backup-home.sh**  
  Backup script for home directory files.

- **compress-and-email.sh**  
  Compress files and email them using a specified mail client.

- **disable-gnome-energy-saver1.sh**  
  Disables GNOME energy saving features (first iteration).

- **disable-gnome-energy-saver2.sh**  
  Disables GNOME energy saving features (second iteration).

- **generate_disk_report2.sh**  
  Generates a disk usage report with details.

- **generate_disk_report.sh**  
  Another disk report generation script.

- **git-0-notes.txt**  
  Git-related notes or tips.

- **git-credential-manager.sh**  
  Script for configuring Git credential management.

- **git-ssh-authentication.sh**  
  Set up SSH authentication for Git.

- **install-glow.sh**  
  Installation script for the Glow CLI tool.

- **install-prompt-zsh-and-powerlevel10k.sh**  
  Sets up Zsh and installs Powerlevel10k theme.

- **install-ssh-keygen.sh**  
  Installs and configures SSH key generation.

- **install-unimatrix.sh**  
  Script for installing Unimatrix (system monitoring tool).

- **install-vscode.sh**  
  Installs Visual Studio Code editor.

- **manage-samba.sh**  
  Script to manage Samba file sharing services.

- **mount-winshare.sh**  
  Mount Windows share using Samba or CIFS.

- **mount-winshare-x.sh**  
  Alternative method to mount Windows shares.

- **new0-add-user-to-sudo.sh**  
  Adds a user to the sudoers group.

- **new0-fix-debian-repos.sh**  
  Fixes Debian package repositories.

- **new0-ssh-setup.sh**  
  Initial SSH setup for remote access.

- **new1-add-new_linux-to-path.sh**  
  Adds `new_linux` to the system's PATH variable.

- **new1-set-sudo-timeout-24-hours.sh**  
  Sets sudo timeout to 24 hours.

- **new1-timeshift.sh**  
  Sets up TimeShift for system backups.

- **new2-x11-forwarding.sh**  
  Configures X11 forwarding over SSH.

- **new2-vnc.sh**  
  Configures VNC server for remote desktop.

- **new3-bashrc.sh**  
  Custom `.bashrc` configuration.

- **new3-vim-root.sh**  
  Vim configuration for root users.

- **new3-vim.sh**  
  General Vim configuration setup.

- **new4-nas-home-only.sh**  
  Configures NAS (Network Attached Storage) for home directory only.

- **new4-nas-nas.sh**  
  Configures NAS with network share settings.

- **new4-nas-setup.sh**  
  Setup script for a NAS server.

- **new4-nfs.sh**  
  Configures NFS (Network File System) shares.

- **new4-partitions-mount-and-share.sh**  
  Manages disk partitions, mounting, and sharing.

- **new5-benchmark.sh**  
  Benchmarking script for system performance.

- **new5-web-cockpit-9090.sh**  
  Installs and configures Cockpit web UI on port 9090.

- **new5-web-system-info-8081.sh**  
  Web-based system info viewer on port 8081.

- **new5-web-webmin-10000.sh**  
  Installs Webmin for web-based server management on port 10000.

- **new6-ansible-example.yml**  
  Example Ansible playbook for system automation.

- **new6-ansible.sh**  
  Sets up Ansible for system configuration management.

- **new6-email-with-gmail-relay.sh**  
  Configures email relay using Gmail SMTP.

- **new6-htop-btop-vtop-atop.sh**  
  Installs and configures system resource monitoring tools.

- **new6-lazygit.sh**  
  Installs and sets up LazyGit for Git management.

- **new6-powershell-pwsh.sh**  
  Installs PowerShell (pwsh) on Linux.

- **new6-python-venv-and-pipx.sh**  
  Setup script for Python virtual environments and Pipx.

- **new6-x11-forwarding.sh**  
  Configures X11 forwarding.

- **quick-inventory.sh**  
  Generates a quick inventory of system hardware and software.

- **replicate-new_linux.sh**  
  Replicates the configuration of the `new_linux` setup.

- **rsync-to-winshare.sh**  
  Syncs files to a Windows share using rsync.

- **set-nvim.sh**  
  Installs and configures Neovim (nvim).

- **set-vi-mode.sh**  
  Sets the vi-mode for command-line editing.

- **set-vim.sh**  
  General Vim setup.

- **switch-desktop-environment.sh**  
  Script to switch between different desktop environments.

- **timeshift-calculate-image-size.sh**  
  Calculates the size of a TimeShift backup image.

- **timeshift-restore-last-snapshot.sh**  
  Restores the last snapshot taken by TimeShift.

- **yabs.sh**  
  Yet Another Benchmark Script for testing system performance.

## Usage

You can explore each of the scripts to automate and streamline various Linux setup and maintenance tasks. Simply run the appropriate script and modify as needed for your own environment.

---

### Contribution

Feel free to fork this repository, modify it, and submit pull requests for any improvements or additions you'd like to see!

### License

This project is licensed under the [MIT License](LICENSE).

