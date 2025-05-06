#!/bin/bash

softclear() { printf '\033[H\033[2J'; }  # May not work in GNOME terminal

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
echo
softclear

# Function to wait for user input
press_any_key() {
    echo -e "${YELLOW}\nPress any key to continue...${NC}"
    # Use read -n 1 -s -r without the explicit prompt in the read command
    read -n 1 -s -r
    echo "" # Add a newline after the key press
}

# Function to display a section
display_section() {
    local title="$1"
    local content="$2" # This variable now holds the entire multi-line content

    # clear # Clear the screen for each section (optional, uncomment if desired)
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${CYAN}${title}${NC}"
    echo -e "${BLUE}==================================================${NC}"
    # Use echo -e to interpret the newlines and colors in the content variable
    echo -e "${content}"
    press_any_key
    softclear
}

# --- Section 1: Basics and Windows Terminal Tabs and Splits ---

intro_content="This is a quick refresher on useful features of Windows Terminal when connecting via SSH to Linux systems, with pros and cons for using tools like xclip and tmux.

Windows Terminal allows you to manage multiple connections or shells in one window.
1.  ${GREEN}Tabs:${NC}
    -   Open a new tab (often a new connection/shell): ${YELLOW}Ctrl + Shift + T${NC}
    -   Close the current tab: ${YELLOW}Ctrl + Shift + W${NC}
    -   Navigate between tabs: ${YELLOW}Ctrl + Tab${NC} or ${YELLOW}Ctrl + Page Up/Down${NC}
    -   Jump to a specific tab (1-9): ${YELLOW}Ctrl + Alt + [number]${NC}

2.  ${GREEN}Splits (Panes):${NC}
    -   Split the current pane horizontally: ${YELLOW}Alt + Shift + +${NC} or ${YELLOW}Alt + Shift + D${NC}
    -   Split the current pane vertically: ${YELLOW}Alt + Shift + -${NC}
    -   Navigate between panes: ${YELLOW}Alt + Arrow Keys${NC} (Up, Down, Left, Right)
        (or just mouse click on the pane to focus)
    -   Close the current pane: ${YELLOW}Ctrl + Shift + W${NC}
    -   Resize panes: ${YELLOW}Alt + Shift + Arrow Keys${NC}
    -   Switch to layout mode (for more complex pane management): ${YELLOW}Alt + Shift + L${NC}
        (Then use Arrow Keys and Enter)

Using splits is great for:
-   Running a command in one pane while editing a file in another.
-   Monitoring logs in one pane while working elsewhere.
-   Having multiple SSH sessions open side-by-side."
display_section \
"Windows Terminal Basics, and Tabs/Splits" \
"$intro_content"
echo
echo

# --- Section 2: Copy and Paste ---

section2_content="\
Copying and pasting text is straightforward.

1.  ${GREEN}Mouse Selection:${NC}
    -   Click and drag with your ${YELLOW}left mouse button${NC} to select text.
    -   The selected text is automatically copied to the Windows clipboard by default in Windows Terminal.

2.  ${GREEN}Keyboard Shortcuts:${NC}
    -   Copy selected text to clipboard: ${YELLOW}Ctrl + Shift + C${NC}
    -   Paste from clipboard: ${YELLOW}Ctrl + Shift + V${NC}

Note: This will copy/paste text to/from the Windows clipboard. This distinction is important when working in tools like vim or nano where they have their own separate buffers.

Note: ${YELLOW}Ctrl + C${NC} is typically used in the terminal to send an interrupt signal (like stopping a running command). Avoid using it for copying unless you specifically configure your terminal.

This method works directly with the Windows clipboard without needing extra Linux tools for basic text selection."

display_section \
"Copy and Paste in Windows Terminal" \
"$section2_content"
echo
echo

# --- Section 3: tmux: Terminal Multiplexer ---

section3_content="\
${GREEN}tmux${NC} (Terminal Multiplexer) is a powerful tool that runs on the ${YELLOW}remote Linux server${NC}. It allows you to create, manage, and detach from sessions containing multiple windows and panes, even if your SSH connection is interrupted.

