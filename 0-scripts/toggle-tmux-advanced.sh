#!/bin/bash
#
# Purpose: Script to toggle tmux advanced features, manage basic TPM setup,
# and inject custom git status into the Dracula theme script.
#
# WARNING: This script directly modifies a Dracula theme file. This is inherently risky
# and changes may be overwritten by theme updates. Proceed with caution.

# ===== CONFIGURATION - TMUX ADVANCED SETTINGS =====

SETTING_NAME="advanced tmux features"
CONFIG_FILE="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO_URL="https://github.com/tmux-plugins/tpm"

# For Dracula script injection
DRACULA_SCRIPT_TARGET_PATH="$HOME/.tmux/plugins/tmux/scripts/dracula.sh" # User-specified target
DRACULA_SCRIPT_ANCHOR_LINE="tmux set-option -g status-right \"\""
GIT_POWERLINE_SCRIPT_PATH="$HOME/new_linux/0-scripts/git-powerline-tmux.sh"
LINE_TO_INJECT_IN_DRACULA="tmux set-option -ag status-right \"#[fg=cyan]#(${GIT_POWERLINE_SCRIPT_PATH}) #[default]\""


START_MARKER="# --- BEGIN TOGGLE-TMUX-ADVANCED SETTINGS ---"
END_MARKER="# --- END TOGGLE-TMUX-ADVANCED SETTINGS ---"

DESC_STYLE_1="# Advanced Tmux options are ENABLED:
# - Leader key: Ctrl+b
# - Vim keymaps for pane switching (PREFIX h,j,k,l)
# - Dracula plugin ENABLED via TPM
# - Dracula theme customized (plugins: cpu, ram, time)
# - Detailed Git status injected into Dracula theme script
# - Time format: Day MM/DD HH:MM (24-hour)
# - Session name and vampire icon on left status"

DESC_STYLE_2="# Advanced Tmux options are DISABLED:
# - Leader key: Ctrl+b (default)
# - Pane switching keymaps: Default (custom PREFIX h,j,k,l removed)
# - Dracula plugin DISABLED via TPM (commented out)
# - TPM execution line REMOVED (TPM will not run)
# - Dracula theme customizations: Removed
# - Custom Git status injection in Dracula theme script: REMOVED"

STYLE_1_NAME="Advanced Tmux (Injected Git Status)"
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
# 'git' module removed as detailed status is injected directly into dracula.sh
set -g @dracula-plugins \"cpu-usage ram-usage time\"

# Time Format: Day MM/DD HH:MM (24-hour)
set -g @dracula-time-format \"%a %m/%d %H:%M\"

# Configure left status: show session module with custom icon (session name + vampire)
set -g @dracula-show-left-icon \"session\"
set -g @dracula-session-icon \"[#S] 🧛\"

# Adjust status bar lengths
set -g status-left-length 40
set -g status-right-length 90 # Increased for detailed git + other modules

set -g @dracula-show-fahrenheit false
set -g @dracula-show-location false
"

STYLE_2_NAME="Basic Tmux"
STYLE_2_SETTINGS="${DESC_STYLE_2}

# Revert to default leader key (Ctrl+b only)
set -g prefix C-b
bind-key C-b send-prefix
unbind-key C-s

# Unbind custom Vim keymaps
unbind-key h; unbind-key j; unbind-key k; unbind-key l

# Dracula Plugin and Theme Configurations (Disabled)
# set -g @plugin 'dracula/tmux'
"

APPLY_COMMAND="tmux source-file \"\${CONFIG_FILE}\""

# ===== END CONFIGURATION =====

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

