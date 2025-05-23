#!/bin/bash
# path - Script to manage and inspect the PATH environment variable.

# Define colors
RED='\e[31m'
YELLOW='\e[33m' # For non-existent paths
GREEN='\e[32m'
BLUE='\e[34m'  # For file names in --from
NC='\e[0m'     # No Color

# Function to show usage help
show_help() {
    echo    "Path Tool. Usage: ${0##*/} [option] [argument]"   # replace basename with ${0##*/}
    echo    "Options:"
    echo    "  (no option)         Show current user's \$PATH, one entry per line. Duplicates are highlighted"
    echo -e "                      in ${RED}red${NC}; non-existent paths are highlighted in ${YELLOW}yellow${NC}."
    echo    "  -h, --help          Show this help message."
    echo    "  -hh                 A help explainer for how paths are generated."
    echo    "  -s, --sudo          Show the sudo/root user's \$PATH, formatted."
    echo    "                      (Checks for path existence by default)."
    echo    "  -a, --add <dir>     Append <dir> to the current session's \$PATH."
    echo    "                      Example: ${0##*/} -a /usr/local/custom/bin"
    echo    "  -p, --prepend <dir> Prepend <dir> to the current session's \$PATH."
    echo    "                      Example: ${0##*/} -p ~/my_scripts"
    echo    "  -f, --from          Search common startup files for lines that set or modify \$PATH."
    echo    "                      (Prints filename, line number, and the matching line)."
    echo    "  -c, --check         Check current \$PATH for non-existent directories."
    echo -e "                      Non-existent paths are highlighted in ${YELLOW}yellow${NC}."
    echo -e "                      If a path is both a duplicate and non-existent, it will be ${RED}red${NC}"
    echo -e "                      and marked with a ${YELLOW}(non-existent)${NC} tag."
    echo    "  -w, --where <cmd>   Show all locations of <cmd> in the current \$PATH."
    echo    "                      Also checks if <cmd> is a shell alias or function."
    echo
    echo "If duplicates are found, a message will appear at the bottom."
    echo "If non-existent paths are found (with default display or -c), a message will appear."
}