${YELLOW}Key Concept:${NC} tmux sessions persist on the server. You can start a long process, detach from tmux, close your SSH connection, and reattach later to find your process still running and your layout intact.

1.  ${GREEN}Installation (on Debian):${NC}
    -   ${YELLOW}sudo apt update && sudo apt install tmux${NC}

2.  ${GREEN}Basic Usage:${NC}
    -   Start a new session: ${YELLOW}tmux${NC}
    -   Start a named session: ${YELLOW}tmux new -s mysession${NC}
    -   List sessions: ${YELLOW}tmux ls${NC}
    -   Attach to the last session: ${YELLOW}tmux attach${NC}
    -   Attach to a named session: ${YELLOW}tmux attach -t mysession${NC}
    -   Detach from the current session: Press ${YELLOW}Prefix Key${NC}, then ${YELLOW}d${NC}

3.  ${GREEN}tmux Panes (Splits) Shortcuts:${NC}
    -   Most tmux commands are invoked by pressing a ${YELLOW}Prefix Key${NC} first, followed by a command key.
    -   The ${MAGENTA}default Prefix Key is Ctrl + B${NC}. Press and release Ctrl+B, then press the command key.
    -   ${YELLOW}Prefix %${NC}: Split the current pane ${GREEN}horizontally${NC}.
    -   ${YELLOW}Prefix \"${NC}: Split the current pane ${GREEN}vertically${NC}.
    -   ${YELLOW}Prefix Arrow Key${NC} (Up/Down/Left/Right): Navigate to the pane in that direction.
    -   ${YELLOW}Prefix z${NC}: Zoom pane (toggle maximize/restore).
    -   ${YELLOW}Prefix x${NC}: Close the current pane. (Requires confirmation)

4.  ${GREEN}tmux Windows Shortcuts:${NC}
    -   ${YELLOW}Prefix c${NC}: Create a new window.
    -   ${YELLOW}Prefix w${NC}: List windows (select with arrow keys and Enter).
    -   ${YELLOW}Prefix [number]${NC}: Switch to window number [number]. (e.g., Prefix 0, Prefix 1)
    -   ${YELLOW}Prefix n${NC}: Go to the next window.
    -   ${YELLOW}Prefix p${NC}: Go to the previous window.
"
display_section \
"tmux: Terminal Multiplexer" \
"$section3_content"
echo
echo

# --- Section 4: Comparison: tmux vs. Windows Terminal Splits ---

section4_content="\
Both tmux and Windows Terminal (WT) Splits let you have multiple views, but they operate fundamentally differently:

1.  ${GREEN}Where they Run:${NC}
    -   ${YELLOW}tmux:${NC} Runs entirely on the ${MAGENTA}remote Linux server${NC}. Your session lives there.
    -   ${YELLOW}WT Splits:${NC} Managed by the ${MAGENTA}local Windows Terminal application${NC}. Each split is typically a separate local process (like a separate SSH connection).

2.  ${GREEN}Session Persistence:${NC}
    -   ${GREEN}tmux Advantages:${NC} Sessions ${YELLOW}persist${NC} even if your local machine reboots or your SSH connection drops. You can detach and reattach later from the same or a different client. Ideal for long-running jobs.
    -   ${YELLOW}WT Splits Disadvantages:${NC} If Windows Terminal closes or your Windows machine reboots, all your SSH connections in splits are ${YELLOW}lost${NC}.

3.  ${GREEN}Connectivity & Performance:${NC}
    -   ${GREEN}tmux Advantages:${NC} Once attached, navigating panes/windows is fast as it's server-side. You only have ${YELLOW}one SSH connection${NC} per tmux session.
    -   ${YELLOW}WT Splits Disadvantages:${NC} Each split requires a ${YELLOW}separate SSH connection${NC} and process running on your local machine, potentially using more local resources and connection overhead if you have many splits/tabs.

