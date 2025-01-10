#!/bin/bash

# Function to summarize Samba shares
check_samba_shares() {
    if ! command -v smbd &>/dev/null; then
        echo "Samba is not installed. Skipping Samba check."
        return
    fi

    SAMBA_CONFIG="/etc/samba/smb.conf"
    if [[ ! -f $SAMBA_CONFIG ]]; then
        echo "Samba configuration file not found at $SAMBA_CONFIG. Skipping Samba check."
        return
    fi

    echo "--- Samba Shares ---"
    awk -v RS="\[" 'NR > 1 {
        gsub(/\n[[:space:]]*/, " ");
        gsub(/\s*\n/, " ");
        gsub(/\s{2,}/, " ");
        split($0, lines, "\n");
        share_name = lines[1];
        details = ""
        for (i = 2; i <= length(lines); i++) {
            details = details lines[i] "; ";
        }
        print "Share: " share_name ", " details;
    }' $SAMBA_CONFIG
}

# Function to summarize NFS shares
check_nfs_shares() {
    if ! command -v exportfs &>/dev/null; then
        echo "NFS is not installed. Skipping NFS check."
        return
    fi

    NFS_CONFIG="/etc/exports"
    if [[ ! -f $NFS_CONFIG ]]; then
        echo "NFS configuration file not found at $NFS_CONFIG. Skipping NFS check."
        return
    fi

    echo "--- NFS Shares ---"
    while IFS= read -r line; do
        # Ignore comments and empty lines
        [[ $line =~ ^# ]] && continue
        [[ -z $line ]] && continue

        # Parse the line
        share=$(echo "$line" | awk '{print $1}')
        options=$(echo "$line" | awk '{$1=""; print $0}')

        echo "Share: $share, Options: $options"
    done < "$NFS_CONFIG"
}

# Main script execution
echo "Analyzing system shares..."
check_samba_shares
check_nfs_shares