# Function to process and display a given PATH string
# Arguments:
# $1: The PATH string (e.g., "$PATH" or output of sudo env PATH)
# $2: Optional flag. If "check_existence", then check if paths exist.
#     If empty or not provided, "check_existence" is implicitly on for the default display.
display_path() {
    local path_string="$1"
    # Default to checking existence unless explicitly told not to (though current options always want it or don't care)
    # For simplicity, this script will always run the existence check logic when display_path is called.
    # We'll control message printing based on the explicit -c flag or default call.
    local is_explicit_check_command="$2" 

    local old_ifs="$IFS"
    IFS=':'
    
    declare -A counts
    declare -A is_existent # Store existence status
    declare -a unique_paths_ordered # Store unique paths in their original order of appearance
    local has_duplicates=false
    local has_non_existent=false

    # First pass: count occurrences, check existence, and populate unique_paths_ordered
    for p_component in $path_string; do
        local p_component_display
        local p_for_check

        if [[ -z "$p_component" ]]; then
            # Represent empty string path component explicitly for clarity
            p_component_display="<empty_path_component>" 
            p_for_check="." # For existence check, treat as current dir (which always exists)
        else
            p_component_display="$p_component"
            p_for_check="$p_component"
        fi

        if [[ -z "${counts[$p_component_display]}" ]]; then
            unique_paths_ordered+=("$p_component_display")
        fi
        ((counts[$p_component_display]++))

        # Always check existence internally
        if [[ "$p_component_display" == "<empty_path_component>" ]]; then
             is_existent["$p_component_display"]=true # Current directory always exists
        elif [[ -d "$p_for_check" ]]; then
            is_existent["$p_component_display"]=true
        else
            is_existent["$p_component_display"]=false
        fi
    done

    # Second pass: print unique paths with highlighting
    for p_display in "${unique_paths_ordered[@]}"; do
        local current_color="$NC"
        local marker=""

        # Check for duplicates
        if [[ "${counts[$p_display]}" -gt 1 ]]; then
            current_color="$RED"
            has_duplicates=true
        fi

        # Check for non-existence
        if [[ "${is_existent[$p_display]}" == false ]]; then
            has_non_existent=true # Mark that at least one non-existent path was found
            if [[ "$current_color" == "$RED" ]]; then # Already red (duplicate)
                marker=" ${YELLOW}(non-existent)${NC}"
            else # Not a duplicate, so color it yellow
                current_color="$YELLOW"
            fi
        fi
        
        echo -e "${current_color}${p_display}${NC}${marker}"
    done

    IFS="$old_ifs"

    if [[ "$has_duplicates" == true ]]; then
        echo -e "\n${RED}Paths in red exist multiple times in the processed PATH.${NC}"
    fi
    # Show non-existent message if called by -c or if it's the default display and non-existent paths were found.
    if [[ "$has_non_existent" == true ]]; then
        if [[ "$is_explicit_check_command" == "explicit_check" ]] || [[ $# -eq 1 && -z "$1" ]]; then # $1 is path_string for default
             echo -e "\nPaths in ${YELLOW}yellow${NC} (or marked as non-existent) were not found as directories on the filesystem.${NC}"
        fi
    fi
}

# --- Main Script Logic ---

if [ $# -eq 0 ]; then
    # Default action: display current user's PATH, checking existence
    echo "PATH in this session:"
    echo
    display_path "$PATH" "explicit_check" # Pass "explicit_check" to ensure non-existent message prints if needed
    echo "Path Tool. Usage: ${0##*/} [option] [argument].   '${0##*/} -h' for options"
    echo
    exit 0
fi

option="$1"
case "$option" in
    -h|--help)
        show_help
        ;;
    -s|--sudo)
        echo "Attempting to retrieve sudo/root user's PATH..."
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}sudo command not found. Cannot display root PATH.${NC}" >&2
            exit 1
        fi

        # Try 'sudo printenv PATH' first, as it's cleaner
        sudo_path=$(sudo printenv PATH 2>/dev/null)
        
        if [[ -z "$sudo_path" ]]; then
            # Fallback to 'sudo sh -c "echo \$PATH"'
            # Using a subshell with `sh -c` ensures $PATH is from root's environment
            sudo_path=$(sudo sh -c 'echo "$PATH"' 2>/dev/null)
        fi

        if [[ -n "$sudo_path" ]]; then
            echo "Root user's PATH (obtained via sudo):"
            display_path "$sudo_path" "explicit_check" # Check existence for sudo path
        else
            echo -e "${RED}Could not retrieve sudo/root PATH.${NC}" >&2
            echo "Possible reasons:" >&2
            echo "  - Your user may not have sudo privileges." >&2
            echo "  - Sudo environment policies (e.g., secure_path in sudoers) might restrict PATH visibility or modification." >&2
            echo "  - The root user might have an empty PATH (unlikely but possible)." >&2
            exit 1
        fi
        ;;
    -a|--add)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Error: No directory specified for --add.${NC}" >&2
            show_help >&2
            exit 1
        fi
        new_dir="$2"
        
        if [[ ! -d "$new_dir" && "$new_dir" != "." && "$new_dir" != ".." ]]; then
             echo -e "${YELLOW}Warning: Directory '$new_dir' does not currently exist or is not a directory. Adding to PATH anyway.${NC}"
        fi
        
        local path_exists_in_path=false
        local temp_ifs="$IFS"
        IFS=':'
        for p_component in $PATH; do
            if [[ "$p_component" == "$new_dir" ]]; then
                path_exists_in_path=true
                break
            fi
        done
        IFS="$temp_ifs"

        if [[ "$path_exists_in_path" == true ]]; then
            echo -e "${YELLOW}'$new_dir' is already in your \$PATH.${NC}"
            echo "Current PATH:"
            display_path "$PATH" "explicit_check"
        else
            export PATH="$PATH:$new_dir"
            echo -e "${GREEN}Appended '$new_dir' to \$PATH for the current session.${NC}"
            echo "New PATH:"
            display_path "$PATH" "explicit_check"
            echo -e "\nNote: This change is temporary and only affects the current shell session."
            echo "To make it permanent, add the following line to your shell's startup file (e.g., ~/.bashrc, ~/.zshrc):"
            echo "export PATH=\"\$PATH:$new_dir\""
        fi
        ;;
    -p|--prepend)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Error: No directory specified for --prepend.${NC}" >&2
            show_help >&2
            exit 1
        fi
        new_dir="$2"

        if [[ ! -d "$new_dir" && "$new_dir" != "." && "$new_dir" != ".." ]]; then
             echo -e "${YELLOW}Warning: Directory '$new_dir' does not currently exist or is not a directory. Prepending to PATH anyway.${NC}"
        fi

        local path_exists_in_path=false
        local is_already_prepended=false
        local temp_ifs="$IFS"
        IFS=':'
        # Check if PATH is empty or just contains the new_dir already
        if [[ -z "$PATH" ]]; then
            : # PATH is empty, will prepend fine
        elif [[ "$PATH" == "$new_dir" || "$PATH" == "$new_dir:"* ]]; then
            is_already_prepended=true
        else
            for p_component in $PATH; do
                if [[ "$p_component" == "$new_dir" ]]; then
                    path_exists_in_path=true
                    break 
                fi
            done
        fi
        IFS="$temp_ifs"

        if [[ "$is_already_prepended" == true ]]; then
             echo -e "${YELLOW}'$new_dir' is already at the beginning of your \$PATH.${NC}"
        elif [[ "$path_exists_in_path" == true ]]; then
             echo -e "${YELLOW}'$new_dir' is already present in your \$PATH (but not at the beginning).${NC}"
             read -r -p "Prepending it will change its priority (and create a duplicate if it's listed multiple times). Prepend anyway? (y/N): " confirm
             if [[ "${confirm,,}" == "y" ]]; then # case insensitive compare
                export PATH="$new_dir:$PATH"
                echo -e "${GREEN}Prepended '$new_dir' to \$PATH for the current session.${NC}"
             else
                echo "Aborted."
                exit 0
             fi
        else
            export PATH="$new_dir:$PATH"
            echo -e "${GREEN}Prepended '$new_dir' to \$PATH for the current session.${NC}"
        fi
        
        echo "New PATH:"
        display_path "$PATH" "explicit_check"
        echo -e "\nNote: This change is temporary and only affects the current shell session."
        echo "To make it permanent, add the following line to your shell's startup file (e.g., ~/.bashrc, ~/.zshrc):"
        echo "export PATH=\"$new_dir:\$PATH\""
        ;;
    -f|--from)
        echo "Searching for PATH modifications in common startup files..."
        echo "(This may show errors for non-existent files, which is normal for some system configurations)"
        cat <<EOF
