new_linux Bootstrap Project
=========================

---

▶ Purpose: A reusable, modular bootstrap layer for any Linux syste running bash

---

The `new_linux` repo can rapidly bootstrap any Linux system:

  • Run `source ./update-bashrc-vimrc-paths.sh` in the root of `new_linux`

  • Essential `.bashrc`, `.vimrc`, and`.inputrc` configuration (all idempotent and non-invasive)

  • Menu guided new system setup to get up and running fast

  • Idempotent Docker logic, and sane interactive defaults with various projects

  • Git integration with SSH and clean setup scripts to connect to GitHub

  • Help system for many aspects of Linux and common applications

  • Deploying clean, powerful, and easy to use helper scripts: `a`, `b`, `def`, `dk`, `g`, `h`, `z`, etc

Bootstrap Process
=========================

 1. 🏁 Initial Setup

    • Custom .bashrc setup provides the very useful h and def functions
    • Ensures required tools are installed: curl, git, vim, mdcat, etc (wip)
    • Ensures Bash and Readline behave consistently across sessions
    • Adds 0-scripts to PATH for access to core scripts: a, b, d, f, g, z, dk, etc

 2. 🐚 .bashrc and Shell Environment

    • Adds aliases, functions, and helper logic cleanly
    • Idempotent: avoids duplication if .bashrc already contains a block
    • Preserves any existing user logic

3. 🎯 .inputrc and Navigation
    - Adds readline keybindings:
        - `Ctrl-k/j`: Vim-style up/down history
        - `Ctrl-Backspace`: Delete previous word
        - `Ctrl-Home` / `Ctrl-End`: Jump to start/end of line
    - Detects terminal quirks (e.g. tmux) and avoids all keybinding conflicts

