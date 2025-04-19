# new_linux Project

Tools to quickly configure new Linux systems, with various management utilities. The project root contains menu scripts for guided setup of essential components.

## Folder Structure

### `0-new-system/`
Scripts for setting up a new Linux system, or to configure existing systems). These automate the installation and configuration of essential system settings and step through maintainance. Run `setup-new-system-by-menu.sh` in the root of `new_linux` to select settings as as required.  
Running `0-new-system\new1-bashrc.sh` updates `.bashrc` and makes it easier to use these tools (either run it directly or call it from the `setup-new-system-by-menu.sh` menu). It will *not* overwrite existing settings in `.bashrc`, carefully only adding those that do not exist. Note: dotsource `new1-bashrc.sh` to make it also apply to the current session.  
This will add many simple convenience enhancements to bash (review the script to see them), including some quick jump aliases to navigate the project and it will add `~\new_linux\0-scripts` to the path to make tools there available. `update-bashrc.sh` will also run `new1-bashrc.sh` from the project root.
```bash
n   : jump to new_linux root.
0ns, 0h, 0i, 0s, 0n, 0g: jump to the the various project directories listed below
```

# `0-help/`
Markdown-based help that provide quick reference guides for many Linux commands and tools in this project. These are installed on the PATH at `/usr/local/bin` by the setup menu script, or `update-h-scripts.sh` in the project root. 

### `0-install/`
Scripts and logs related to software installation and system setup. Includes:

### `0-scripts/`
A collection of general-purpose scripts for system automation, maintenance, and management.

### `0-notes/`
A collection of text-based notes documenting various aspects of system management, troubleshooting, and customizations.

### `0-games/`
Contains scripts and configurations related to game automation and running terminal-based games. Notable contents:
- `0-tmux-expect-moria/`: Scripts for automating Moria setup using `tmux` and `expect`.

## Getting Started
1. Clone the repository to your system:
   ```sh
   git clone https://github.com/roysubs/new_linux
   ```
2. Navigate to the directory:
   ```sh
   cd ~/new_linux
   ```
3. Explore the available scripts and documentation as needed.

## Usage
- The `0-help/` directory contains markdown-based help files viewable with `mdcat`.
- The `0-install/` and `0-new-system/` folders contain installation and system setup scripts.
- The `0-scripts/` directory includes various automation tools for Linux management.

## License
This project is licensed under [Insert License Name]. See the `LICENSE` file for details.

---