Files checked:

--- System-Wide Files ---     Generally loaded earlier or provide the base environment.
/etc/environment       Typically loaded by PAM very early in the login process, before shell-specific files.
                       Sets environment variables for all processes started after login.
/etc/profile           System-wide login file for Bourne-compatible shells (like Bash, Zsh). Often sources '*.sh' in /etc/profile.d/
Zsh system-specific:
/etc/zsh/zshenv        Zsh system-wide, sourced on ALL Zsh invocations (login, interactive, scripts). Loaded very early for Zsh.
/etc/zsh/zshrc         Zsh system-wide, for INTERACTIVE shells. (After /etc/profile if it's a login shell, and after zshenv).
                       Note: Zsh also has /etc/zprofile (login, after zshenv, before zshrc) and /etc/zlogin (login, last).
Bash system-specific:
/etc/bash.bashrc       Bash system-wide, for INTERACTIVE non-login shells. Usually sourced from the user's ~/.bashrc if it exists.
Fish system-specific:
/etc/fish/config.fish  Fish system-wide configuration. Loaded before user's Fish config.

--- User-Specific Files ---   For user customisation, typically loaded after system-wide counterparts.
Zsh user-specific files (following the Zsh system file order):
$HOME/.zshenv        Zsh user, sourced on ALL Zsh invocations, after /etc/zsh/zshenv.
$HOME/.zshrc         Zsh user, for INTERACTIVE shells, after /etc/zsh/zshrc. Note: Zsh also has ~/.zprofile (login) and ~/.zlogin (login).
Bash user-specific (Bash reads ONE of .bash_profile, .bash_login, or .profile for login shells)
$HOME/.bash_profile  Bash user, for LOGIN shells. Preferred by Bash if it exists.
$HOME/.bash_login    Bash user, for LOGIN shells. (Alternative if .bash_profile doesn't exist - not in your original list but for context)
$HOME/.profile       Bash user, for LOGIN shells (fallback if .bash_profile/.bash_login don't exist).
                     Also used by other Bourne-compatible shells for login.
Bash user interactive:
$HOME/.bashrc        Bash user, for INTERACTIVE non-login shells.
                     Often sourced by ~/.bash_profile or ~/.profile for login shells to share settings.
Fish user-specific file
$HOME/.config/fish/config.fish   Fish user configuration.

--- Other Files ---
/etc/shells          Lists paths of valid login shells. Not for setting PATH itself.
EOF
        
        # Determine current user's home even if script is run via sudo path -f
        # However, for system-wide files, $HOME is not relevant.
        # This command is about where the *current user's active PATH* (or a generic user's PATH) might be configured.
        current_user_home="${HOME}" # Default to current $HOME
        # If sudo is used to run this script, $HOME might be root's home.
        # To get the invoking user's home:
        #   invoking_user_home=$(getent passwd $SUDO_USER | cut -d: -f6) if $SUDO_USER is set
        #   Or simply use $HOME, assuming the user runs `path -f` not `sudo path -f` to check their own files.
        # For simplicity, we'll use $HOME, which is usually correct for the context.

        files_to_check=(
            # --- System-Wide Files ---
            # These are generally loaded earlier or provide the base environment.

            "/etc/environment"              # Typically loaded by PAM very early in the login process, before shell-specific files.
                                            # Sets environment variables for all processes started after login.

            "/etc/profile"                  # System-wide login file for Bourne-compatible shells (like Bash, Zsh).
                                            # Often sources all `*.sh` scripts in /etc/profile.d/

            # Zsh system-specific files
            "/etc/zsh/zshenv"               # Zsh system-wide, sourced on ALL Zsh invocations (login, interactive, scripts). Loaded very early for Zsh.
            "/etc/zsh/zshrc"                # Zsh system-wide, for INTERACTIVE shells. (After /etc/profile if it's a login shell, and after zshenv).
                                            # Note: Zsh also has /etc/zprofile (login, after zshenv, before zshrc) and /etc/zlogin (login, last).

            # Bash system-specific file
            "/etc/bash.bashrc"    # Bash system-wide, for INTERACTIVE non-login shells.
                                  # Usually sourced from the user's ~/.bashrc if it exists.

            # Fish system-specific file
            "/etc/fish/config.fish"   # Fish system-wide configuration. Loaded before user's Fish config.

            # --- User-Specific Files ---
            # These allow users to customize their environment, typically loaded after system-wide counterparts.

            # Zsh user-specific files (following the Zsh system file order)
            "$HOME/.zshenv"    # Zsh user, sourced on ALL Zsh invocations, after /etc/zsh/zshenv.
            "$HOME/.zshrc"     # Zsh user, for INTERACTIVE shells, after /etc/zsh/zshrc.
                                            # Note: Zsh also has ~/.zprofile (login) and ~/.zlogin (login).

            # Bash user login files (Bash reads ONE of .bash_profile, .bash_login, or .profile for login shells)
            "$HOME/.bash_profile"    # Bash user, for LOGIN shells. Preferred by Bash if it exists.
            # "$HOME/.bash_login"    # Bash user, for LOGIN shells. (Alternative if .bash_profile doesn't exist - not in your original list but for context)
            "$HOME/.profile"    # Bash user, for LOGIN shells (fallback if .bash_profile/.bash_login don't exist).
                                # Also used by other Bourne-compatible shells for login.

            # Bash user interactive file
            "$HOME/.bashrc"    # Bash user, for INTERACTIVE non-login shells.
                               # Often sourced by ~/.bash_profile or ~/.profile for login shells to share settings.

            # Fish user-specific file
            "$HOME/.config/fish/config.fish"   # Fish user configuration.

            # --- Other Files ---
            "/etc/shells"    # Lists paths of valid login shells. Not for setting PATH itself.
        )
        
        if [[ -d "/etc/profile.d" ]]; then
            for f_in_profile_d in /etc/profile.d/*.sh; do
                # Check if the glob found any files to avoid adding the pattern itself
                [[ -e "$f_in_profile_d" ]] && files_to_check+=("$f_in_profile_d")
            done
        fi

        found_any_path_setting=false
        for file_path in "${files_to_check[@]}"; do
            if [[ -f "$file_path" ]]; then
                # Regex: (\bexport\s+)?\bPATH\s*=  matches 'PATH=' or 'export PATH='
                # For /etc/environment, it's just 'PATH='
                # -H prints filename, -n prints line number. --color=always keeps color.
                # We grep for lines containing PATH followed by an equals sign, optionally prefixed by export.
                if command grep --color=always -Hn -E '(\bexport\s+)?\bPATH\s*=' "$file_path"; then
                    found_any_path_setting=true
                    echo # Add a newline for better separation between files
                fi
            fi
        done

        if [[ "$found_any_path_setting" == false ]]; then
            echo "No direct PATH assignments found in the common files checked."
            echo "PATH can also be inherited or set by parent processes, login managers, or PAM modules."
        fi

        ;;

    -hh)
        cat << EOF
The $PATH environment variable can be quite extensive, and scripts files may only have explicit settings for a few of those directories, especially in in WSL (Windows Subsystem for Linux) environments, might not appear to be directly set in the usual Linux login scripts:

Default System PATH (The Basics)

Long before your ~/.bashrc or ~/.profile are executed, the system establishes a fundamental, default PATH. This often includes standard directories like:
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
And sometimes /usr/games, /usr/local/games.
This initial PATH can be set by:
The login program itself, often based on configurations in /etc/login.defs (look for ENV_PATH or ENV_SUPATH).
Compiled-in defaults within the shell (e.g., bash).
Early system-wide scripts like /etc/profile might set an initial PATH. Your p -f output didn't show a direct PATH= line from /etc/profile itself, but this file often contains logic that sets it or sources other files (like those in /etc/profile.d/) that do. The snap/bin path was found via /etc/profile.d/apps-bin-path.sh, which shows this mechanism is active.
WSL Interoperability (The Windows Paths)

This is the biggest contributor to the "mystery paths" in your case. WSL has a feature that automatically appends your Windows %PATH% environment variable to the Linux $PATH. This is why you see all those /mnt/c/... directories:
/mnt/c/Program Files/PowerShell/7
/mnt/c/Program Files (x86)/Common Files/Oracle/Java/java8path
...and all the others under /mnt/c/.
This behavior is typically controlled by the [interop] section in /etc/wsl.conf. If appendWindowsPath is set to true (which is often the default), these paths are added.
The /usr/lib/wsl/lib path is also specific to WSL's infrastructure, set up during WSL's initialization.
These paths are added by WSL outside of the standard Linux shell startup scripts your p -f command is checking.
PAM (Pluggable Authentication Modules)

PAM modules can influence the environment. For instance, pam_env.so can set environment variables based on /etc/environment and /etc/security/pam_env.conf.
Your p -f output shows /etc/environment was checked, but no PATH modifications were reported from it in your current output. This means either PATH isn't set there, or it's set in a way your grep pattern didn't catch (though /etc/environment usually has simple KEY=VALUE pairs).
Scripts Not Checked or Complex Logic:

While your files_to_check list is quite comprehensive, there could be other less common scripts or system configurations.
If scripts use complex logic to build the PATH (e.g., loops, conditional statements that append multiple directories without a direct PATH=... on one line for each), your grep command might only catch parts of it or miss the overall picture for those specific files.
EOF
    ;;  

    -c|--check)
        echo "Checking current \$PATH for non-existent directories:"
        display_path "$PATH" "explicit_check" # Pass flag to ensure message prints
        ;;
    -w|--where)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Error: No command specified for --where.${NC}" >&2
            show_help >&2
            exit 1
        fi
        command_to_find="$2"
        echo -e "Searching for executable '$command_to_find' in \$PATH (${BLUE}$PATH${NC}):"
        
        local old_ifs="$IFS"
        IFS=':'
        local found_cmd_in_path=false
        local i=1
        for p_dir in $PATH; do
            if [[ -z "$p_dir" ]]; then # Handle empty path components (like current dir if "::")
                p_dir="." # Check current directory for empty path components
            fi
            if [[ -d "$p_dir" && -x "$p_dir/$command_to_find" && ! -d "$p_dir/$command_to_find" ]]; then # Exists, executable, and not a directory
                echo -e "  ${GREEN}Found:${NC} $p_dir/$command_to_find"
                found_cmd_in_path=true
            fi
            ((i++))
        done
        IFS="$old_ifs"

        if [[ "$found_cmd_in_path" == false ]]; then
            echo -e "${YELLOW}Command '$command_to_find' not found as an executable file in any directory in your \$PATH.${NC}"
        fi
        
        # Additionally, check if it's an alias, function, or shell builtin
        type_output=$(type "$command_to_find" 2>/dev/null)
        if [[ -n "$type_output" && "$type_output" != *"not found"* ]]; then
            echo -e "\nAdditionally, 'type $command_to_find' reports:"
            echo "$type_output"
        elif [[ "$found_cmd_in_path" == false ]]; then # If not in path and not a type
             echo -e "${RED}'$command_to_find' does not appear to be an executable in PATH, alias, function, or builtin.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}\n" >&2
        show_help >&2
        exit 1
        ;;
esac

exit 0
