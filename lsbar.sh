#!/bin/bash

# Check if robobunny bargraph is installed (check URL or local path to the tool)
BARGRAPH_URL="https://robobunny.com/projects/bargraph/html/"

# Directory to list files (default: current directory)
DIRECTORY="${1:-.}"

# Get the file sizes
file_sizes=$(find "$DIRECTORY" -maxdepth 1 -type f -exec stat --format="%s %n" {} \;)

# Get the maximum file size for scaling the bars
max_size=$(echo "$file_sizes" | awk '{print $1}' | sort -n | tail -n 1)

# Display the bar graph for each file
echo "<html>"
echo "<head><title>File Size Bar Graph</title></head>"
echo "<body>"
echo "<h1>File Size Bar Graph</h1>"

# Loop through each file and create a bar graph
while read -r line; do
    # Split the size and filename
    size=$(echo "$line" | awk '{print $1}')
    filename=$(echo "$line" | awk '{$1=""; print substr($0,2)}')

    # Calculate the bar length relative to the maximum size
    bar_length=$(( (size * 50) / max_size ))  # Scale to a max length of 50

    # Generate the bar graph using robobunny HTML format
    echo "<div style='font-family: monospace;'>"
    echo "<b>$filename</b>"
    echo "<div style='width: $bar_length%; background-color: green; height: 20px;'></div>"
    echo "</div>"
done <<< "$file_sizes"

echo "</body>"
echo "</html>"