ensure_tpm_installed() {
    echo -e "${BLUE}Checking TPM installation...${NC}"
    local tpm_was_just_installed=false
    local tpm_run_line_std="run '$HOME/.tmux/plugins/tpm/tpm'"
    if [ -d "$TPM_DIR" ]; then echo -e "${GREEN}TPM found at $TPM_DIR.${NC}"; else
        echo -e "${BLUE}TPM not found. Attempting to install TPM...${NC}"
        if ! command -v git &>/dev/null; then echo -e "${RED}Error: git not found.${NC}"; return 1; fi
        mkdir -p "$(dirname "$TPM_DIR")" 2>/dev/null
        if git clone --depth 1 "$TPM_REPO_URL" "$TPM_DIR"; then
            echo -e "${GREEN}TPM cloned successfully.${NC}"; tpm_was_just_installed=true
        else echo -e "${RED}Error: Failed to clone TPM.${NC}"; return 1; fi
    fi
    if [ "$tpm_was_just_installed" = true ] && [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}Creating minimal $CONFIG_FILE...${NC}"
        { echo "set -g @plugin 'tmux-plugins/tpm'"; echo "set -g @plugin 'tmux-plugins/tmux-sensible'"; echo "";
          echo "$tpm_run_line_std # Initialize TMUX plugin manager (MUST BE LAST LINE!)"; } > "$CONFIG_FILE"
        echo -e "${GREEN}Minimal $CONFIG_FILE created. ${YELLOW}Press 'Prefix + I' in tmux to fetch plugins.${NC}"
    fi; return 0
}

manage_tpm_run_line() {
    local action="$1"; local tpm_run_line_to_add="run '$HOME/.tmux/plugins/tpm/tpm'"
    local tpm_run_patterns=("run '$HOME/.tmux/plugins/tpm/tpm'" "run '~/.tmux/plugins/tpm/tpm'")
    if [ ! -f "$CONFIG_FILE" ]; then echo -e "${RED}Err: $CONFIG_FILE missing (run line mgmt).${NC}"; return 1; fi
    local tmp_cleaned; tmp_cleaned=$(mktemp) || { echo -e "${RED}Mktemp failed (run line).${NC}"; return 1; }
    current_content=$(cat "$CONFIG_FILE"); filtered_content="$current_content"
    for pattern in "${tpm_run_patterns[@]}"; do
        filtered_content=$(printf '%s\n' "$filtered_content" | grep -vF "$pattern")
    done
    printf '%s\n' "$filtered_content" | awk 'NF {p=1} p' > "$tmp_cleaned"
    if [ "$action" = "enable" ]; then
        echo -e "${BLUE}Ensuring TPM run line is at the end of $CONFIG_FILE...${NC}"
        if [ -s "$tmp_cleaned" ] && [ "$(tail -c1 "$tmp_cleaned" | wc -l)" -eq 0 ]; then echo "" >> "$tmp_cleaned"; fi
        echo "$tpm_run_line_to_add # Initialize TMUX plugin manager (MUST BE LAST LINE!)" >> "$tmp_cleaned"
    elif [ "$action" = "disable" ]; then
        echo -e "${BLUE}Removing TPM run line from $CONFIG_FILE...${NC}"
    else echo -e "${RED}Invalid action: $action (run line).${NC}"; rm "$tmp_cleaned"; return 1; fi
    if mv "$tmp_cleaned" "$CONFIG_FILE"; then return 0; else
        echo -e "${RED}Error writing $CONFIG_FILE (run line).${NC}"; rm "$tmp_cleaned" 2>/dev/null; return 1;
    fi
}

