#!/bin/bash
#
# Purpose: Generic script to toggle between two sets of tmux configuration settings.
# Manages advanced features and ensures TPM (Tmux Plugin Manager) is available.
#
# Toggles between "Advanced Tmux" (Dual Prefix, Vim keys, Dracula plugin & options)
# and "Basic Tmux" (Ctrl+b leader, default keys, Dracula plugin disabled).

# ===== CONFIGURATION - TMUX ADVANCED SETTINGS =====

# Script-level & TPM configuration
SETTING_NAME="advanced tmux features"
CONFIG_FILE="$HOME/.tmux.conf"             # Main tmux configuration file
TPM_DIR="$HOME/.tmux/plugins/tpm"          # TPM installation directory
TPM_REPO_URL="https://github.com/tmux-plugins/tpm" # TPM repository

# Define the marker comments we'll use to identify our settings block
START_MARKER="# --- BEGIN TOGGLE-TMUX-ADVANCED SETTINGS ---"
END_MARKER="# --- END TOGGLE-TMUX-ADVANCED SETTINGS ---"

# --- Define Description Strings for each style (with # prefix as requested) ---
DESC_STYLE_1="# Advanced Tmux options are ENABLED:
# - Leader keys: Ctrl+b (primary) AND Ctrl+s (secondary)
# - Vim keymaps for pane switching (PREFIX h,j,k,l)
# - Dracula plugin ENABLED via TPM
# - Dracula theme customized (plugins: git, cpu, ram, gpu, weather, time)"

DESC_STYLE_2="# Advanced Tmux options are DISABLED:
# - Leader key: Ctrl+b (default)
# - Pane switching keymaps: Default (custom PREFIX h,j,k,l removed)
# - Dracula plugin DISABLED via TPM (commented out)
# - Dracula theme customizations: Removed"

# --- Define Settings Blocks using the descriptions above ---
# First style settings block (Advanced ON)
STYLE_1_NAME="Advanced Tmux (Dual Prefix, Dracula)"
STYLE_1_SETTINGS="${DESC_STYLE_1}

# Leader keys: Ctrl+b (primary) AND Ctrl+s (secondary)
set -g prefix C-b
bind-key C-b send-prefix
bind-key C-s send-prefix

# Vim keymaps for pane switching (activated by PREFIX h,j,k,l)
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

# Dracula Plugin and Theme Configurations
set -g @plugin 'dracula/tmux' # Enable Dracula plugin for TPM
set -g @dracula-plugins \"git cpu-usage ram-usage gpu-usage weather time\"
set -g @dracula-show-fahrenheit false
set -g @dracula-show-location false
# Example: You can add more specific Dracula settings here
# set -g @dracula-cpu-usage-label \"CPU\""

# Second style settings block (Advanced OFF / Basic)
STYLE_2_NAME="Basic Tmux"
STYLE_2_SETTINGS="${DESC_STYLE_2}

# Revert to default leader key (Ctrl+b only)
set -g prefix C-b
bind-key C-b send-prefix
unbind-key C-s # Remove C-s as a prefix trigger

# Unbind custom Vim keymaps for pane switching from the prefix table
unbind-key h
unbind-key j
unbind-key k
unbind-key l

# Dracula Plugin and Theme Configurations (Disabled)
# set -g @plugin 'dracula/tmux' # Dracula plugin disabled for TPM
# Specific Dracula configurations are not included here."

# Command to run after applying settings (variable expanded by eval)
APPLY_COMMAND="tmux source-file \"\${CONFIG_FILE}\"" # Using quotes around ${CONFIG_FILE} for safety

# ===== END CONFIGURATION =====

