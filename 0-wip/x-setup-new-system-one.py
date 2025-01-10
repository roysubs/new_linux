#!/usr/bin/env python3
import os
import curses
import subprocess
import time
from datetime import datetime
import signal
import sys

def list_scripts(folder, prefix="new"):
    """List all scripts in the folder starting with the specified prefix."""
    scripts = [
        f for f in os.listdir(folder)
        if f.startswith(prefix) and f.endswith(".sh") and os.path.isfile(os.path.join(folder, f))
    ]
    return sorted(scripts)

def display_list(stdscr, options):
    """Display a list of options and allow selection with ENTER."""
    curses.curs_set(0)  # Hide cursor
    current_row = 0

    while True:
        stdscr.clear()

        # Display the menu
        for idx, option in enumerate(options):
            if idx == current_row:
                stdscr.attron(curses.color_pair(1))  # Highlight current selection
                stdscr.addstr(idx, 0, f"> {option}")
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(idx, 0, f"  {option}")

        # Display instructions below the options
        stdscr.addstr(len(options) + 1, 0, "Use UP/DOWN arrows to navigate.")
        stdscr.addstr(len(options) + 2, 0, "Press ENTER to execute the selected script.")
        stdscr.addstr(len(options) + 3, 0, "Press 'q' or ESC to quit.")
        stdscr.refresh()

        # Get user input
        key = stdscr.getch()

        # Handle user input
        if key == curses.KEY_UP:
            current_row = (current_row - 1) % len(options)  # Wrap around to the bottom
        elif key == curses.KEY_DOWN:
            current_row = (current_row + 1) % len(options)  # Wrap around to the top
        elif key == ord("\n"):  # ENTER key to select
            return options[current_row]
        elif key == ord("q") or key == 27:  # 'q' or ESC to quit
            return None

def run_script(script_dir, script):
    """Run the selected script with streaming output and timing."""
    script_path = os.path.join(script_dir, script)
    start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print("-" * 40)
    print(f"Starting: {start_time} - {script}")
    print("-" * 40)

    try:
        # Stream output line by line
        process = subprocess.Popen(
            [script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        for line in process.stdout:
            print(line, end="")

        process.stdout.close()
        return_code = process.wait()

        if return_code != 0:
            error_output = process.stderr.read()
            print(f"\nError running {script}:\n{error_output}")
            process.stderr.close()
    except FileNotFoundError:
        print(f"Error: Script not found: {script_path}")
    except PermissionError:
        print(f"Error: Script not executable: {script_path}")
    except OSError as e:
        print(f"OS Error: {e}\nCheck if {script_path} has a valid shebang and is executable.")

    end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("-" * 40)
    print(f"Finished: {end_time}")
    print("-" * 40)

def main():
    # Handle Ctrl+C without generating Python errors
    def signal_handler(sig, frame):
        print("\nCtrl+C pressed, exiting.")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    # Define the folder containing scripts
    script_dir = os.path.expanduser("~/new_linux")
    scripts = list_scripts(script_dir)

    if not scripts:
        print("No scripts found in the directory.")
        return

    try:
        # Run the curses UI
        selected_script = curses.wrapper(lambda stdscr: start_ui(stdscr, script_dir, scripts))
    except KeyboardInterrupt:
        print("\nExiting gracefully. Goodbye!")
        sys.exit(0)

    if selected_script is None:
        print("No script was executed. Exiting.")
    else:
        print(f"The selected script is '{selected_script}'")
        input("Press any key to run the script.")  # Pause for user confirmation
        print("\nExecuting the selected script...\n")
        run_script(script_dir, selected_script)

def start_ui(stdscr, script_dir, scripts):
    # Initialize curses colors
    curses.start_color()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

    return display_list(stdscr, scripts)

if __name__ == "__main__":
    main()