manage_dracula_script_injection() {
    local action="$1"
    echo -e "${BLUE}Managing Dracula script injection ($action)...${NC}"
    if [ ! -f "$DRACULA_SCRIPT_TARGET_PATH" ]; then
        echo -e "${RED}Dracula script target not found: $DRACULA_SCRIPT_TARGET_PATH${NC}"
        echo -e "${YELLOW}Cannot inject/remove git status line. Please verify Dracula installation and paths.${NC}"
        # For "enable", this is a failure to apply the feature. For "disable", it means nothing to remove.
        # It's probably best to return an error if enabling, and success if disabling (as there's nothing to do).
        [ "$action" = "enable" ] && return 1 || return 0
    fi

    local dracula_backup_file="${DRACULA_SCRIPT_TARGET_PATH}.bak.inj.${TIMESTAMP}" # TIMESTAMP is global
    if ! cp "$DRACULA_SCRIPT_TARGET_PATH" "$dracula_backup_file"; then
        echo -e "${RED}Failed to backup $DRACULA_SCRIPT_TARGET_PATH. Aborting modification.${NC}"
        return 1
    fi
    echo -e "${BLUE}Backup of $DRACULA_SCRIPT_TARGET_PATH created at $dracula_backup_file${NC}"

    local temp_script_content; temp_script_content=$(mktemp) || { echo -e "${RED}Mktemp failed (Dracula inject).${NC}"; return 1; }
    
    # Always remove any existing injected line first for idempotency
    grep -vF "$LINE_TO_INJECT_IN_DRACULA" "$DRACULA_SCRIPT_TARGET_PATH" > "$temp_script_content"

    local anchor_actually_found=false
    if [ "$action" = "enable" ]; then
        echo -e "${BLUE}Attempting to inject git status line into $DRACULA_SCRIPT_TARGET_PATH...${NC}"
        local temp_script_injected; temp_script_injected=$(mktemp) || { echo -e "${RED}Mktemp failed (Dracula inject stage 2).${NC}"; rm "$temp_script_content"; return 1; }

        # Use awk to find anchor and print existing lines + injected line
        awk -v anchor="$DRACULA_SCRIPT_ANCHOR_LINE" -v inject="$LINE_TO_INJECT_IN_DRACULA" '
            { print } # Print current line
            $0 == anchor { print inject; found_anchor=1 }
            END { if (found_anchor==1) exit 0; else exit 1 }
        ' "$temp_script_content" > "$temp_script_injected"
        
        if [ $? -eq 0 ]; then # Anchor was found by awk, injection attempted
            mv "$temp_script_injected" "$temp_script_content" # Use the injected version
            anchor_actually_found=true
            echo -e "${GREEN}Anchor found. Git status line injected command prepared.${NC}"
        else
            echo -e "${RED}Anchor line \"$DRACULA_SCRIPT_ANCHOR_LINE\" not found in $DRACULA_SCRIPT_TARGET_PATH.${NC}"
            echo -e "${YELLOW}Git status line NOT injected. The script remains cleaned of previous injections only.${NC}"
            # temp_script_content already holds the version cleaned of any previous injection
        fi
        rm "$temp_script_injected" 2>/dev/null # Clean up .injected temp if it exists
    fi # For "disable", temp_script_content (cleaned version) is already what we want.

    # Check if actual changes are to be made to the target script
    if cmp -s "$DRACULA_SCRIPT_TARGET_PATH" "$temp_script_content"; then
        echo -e "${BLUE}No effective change needed for $DRACULA_SCRIPT_TARGET_PATH for action '$action'.${NC}"
        if [ "$action" = "enable" ] && [ "$anchor_actually_found" = false ]; then
            echo -e "${YELLOW}Note: Injection for git status was desired but anchor was not found.${NC}"
        fi
        rm "$temp_script_content"
        return 0 # Success, but no change made to file
    fi

    # Write the modified content (either with injection or with removal) back
    if mv "$temp_script_content" "$DRACULA_SCRIPT_TARGET_PATH"; then
        echo -e "${GREEN}Successfully modified $DRACULA_SCRIPT_TARGET_PATH for action '$action'.${NC}"
        if [ "$action" = "enable" ] && [ "$anchor_actually_found" = false ]; then
             echo -e "${YELLOW}Warning: Anchor for git status injection not found. Line was not injected.${NC}"
             echo -e "${YELLOW}$DRACULA_SCRIPT_TARGET_PATH was only cleaned of any previous identical injections.${NC}"
        fi
        return 0
    else
        echo -e "${RED}Error: Failed to write changes to $DRACULA_SCRIPT_TARGET_PATH.${NC}"
        echo -e "${RED}Attempting to restore from backup: $dracula_backup_file ...${NC}"
        if cp "$dracula_backup_file" "$DRACULA_SCRIPT_TARGET_PATH"; then
            echo -e "${GREEN}Restored $DRACULA_SCRIPT_TARGET_PATH from backup.${NC}"
        else
            echo -e "${RED}CRITICAL: Failed to restore $DRACULA_SCRIPT_TARGET_PATH. Please check manually! Path: $DRACULA_SCRIPT_TARGET_PATH Backup: $dracula_backup_file${NC}"
        fi
        rm "$temp_script_content"
        return 1
    fi
}

