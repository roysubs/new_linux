#!/bin/bash

# Only run 'apt update' if last update was 2 days or more
if [ $(find /var/cache/apt/pkgcache.bin -mtime +2 -print) ]; then sudo apt update; fi
HOME_DIR="$HOME"

# Install tools if not already installed
PACKAGES=("lynx" "pv")
install-if-missing() { if ! dpkg-query -W "$1" > /dev/null 2>&1; then sudo apt install -y $1; fi; }
for package in "${PACKAGES[@]}"; do install-if-missing $package; done

# URL to visit
URL="https://genius.com/Monty-python-the-knights-who-say-ni-annotated"
OUTPUT_FILE="/tmp/ni.txt"
LYNX_CFG="/etc/lynx/lynx.cfg"

# Backup current settings
COOKIE_SETTINGS_BACKUP="$(mktemp).lynx.cfg"
cp "$LYNX_CFG" "$COOKIE_SETTINGS_BACKUP"
# grep extract of each setting is not required if we backup the whole file and then put it back immediately after use
# grep -E "^#?SET_COOKIES|^#?ACCEPT_ALL_COOKIES|^#?COOKIE_FILE|^#?COOKIE_SAVE_FILE" $LYNX_CFG > "$COOKIE_SETTINGS_BACKUP"

# Update or add the necessary settings
sudo sed -i 's/^#?SET_COOKIES:.*/SET_COOKIES:TRUE/' "$LYNX_CFG"
sudo sed -i 's/^#?ACCEPT_ALL_COOKIES:.*/ACCEPT_ALL_COOKIES:TRUE/' "$LYNX_CFG"
sudo sed -i 's|^#?COOKIE_FILE:.*|COOKIE_FILE:~/.lynx_cookies|' "$LYNX_CFG"
sudo sed -i 's|^#?COOKIE_SAVE_FILE:.*|COOKIE_SAVE_FILE:~/.lynx_cookies|' "$LYNX_CFG"

# Add settings if they don't exist
grep -q "^SET_COOKIES" "$LYNX_CFG" || echo "SET_COOKIES:TRUE" | sudo tee -a "$LYNX_CFG"
grep -q "^ACCEPT_ALL_COOKIES" "$LYNX_CFG" || echo "ACCEPT_ALL_COOKIES:TRUE" | sudo tee -a "$LYNX_CFG"
grep -q "^COOKIE_FILE" "$LYNX_CFG" || echo "COOKIE_FILE:~/.lynx_cookies" | sudo tee -a "$LYNX_CFG"
grep -q "^COOKIE_SAVE_FILE" "$LYNX_CFG" || echo "COOKIE_SAVE_FILE:~/.lynx_cookies" | sudo tee -a "$LYNX_CFG"

# Ensure the cookie file exists
touch ~/.lynx_cookies

# Dump the text content to a file
lynx --dump "$URL" > "$OUTPUT_FILE"

# Extract lines between start and end markers
awk '
/HEAD KNIGHT: Ni!/ { start = NR }         # Find the start marker
/KNIGHTS: Aaaaugh!/ { end = NR }          # Find the last occurrence of the end marker
{ lines[NR] = $0 }                        # Save all lines in an array
END {
    if (start && end && start <= end) {   # Check if valid markers exist
        for (i = start; i <= end; i++) {  # Print the lines from start to end
            print lines[i]
        }
    } else {
        print "Error: Start or end markers not found or invalid." > "/dev/stderr"
        exit 1
    }
}
' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp"

# Replace the original file with the extracted content
mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

# Revert lynx settings
while IFS= read -r line; do
    setting=$(echo "$line" | cut -d':' -f1)
    value=$(echo "$line" | cut -d':' -f2-)
    sudo sed -i "s|^$setting:.*|$setting:$value|" "$LYNX_CFG"
done < "$COOKIE_SETTINGS_BACKUP"

# Clean up
rm "$COOKIE_SETTINGS_BACKUP"

# Display with pv
cat $OUTPUT_FILE | pv -qL 50;

