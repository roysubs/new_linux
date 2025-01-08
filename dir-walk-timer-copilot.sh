#!/bin/bash

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
    "Directory Method 5 (bash loop): count=0; sudo find '$dir' -type d | while IFS= read -r; do count=\$((count + 1)); done; echo \$count"
    "Directory Method 6 (perl): sudo /usr/bin/perl -MFile::Find -le 'find({wanted => sub {}, postprocess => sub { ++\$n }}, \"$dir\"); print \$n'"
    "Directory Method 7 (python): sudo /usr/bin/python3 -c 'import os; print(sum([len(dirs) for _, dirs, _ in os.walk(\"$dir\")]) + 1)'"
)

# Methods to count files
file_methods=(
    "File Method 1 (find): sudo find '$dir' -type f | wc -l"
    "File Method 2 (tree): sudo tree -a '$dir' | tail -n1 | awk '{print \$3}'"
    "File Method 4 (bash loop): count=0; sudo find '$dir' -type f | while IFS= read -r; do count=\$((count + 1)); done; echo \$count"
    "File Method 5 (perl): sudo /usr/bin/perl -MFile::Find -le 'find({wanted => sub { ++\$n },postprocess => sub {--\$n}}, \"$dir\"); print \$n'"
    "File Method 6 (python): sudo /usr/bin/python3 -c 'import os; print(sum([len(files) for _, _, files in os.walk(\"$dir\")]))'"
)

# Run and time each directory counting method
echo "Counting directories at $datetime..." | tee -a "$log_file"
echo | tee -a "$log_file"
for method in "${dir_methods[@]}"; do
    description="${method%%:*}"
    command="${method#*: }"
    if [[ "$description" == *"(du)"* ]]; then
        echo "$description" | tee -a "$log_file"
        echo "Running: $command" | tee -a "$log_file"
        eval "$command"
    else
        time_command "$description" "$command"
    fi
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