check_current_status() {
    local desc1_first_line="${DESC_STYLE_1%%$'\n'*}"; local desc2_first_line="${DESC_STYLE_2%%$'\n'*}"
    if awk -v s="$START_MARKER" -v e="$END_MARKER" -v d="$desc1_first_line" '$0~s{b=1;next}$0~e{b=0;next}b&&$0~d{f=1;exit}END{exit !f}' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current: $STYLE_1_NAME ENABLED${NC}"; echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'; return 0
    elif awk -v s="$START_MARKER" -v e="$END_MARKER" -v d="$desc2_first_line" '$0~s{b=1;next}$0~e{b=0;next}b&&$0~d{f=1;exit}END{exit !f}' "$CONFIG_FILE"; then
        echo -e "${GREEN}Current: $STYLE_2_NAME ENABLED (Advanced OFF)${NC}"; echo "$DESC_STYLE_2" | grep -E '^# - ' | sed 's/^# - /  • /'; return 1
    else
        echo -e "${BLUE}Current: No specific block detected.${NC}"; echo -e "${YELLOW}Will init with '$STYLE_1_NAME'.${NC}"; echo "$DESC_STYLE_1" | grep -E '^# - ' | sed 's/^# - /  • /'; return 2
    fi
}

apply_settings_block() {
    local content="${1}"; local tmp; tmp=$(mktemp) || { echo -e "${RED}Mktemp failed (apply_settings).${NC}"; return 1; }
    awk -v s="$START_MARKER" -v e="$END_MARKER" 'BEGIN{ib=0}$0~s{ib=1;next}$0~e{ib=0;next}!ib{print}' "$CONFIG_FILE" > "$tmp"
    if [ -s "$tmp" ] && [ "$(tail -c1 "$tmp"|wc -l)" -eq 0 ]; then echo "" >> "$tmp"; fi
    echo "$START_MARKER" >> "$tmp"; echo "${content}" >> "$tmp"; echo "$END_MARKER" >> "$tmp"
    if [ -n "$(tail -c1 "$tmp")" ]; then echo "" >> "$tmp"; fi
    awk 'BEGIN{el=0}NF{print;el=0;next}!NF{el++;if(el<=1)print}' "$tmp" > "${tmp}.new" && mv -f "${tmp}.new" "$tmp"
    if mv -f "$tmp" "$CONFIG_FILE"; then return 0; else
        echo -e "${RED}Error writing $CONFIG_FILE block.${NC}"; rm -f "$tmp" 2>/dev/null; return 1;
    fi
}

# --- Main Script Execution ---
echo -e "${BLUE}Starting ${SETTING_NAME} settings check for $CONFIG_FILE...${NC}"
if ! ensure_tpm_installed; then
    echo -e "${RED}TPM setup issues. Plugin features might not work.${NC}"
    read -p "Continue anyway? [y/N] " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then echo -e "${YELLOW}Cancelled.${NC}"; exit 1; fi
    echo -e "${YELLOW}Proceeding, but TPM may not be configured.${NC}"
fi
if [ ! -f "$CONFIG_FILE" ]; then echo -e "${RED}Err: $CONFIG_FILE not found.${NC}"; exit 1; fi

echo -e "\n${BLUE}--- Checking current ${SETTING_NAME} settings ---${NC}"; check_current_status
current_status_code=$?

new_style_is_style1=false
if [ $current_status_code -eq 0 ]; then
    echo -e "\n${YELLOW}>>> About to remove advanced tmux features (switching to $STYLE_2_NAME)${NC}"
    new_style_content="$STYLE_2_SETTINGS"; new_style_name_display="$STYLE_2_NAME"; new_style_desc_display="$DESC_STYLE_2"
