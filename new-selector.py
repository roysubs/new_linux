#!/usr/bin/env python3
import os
import curses
import subprocess
import time
from datetime import datetime

def list_scripts(folder, prefix="new"):
    """List all scripts in the folder starting with the specified prefix."""
    scripts = [
        f for f in os.listdir(folder)
        if f.startswith(prefix) and f.endswith(".sh") and os.path.isfile(os.path.join(folder, f))
    ]
    return sorted(scripts)

def display_menu(stdscr, options):
    """Display a list of options with checkboxes and additional commands."""
    curses.curs_set(0)  # Hide cursor
    current_row = 0
    checked = [False] * len(options)

    while True:
        stdscr.clear()

        # Display the menu
        for idx, option in enumerate(options):
            if idx == current_row:
                stdscr.attron(curses.color_pair(1))  # Highlight current selection
            checkbox = "[X]" if checked[idx] else "[ ]"
            stdscr.addstr(idx, 0, f"{checkbox} {option}")
            if idx == current_row:
                stdscr.attroff(curses.color_pair(1))

        # Display instructions below the options
        stdscr.addstr(len(options) + 1, 0, "Select scripts to be executed.")
        stdscr.addstr(len(options) + 2, 0, "Press 'x' to execute selected scripts.")
        stdscr.addstr(len(options) + 3, 0, "Press 'q' to quit without running any scripts.")
        stdscr.refresh()

        # Get user input
        key = stdscr.getch()

        # Handle user input
        if key == curses.KEY_UP and current_row > 0:
            current_row -= 1
        elif key == curses.KEY_DOWN and current_row < len(options) - 1:
            current_row += 1
        elif key == ord(" "):  # Toggle checkbox
            checked[current_row] = not checked[current_row]
        elif key == ord("x"):  # Execute selected scripts
            return [options[i] for i, is_checked in enumerate(checked) if is_checked]
        elif key == ord("q"):  # Quit without running scripts
            return None

def run_scripts(script_dir, selected_scripts):
    """Run the selected scripts in order with streaming output and timing."""
    script_start_times = {}
    overall_start_time = time.time()

    for script in selected_scripts:
        script_path = os.path.join(script_dir, script)
        start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        script_start_times[script] = start_time

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

    overall_end_time = time.time()

    # Summary and total runtime
    print("-" * 40)
    print("Execution Summary:")
    for script, start_time in script_start_times.items():
        print(f"{start_time} - {script}")
    final_end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{final_end_time} - Finished running scripts")
    total_runtime = overall_end_time - overall_start_time
    print(f"Total runtime: {total_runtime:.2f} seconds.")

def main():
    # Define the folder containing scripts
    script_dir = os.path.expanduser("~/new_linux")
    scripts = list_scripts(script_dir)

    if not scripts:
        print("No scripts found in the directory.")
        return

    # Run the curses UI
    selected_scripts = curses.wrapper(lambda stdscr: start_ui(stdscr, script_dir, scripts))

    if selected_scripts is None:
        print("No scripts were executed. Exiting.")
    elif selected_scripts:
        # Avoid printing multiple confirmations
        print("The following scripts will be executed in order:")
        for script in selected_scripts:
            print(f"- {script}")
        input("\nPress Enter to start execution...")  # Pause for user confirmation
        print("\nExecuting selected scripts...\n")
        run_scripts(script_dir, selected_scripts)
    else:
        print("No scripts were selected. Exiting.")

def start_ui(stdscr, script_dir, scripts):
    # Initialize curses colors
    curses.start_color()
    curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

    selected_scripts = display_menu(stdscr, scripts)
    return selected_scripts

if __name__ == "__main__":
    main()

