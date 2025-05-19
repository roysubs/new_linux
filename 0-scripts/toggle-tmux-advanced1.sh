#!/bin/bash
#
# Purpose: Generic script to toggle between two sets of tmux configuration settings.
# Manages advanced features and ensures TPM (Tmux Plugin Manager) is available.
#
# Toggles between "Advanced Tmux" (Dual Prefix, Vim keys, Dracula plugin & options)
# and "Basic Tmux" (Ctrl+b leader, default keys, Dracula plugin disabled).

# ===== CONFIGURATION - TMUX ADVANCED SETTINGS (Updated) =====

# Settings description - what are we toggling?
SETTING_NAME="advanced tmux features"
CONFIG_FILE="$HOME/.tmux.conf" # Main tmux configuration file
TPM_DIR="$HOME/.tmux/plugins/tpm" # TPM installation directory
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"

# Define the marker comments we'll use to identify our settings block
START_MARKER="# --- BEGIN TOGGLE-TMUX-ADVANCED SETTINGS ---"
END_MARKER="# --- END TOGGLE-TMUX-ADVANCED SETTINGS ---"

# First style settings block (Advanced ON - C-b primary, C-s secondary, Dracula enabled)
STYLE_1_NAME="Advanced Tmux (Dual Prefix, Dracula)"
STYLE_1_DESC="Advanced Tmux options are ENABLED:
# - Leader keys: Ctrl+b (primary) AND Ctrl+s (secondary)
# - Vim keymaps for pane switching (PREFIX h,j,k,l)
# - Dracula plugin ENABLED via TPM
# - Dracula theme customized (plugins: git, cpu, ram, gpu, weather, time)"
STYLE_1_SETTINGS="# \${STYLE_1_DESC}

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

# Second style settings block (Advanced OFF / Basic - C-b only, Dracula disabled)
STYLE_2_NAME="Basic Tmux"
STYLE_2_DESC="Advanced Tmux options are DISABLED:
# - Leader key: Ctrl+b (default)
# - Pane switching keymaps: Default (custom PREFIX h,j,k,l removed)
# - Dracula plugin DISABLED via TPM (commented out)
# - Dracula theme customizations: Removed"
STYLE_2_SETTINGS="# \${STYLE_2_DESC}

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

# Command to run after applying settings
APPLY_COMMAND="tmux source-file \${CONFIG_FILE}"

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
    if [ -d "$TPM_DIR" ]; then
        echo -e "${GREEN}TPM found at $TPM_DIR.${NC}"
    else
        echo -e "${BLUE}TPM not found. Attempting to install TPM from $TPM_REPO_URL...${NC}"
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Error: git command not found. Please install git to clone TPM.${NC}"
            echo -e "${YELLOW}Skipping automatic TPM installation. Please install TPM manually.${NC}"
            return 1 # Indicate TPM setup was not completed
        fi

        mkdir -p "$(dirname "$TPM_DIR")" 2>/dev/null # Ensure ~/.tmux/plugins exists

        if git clone --depth 1 "$TPM_REPO_URL" "$TPM_DIR"; then
            echo -e "${GREEN}TPM cloned successfully into $TPM_DIR.${NC}"
            tpm_was_just_installed=true
        else
            echo -e "${RED}Error: Failed to clone TPM. Please check git installation and network.${NC}"
            echo -e "${YELLOW}Skipping automatic TPM installation. Please install TPM manually.${NC}"
            return 1 # Indicate TPM setup was not completed
        fi
    fi

    # If TPM was just installed, or if .tmux.conf is missing, set up/check essentials
    if [ "$tpm_was_just_installed" = true ] || [ ! -f "$CONFIG_FILE" ]; then
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${BLUE}File $CONFIG_FILE not found. Creating a minimal configuration...${NC}"
            # Create a backup if we are about to overwrite, though touch is safe for new.
            # touch "$CONFIG_FILE" # Ensure file exists before appending
            echo "set -g @plugin 'tmux-plugins/tpm'        # TPM itself" > "$CONFIG_FILE"
            echo "set -g @plugin 'tmux-plugins/tmux-sensible' # Sensible defaults (recommended)" >> "$CONFIG_FILE"
            echo "" >> "$CONFIG_FILE"
            echo "# Add other plugins and custom settings here, or let this toggle script manage its block." >> "$CONFIG_FILE"
            echo "" >> "$CONFIG_FILE"
            echo "# --- This toggle script will manage settings between START and END markers ---" >> "$CONFIG_FILE"
            echo "" >> "$CONFIG_FILE"
            echo "run '$HOME/.tmux/plugins/tpm/tpm' # Initialize TMUX plugin manager (MUST BE LAST LINE!)" >> "$CONFIG_FILE"
            echo -e "${GREEN}Minimal $CONFIG_FILE created.${NC}"
            echo -e "${YELLOW}IMPORTANT: Start/restart tmux, then press 'Prefix + I' (capital I) to fetch initial plugins.${NC}"
        elif [ "$tpm_was_just_installed" = true ]; then
            # TPM just installed, but .tmux.conf exists. Check for run line.
             echo -e "${YELLOW}TPM was just installed.${NC}"
            if ! grep -q "plugins/tpm/tpm'" "$CONFIG_FILE"; then # Basic check for any tpm run line
                 echo -e "${RED}CRITICAL WARNING: The TPM 'run' line might be missing or incorrect in your existing $CONFIG_FILE.${NC}"
                 echo -e "${RED}Please ensure 'run '$HOME/.tmux/plugins/tpm/tpm'' is the VERY LAST line in $CONFIG_FILE.${NC}"
            fi
            echo -e "${YELLOW}IMPORTANT: After verifying $CONFIG_FILE, start/restart tmux, then press 'Prefix + I' to initialize plugins.${NC}"
        fi
    fi
    return 0
}


