#!/bin/bash

# Function to print a command in green and execute it
run_command() {
    local full_cmd_string="$1"
    echo -e "# ${GREEN}${full_cmd_string}${NC}"
    # Execute the command string. Using bash -c is generally safe for constructed strings.
    bash -c "$full_cmd_string"
    return $? # Return the exit status of the executed command
}

echo "Show the space used by this project."
echo
echo "1. By Apparent Size (Sum of individual file sizes)"
echo "   Not the used space on disk but counting each file by it's byte size."

run_command "find . -type d -name \".git\" -prune -o -type f -print0 | xargs -0 du -bc | awk 'END{print $1}'"

# Explanation:
# find .: Starts the search in the current directory (.).
# -type d -name ".git" -prune: This is the key part for exclusion.
# -type d -name ".git": Finds directories named ".git".
# -prune: If a directory named ".git" is found, find will not descend into it.
# -o: This is an OR operator.
# -type f -print0: If the entry is not a pruned ".git" directory, and it's a regular file (-type f), its name is printed.
#    This is followed by a null character (-print0). Using null characters is safer for filenames containing spaces or special characters.
# | xargs -0 du -bc:
# xargs -0: Reads the null-terminated file names.
# du -bc: For each file, du (disk usage) is called.
# -b: Shows apparent size in bytes.
# -c: Produces a grand total.
# | awk 'END{print $1}': This processes the output of du -bc.
# END{print $1}: After processing all lines, awk prints the first field of the last line, which is the grand total in bytes from du -c.

echo "2. By Space Used on Disk (Actual disk allocation)"
echo "   The actual disk space occupied by the files, which can be larger than the apparent size due to block allocation."

run_command "find . -type d -name \".git\" -prune -o -print0 | xargs -0 du -scb | awk 'END{print $1}'"

echo
echo "Or, for a more human-readable total at the end (e.g., KB, MB, GB):"

run_command "find . -type d -name \".git\" -prune -o -print0 | xargs -0 du -sch | tail -n1 | awk '{print $1}'"

# Explanation:
# find . -type d -name ".git" -prune -o -print0: This part is similar to the apparent size command, but instead of just printing files (-type f), it prints all non-.git items (-print0). This is because du works on directories as well to calculate disk usage.
# | xargs -0 du -scb:
# xargs -0: Reads the null-terminated names.
# du -scb:
# -s: Display only a total for each argument (effectively, for all found items when piped together).
# -c: Produce a grand total.
# -b: Report size in bytes (for consistency, though du defaults to blocks usually). If you want human-readable like KB, MB, use -h instead of -b in the du -sch version.
# | awk 'END{print $1}': Prints the grand total figure from the du -scb output.
# For the human-readable version:
# du -sch: -h provides human-readable sizes.
# | tail -n1: Gets the last line, which is the total.
# | awk '{print $1}': Prints just the size value from that total line (e.g., "1.2G").
# Choose the command that best suits the information you need!
