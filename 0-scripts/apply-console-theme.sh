#!/bin/bash

# Script to attempt to set the terminal emulator's palette and
# default foreground/background colors for the current SSH session
# via OSC escape sequences.
#
# This needs to be run on the server (Debian) and requires the client
# (e.g., Windows Terminal hosting PowerShell) to support these sequences.
#
# Usage: ./apply_ssh_theme.sh <theme_name>
# Available themes: default, solarized_dark, gruvbox_dark, dracula, nord,
#                   material_dark, one_dark_pro, tomorrow_night_eighties

# --- Helper function to apply palette and main FG/BG ---
apply_colors() {
    local theme_name="$1"
    # Associative array for palette passed as name
    declare -n palette_ref="$2"
    local background_color="$3"
    local foreground_color="$4"

    echo "Attempting to set '$theme_name' palette for your SSH client..."

    # Apply the 16 ANSI colors
    for i in {0..15}; do
        if [ -n "${palette_ref[$i]}" ]; then
            printf "\033]4;%d;%s\007" "$i" "${palette_ref[$i]}"
        fi
    done

    # Set default background (OSC 11) and foreground (OSC 10)
    if [ -n "$background_color" ]; then
        printf "\033]11;%s\007" "$background_color"
    fi
    if [ -n "$foreground_color" ]; then
        printf "\033]10;%s\007" "$foreground_color"
    fi

    echo "'$theme_name' palette commands sent."
}

# --- Theme Definitions ---

apply_theme_default() {
    echo "Attempting to reset to your terminal's default palette..."
    # OSC 104 without arguments: Resets the color palette (ANSI 0-255) to defaults
    printf "\033]104\007"
    # OSC 10 without arguments: Resets default foreground color
    printf "\033]10\007"
    # OSC 11 without arguments: Resets default background color
    printf "\033]11\007"
    # OSC 107: Resets text highlight color (less common, but for completeness)
    # printf "\033]107\007"
    echo "Terminal default palette reset commands sent."
    echo "You may need to 'clear' or open a new tab to see the full effect."
}

apply_theme_solarized_dark() {
    declare -A p
    p[0]="#073642";  p[1]="#dc322f";  p[2]="#859900";  p[3]="#b58900"
    p[4]="#268bd2";  p[5]="#d33682";  p[6]="#2aa198";  p[7]="#eee8d5"
    p[8]="#002b36";  p[9]="#cb4b16";  p[10]="#586e75"; p[11]="#657b83"
    p[12]="#839496"; p[13]="#6c71c4"; p[14]="#93a1a1"; p[15]="#fdf6e3"
    apply_colors "Solarized Dark" p "#002b36" "#839496"
}

apply_theme_gruvbox_dark() {
    declare -A p
    p[0]="#282828";  p[1]="#cc241d";  p[2]="#98971a";  p[3]="#d79921"
    p[4]="#458588";  p[5]="#b16286";  p[6]="#689d6a";  p[7]="#a89984"
    p[8]="#928374";  p[9]="#fb4934";  p[10]="#b8bb26"; p[11]="#fabd2f"
    p[12]="#83a598"; p[13]="#d3869b"; p[14]="#8ec07c"; p[15]="#ebdbb2"
    apply_colors "Gruvbox Dark" p "#282828" "#ebdbb2"
}

apply_theme_dracula() {
    declare -A p
    p[0]="#21222C";  p[1]="#FF5555";  p[2]="#50FA7B";  p[3]="#F1FA8C"
    p[4]="#6272A4";  p[5]="#BD93F9";  p[6]="#8BE9FD";  p[7]="#F8F8F2"
    p[8]="#44475A";  p[9]="#FF6E6E";  p[10]="#69FF94"; p[11]="#FFFFA5"
    p[12]="#7D8AC2"; p[13]="#FF79C6"; p[14]="#A4FFFF"; p[15]="#FFFFFF"
    apply_colors "Dracula" p "#282A36" "#F8F8F2"
}

