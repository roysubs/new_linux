#!/bin/bash

# Time various methods of recursively counting files and then directories
# under a given start directory.
# Usage:  dir-walk.sh dir-to-check
# Check if device argument is provided
if [ -z "$1" ]; then
    echo
    echo -e "Usage:  $(basename "$0") directory-path"
    echo "The directory path could be '~' or a relative path ./my_path etc"
    echo
    exit 1
fi

# Default to home directory if no argument is provided
dir="${1:-$HOME}"
datetime=$(date +"%Y-%m-%d_%H-%M-%S")

script_name=$(basename "$0")
log_file="${script_name%.*}.log"

echo "Analyzing directories and files in: $dir" | tee "$log_file"

# Function to time and run a command, and print the count
time_command() {
    local description="$1"
    local command="$2"
    echo "$description" | tee -a "$log_file"
    echo "Running: $command" | tee -a "$log_file"
    start_time=$(date +%s.%N)
    result=$(eval "$command")
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    echo "Count: $result" | tee -a "$log_file"
    echo "Time: $duration seconds" | tee -a "$log_file"
}

# Methods to count directories
dir_methods=(
    "Directory Method 1 (find): sudo find '$dir' -type d | wc -l"
    "Directory Method 2 (tree): sudo tree -afi '$dir' | tail -n 1 | awk '{print \$1}'"
    "Directory Method 5 (bash loop): count=0; while IFS= read -r line; do count=\$((count + 1)); done < <(sudo find '$dir' -type d); echo \$count"
    "Directory Method 6 (perl): sudo /usr/bin/perl -MFile::Find -le 'find({wanted => sub {}, postprocess => sub { ++\$n }}, \"$dir\"); print \$n'"
    # "Directory Method 7 (python): sudo /usr/bin/python3 -c 'import os; print(sum([len(dirs) for _, dirs, _ in os.walk(\"$dir\")]) + 1)'"
    "Directory Method 7 (python): sudo /usr/bin/python3 -c '
import os
count = 0
for root, dirs, _ in os.walk(\"$dir\", followlinks=False):
    count += len(dirs)
print(count)'
"
    "Directory Method 8 (powershell): sudo /usr/bin/pwsh -Command \"Get-ChildItem -Recurse -Force -Attributes Directory -Path \\\"$dir\\\" | Measure-Object | Select-Object -ExpandProperty Count\""
)

# Methods to count files
file_methods=(
    "File Method 1 (find): sudo find '$dir' -type f | wc -l"
    "File Method 2 (tree): sudo tree -a '$dir' | tail -n1 | awk '{print \$3}'"
    "File Method 4 (bash loop): count=0; while IFS= read -r line; do count=\$((count + 1)); done < <(sudo find '$dir' -type f); echo \$count"
    "File Method 5 (perl): sudo /usr/bin/perl -MFile::Find -le 'find({wanted => sub { ++\$n },postprocess => sub {--\$n}}, \"$dir\"); print \$n'"
    "File Method 6 (python): sudo /usr/bin/python3 -c 'import os; print(sum([len(files) for _, _, files in os.walk(\"$dir\")]))'"
    "File Method 7 (powershell): sudo /usr/bin/pwsh -Command \"Get-ChildItem -Recurse -Force -File -Path \\\"$dir\\\" | Measure-Object | Select-Object -ExpandProperty Count\""
)

echo | tee -a "$log_file"
echo | tee -a "$log_file"
echo | tee -a "$log_file"

# Run and time each directory counting method
echo "Counting directories at $datetime..." | tee -a "$log_file"
echo | tee -a "$log_file"
for method in "${dir_methods[@]}"; do
    description="${method%%:*}"
    command="${method#*: }"
    time_command "$description" "$command"
    echo | tee -a "$log_file"
done

# Run and time each file counting method
echo "Counting files at $datetime..." | tee -a "$log_file"
echo | tee -a "$log_file"
for method in "${file_methods[@]}"; do
    description="${method%%:*}"
    command="${method#*: }"
    time_command "$description" "$command"
    echo | tee -a "$log_file"
done