# --- Main Script Logic ---
echo -e "${BLUE}Starting ${SETTING_NAME} settings check for $CONFIG_FILE...${NC}"

# Call TPM check and setup function
if ! ensure_tpm_installed; then
    echo -e "${RED}TPM setup encountered issues. Plugin-dependent features might not work.${NC}"
    read -p "Continue with toggle script anyway? (Features like Dracula might not work) [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled by user.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Proceeding, but be aware TPM might not be correctly configured.${NC}"
fi


# Check if config file exists (it should after ensure_tpm_installed if it was missing)
# However, ensure_tpm_installed might fail before creating it if git is missing.
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${BLUE}Creating $CONFIG_FILE as it was not found (TPM setup might have failed to create it if git was missing)...${NC}"
    touch "$CONFIG_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Could not create $CONFIG_FILE. Check permissions.${NC}"
        exit 1
    fi
    # Add a comment to the new file indicating it can be managed by this script
    echo "# $CONFIG_FILE - Can be managed by $(basename "$0")" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE" # Add a newline
fi

# Create a backup of the current config file with a timestamp
TIMESTAMP=$(date +"%Y%m%d.%H%M%S")
BACKUP_FILE="${CONFIG_FILE}.bak.${TIMESTAMP}"
if cp -f "$CONFIG_FILE" "$BACKUP_FILE"; then
    echo -e "${BLUE}Created backup of $CONFIG_FILE at $BACKUP_FILE${NC}"
else
    echo -e "${RED}Warning: Could not create backup file $BACKUP_FILE. Proceed with caution.${NC}"
fi


# Function to display current status
check_current_status() {
    if awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="${STYLE_1_DESC%%$'\n'*}" '
        $0 ~ start {in_block=1; next}
        $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit}
        END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_1_NAME ${SETTING_NAME} is ENABLED${NC}"
        echo -e "${YELLOW}Features active (details in $CONFIG_FILE within markers):${NC}"
        echo "$STYLE_1_DESC" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 0  # Style 1 is active
    elif awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="${STYLE_2_DESC%%$'\n'*}" '
        $0 ~ start {in_block=1; next}
        $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit}
        END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_2_NAME ${SETTING_NAME} is ENABLED${NC}"
        echo -e "${YELLOW}Features active (details in $CONFIG_FILE within markers):${NC}"
        echo "$STYLE_2_DESC" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 1  # Style 2 is active
    else
        echo -e "${BLUE}Current status: No specific '${START_MARKER}' block detected.${NC}"
        echo -e "${YELLOW}This script will initialize settings to '$STYLE_1_NAME'.${NC}"
        echo "$STYLE_1_DESC" | grep -E '^# - ' | sed 's/^# - /  • /' # Show what Style 1 would enable
        return 2  # No known style active, will default to applying Style 1
    fi
}

