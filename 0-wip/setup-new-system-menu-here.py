#!/usr/bin/env python3
import os
import curses
import subprocess
import time
import signal
import sys
from datetime import datetime

LOG_FILE = "/tmp/new_selector_debug.log"

def log_message(message):
    """Log debug messages to a file."""
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{datetime.now()}: {message}\n")

def list_scripts(folder, prefix="new"):
    """List all scripts in the folder starting with the specified prefix."""
    scripts = [
        f for f in os.listdir(folder)
        if f.startswith(prefix) and f.endswith(".sh") and os.path.isfile(os.path.join(folder, f))
    ]
    log_message(f"Scripts found: {scripts}")
    return sorted(scripts)

def read_first_comment(file_path):
    """Read the first meaningful comment line of a script, excluding the shebang."""
    try:
        with open(file_path, "r") as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith("#") and not stripped.startswith("#!"):
                    return stripped[1:].strip()  # Strip '#' and leading spaces
        return "No description available."
    except Exception as e:
        log_message(f"Error reading comment from {file_path}: {e}")
        return "Error reading description."

def display_menu(stdscr, options, script_dir):
    """Display a list of options with checkboxes and show the first comment of selected script."""
    curses.curs_set(0)
    curses.start_color()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)  # Highlighted
    curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLACK)  # Normal

    current_row = 0
    checked = [False] * len(options)

    while True:
        try:
            stdscr.clear()
            height, width = stdscr.getmaxyx()

            # Minimum size check
            if height < 10 or width < 40:
                stdscr.addstr(0, 0, "Terminal size too small. Resize and try again.")
                stdscr.refresh()
                time.sleep(1)
                continue

            # Calculate columns and rows
            max_option_width = max(len(option) for option in options) + 4
            num_columns = max(1, width // max_option_width)
            num_rows = (len(options) + num_columns - 1) // num_columns

            # Display the menu in a grid layout
            for idx, option in enumerate(options):
                row = idx % num_rows
                col = idx // num_rows
                x = col * max_option_width
                y = row

                if y < height - 5:  # Ensure within bounds
                    checkbox = "[X]" if checked[idx] else "[ ]"
                    if idx == current_row:
                        stdscr.attron(curses.color_pair(1))
                        stdscr.addstr(y, x, f"{checkbox} {option[:max_option_width-4]}")
                        stdscr.attroff(curses.color_pair(1))
                    else:
                        stdscr.attron(curses.color_pair(2))
                        stdscr.addstr(y, x, f"{checkbox} {option[:max_option_width-4]}")
                        stdscr.attroff(curses.color_pair(2))

            # Display footer and comments
            footer_row = min(height - 3, num_rows + 1)
            stdscr.addstr(footer_row, 0, "Press 'x' to execute, 'q' to quit.", curses.A_BOLD)

            # Display the first comment of the highlighted script
            comment_row = footer_row + 1
            if 0 <= current_row < len(options):
                script_path = os.path.join(script_dir, options[current_row])
                comment = read_first_comment(script_path)
                stdscr.addstr(comment_row, 0, f"Description: {comment[:width-1]}")

            stdscr.refresh()

            # Handle user input
            key = stdscr.getch()
            if key == curses.KEY_UP:
                current_row = (current_row - 1) % len(options)
            elif key == curses.KEY_DOWN:
                current_row = (current_row + 1) % len(options)
            elif key == ord(" "):  # Toggle checkbox
                checked[current_row] = not checked[current_row]
            elif key == ord("x"):  # Execute selected scripts
                return [options[i] for i, is_checked in enumerate(checked) if is_checked]
            elif key == ord("q"):  # Quit without running scripts
                return None

        except curses.error as e:
            log_message(f"Curses error: {e}")
            pass  # Ignore curses errors caused by resizing

def main():
    def signal_handler(sig, frame):
        print("\nProgram terminated by user.")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    script_dir = os.path.expanduser("~/new_linux")
    scripts = list_scripts(script_dir)

    if not scripts:
        print("No scripts found in the directory.")
        return

    try:
        selected_scripts = curses.wrapper(lambda stdscr: display_menu(stdscr, scripts, script_dir))
        if selected_scripts is None:
            print("No scripts were selected.")
        else:
            print(f"Selected scripts: {', '.join(selected_scripts)}")
    except Exception as e:
        log_message(f"Unhandled exception: {e}")
        print("An error occurred. Check the log file for details.")

if __name__ == "__main__":
    log_message("Starting new-selector script.")
    main()
    log_message("Script finished.")

