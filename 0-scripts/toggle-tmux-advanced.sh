#!/bin/bash
#
# Purpose: Script to toggle tmux advanced features and manage basic TPM setup.
#
# Toggles between "Advanced Tmux" (Ctrl+b Prefix, Vim keys, Dracula plugin & options)
# and "Basic Tmux" (Ctrl+b leader, default keys, Dracula plugin & TPM run line disabled).

# ===== CONFIGURATION - TMUX ADVANCED SETTINGS =====

SETTING_NAME="advanced tmux features"
CONFIG_FILE="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"

START_MARKER="# --- BEGIN TOGGLE-TMUX-ADVANCED SETTINGS ---"
END_MARKER="# --- END TOGGLE-TMUX-ADVANCED SETTINGS ---"

DESC_STYLE_1="# Advanced Tmux options are ENABLED:
# - Leader key: Ctrl+b
# - Vim keymaps for pane switching (PREFIX h,j,k,l)
# - Dracula plugin ENABLED via TPM
# - Dracula theme customized (plugins: git, cpu, ram, time)
# - Time format: Day MM/DD HH:MM (24-hour)
# - Session name and vampire icon on left status"

DESC_STYLE_2="# Advanced Tmux options are DISABLED:
# - Leader key: Ctrl+b (default)
# - Pane switching keymaps: Default (custom PREFIX h,j,k,l removed)
# - Dracula plugin DISABLED via TPM (commented out)
# - TPM execution line REMOVED (TPM will not run)
# - Dracula theme customizations: Removed"

STYLE_1_NAME="Advanced Tmux (Dracula Customized)"
STYLE_1_SETTINGS="${DESC_STYLE_1}

# Leader key: Ctrl+b
set -g prefix C-b
bind-key C-b send-prefix

# Vim keymaps for pane switching (activated by PREFIX h,j,k,l)
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

# Dracula Plugin and Theme Configurations
set -g @plugin 'dracula/tmux' # Enable Dracula plugin for TPM

# List of plugins/segments for Dracula to display
set -g @dracula-plugins \"git cpu-usage ram-usage time\"

# Time Format: Day MM/DD HH:MM (24-hour)
set -g @dracula-time-format \"%a %m/%d %H:%M\"

# Configure left status: show session module with custom icon (session name + vampire)
set -g @dracula-show-left-icon \"session\"  # Ensure the session module is active on the left
set -g @dracula-session-icon \"[#S] 🧛\"   # Prepend session name to the vampire icon; #S is session name

# Adjust status bar lengths
set -g status-left-length 40  # Increased length for session name + icon + command
set -g status-right-length 60 # Ensure enough space for Dracula right elements

set -g @dracula-show-fahrenheit false
set -g @dracula-show-location false
"

STYLE_2_NAME="Basic Tmux"
STYLE_2_SETTINGS="${DESC_STYLE_2}

# Revert to default leader key (Ctrl+b only)
set -g prefix C-b
bind-key C-b send-prefix
unbind-key C-s # Harmless if C-s was never bound

# Unbind custom Vim keymaps for pane switching
unbind-key h
unbind-key j
unbind-key k
unbind-key l

# Dracula Plugin and Theme Configurations (Disabled)
# set -g @plugin 'dracula/tmux' # Dracula plugin disabled for TPM
# @dracula-* variables specific to Style 1 are not set here.
"

APPLY_COMMAND="tmux source-file \"\${CONFIG_FILE}\""

# ===== END CONFIGURATION =====

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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
            return 1
        fi
        mkdir -p "$(dirname "$TPM_DIR")" 2>/dev/null
        if git clone --depth 1 "$TPM_REPO_URL" "$TPM_DIR"; then
            echo -e "${GREEN}TPM cloned successfully into $TPM_DIR.${NC}"
            tpm_was_just_installed=true
        else
            echo -e "${RED}Error: Failed to clone TPM. Please check git and network.${NC}"
            return 1
        fi
    fi

    if [ "$tpm_was_just_installed" = true ] && [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}File $CONFIG_FILE not found. Creating a minimal configuration...${NC}"
        {
            echo "set -g @plugin 'tmux-plugins/tpm'        # TPM itself";
            echo "set -g @plugin 'tmux-plugins/tmux-sensible' # Sensible defaults";
            echo "";
            echo "# This toggle script will manage its settings block below if enabled.";
            echo "";
            echo "$tpm_run_line_std # Initialize TMUX plugin manager (MUST BE LAST LINE!)";
        } > "$CONFIG_FILE"
        echo -e "${GREEN}Minimal $CONFIG_FILE created.${NC}"
        echo -e "${YELLOW}IMPORTANT: Start/restart tmux, then ${YELLOW}press 'Prefix + I' (capital I)${NC}${YELLOW} to fetch initial plugins.${NC}"
    fi
    return 0
}

