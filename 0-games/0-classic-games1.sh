#!/bin/bash

# Define colors for output
C_CATEGORY_TITLE="\033[1;34m" # Bold Blue
C_RESET="\033[0m"

# Game entries: name|Category|Description|apt package
# The 'name' is also assumed to be the command to run the game, unless specified otherwise.
games=(
    # Original Games
    "rogue|Roguelike|Classic dungeon crawling game.|bsdgames-nonfree"
    "angband|Roguelike|Single-player, text-based, dungeon simulation game.|angband"
    "crawl|Roguelike|Dungeon Crawl, a text-based roguelike game.|crawl"
    "moria|Roguelike|Rogue-like game with an infinite dungeon, also known as Umoria.|moria"
    "nethack|Roguelike|Dungeon crawl game – text-based interface.|nethack-console"
    "2048|Puzzle|Slide and add puzzle game for text mode.|2048"
    "asciijump|Arcade|ASCII-art game about ski jumping.|asciijump"
    "bastet|Arcade|Ncurses Tetris clone with a bastard algorithm.|bastet"
    "bombardier|Puzzle|The GNU Bombing utility.|bombardier"
    "cavezofphear|Arcade|ASCII Boulder Dash clone.|cavezofphear"
    "freesweep|Puzzle|Text-based minesweeper.|freesweep"
    "greed|Puzzle|Clone of the DOS freeware game Greed.|greed"
    "ninvaders|Arcade|Space invaders-like game using ncurses.|ninvaders"
    "nsnake|Arcade|Classic snake game on the terminal.|nsnake"
    "pacman4console|Arcade|Ncurses-based Pac-Man game.|pacman4console"
    "petris|Arcade|Peter's Tetris – a Tetris(TM) clone.|petris"
    "vitetris|Arcade|Virtual terminal Tetris clone.|vitetris"
    "robotfindskitten|Zen|Zen simulation of robot finding kitten.|robotfindskitten"
    "sudoku|Puzzle|Console-based Sudoku.|sudoku"
    "tty-solitaire|Card|Ncurses-based Klondike solitaire game.|tty-solitaire"
    "adventure|Adventure|Colossal Cave Adventure game.|bsdgames"
    "animals|Trivia|AI animal guessing engine using binary tree DB.|bsdgames"
    "arithmetic|Educational|Drill on simple arithmetic problems.|bsdgames"
    "atc|Simulation|Air Traffic Controller simulation.|bsdgames"
    "backgammon|Board|The classic board game.|bsdgames"
    "battlestar|Adventure|Space adventure game.|bsdgames"
    "boggle|Word|Word search game.|bsdgames"
    "canfield|Card|Solitaire card game.|bsdgames"
    "cribbage|Card|The classic card game.|bsdgames"
    "gomoku|Board|Five in a row game.|bsdgames"
    "hangman|Word|Guess the word game.|bsdgames"
    "mille|Card|Mille Bornes card game.|bsdgames"
    "monop|Board|Monopoly game.|bsdgames"
    "phantasia|RPG|Fantasy role-playing game.|bsdgames"
    "quiz|Trivia|Random knowledge quiz.|bsdgames"
    "robots|Puzzle|Avoid the robots game.|bsdgames"
    "sail|Strategy|Naval strategy game.|bsdgames"
    "empire|Strategy|Sci-Fi strategy game.|empire"
    "snake|Arcade|Classic snake game (from bsdgames).|bsdgames" # Distinct from nsnake
    "tetris|Arcade|Classic Tetris game (from bsdgames).|bsdgames" # Distinct from other tetris clones
    "trek|Strategy|Star Trek game.|bsdgames"

    # Added Games (approx 50+)
    "sl|Fun|Steam Locomotive for your terminal (often a joke for 'ls').|sl"
    "moon-buggy|Arcade|Drive a buggy on the moon's surface in ASCII.|moon-buggy"
    "gnugo|Board|GNU Go - text-based Go player. Use 'gnugo -T' or similar for terminal play.|gnugo"
    "gnuchess|Board|GNU Chess - text-based chess player. Run 'gnuchessc' for console.|gnuchess" # Executable: gnuchessc
    "tint|Arcade|Yet another Tetris clone for the terminal.|tint"
    "curseofwar|Strategy|A fast-paced action strategy game in text mode.|curseofwar"
    "cataclysm-dda-curses|Roguelike|Cataclysm: Dark Days Ahead. A very deep survival roguelike.|cataclysm-dda-curses" # Executable: cataclysm
    "gearhead2|Roguelike|Mecha roguelike focusing on story and exploration.|gearhead2"
    "brogue|Roguelike|A popular, visually distinct, and accessible roguelike.|brogue"
    "tome|Roguelike|Tales of Maj'Eyal - a feature-rich roguelike RPG.|tome"
    "frotz|Interactive Fiction|Interpreter for Z-code interactive fiction (e.g., Zork). Needs story files.|frotz"
    "wump|Adventure|Hunt the Wumpus in a dangerous, randomly generated cave.|bsdgames" # Executable: wump
    "rain|Fun|Animated ASCII rain in your terminal.|bsdgames-nonfree"
    "worm|Arcade|Animated ASCII worm game (different from snake).|bsdgames-nonfree" # Executable: worm
    "hunt|Multiplayer|The classic BSD game 'hunt' - a multiplayer terminal game for LAN.|bsdgames" # Executable: hunt
    "cnuke|Strategy|Text-mode nuclear war simulation game (clone of Nuke).|cnuke"
    "gobots|Arcade|Remake of the old BSD 'robots' game with more features.|gobots"
    "multitee|Multiplayer|Terminal based multiplayer shooter based on Teeworlds.|multitee"
    "netris|Multiplayer|Networked Tetris-like game for the console.|netris"
    "dwarffortress-legacy|Simulation|Dwarf Fortress (classic text-based version). A legendary colony sim.|dwarffortress-legacy" # Executable: dwarffortress
    "doomrl|Roguelike|Doom, the Roguelike. Turn-based, coffee-break, tactical fun.|doomrl"
    "powder|Roguelike|Pi's Own WondeRous Roguelike, designed for simple play.|powder"
    "zangband|Roguelike|A variant of Angband with a rich history and many features.|zangband"
    "nzons|Multiplayer|Multiplayer inter-terminal text-mode tank battle game.|nzons"
    "moonlander|Arcade|ASCII art lunar lander game.|moonlander" # Package: moonlander (or moon-lander)
    "typespeed|Educational|Test your typing speed and accuracy in the terminal.|typespeed"
    "bs|Board|Battleships, the classic board game, for the console.|bs"
    "fortune|Fun|Displays a random fortune cookie message. Often piped to cowsay.|fortune"
    "cowsay|Fun|Generates an ASCII cow (or other creature) with a message.|cowsay"
    "hollywood|Fun|Fills your terminal with technobabble like in a Hollywood movie.|hollywood"
    "rig|Utility|Random Identity Generator. Can be fun for character names.|rig"
    "morse|Utility|Translate text to morse code and play it.|morse" # Package: morse
    "asciiquarium|Fun|An aquarium/sea animation in ASCII art. Relaxing!|asciiquarium"
    "cmatrix|Fun|Simulates the scrolling green code display from 'The Matrix'.|cmatrix"
    "freecell|Card|Console-based Freecell card game.|freecell"
    "sol|Card|Spider Solitaire for the console.|sol" # Package: sol
    "ttytron|Arcade|A Tron light-cycle game for two players on the same terminal.|ttytron"
    "maze|Puzzle|Generates and optionally solves mazes. From bsdgames.|bsdgames" # Executable: maze
    "fish|Card|Plays the 'Go Fish' card game. From bsdgames.|bsdgames" # Executable: fish
    "zzz|Arcade|Arcade game similar to ZZT, with shooting and puzzles.|zzz"
    "cpat|Card|Collection of patience/solitaire games for the terminal.|cpat"
    "conquest|Strategy|Text-based game of world conquest (similar to Risk).|conquest" # Package might be gnuconquest on older systems
    "gnushogi|Board|Shogi (Japanese Chess) program for the console.|gnushogi"
    "gnubg|Board|GNU Backgammon. Use 'gnubg -t' for terminal play.|gnubg" # Executable: gnubg
    "matanza|Arcade|Fast-paced ASCII art space shooter game for the console.|matanza"
    "mgt|Board|Text-based manager for various board games (Go, Chess, etc.).|mgt"
    "redqueen|Board|Chess engine and interface for console. Use 'redqueen -c' for console.|redqueen" # Executable: redqueen
    "slashem|Roguelike|A variant of NetHack with many more monsters, items, and features.|slashem"
    "sudoku-curses|Puzzle|Sudoku game with a curses interface (alternative to 'sudoku').|sudoku-curses"
    "minesweeper-curses|Puzzle|Minesweeper game with a curses interface (alternative to 'freesweep').|minesweeper-curses"
    "nudoku|Puzzle|Ncurses based Sudoku game with advanced features.|nudoku"
    "asciibrot|Fun|Generates Mandelbrot and Julia set fractals in ASCII.|asciibrot"
    "dadadodo|Fun|Deconstructs text and generates amusing nonsense.|dadadodo"
    "dopewars|Simulation|Deal drugs and evade police in this cult classic.|dopewars"
    "moonlander-sdl|Arcade|SDL version of moon-buggy (graphical, but related).|moonlander-sdl" # Potentially graphical
    "tty-clock|Utility|Displays a digital clock on the terminal.|tty-clock"
    "vitnc|Utility|Vi-like ncurses based text editor.|vitnc" # Not a game, but a cool tui app
    "eterm|Utility|Enlightened Terminal Emulator (often includes fun themes).|eterm" # Not a game itself
    "wordwarvi|Word|A multiplayer game that tests your vi editing skills.|wordwarvi"
)