apply_theme_nord() {
    declare -A p
    p[0]="#2E3440";  p[1]="#BF616A";  p[2]="#A3BE8C";  p[3]="#EBCB8B"
    p[4]="#81A1C1";  p[5]="#B48EAD";  p[6]="#88C0D0";  p[7]="#D8DEE9"
    p[8]="#3B4252";  p[9]="#BF616A";  p[10]="#A3BE8C"; p[11]="#EBCB8B"
    p[12]="#5E81AC"; p[13]="#B48EAD"; p[14]="#8FBCBB"; p[15]="#ECEFF4"
    apply_colors "Nord" p "#2E3440" "#D8DEE9"
}

apply_theme_material_dark() {
    declare -A p
    p[0]="#263238";  p[1]="#FF5252";  p[2]="#69F0AE";  p[3]="#FFFF00"
    p[4]="#82AAFF";  p[5]="#F06292";  p[6]="#80CBC4";  p[7]="#EEFFFF"
    p[8]="#546E7A";  p[9]="#FF8A80";  p[10]="#B9F6CA"; p[11]="#FFFF8D"
    p[12]="#82B1FF"; p[13]="#FF80AB"; p[14]="#A7FFEB"; p[15]="#FFFFFF"
    apply_colors "Material Dark" p "#263238" "#EEFFFF"
}

apply_theme_one_dark_pro() {
    declare -A p
    p[0]="#282C34";  p[1]="#E06C75";  p[2]="#98C379";  p[3]="#E5C07B"
    p[4]="#61AFEF";  p[5]="#C678DD";  p[6]="#56B6C2";  p[7]="#ABB2BF"
    p[8]="#5C6370";  p[9]="#E06C75";  p[10]="#98C379"; p[11]="#E5C07B"
    p[12]="#61AFEF"; p[13]="#C678DD"; p[14]="#56B6C2"; p[15]="#FFFFFF"
    apply_colors "One Dark Pro" p "#282C34" "#ABB2BF"
}

apply_theme_tomorrow_night_eighties() {
    declare -A p
    p[0]="#2D2D2D";  p[1]="#F2777A";  p[2]="#99CC99";  p[3]="#FFCC66"
    p[4]="#6699CC";  p[5]="#CC99CC";  p[6]="#66CCCC";  p[7]="#CCCCCC"
    p[8]="#999999";  p[9]="#F2777A";  p[10]="#99CC99"; p[11]="#FFCC66"
    p[12]="#6699CC"; p[13]="#CC99CC"; p[14]="#66CCCC"; p[15]="#FFFFFF"
    apply_colors "Tomorrow Night Eighties" p "#2D2D2D" "#CCCCCC"
}


# --- Main script logic ---
if [ -z "$1" ]; then
    echo "Usage: $0 <theme_name>"
    echo "Available themes: default, solarized_dark, gruvbox_dark, dracula, nord,"
    echo "                  material_dark, one_dark_pro, tomorrow_night_eighties"
    exit 1
fi

# Optional: Rough check for TERM variable compatibility
# if [[ "$TERM" != *"xterm"* && "$TERM" != *"putty"* && "$TERM" != *"linux"* && "$TERM" != *"screen"* && "$TERM" != *"tmux"* ]]; then
#     echo "Warning: Your TERM variable ('$TERM') might not fully support OSC palette changes."
# fi

case "$1" in
    default)
        apply_theme_default
        ;;
    solarized_dark)
        apply_theme_solarized_dark
        ;;
    gruvbox_dark)
        apply_theme_gruvbox_dark
        ;;
    dracula)
        apply_theme_dracula
        ;;
    nord)
        apply_theme_ nord
        ;;
    material_dark)
        apply_theme_material_dark
        ;;
    one_dark_pro)
        apply_theme_one_dark_pro
        ;;
    tomorrow_night_eighties)
        apply_theme_tomorrow_night_eighties
        ;;
    *)
        echo "Unknown theme: $1"
        echo "Available themes: default, solarized_dark, gruvbox_dark, dracula, nord,"
        echo "                  material_dark, one_dark_pro, tomorrow_night_eighties"
        exit 1
        ;;
esac

echo ""
echo "Reminder: These changes are likely temporary for this SSH session only."
echo "Run 'clear' to refresh the full screen with the new theme if needed."