4. 🔧 Wrapper Scripts to make essential tools more accessible
    - `h` in .bashrc: Custom history manager with fuzzy search, timestamps, grep, and rerun
    - `def` in .bashrc: See definitions of functions, aliases, shell commands
    - `a`: Auto wrapper for app packaging (e.g. apt, apk, dnf, zypper, etc (wip: AppImage, pipx, Nix, brew?)
    - `dk`: Wrapper for `docker`, provides a lot of useful shortcuts
    - `g`: Git wrapper for common workflows, push protection, old-version retrieval
    - `z`: Smart archive tool: extract/compress across formats

5. 🐳 Docker Environment
    - Checks for Docker/Docker Compose, installs if missing
    - Ensures proper permissions (adds user to docker group)
    - `dk-monitor.py`: real-time stats + I/O + sampling
    - Adds pre-deploy safety logic:
        - Detects port conflicts
        - Detects already-running containers using same image
        - Warns if containers with the same names exist
        - Fully idempotent: safe to re-run bootstrap anytime

6. 🧠 Git Setup
    - `g acp`: Add/commit/push with optional gitleaks scan
    - `g pl`: Pull with inspection, backup, and diff before merge (wip)
    - SSH setup helper: generates SSH key, prints copy-paste GitHub instructions
    - `.gitconfig` customization with sane diff, log, and push defaults

7. 💾 Vim Setup
    - Creates a well-commented `.vimrc`, with no overriding of core vim keybindings
    - Sets these up in both `vim` and `nvim` (`neovim`)
    - `h-vim` help file explains usage, visual modes, and power tips

8. 📁 Config Layout
    - `~/new_linux/`, `~/new_linux/0-scriptsbin/`, and `~/.config/`  
    - Project-local `.env` and `config.sh` conventions supported  
    - Standard layout:  
        ├── ~/new_linux/              ← project root  
        ├── ~/new_linux/0-new-system  ← new system essentials  
        ├── ~/new_linux/0-scripts     ← Main body of scripts  
        ├── ~/new_linux/0-docker      ← Container setup scripts  
        └── ~/new_linux/0-help        ← Custom help files  

---

Re-running bootstrap
=========================
🌀 Fully Idempotent:  
    - Script detects and skips existing entries in `.bashrc`, `.inputrc`, etc  
    - Will never break your shell or duplicate entries  
    - If rerun, will:  
        - Print summary of what it would do  
        - Ask for confirmation before overwriting anything  
        - Offer `diff` style output of any proposed changes  

---

Optional Add-ons
=========================

✅ Media-Stack containers (qBittorrent / Sonarr / Radarr)  
    - Manage as a single container stack  
    - Uses `wireguard` VPN container (significantly lower footprint than OpenVPN)  
    - Media folder paths standardized under `/mnt/media` via bind mount  
    - Media config paths standardized under `~/.config/media-stack`  
    - Generic Wireguard setup with work with any VPN vendor  

✅ Backup, Sync, and Sharing integration  
    - rsync, rclone, and borgbackup scripts available (wip)  
    - Syncthing as local or container install  
    - Filebrowser for web UI access to `media-stack`  

✅ Monitoring Container Stack  
    - `monitoring-stack` : grafana + prometheus instannt setup  
    - CPU, mem, network, and container states  

---

See also:  
    - `h-vim`           ← Vim quickstart  
    - `h-git`           ← Git workflows and SSH key setup  
    - `h-docker-stack`  ← Media + VPN stack deploy  
    - `h-ssh`           ← SSH key, agent, known_hosts explained  
    - `h-inputrc`       ← Terminal keys and .inputrc behavior  




# New Linux System Setup Scripts

Essential tools to add to any Debian/Mint/Ubuntu system to cleanly add functionality, and paricularly useful for new environments to get up and running quickly. There is no need to run every script, just pick and choose as required from each section.
The menu script `setup-new-system-by-menu.py` is provided in the root of this project to automate the installation of multiple scripts.  

## Phase 0: Initial System Configuration (new0-*)

These scripts perform foundational setup tasks. Run them first, especially on a new system.

* `new0-apt-update-upgrade-autoremove.sh`: Updates package lists, upgrades installed packages, and removes unused packages. Essential first step.
* `new0-disable-gnome-power-settings.sh`: Disables GNOME's default power management settings (e.g., suspend) which can be problematic for servers or systems without resume capabilities.
* `new0-disable-power-settings.sh`: A more general script to disable system power-saving features (e.g., suspend, lid close actions) for headless or always-on systems.
* `new0-fix-debian-repos.sh`: Corrects Debian repository sources. (Note: May become redundant with newer Debian releases).
* `new0-fstab-nofail.sh`: Modifies `/etc/fstab` entries to include the `nofail` option, preventing boot issues if listed volumes are temporarily unavailable.
* `new0-openssh-server-setup.sh`: Installs and configures the OpenSSH server, enabling remote access (SSH) to the system.
* `new0-ssh-setup.sh`: General SSH setup, potentially configuring client settings or further hardening the SSH server. *(Consider merging with or clarifying difference from `new0-openssh-server-setup.sh`)*.
* `new0-sudo-add-current-user.sh`: Adds the current user to the `sudo` group, granting administrative privileges.
* `new0-sudo-set-timeout-24-hours.sh`: Extends the `sudo` password timeout to 24 hours, reducing frequent password prompts for privileged operations.
* `new0-sync-clock-to-Amsterdam.sh`: Synchronizes the system clock with a time server, setting the timezone to Amsterdam.
* `new0-sync-clock-to-London.sh`: Synchronizes the system clock with a time server, setting the timezone to London.

## Phase 1: User Environment and Core Tools (new1-*)

Scripts for setting up the user's environment, essential development tools, and version control.

* `new1-add-paths.sh`: Adds custom directories to the system's or user's `PATH` environment variable for easier command execution. *(Consider renaming to be more specific if it adds particular paths, e.g., `new1-add-custom-scripts-to-path.sh`)*.
* `new1-bashrc.sh`: Configures the `.bashrc` file with custom aliases, functions, and settings for the Bash shell in a non-disruptive way.
* `new1-essential-tools.sh`: Installs a collection of essential command-line tools and utilities for general use and development.
* `new1-github-https-authentication-with-gcm.sh`: Sets up Git Credential Manager (GCM) for simplified HTTPS authentication with GitHub.
* `new1-github-ssh-authentication.sh`: Configures SSH key-based authentication for interacting with GitHub repositories.
* `new1-inputrc-key-bindings.sh`: Customizes readline key bindings in `/etc/inputrc` or `~/.inputrc` for enhanced command-line editing (e.g., Vi or Emacs mode).
* `new1-inputrc-tab-completion.sh`: Enhances bash tab completion settings via `inputrc` for more efficient command input.
* `new1-timeshift.sh`: Installs and configures Timeshift for system snapshot creation and restoration, taking an initial snapshot.
* `new1-update-h-scripts.sh`: Updates a specific set of scripts, possibly helper scripts or scripts from another source referred to as "h-scripts". *(Clarify what "h-scripts" are for better understanding)*.
* `new1-vimrc.sh`: Sets up a custom `.vimrc` for Vim (and potentially Neovim) with preferred settings and plugins in a non-disruptive manner.

## Phase 2: Services and Applications (new2-*)

Installation and configuration of various services and applications.

* `new2-clamav.sh`: Installs and configures ClamAV, an open-source antivirus engine.
* `new2-dev-package-managers.sh`: Installs various package managers for different programming languages (e.g., Yarn, Pipx, Cargo, Composer, Maven, Gradle, CPAN, Homebrew, Miniconda, cabal, Go).
* `new2-ssh-keygen.sh`: Generates SSH key pairs for the user, typically for passwordless authentication to other systems.
* `new2-syncthing.sh`: Installs and configures Syncthing, a continuous file synchronization program.
* `new2-tailscale.sh`: Installs and configures Tailscale, a VPN service for creating secure networks.
* `new2-vnc.sh`: Sets up a VNC (Virtual Network Computing) server for remote graphical desktop access.
* `new2-x11-f1.sh`: Purpose unclear from name. Could be related to X11, function key F1 configuration, or a specific application. *(Needs clarification)*.
* `new2-x11-forwarding.sh`: Configures SSH X11 forwarding to allow running graphical applications remotely.
* `new2-xrdp1.sh`: Sets up XRDP (an open-source Remote Desktop Protocol server), possibly a specific configuration variant. *(Clarify difference from `new2-xrdp.sh` if both are kept)*.
* `new2-xrdp-check.sh`: A script to check the status or configuration of the XRDP service.
* `new2-xrdp.sh`: Sets up XRDP, enabling remote desktop access from RDP clients (like Remmina on Linux or Remote Desktop Connection on Windows).

## Phase 6: Advanced Tools & Automation (new6-*)

Scripts for more specialized tools, automation, and specific software stacks.
*(Note: Phases 3, 4, and 5 scripts from your original text file are missing from the `ls` output. You may need to locate or recreate them if they are still needed.)*

* `new6-ansible-example.yml`: An example Ansible playbook, demonstrating how to use Ansible for configuration management or deployment.
* `new6-ansible.sh`: Installs Ansible, the IT automation tool.
* `new6-email-with-gmail-relay.sh`: Installs and configures a local mail server (e.g., Postfix) to relay emails through a Gmail account for sending console/system emails.
* `new6-powershell-pwsh-debian.sh`: Installs PowerShell (pwsh) on Debian-based systems.
* `new6-powershell-pwsh-ubuntu-mint.sh`: Installs PowerShell (pwsh) on Ubuntu/Mint systems.
* `new6-python-venv-and-pipx.sh`: Sets up Python virtual environments and installs `pipx` for managing Python command-line applications in isolated environments.

---
