#!/bin/bash

# Prevent Debian from entering emergency mode when there are errors in /etc/fstab.
# This is done by applying the nofail option for entries in fstab that we want
# the OS to be less strict about mounting at boot time.

# Bypassing fstab errors entirely during boot might lead to other issues, as some
# filesystems may be necessary for proper booting, but in a simple NAS setup,
# /dev/sdb, /dev/sdc and non-essential network mounts etc are not critical and so
# this will at least allow the system to continue booting with warnings rather
# than halting or entering emergency mode.

# Adding the nofail option to the relevant lines in /etc/fstab.

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then echo "Please run as root."; exit 1; fi


# Define the file location and backup before modifying
FSTAB="/etc/fstab"
cp "$FSTAB" "$FSTAB.$(date +'%Y-%m-%d_%H-%M-%S').bak"
GRUB_CONF="/etc/default/grub"
cp "$GRUB_CONF" "$GRUB_CONF.$(date +'%Y-%m-%d_%H-%M-%S').bak"

# Function to update /etc/fstab
update_fstab() {
  echo "Backing up fstab..."
  cp "$FSTAB" "$FSTAB.bak"
  
  echo "Adding 'nofail' option to non-root filesystems in fstab..."
  awk 'BEGIN {FS=" "; OFS=" ";} 
      {
          # Skip comments and blank lines
          if ($1 ~ /^#/ || NF == 0) {
              print $0;
              next;
          }
          
          # Add 'nofail' option to non-root filesystem entries
          if ($2 != "/" && $2 != "swap") {
              for (i = 4; i <= NF; i++) {
                  if ($i == "nofail") {
                      print $0; 
                      next;
                  }
              }
              $4 = $4 " nofail";  # Add nofail to the mount options
          }
          print $0;
      }' "$FSTAB" > "$FSTAB.tmp" && mv "$FSTAB.tmp" "$FSTAB"

  echo "Updated /etc/fstab with 'nofail' for non-root filesystems."
}

# Function to update GRUB
update_grub() {
  echo "Backing up GRUB configuration..."
  cp "$GRUB_CONF" "$GRUB_BACKUP"

  echo "Updating GRUB to include 'rootflags=nofail'..."
  sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ rootflags=nofail"/' "$GRUB_CONF"

  echo "Updating GRUB configuration..."
  update-grub
}

# Run both updates
update_fstab
update_grub

echo "All updates completed successfully!"
echo "A reboot is recommended to test the changes."