#!/bin/bash

# phone_convert.sh
# Usage: ./phone_convert.sh "Your Movie.mkv" or ./phone_convert.sh /path/to/folder

input="$1"

if [ -d "$input" ]; then
  # If input is a directory, loop through all files in the directory
  for file in "$input"/*; do
    if [ -f "$file" ]; then
      ./phone_convert.sh "$file"
    fi
  done
  exit 0
fi

if [ ! -f "$input" ]; then
  echo "File not found: $input"
  echo "Usage:"
  echo "$(basename $0) 'Your Movie.mkv'"
  echo "or"
  echo "$(basename $0) /path/to/folder   # process every file in folder"
  exit 1
fi

# Strip extension and append (phone)
filename="${input%.*}"
extension="${input##*.}"
output="${filename} (phone).mp4"

echo "Converting: $input"
echo "Output: $output"

# Run ffmpeg conversion
ffmpeg -i "$input" \
  -c:v libx264 -preset medium -crf 24 \
  -c:a aac -b:a 128k \
  -movflags +faststart \
  -vf "scale='min(960,iw)':-2" \
  "$output"

echo "Done."

