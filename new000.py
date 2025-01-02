#!/usr/bin/env python3
import os
import curses
import subprocess
import time
from datetime import datetime

def list_scripts(folder, prefix="new"):
    """List all scripts in the folder starting with the specified prefix and extract their descriptions."""
    scripts = []
    for filename in os.listdir(folder):
        if filename.startswith(prefix) and filename.endswith(".sh") and os.path.isfile(os.path.join(folder, filename)):
            path = os.path.join(folder, filename)
            description = parse_first_comment(path)
            scripts.append((filename, description))
    return sorted(scripts, key=lambda x: x[0])

def parse_first_comment(filepath):
    """Extract the first comment line from the script, ignoring the shebang."""
    try:
        with open(filepath, "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith("#") and not line.startswith("#!"):
                    return line.lstrip("#").strip()
    except Exception as e:
        return f"Error reading file: {e}"
    return "No description available."

def display_menu(stdscr, options):
    """Display a list of options with checkboxes and descriptions in a dynamic multi-column layout."""
    curses.curs_set(0)  # Hide cursor
    current_row = 0
    checked = [False] * len(options)

    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()

        # Calculate columns and rows
        max_option_width = max(len(option[0]) for option in options) + 4  # [X] + space + option
        num_columns = max(1, width // max_option_width)
        num_rows = (len(options) + num_columns - 1) // num_columns  # Ceiling division

        # Display the menu in a grid layout
        for idx, (option, _) in enumerate(options):
            row = idx % num_rows
            col = idx // num_rows
            x = col * max_option_width
            y = row

            checkbox = "[X]" if checked[idx] else "[ ]"
            if idx == current_row:
                stdscr.attron(curses.color_pair(1))  # Highlight current selection
                stdscr.addstr(y, x, f"{checkbox} {option}")
                stdscr.attroff(curses.color_pair(1))
            else:
                stdscr.addstr(y, x, f"{checkbox} {option}")

        # Display the description of the currently highlighted option
        footer_row = num_rows + 2
        stdscr.addstr(footer_row, 0, "Description:")
        description = options[current_row][1]
        stdscr.addstr(footer_row + 1, 0, description[:width])  # Truncate if too long
        stdscr.addstr(footer_row + 3, 0, "Select scripts to be executed.")
        stdscr.addstr(footer_row + 4, 0, "Press 'x' to execute selected scripts.")
        stdscr.addstr(footer_row + 5, 0, "Press 'q' to quit without running any scripts.")
        stdscr.refresh()

        # Get user input
        key = stdscr.getch()

        # Handle user input
        if key == curses.KEY_UP:
            current_row = (current_row - 1) % len(options)
        elif key == curses.KEY_DOWN:
            current_row = (current_row + 1) % len(options)
        elif key == curses.KEY_LEFT:
            current_row = (current_row - num_rows) % len(options)
        elif key == curses.KEY_RIGHT:
            current_row = (current_row + num_rows) % len(options)
        elif key == ord(" "):  # Toggle checkbox
            checked[current_row] = not checked[current_row]
        elif key == ord("x"):  # Execute selected scripts
            return [options[i][0] for i, is_checked in enumerate(checked) if is_checked]
        elif key == ord("q"):  # Quit without running scripts
            return None

def run_scripts(script_dir, selected_scripts):
    """Run the selected scripts interactively in order with streaming output and timing."""
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
            # Run the script interactively
            subprocess.run(
                [script_path],
                check=True,
            )
        except subprocess.CalledProcessError as e:
            print(f"Script {script} failed with error code {e.returncode}")
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