4.  ${GREEN}Clipboard Integration:${NC}
    -   ${YELLOW}tmux Disadvantages:${NC} Copy/paste within tmux uses tmux's internal buffer. Getting text to/from the Windows clipboard often requires extra steps (like using mouse selection anyway, or configuring tmux's copy-mode to interact with xclip/pbcopy if X11 forwarding or other mechanisms are set up).
    -   ${GREEN}WT Splits Advantages:${NC} Native ${YELLOW}Ctrl+Shift+C${NC}/${YELLOW}Ctrl+Shift+V${NC} and mouse selection work directly with the Windows clipboard across all panes/tabs effortlessly.

5.  ${GREEN}Setup & Learning Curve:${NC}
    -   ${YELLOW}tmux Disadvantages:${NC} Requires installation and configuration on the ${MAGENTA}remote server${NC}. Has its own set of prefix-key shortcuts to learn.
    -   ${GREEN}WT Splits Advantages:${NC} Configuration is done locally in Windows Terminal settings. Uses more familiar local shortcut patterns.

${CYAN}When to use which?:${NC}

-   Use ${YELLOW}Windows Terminal Splits${NC} for:
    -   Having multiple independent SSH sessions open side-by-side for quick access or monitoring.
    -   Working across different servers simultaneously.
    -   When easy, native Windows clipboard copy/paste is a priority.
    -   When you don't need sessions to survive connection drops or local reboots.

-   Use ${GREEN}tmux${NC} (inside a single WT tab/pane) for:
    -   Running long-duration tasks on the server that you might want to detach from.
    -   Maintaining complex multi-pane layouts for a specific project or task on one server, even if you disconnect.
    -   When session persistence across connections/reboots is essential.
    -   If you need to share a terminal session (less common).
"
display_section \
"Comparison: tmux vs. Windows Terminal Splits" \
"$section4_content"
echo
echo


# --- Section 5: Other Useful Windows Terminal Features ---
# Re-numbered this section

section5_content="\
A few more things that can enhance your experience:

1.  ${GREEN}Searching:${NC}
    -   Search the terminal buffer for text: ${YELLOW}Ctrl + Shift + F${NC}
    -   Useful for finding previous commands or output.

2.  ${GREEN}Zooming:${NC}
    -   Increase/decrease font size: ${YELLOW}Ctrl + Mouse Scroll Wheel${NC}
    -   Reset zoom: ${YELLOW}Ctrl + 0${NC}

3.  ${GREEN}Settings:${NC}
    -   Open the Settings UI or JSON file: ${YELLOW}Ctrl + ,${NC}
    -   Here you can customize keybindings, color schemes, profiles (including your SSH connection), and more.

4.  ${GREEN}Dragging and Dropping:${NC}
    -   You can often drag files from Windows Explorer onto the terminal window.

5.  ${GREEN}Clear terminal (but retain scrollback history):${NC}
    -   Clear screen: ${YELLOW}Ctrl + L${NC}
    -   Not a Windows Terminal specifically, applies in most shells (bash and PowerShell etc).
    -   It does not wipe out history like ${YELLOW}clear${NC}, but unclutters the terminal window.
    -   To do this in a script:   softclear() { printf '\\033[H\\033[2J'; }"   # softclear() { printf '\033[H\033[2J'; }
:
display_section \
"Other Useful Windows Terminal Features" \
"$section5_content"
echo
echo

# --- Conclusion ---

conclusion_content="\
You've reviewed features of Windows Terminal, the clipboard integration with xclip, and a comparison between using tmux server-side sessions/splits versus Windows Terminal client-side splits.

Remember to explore Windows Terminal settings (${YELLOW}Ctrl + ,${NC}) for more customization options and consider when tmux might be beneficial for server-side session management."

display_section \
"Refresher Complete!" \
"$conclusion_content"
echo
echo

# --- End of script ---
echo -e "${BLUE}==================================================${NC}"
echo -e "${CYAN}Exiting refresher script.${NC}"
echo -e "${BLUE}==================================================${NC}"