# Define color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to ensure TPM is installed and basic .tmux.conf structure exists
ensure_tpm_installed() {
    echo -e "${BLUE}Checking TPM installation...${NC}"
    local tpm_was_just_installed=false
    local tpm_run_line_std="run '$HOME/.tmux/plugins/tpm/tpm'"

    if [ -d "$TPM_DIR" ]; then
        echo -e "${GREEN}TPM found at $TPM_DIR.${NC}"
    else
        echo -e "${BLUE}TPM not found. Attempting to install TPM from $TPM_REPO_URL...${NC}"
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Error: git command not found. Please install git to clone TPM.${NC}"
            echo -e "${YELLOW}Skipping automatic TPM installation. Please install TPM manually.${NC}"
            return 1
        fi

        mkdir -p "$(dirname "$TPM_DIR")" 2>/dev/null

        if git clone --depth 1 "$TPM_REPO_URL" "$TPM_DIR"; then
            echo -e "${GREEN}TPM cloned successfully into $TPM_DIR.${NC}"
            tpm_was_just_installed=true
        else
            echo -e "${RED}Error: Failed to clone TPM. Please check git installation and network.${NC}"
            echo -e "${YELLOW}Skipping automatic TPM installation. Please install TPM manually.${NC}"
            return 1
        fi
    fi

    if [ "$tpm_was_just_installed" = true ] || [ ! -f "$CONFIG_FILE" ]; then
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${BLUE}File $CONFIG_FILE not found. Creating a minimal configuration...${NC}"
            {
                echo "set -g @plugin 'tmux-plugins/tpm'        # TPM itself";
                echo "set -g @plugin 'tmux-plugins/tmux-sensible' # Sensible defaults (recommended)";
                echo "";
                echo "# Add other plugins and custom settings here, or let this toggle script manage its block.";
                echo "";
                echo "# --- This toggle script will manage settings between START and END markers ---";
                echo "";
                echo "$tpm_run_line_std # Initialize TMUX plugin manager (MUST BE LAST LINE!)";
            } > "$CONFIG_FILE"
            echo -e "${GREEN}Minimal $CONFIG_FILE created.${NC}"
            echo -e "${YELLOW}IMPORTANT: Start/restart tmux, then ${YELLOW}press 'Prefix + I' (capital I)${NC}${YELLOW} to fetch initial plugins.${NC}"
        elif [ "$tpm_was_just_installed" = true ]; then
             echo -e "${YELLOW}TPM was just installed.${NC}"
            if ! grep -Fxq "$tpm_run_line_std" "$CONFIG_FILE"; then
                 echo -e "${RED}CRITICAL WARNING: The TPM 'run' line ('$tpm_run_line_std') might be missing, incorrect, or not the last line in your existing $CONFIG_FILE.${NC}"
                 echo -e "${RED}Please ensure it is the VERY LAST line in $CONFIG_FILE.${NC}"
            fi
            echo -e "${YELLOW}IMPORTANT: After verifying $CONFIG_FILE, start/restart tmux, then ${YELLOW}press 'Prefix + I' (capital I)${NC}${YELLOW} to initialize plugins.${NC}"
        fi
    elif [ -f "$CONFIG_FILE" ] && ! grep -q "plugins/tpm/tpm'" "$CONFIG_FILE"; then
        echo -e "${RED}WARNING: The TPM 'run' line ('$tpm_run_line_std') might be missing or incorrect in your $CONFIG_FILE.${NC}"
        echo -e "${RED}Please ensure it is the VERY LAST line in $CONFIG_FILE for TPM to work.${NC}"
    fi
    return 0
}

# --- Main Script Logic ---
echo -e "${BLUE}Starting ${SETTING_NAME} settings check for $CONFIG_FILE...${NC}"

if ! ensure_tpm_installed; then
    echo -e "${RED}TPM setup encountered issues. Plugin-dependent features (like Dracula) might not work.${NC}"
    read -p "Continue with toggle script anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled by user.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Proceeding, but be aware TPM might not be correctly configured.${NC}"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: $CONFIG_FILE still not found. Cannot proceed without it.${NC}"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d.%H%M%S")
BACKUP_FILE="${CONFIG_FILE}.bak.${TIMESTAMP}"
if cp -f "$CONFIG_FILE" "$BACKUP_FILE"; then
    echo -e "${BLUE}Created backup of $CONFIG_FILE at $BACKUP_FILE${NC}"
else
    echo -e "${RED}Warning: Could not create backup file $BACKUP_FILE. Proceed with caution.${NC}"
fi

# Function to display current status
check_current_status() {
    local desc1_first_line="${DESC_STYLE_1%%$'\n'*}" # Get first line of description for matching
    local desc2_first_line="${DESC_STYLE_2%%$'\n'*}"

    if awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="$desc1_first_line" '
        $0 ~ start {in_block=1; next}
        $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit}
        END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_1_NAME ${SETTING_NAME} is ENABLED${NC}"
        echo -e "${YELLOW}Features active (details in $CONFIG_FILE within markers):${NC}"
        echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 0
    elif awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="$desc2_first_line" '
        $0 ~ start {in_block=1; next}
        $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit}
        END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_2_NAME ${SETTING_NAME} is ENABLED${NC}"
        echo -e "${YELLOW}Features active (details in $CONFIG_FILE within markers):${NC}"
        echo "$DESC_STYLE_2" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 1
    else
        echo -e "${BLUE}Current status: No specific '${START_MARKER}' block detected.${NC}"
        echo -e "${YELLOW}This script will initialize settings to '$STYLE_1_NAME'.${NC}"
        echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 2
    fi
}