manage_tpm_run_line() {
    local action="$1"
    local tpm_run_line_to_add="run '$HOME/.tmux/plugins/tpm/tpm'"
    local tpm_run_patterns=(
        "run '$HOME/.tmux/plugins/tpm/tpm'"
        "run '~/.tmux/plugins/tpm/tpm'"
    )

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error managing TPM run line: $CONFIG_FILE does not exist.${NC}"
        return 1
    fi

    local temp_conf_cleaned
    temp_conf_cleaned=$(mktemp) || { echo -e "${RED}Failed to create temp file for run line mgmt.${NC}"; return 1; }

    current_content=$(cat "$CONFIG_FILE")
    filtered_content="$current_content"

    for pattern in "${tpm_run_patterns[@]}"; do
        filtered_content=$(printf '%s\n' "$filtered_content" | grep -vF "$pattern")
    done
    printf '%s\n' "$filtered_content" | awk 'NF {p=1} p' > "$temp_conf_cleaned" # Removes empty lines from end too

    if [ "$action" = "enable" ]; then
        echo -e "${BLUE}Ensuring TPM run line is correctly placed at the end of $CONFIG_FILE...${NC}"
        if [ -s "$temp_conf_cleaned" ] && [ "$(tail -c1 "$temp_conf_cleaned" | wc -l)" -eq 0 ]; then
            echo "" >> "$temp_conf_cleaned"
        elif [ ! -s "$temp_conf_cleaned" ]; then # If file became empty, still add run line
             true # No extra newline needed
        fi
        echo "$tpm_run_line_to_add # Initialize TMUX plugin manager (MUST BE LAST LINE!)" >> "$temp_conf_cleaned"
    elif [ "$action" = "disable" ]; then
        echo -e "${BLUE}Removing TPM run line from $CONFIG_FILE (disabling TPM execution)...${NC}"
    else
        echo -e "${RED}Invalid action for manage_tpm_run_line: $action${NC}"
        rm "$temp_conf_cleaned"; return 1;
    fi

    if mv "$temp_conf_cleaned" "$CONFIG_FILE"; then
        return 0
    else
        echo -e "${RED}Error: Failed to write $CONFIG_FILE after managing TPM run line.${NC}"
        rm "$temp_conf_cleaned" 2>/dev/null; return 1;
    fi
}

check_current_status() {
    local desc1_first_line="${DESC_STYLE_1%%$'\n'*}"
    local desc2_first_line="${DESC_STYLE_2%%$'\n'*}"

    if awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="$desc1_first_line" '
        $0 ~ start {in_block=1; next} $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit} END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_1_NAME features are ENABLED${NC}"
        echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 0
    elif awk -v start="$START_MARKER" -v end="$END_MARKER" -v desc_query="$desc2_first_line" '
        $0 ~ start {in_block=1; next} $0 ~ end {in_block=0; next}
        in_block && $0 ~ desc_query {found=1; exit} END {exit !found}
    ' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current status: $STYLE_2_NAME features are ENABLED (Advanced features are OFF)${NC}"
        echo "$DESC_STYLE_2" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 1
    else
        echo -e "${BLUE}Current status: No specific '${START_MARKER}' block detected.${NC}"
        echo -e "${YELLOW}This script will initialize by enabling '$STYLE_1_NAME'.${NC}"
        echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'
        return 2
    fi
}

apply_settings_block() {
    local content_to_write="${1}"
    local temp_file
    temp_file=$(mktemp) || { echo -e "${RED}Failed to create temp file.${NC}"; return 1; }

    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN { in_our_block = 0 }
        $0 ~ start { in_our_block = 1; next } $0 ~ end { in_our_block = 0; next }
        !in_our_block { print }
    ' "$CONFIG_FILE" > "$temp_file"

    if [ -s "$temp_file" ] && [ "$(tail -c1 "$temp_file" | wc -l)" -eq 0 ]; then
      echo "" >> "$temp_file"
    fi

    echo "$START_MARKER" >> "$temp_file"
    echo "${content_to_write}" >> "$temp_file" # Write the multi-line settings content
    echo "$END_MARKER" >> "$temp_file"

    if [ -n "$(tail -c1 "$temp_file")" ]; then echo "" >> "$temp_file"; fi
    awk 'BEGIN{e=0} NF{print;e=0;next} !NF{e++;if(e<=1)print}' "$temp_file" > "${temp_file}.new" && mv -f "${temp_file}.new" "$temp_file"

    if mv -f "$temp_file" "$CONFIG_FILE"; then return 0; else
        echo -e "${RED}Error writing $CONFIG_FILE settings block.${NC}"; rm -f "$temp_file" 2>/dev/null; return 1;
    fi
}

# --- Main Script Execution ---
echo -e "${BLUE}Starting ${SETTING_NAME} settings check for $CONFIG_FILE...${NC}"