# Function to apply new settings
apply_settings() {
    local new_settings_block="${START_MARKER}
${1}
${END_MARKER}"
    local temp_file
    temp_file=$(mktemp) || { echo -e "${RED}Failed to create temp file.${NC}"; exit 1; }

    # Copy the original file content, excluding any existing managed block
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN { printing = 1 }
        $0 ~ start { printing = 0; in_block = 1; next }
        in_block && $0 ~ end { printing = 1; in_block = 0; next }
        !in_block && printing { print }
        # If only start was found but no end, this logic might be tricky.
        # Assuming blocks are well-formed or absent.
        # More robust: track if we are inside a block.
        # If start found, set printing=0. If end found, set printing=1 and skip end line.
        # Print lines where printing=1.
    ' "$CONFIG_FILE" > "$temp_file"


    # Refined awk for removing block:
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN { in_our_block = 0 }
        $0 ~ start { in_our_block = 1; next } # Skip start marker line
        $0 ~ end { in_our_block = 0; next }   # Skip end marker line
        !in_our_block { print }               # Print if not in our block
    ' "$CONFIG_FILE" > "$temp_file"


    # Ensure there's a newline before appending, if file not empty and doesn't end with one
    if [ -s "$temp_file" ] && [ -n "$(tail -c1 "$temp_file")" ]; then
      echo "" >> "$temp_file"
    fi

    echo "$new_settings_block" >> "$temp_file"
    # Ensure a final newline for cleanliness if not already there by the end marker
    if [ -n "$(tail -c1 "$temp_file")" ]; then
        echo "" >> "$temp_file"
    fi

    # Clean up multiple empty lines (max 2 consecutive, or 1 if preferred)
    awk 'BEGIN{empty_lines=0} NF {print; empty_lines=0; next} !NF {empty_lines++; if(empty_lines <= 1) print}' "$temp_file" > "${temp_file}.new" && mv -f "${temp_file}.new" "$temp_file"

    if mv -f "$temp_file" "$CONFIG_FILE"; then
        return 0
    else
        echo -e "${RED}Error: Failed to write changes to $CONFIG_FILE.${NC}"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Check the current status
echo -e "\n${BLUE}--- Checking current ${SETTING_NAME} settings ---${NC}"
check_current_status
current_status_code=$?

# Determine which style to apply
new_style_is_style1=false
if [ $current_status_code -eq 0 ]; then # Style 1 is active, switch to Style 2
    echo -e "\n${YELLOW}>>> About to switch to: $STYLE_2_NAME ${SETTING_NAME}${NC}"
    new_style_content="$STYLE_2_SETTINGS"
    new_style_name_display="$STYLE_2_NAME"
    new_style_desc_display="$STYLE_2_DESC"
else # Style 2 is active, or no style detected (default to Style 1)
    echo -e "\n${YELLOW}>>> About to switch to: $STYLE_1_NAME ${SETTING_NAME}${NC}"
    if [ $current_status_code -eq 2 ]; then
        echo -e "${BLUE}(No existing managed block found, initializing with $STYLE_1_NAME settings)${NC}"
    fi
    new_style_content="$STYLE_1_SETTINGS"
    new_style_name_display="$STYLE_1_NAME"
    new_style_desc_display="$STYLE_1_DESC"
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
        echo -e "  1. If not already in tmux, start a new tmux session."
        echo -e "  2. Inside tmux, reload the configuration by running:"
        echo -e "     ${GREEN}tmux source-file $CONFIG_FILE${NC}"
        echo -e "     (Or use your prefix and then type ':source-file $CONFIG_FILE' and Enter)"

        if [ "$new_style_is_style1" = true ]; then
            echo -e "\n${YELLOW}IMPORTANT FOR PLUGINS (like Dracula):${NC}"
            echo -e "  If this is the first time enabling these advanced settings, or if plugins"
            echo -e "  were not previously installed by TPM, press 'Prefix + I' (capital I)"
            echo -e "  inside tmux AFTER reloading the config to make TPM install/update plugins.${NC}"
        fi

        if [[ -n "$TMUX" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
            echo -e "\n${GREEN}Script was sourced inside a tmux session - attempting to apply changes...${NC}"
            if eval "$APPLY_COMMAND"; then
                echo -e "${GREEN}Tmux configuration reloaded.${NC}"
                if [ "$new_style_is_style1" = true ]; then
                     echo -e "${YELLOW}Remember to press 'Prefix + I' if plugins need to be installed/updated by TPM.${NC}"
                fi
            else
                echo -e "${RED}Failed to reload tmux configuration automatically. Please run manually:${NC}"
                echo -e "  ${GREEN}${APPLY_COMMAND}${NC}"
            fi
        elif [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ -z "$TMUX" ]]; then
            echo -e "\n${YELLOW}Script was sourced, but not inside a tmux session. Changes to tmux config saved but not actively applied to a running session.${NC}"
        fi
    else
        echo -e "\n${RED}Failed to apply settings. Original file should be intact. Backup is at $BACKUP_FILE.${NC}"
    fi
else
    echo -e "\n${YELLOW}Operation cancelled. No changes were made to $CONFIG_FILE (beyond initial backup, if created).${NC}"
    echo -e "${BLUE}Backup $BACKUP_FILE (if created) contains the state before this operation.${NC}"
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exit 0
fi