# Function to apply new settings
apply_settings() {
    # ${1} is the multi-line settings content (STYLE_1_SETTINGS or STYLE_2_SETTINGS)
    local temp_file
    temp_file=$(mktemp) || { echo -e "${RED}Failed to create temp file.${NC}"; exit 1; }

    # Copy lines from original config file, EXCLUDING the old managed block
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN { in_our_block = 0 }
        $0 ~ start { in_our_block = 1; next } # Skip start marker line
        $0 ~ end { in_our_block = 0; next }   # Skip end marker line
        !in_our_block { print }               # Print if not in our block
    ' "$CONFIG_FILE" > "$temp_file"

    # Ensure there's a newline before appending our new block, if $temp_file is not empty
    # and doesn't already end with a newline.
    if [ -s "$temp_file" ] && [ "$(tail -c1 "$temp_file" | wc -l)" -eq 0 ]; then
      echo "" >> "$temp_file"
    fi

    # Append the new settings block (start_marker, content, end_marker)
    echo "$START_MARKER" >> "$temp_file"
    echo "${1}" >> "$temp_file" # This is $STYLE_1_SETTINGS or $STYLE_2_SETTINGS
    echo "$END_MARKER" >> "$temp_file"

    # Clean up multiple empty lines (max 1 consecutive)
    awk 'BEGIN{empty_lines=0} NF {print; empty_lines=0; next} !NF {empty_lines++; if(empty_lines <= 1) print}' "$temp_file" > "${temp_file}.new" && mv -f "${temp_file}.new" "$temp_file"

    if mv -f "$temp_file" "$CONFIG_FILE"; then
        return 0
    else
        echo -e "${RED}Error: Failed to write changes to $CONFIG_FILE.${NC}"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

echo -e "\n${BLUE}--- Checking current ${SETTING_NAME} settings ---${NC}"
check_current_status
current_status_code=$?

new_style_is_style1=false
if [ $current_status_code -eq 0 ]; then
    echo -e "\n${YELLOW}>>> About to switch to: $STYLE_2_NAME ${SETTING_NAME}${NC}"
    new_style_content="$STYLE_2_SETTINGS"
    new_style_name_display="$STYLE_2_NAME"
    new_style_desc_display="$DESC_STYLE_2"
else
    echo -e "\n${YELLOW}>>> About to switch to: $STYLE_1_NAME ${SETTING_NAME}${NC}"
    if [ $current_status_code -eq 2 ]; then
        echo -e "${BLUE}(No existing managed block found, initializing with $STYLE_1_NAME settings)${NC}"
    fi
    new_style_content="$STYLE_1_SETTINGS"
    new_style_name_display="$STYLE_1_NAME"
    new_style_desc_display="$DESC_STYLE_1"
    new_style_is_style1=true
fi

echo -e "\n${RED}This will modify your $CONFIG_FILE file.${NC}"
read -p "Do you want to continue? [y/N] " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if apply_settings "$new_style_content"; then
        echo -e "\n${GREEN}Successfully updated $CONFIG_FILE to $new_style_name_display ${SETTING_NAME}!${NC}"
        echo -e "\n${BLUE}Settings summary for $new_style_name_display:${NC}"
        echo "$new_style_desc_display" | grep -E '^# - ' | sed 's/^# - /  • /'

        echo -e "\n${BLUE}To apply changes:${NC}"
        echo -e "  1. If not already in tmux, start a new tmux session (or restart your existing one: ${GREEN}tmux kill-server && tmux${NC})."
        echo -e "  2. Inside tmux, reload the configuration by running:"
        echo -e "     ${GREEN}tmux source-file \"$CONFIG_FILE\"${NC}"
        echo -e "     (Or use your prefix and then type '${GREEN}:source-file \"$CONFIG_FILE\"${NC}' and Enter)"

        if [ "$new_style_is_style1" = true ]; then
            echo -e "\n${YELLOW}IMPORTANT FOR PLUGINS (like Dracula):${NC}"
            echo -e "  If this is the first time enabling these advanced settings (or if Dracula plugin was just added),"
            echo -e "  you MUST instruct TPM to install plugins. After reloading the config (step 2),"
            echo -e "  ${YELLOW}press 'Prefix + I' (that's your Tmux Prefix key, then Shift+i)${NC}"
            echo -e "  ${YELLOW}inside tmux to make TPM install/update plugins.${NC}"
        fi

        if [[ -n "$TMUX" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
            echo -e "\n${GREEN}Script was sourced inside a tmux session - attempting to apply changes...${NC}"
            if eval "$APPLY_COMMAND"; then
                echo -e "${GREEN}Tmux configuration reloaded.${NC}"
                if [ "$new_style_is_style1" = true ]; then
                     echo -e "  ${YELLOW}Remember to press 'Prefix + I' if plugins need to be installed/updated by TPM.${NC}"
                     echo -e "  ${YELLOW}(That's YOUR_PREFIX_KEY then Shift+i)${NC}"
                fi
            else
                echo -e "${RED}Failed to reload tmux configuration automatically. Please run manually:${NC}"
                echo -e "  ${GREEN}tmux source-file \"$CONFIG_FILE\"${NC}"
            fi
        elif [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ -z "$TMUX" ]]; then
            echo -e "\n${YELLOW}Script was sourced, but not inside a tmux session. Changes to $CONFIG_FILE saved.${NC}"
            echo -e "${YELLOW}You'll need to manually reload the config in your tmux session(s).${NC}"
        fi
    else
        echo -e "\n${RED}Failed to apply settings. Original file should be intact. Backup is at $BACKUP_FILE.${NC}"
    fi
else
    echo -e "\n${YELLOW}Operation cancelled. No changes were made to $CONFIG_FILE by this operation (beyond initial backup).${NC}"
    echo -e "${BLUE}Backup $BACKUP_FILE contains the state before this toggle attempt.${NC}"
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then # Only exit if NOT sourced
    exit 0
fi