else
    echo -e "\n${YELLOW}>>> About to enable advanced tmux features ($STYLE_1_NAME)${NC}"
    if [ $current_status_code -eq 2 ]; then echo -e "${BLUE}(No existing block, initializing with $STYLE_1_NAME)${NC}"; fi
    new_style_content="$STYLE_1_SETTINGS"; new_style_name_display="$STYLE_1_NAME"; new_style_desc_display="$DESC_STYLE_1"
    new_style_is_style1=true
fi

echo -e "\n${RED}This will modify your $CONFIG_FILE AND POSSIBLY A DRACULA THEME SCRIPT.${NC}"
echo -e "${RED}Modifying theme scripts is risky and may be overwritten by theme updates.${NC}"
read -p "Do you want to continue? [y/N] " -n 1 -r; echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    TIMESTAMP=$(date +"%Y%m%d.%H%M%S") # Global TIMESTAMP for backups in this run
    CONFIG_BACKUP_FILE="${CONFIG_FILE}.bak.toggle.${TIMESTAMP}"
    if cp -f "$CONFIG_FILE" "$CONFIG_BACKUP_FILE"; then
        echo -e "${BLUE}Backup of $CONFIG_FILE at $CONFIG_BACKUP_FILE${NC}"
    else echo -e "${RED}Warning: Could not backup $CONFIG_FILE.${NC}"; fi

    echo -e "${BLUE}Applying settings block to $CONFIG_FILE...${NC}"
    if apply_settings_block "$new_style_content"; then
        echo -e "${BLUE}Managing TPM run line in $CONFIG_FILE...${NC}"
        run_line_action="disable"; dracula_script_action="disable"
        if [ "$new_style_is_style1" = true ]; then run_line_action="enable"; dracula_script_action="enable"; fi

        if manage_tpm_run_line "$run_line_action"; then
            echo -e "${BLUE}Managing Dracula script injection...${NC}"
            if manage_dracula_script_injection "$dracula_script_action"; then
                echo -e "\n${GREEN}Successfully updated configurations for $new_style_name_display!${NC}"
                echo "$new_style_desc_display" | grep -E '^# - ' | sed 's/^# - /  • /'
                echo -e "\n${BLUE}To apply changes:${NC}"
                echo -e "  1. Restart tmux (${GREEN}tmux kill-server && tmux${NC})."
                echo -e "  2. Inside tmux, reload config: ${GREEN}tmux source-file \"$CONFIG_FILE\"${NC}"
                if [ "$new_style_is_style1" = true ]; then
                    echo -e "\n${YELLOW}IMPORTANT FOR PLUGINS: ${YELLOW}Press 'Prefix + I' (Shift+i)${NC}${YELLOW} to install/update plugins.${NC}"
                elif [ "$run_line_action" = "disable" ]; then
                    echo -e "\n${YELLOW}NOTE: TPM disabled. Plugins will not load. Git status injection removed from Dracula script.${NC}"
                fi
                # Auto-apply if sourced
                if [[ -n "$TMUX" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
                    echo -e "\n${GREEN}Sourced in tmux - applying...${NC}"
                    if eval "$APPLY_COMMAND"; then echo -e "${GREEN}Config reloaded.${NC}";
                        if [ "$new_style_is_style1" = true ]; then echo -e "  ${YELLOW}Remember: 'Prefix + I' for plugins!${NC}"; fi
                    else echo -e "${RED}Auto-reload failed.${NC}"; fi
                fi
            else echo -e "\n${RED}Failed to manage Dracula script injection. Check messages above.${NC}"; fi
        else echo -e "\n${RED}Failed to manage TPM run line. $CONFIG_FILE might be inconsistent.${NC}"; fi
    else echo -e "\n${RED}Failed to apply settings block to $CONFIG_FILE. Check backup.${NC}"; fi
else
    echo -e "\n${YELLOW}Operation cancelled.${NC}"
fi
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then exit 0; fi