usage() {
    echo "Usage: $0 [option]"
    echo "If no option is provided, lists all games and shows this help."
    echo
    echo "Options:"
    echo "  -l                List games grouped by category"
    echo "  -h                Show this help message"
    echo "  -i <game_name>    Install a specific game by its name from the list"
    echo "  -iall             Install all unique apt packages for all listed games"
    echo "  -itype <category> Install all games of a specific category (e.g., \"Puzzle\", \"Arcade games\")"
    echo "  -r <game_name>    Run a specific game by its name from the list"
    echo
    echo "Note: Installation commands require sudo privileges."
}

# Install specific apt packages (expects package names as arguments)
install_apt_packages() {
    if [[ $# -eq 0 ]]; then
        echo "No packages specified for installation."
        return 1
    fi
    echo "Attempting to update package lists..."
    sudo apt-get update
    echo "Attempting to install packages: $*"
    sudo apt-get install -y "$@"
}

# Install a specific game by its display name
install_game_by_name() {
    local game_name_to_install="$1"
    local apt_package_to_install=""
    local game_found=false

    for entry in "${games[@]}"; do
        IFS='|' read -r name _ _ apt <<< "$entry"
        if [[ "$name" == "$game_name_to_install" ]]; then
            apt_package_to_install="$apt"
            game_found=true
            break
        fi
    done

    if ! $game_found; then
        echo "Error: Game '$game_name_to_install' not found in the list."
        echo "Use '$0 -l' to see available game names."
        exit 1
    fi

    if [[ -z "$apt_package_to_install" ]]; then
        echo "Error: APT package for game '$game_name_to_install' is not defined in the list."
        exit 1
    fi

    echo "Game '$game_name_to_install' uses APT package: '$apt_package_to_install'"
    install_apt_packages "$apt_package_to_install"
}

# Install all unique packages for all games
install_all_games() {
    local -A packages_to_install_map # Using a map to store unique package names

    for entry in "${games[@]}"; do
        IFS='|' read -r _ _ _ apt <<< "$entry"
        if [[ -n "$apt" ]]; then # Ensure apt package is defined
            packages_to_install_map["$apt"]=1
        fi
    done

    if [[ ${#packages_to_install_map[@]} -eq 0 ]]; then
        echo "No APT packages found to install."
        exit 0
    fi

    echo "The following unique APT packages will be installed for ALL listed games:"
    for pkg in "${!packages_to_install_map[@]}"; do
        echo "  - $pkg"
    done
    
    read -p "This will install many packages. Are you sure you want to proceed? (y/N) " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Installation aborted by user."
        exit 0
    fi

    install_apt_packages "${!packages_to_install_map[@]}"
}

# Install games by category type (case-insensitive).
install_by_type() {
    local search_type="$1"
    if [[ -z "$search_type" ]]; then
        echo "Error: Please specify a category (e.g., Puzzle, Arcade, Roguelike, etc.)"
        usage
        exit 1
    fi

    # Normalize: lower-case and remove trailing " games" if present.
    search_type=$(echo "$search_type" | tr '[:upper:]' '[:lower:]')
    search_type=${search_type%" games"}

    local -A packages_to_install_map
    local installed_game_entries=() # To store "Name – Description" for feedback

    for entry in "${games[@]}"; do
        IFS='|' read -r name category description apt <<< "$entry"
        local norm_cat
        norm_cat=$(echo "$category" | tr '[:upper:]' '[:lower:]')
        if [[ "$norm_cat" == "$search_type" ]]; then
            if [[ -n "$apt" ]]; then # Ensure apt package is defined
                packages_to_install_map["$apt"]=1
                installed_game_entries+=("$name – $description (Package: $apt)")
            fi
        fi
    done

    if [[ ${#packages_to_install_map[@]} -eq 0 ]]; then
        echo "No installable games found for category: $search_type"
        echo "Available categories are:"
        declare -A unique_categories
        for game_entry in "${games[@]}"; do
            IFS='|' read -r _ cat _ _ <<< "$game_entry"
            unique_categories["$cat"]=1
        done
        for cat_name in $(printf "%s\n" "${!unique_categories[@]}" | sort); do
            echo "  - $cat_name"
        done
        exit 1
    fi

    echo "The following unique APT packages will be installed for '$search_type' games:"
    for pkg in "${!packages_to_install_map[@]}"; do
        echo "  - $pkg"
    done
    
    read -p "Do you want to proceed with the installation? (y/N) " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Installation aborted by user."
        exit 0
    fi

    install_apt_packages "${!packages_to_install_map[@]}"

    echo -e "\nThe following games from the '$search_type' category were targeted for installation:"
    for entry_desc in "${installed_game_entries[@]}"; do
        echo "  $entry_desc"
    done
    echo "Please check the installation output above for actual success of each package."
}

# Run a game by name.
run_game() {
    local game_to_run="$1"
    local executable_command="$game_to_run" # Default assumption: game name is the command
    local game_found_in_list=false
    local apt_package_for_game=""

    # Some games have a different executable name than their display name,
    # e.g. gnuchess (name) -> gnuchessc (command).
    # This could be handled by adding a 5th field to the games array: command_to_run
    # For now, we adjust specific known cases here or assume name is command.
    case "$game_to_run" in
        "gnuchess") executable_command="gnuchessc" ;;
        "cataclysm-dda-curses") executable_command="cataclysm" ;;
        "dwarffortress-legacy") executable_command="dwarffortress" ;;
        "gnubg") executable_command="gnubg -t" ;; # Add '-t' for terminal mode
        "redqueen") executable_command="redqueen -c" ;; # Add '-c' for console
        "gnugo") executable_command="gnugo -T" ;; # Add '-T' for terminal
        # Add other special cases if 'name' in array is not the direct command
    esac
    
    for entry in "${games[@]}"; do
        IFS='|' read -r name _ _ apt <<< "$entry"
        if [[ "$name" == "$game_to_run" ]]; then
            game_found_in_list=true
            apt_package_for_game="$apt"
            # If a 5th field for command existed, we'd use it here.
            # The case statement above handles current known exceptions.
            break
        fi
    done

    if ! $game_found_in_list; then
        echo "Warning: Game '$game_to_run' is not defined in our known games list."
        echo "Attempting to run it directly assuming it's in PATH..."
        # No exit here, try to run it anyway if user typed a direct command
    fi

    if command -v $(echo $executable_command | awk '{print $1}') &>/dev/null; then # Check only the command part, not args
        # Properly execute commands with arguments
        if [[ "$executable_command" == *" "* ]]; then
            eval "$executable_command" # Use eval if command string contains spaces/arguments
        else
            "$executable_command"
        fi
    else
        echo "Error: Game command '$executable_command' not found on your system."
        if $game_found_in_list && [[ -n "$apt_package_for_game" ]]; then
            echo "It's part of package '$apt_package_for_game'."
            echo "You might need to install it first using: $0 -i \"$game_to_run\""
        else
            echo "Ensure the game is installed and in your PATH."
        fi
        exit 1
    fi
}

# List games grouped by category
list_games() {
    declare -A grouped_games
    for entry in "${games[@]}"; do
        IFS='|' read -r name category description apt <<< "$entry"
        local game_info="$name – $description (APT package: $apt)"
        grouped_games["$category"]+="${game_info}\n"
    done

    echo "Available Classic Games:"
    for category in $(printf "%s\n" "${!grouped_games[@]}" | sort); do
        echo -e "\n${C_CATEGORY_TITLE}# ${category} games${C_RESET}"
        echo -e "${grouped_games[$category]}" | sed 's/\\n$//' # Remove trailing literal \n if any before printing
    done
}

# Main argument handling
if [[ $# -eq 0 ]]; then
    list_games
    echo # Adding an empty line for spacing before usage
    usage
    exit 0
fi

action_taken=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h)
            usage
            action_taken=true
            shift
            ;;
        -l)
            list_games
            action_taken=true
            shift
            ;;
        -i)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -i option requires a game name." >&2
                usage
                exit 1
            fi
            install_game_by_name "$2"
            action_taken=true
            shift 2
            ;;
        -iall)
            install_all_games
            action_taken=true
            shift
            ;;
        -itype)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -itype option requires a category name." >&2
                usage
                exit 1
            fi
            install_by_type "$2"
            action_taken=true
            shift 2
            ;;
        -r)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: -r option requires a game name." >&2
                usage
                exit 1
            fi
            run_game "$2"
            action_taken=true
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    # If an action was taken that should cause exit (like installs, run, help),
    # it should exit within its own block or the script ends after the loop.
done

# This part ensures that if options were processed but didn't explicitly exit,
# the script terminates cleanly.
if $action_taken; then
    exit 0
else
    # Should have been caught by unknown option or no-args case.
    # This is a fallback.
    usage
    exit 1
fi
