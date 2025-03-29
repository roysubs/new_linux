# new_linux Project

Quick setup and configuration for new Linux systems, with various management utilities. The project root contains menu scripts to select guided setup of essential components.

## Folder Structure

### `0-new-system/`
Scripts for setting up a new Linux system (or updating, configuring existing systems). These help streamline the process of installing and configuring essential software and system settings. Use the `setup-new-system-by-menu.sh` in the root of `new_linux` to run some or all of these as required.
Note the `new1-bashrc.sh` in here which will carefully and non-destructively update `.bashrc` (i.e. if a setting already exists in the existing `.bashrc` then it will not be overwritten. These updates add various tools for navigating the project (dotsource `.bashrc` after running this, or use `. ~\new_linux\0new-system\new1-bashrc.sh` to dotsource at runtime):
`n` jump to new_linux root, `0ns` jump to the `0new-system` directory.
`0s` jump to the scripts directory (note that `new1-bashrc.sh` will add this directory to the path by default).

### `0-help/`
Markdown-based help files that can be displayed in the console using `glow`. These provide quick reference guides for various Linux commands and tools.

### `0-install/`
Scripts and logs related to software installation and system setup. Includes:
- `system_monitor.log`: A log file capturing system monitoring data.

### `0-notes/`
A collection of text-based notes documenting various aspects of system management, troubleshooting, and customizations.

### `0-scripts/`
A collection of general-purpose scripts for system automation, maintenance, and management.

### `0-games/`
Contains scripts and configurations related to game automation and running terminal-based games. Notable contents:
- `0-tmux-expect-moria/`: Scripts for automating gameplay in Moria using `tmux` and `expect`.

## Getting Started
1. Clone the repository to your system:
   ```sh
   git clone <repository-url>
   ```
2. Navigate to the directory:
   ```sh
   cd new_linux
   ```
3. Explore the available scripts and documentation as needed.

## Usage
- The `0-help/` directory contains markdown-based help files viewable with `glow`.
- The `0-install/` and `0-new-system/` folders contain installation and system setup scripts.
- The `0-scripts/` directory includes various automation tools for Linux management.

## License
This project is licensed under [Insert License Name]. See the `LICENSE` file for details.

---
Feel free to update this README as the project evolves!


