Fix line-ending problems in scripts:

dos2unix ~/new_linux/0-scripts/shares-smb.sh

Method 2: Using sed

If you prefer not to install dos2unix:
sed -i 's/\r$//' ~/new_linux/0-scripts/shares-smb.sh