if ! ensure_tpm_installed; then
    echo -e "${RED}TPM setup encountered issues. Plugin-dependent features might not work.${NC}"
    read -p "Continue with toggle script anyway? [y/N] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo -e "${YELLOW}Operation cancelled.${NC}"; exit 1; fi
    echo -e "${YELLOW}Proceeding, but TPM might not be correctly configured.${NC}"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: $CONFIG_FILE not found. Cannot proceed.${NC}"; exit 1;
fi

echo -e "\n${BLUE}--- Checking current ${SETTING_NAME} settings ---${NC}"
check_current_status
current_status_code=$?

new_style_is_style1=false
if [ $current_status_code -eq 0 ]; then
    echo -e "\n${YELLOW}>>> About to remove advanced tmux features (switching to $STYLE_2_NAME)${NC}"
    new_style_content="$STYLE_2_SETTINGS"; new_style_name_display="$STYLE_2_NAME"; new_style_desc_display="$DESC_STYLE_2"
else
    echo -e "\n${YELLOW}>>> About to enable advanced tmux features ($STYLE_1_NAME)${NC}"
    if [ $current_status_code -eq 2 ]; then echo -e "${BLUE}(No existing block found, initializing with $STYLE_1_NAME)${NC}"; fi
    new_style_content="$STYLE_1_SETTINGS"; new_style_name_display="$STYLE_1_NAME"; new_style_desc_display="$DESC_STYLE_1"
    new_style_is_style1=true
fi

echo -e "\n${RED}This will modify your $CONFIG_FILE file.${NC}"
read -p "Do you want to continue? [y/N] " -n 1 -r; echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    TIMESTAMP=$(date +"%Y%m%d.%H%M%S")
    BACKUP_FILE="${CONFIG_FILE}.bak.toggle.${TIMESTAMP}"
    if cp -f "$CONFIG_FILE" "$BACKUP_FILE"; then
        echo -e "${BLUE}Created backup of $CONFIG_FILE at $BACKUP_FILE${NC}"
    else
        echo -e "${RED}Warning: Could not create backup $BACKUP_FILE. Proceed with caution.${NC}"
    fi

    echo -e "${BLUE}Applying settings block...${NC}"
    if apply_settings_block "$new_style_content"; then
        echo -e "${BLUE}Managing TPM run line...${NC}"
        run_line_action="disable"
        if [ "$new_style_is_style1" = true ]; then run_line_action="enable"; fi

        if manage_tpm_run_line "$run_line_action"; then
            echo -e "\n${GREEN}Successfully updated $CONFIG_FILE to $new_style_name_display settings!${NC}"
            echo -e "\n${BLUE}Settings summary for $new_style_name_display:${NC}"
            echo "$new_style_desc_display" | grep -E '^# - ' | sed 's/^# - /  • /'

            echo -e "\n${BLUE}To apply changes:${NC}"
            echo -e "  1. If not already in tmux, start/restart tmux (${GREEN}tmux kill-server && tmux${NC})."
            echo -e "  2. Inside tmux, reload config: ${GREEN}tmux source-file \"$CONFIG_FILE\"${NC}"

            if [ "$new_style_is_style1" = true ]; then
                echo -e "\n${YELLOW}IMPORTANT FOR PLUGINS (like Dracula):${NC}"
                echo -e "  After reloading config (step 2), ${YELLOW}press 'Prefix + I' (Shift+i)${NC}"
                echo -e "  ${YELLOW}inside tmux to make TPM install/update plugins.${NC}"
            elif [ "$run_line_action" = "disable" ]; then
                echo -e "\n${YELLOW}NOTE: TPM execution line has been removed. Plugins will not load on next tmux start.${NC}"
            fi

            if [[ -n "$TMUX" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
                echo -e "\n${GREEN}Script sourced in tmux - attempting to apply...${NC}"
                if eval "$APPLY_COMMAND"; then echo -e "${GREEN}Config reloaded.${NC}";
                    if [ "$new_style_is_style1" = true ]; then echo -e "  ${YELLOW}Remember: 'Prefix + I' for plugins!${NC}"; fi
                else echo -e "${RED}Auto-reload failed. Source manually.${NC}"; fi
            fi
        else
            echo -e "\n${RED}Failed to manage TPM run line. $CONFIG_FILE might be in an inconsistent state.${NC}"
            echo -e "${RED}Settings block was applied, but run line management failed. Check backup: $BACKUP_FILE${NC}"
        fi
    else
        echo -e "\n${RED}Failed to apply settings block. Check $CONFIG_FILE. Backup: $BACKUP_FILE${NC}"
    fi
else
    echo -e "\n${YELLOW}Operation cancelled. No changes made by this operation (ensure_tpm_installed might have run).${NC}"
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi
