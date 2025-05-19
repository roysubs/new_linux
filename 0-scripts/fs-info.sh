#!/bin/bash

# fs-info.sh
# Displays a compact overview of filesystem, mount, and share information.
# Designed to be run as a regular user, but some commands (lsblk, df)
# may show more complete information if run with sudo.

# --- Color Definitions ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Function to display lsblk information (cleaned up) ---
display_lsblk_info() {
    echo -e "${CYAN}${BOLD}--- Block Device Information (lsblk) ---${NC}"
    echo -e "${YELLOW}Excluding loop devices. Run with sudo for potentially more details.${NC}"
    if command -v lsblk >/dev/null; then
        lsblk -e 7 -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL,UUID,MODEL
    else
        echo -e "${RED}lsblk command not found. Please install util-linux.${NC}"
    fi
    echo ""
}

# --- Function to display df information (cleaned up) ---
display_df_info() {
    echo -e "${CYAN}${BOLD}--- Filesystem Disk Space Usage (df) ---${NC}"
    echo -e "${YELLOW}Excluding tmpfs, devtmpfs, squashfs, overlay, fuse.lxcfs. Run with sudo for potentially more details.${NC}"
    if command -v df >/dev/null; then
        df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x fuse.lxcfs
    else
        echo -e "${RED}df command not found. Please install coreutils.${NC}"
    fi
    echo ""
}

# --- Function to display fstab information (Corrected AWK with Tab Delimiter) ---
display_fstab_info() {
    local FSTAB_FILE="/etc/fstab"

    echo -e "${CYAN}${BOLD}--- /etc/fstab Content and Field Explanation ---${NC}"
    if [ ! -f "$FSTAB_FILE" ]; then
        echo -e "${RED}$FSTAB_FILE not found.${NC}"
        echo ""
        return
    fi

    echo -e "${GREEN}fstab Fields Explanation:${NC}"
    echo -e "  ${BOLD}1. Filesystem:${NC} Device, UUID, LABEL, or remote filesystem (e.g., UUID=..., /dev/sda1, //server/share)."
    echo -e "  ${BOLD}2. Mount Point:${NC} Directory where the filesystem is attached (e.g., /, /home, /mnt/data)."
    echo -e "  ${BOLD}3. Type:${NC} Filesystem type (e.g., ext4, xfs, ntfs, cifs, nfs, swap)."
    echo -e "  ${BOLD}4. Options:${NC} Comma-separated mount options (e.g., defaults, nofail, ro, rw, user)."
    echo -e "  ${BOLD}5. Dump:${NC} Used by 'dump' utility (0 = no dump, usually 0)."
    echo -e "  ${BOLD}6. Pass:${NC} Used by 'fsck' for boot-time check order (0 = no check, 1 = root, 2 = other)."
    echo ""

    echo -e "${YELLOW}--- $FSTAB_FILE Entries ---${NC}"
    {
        # Header with tab delimiters
        echo -e "Filesystem\tMount_Point\tType\tOptions\tDump\tPass"
        echo -e "----------\t-----------\t----\t-------\t----\t----"
        grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$FSTAB_FILE" | \
        awk '
        NF >= 3 { # Process lines with at least filesystem, mountpoint, and type
            filesystem = $1;
            mount_point = $2;
            type = $3;
            
            options_str = "defaults"; 
            dump_str = "0";      
            pass_str = "0";      

            if (NF >= 6) {
                # Last field is pass, second to last is dump
                # Validate if they are numeric, otherwise they are part of options (and dump/pass get defaults)
                if ($NF ~ /^[0-9]+$/) {
                    pass_str = $NF;
                    if ($(NF-1) ~ /^[0-9]+$/) {
                        dump_str = $(NF-1);
                        options_field_count = NF - 2 - 3; # Number of fields making up options (Total - fs - mp - type - dump - pass)
                    } else { # $(NF-1) is not numeric, so it is part of options, dump is default 0
                        dump_str = "0";
                        options_field_count = NF - 1 - 3; 
                    }
                } else { # $NF is not numeric, so it is part of options, dump & pass are default 0
                    dump_str = "0";
                    pass_str = "0";
                    options_field_count = NF - 0 - 3;
                }
                
                current_options_temp = "";
                if (options_field_count > 0) {
                    for (i = 4; i <= (3 + options_field_count); i++) {
                        current_options_temp = current_options_temp (current_options_temp == "" ? "" : " ") $i;
                    }
                }
                if (current_options_temp != "") {
                    options_str = current_options_temp;
                } # else options_str remains "defaults" if options_field_count was 0 or less

            } else if (NF == 5) { 
                # fs mp type opts dump (pass defaults to 0)
                # OR fs mp type opt_part1 opt_part2 (dump=0, pass=0)
                options_str = $4; # initial assumption
                if ($5 ~ /^[0-9]+$/) { # If $5 is numeric, it IS dump
                    dump_str = $5;
                } else { # $5 is not numeric, so it must be part of options
                    options_str = $4 " " $5; 
                    dump_str = "0"; 
                }
                pass_str = "0"; 
            } else if (NF == 4) { 
                # fs mp type opts (dump=0, pass=0)
                options_str = $4;
            } # else NF == 3 (fs mp type), options/dump/pass remain defaults.
            
            # Final validation that parsed dump and pass are numeric
            if (!(dump_str ~ /^[0-9]+$/)) dump_str="0";
            if (!(pass_str ~ /^[0-9]+$/)) pass_str="0";

            # Print with tab delimiters
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", filesystem, mount_point, type, options_str, dump_str, pass_str;
        }'
    } | column -t -s $'\t' # Use tab as separator for column, -n for no multiple adjacent delimiters

    echo ""
    echo -e "${YELLOW}Remember: Errors in ${FSTAB_FILE} can prevent system boot. Backup before editing:${NC} ${GREEN}sudo cp ${FSTAB_FILE} ${FSTAB_FILE}.$(date +%Y%m%d).bak${NC}"
    echo ""
}


# --- Function to display Samba shares (User Provided AWK script - with minor robustness tweaks) ---
display_samba_shares() {
    echo -e "${CYAN}${BOLD}--- Samba Share Configuration (from testparm) ---${NC}"
    if ! command -v testparm >/dev/null; then
        echo -e "${RED}testparm command not found. Please install Samba (e.g., samba-common-bin or samba package).${NC}"
        echo ""
        return
    fi

    # User's awk script to parse testparm output (header order changed to match user's table example)
    testparm -s 2>&1 | awk '
    BEGIN {
        current_share = ""
        share_count = 0
        # Headers matching user example order
        headers[0] = "Name"
        headers[1] = "Path"
        headers[2] = "Read-Only"
        headers[3] = "ValidUsers"
        headers[4] = "CreateMask" # Swapped order from user AWK
        headers[5] = "DirMask"   # Swapped order from user AWK
        headers[6] = "Comment"


        for (i = 0; i <= 6; i++) {
            max_widths[i] = length(headers[i])
        }
    }

    { # Main processing block for every line
        if ($0 ~ /^\[.*\]$/) {
            if (current_share != "" && current_share != "global" && current_share != "printers") {
                share_order[share_count++] = current_share
            }
            first_bracket = index($0, "[")
            last_bracket = index($0, "]")
            current_share = substr($0, first_bracket + 1, last_bracket - first_bracket - 1)

            if (current_share != "" && current_share != "global" && current_share != "printers") {
                shares[current_share]["path"] = "n/a"
                shares[current_share]["readonly"] = "n/a"
                shares[current_share]["validusers"] = "n/a"
                shares[current_share]["createmask"] = "n/a"
                shares[current_share]["dirmask"] = "n/a"
                shares[current_share]["comment"] = "n/a"
            }

        } else if (current_share != "" && current_share != "global" && current_share != "printers") {
            line = $0
            gsub(/^[ \t]+|[ \t]+$/, "", line) 

            if (match(line, /^path[ \t]*=[ \t]*(.*)/, arr)) {
                shares[current_share]["path"] = arr[1]
            } else if (match(line, /^read only[ \t]*=[ \t]*(Yes|No)/, arr)) {
                shares[current_share]["readonly"] = arr[1]
            } else if (match(line, /^valid users[ \t]*=[ \t]*(.*)/, arr)) {
                shares[current_share]["validusers"] = arr[1]
            } else if (match(line, /^create mask[ \t]*=[ \t]*(.*)/, arr)) {
                shares[current_share]["createmask"] = arr[1]
            } else if (match(line, /^directory mask[ \t]*=[ \t]*(.*)/, arr)) {
                shares[current_share]["dirmask"] = arr[1]
            } else if (match(line, /^comment[ \t]*=[ \t]*(.*)/, arr)) {
                shares[current_share]["comment"] = arr[1]
            }
        }
    }

    END {
        if (current_share != "" && current_share != "global" && current_share != "printers") {
            share_order[share_count++] = current_share
        }

        if (share_count == 0) {
            print "No user-defined Samba shares found (excluding [global] and [printers] sections)."
            exit
        }
        
        for (idx = 0; idx < share_count; idx++) {
            share_name = share_order[idx]
            if (length(share_name) > max_widths[0]) max_widths[0] = length(share_name)
            if (length(shares[share_name]["path"]) > max_widths[1]) max_widths[1] = length(shares[share_name]["path"])
            if (length(shares[share_name]["readonly"]) > max_widths[2]) max_widths[2] = length(shares[share_name]["readonly"])
            if (length(shares[share_name]["validusers"]) > max_widths[3]) max_widths[3] = length(shares[share_name]["validusers"])
            if (length(shares[share_name]["createmask"]) > max_widths[4]) max_widths[4] = length(shares[share_name]["createmask"])
            if (length(shares[share_name]["dirmask"]) > max_widths[5]) max_widths[5] = length(shares[share_name]["dirmask"])
            if (length(shares[share_name]["comment"]) > max_widths[6]) max_widths[6] = length(shares[share_name]["comment"])
        }

        fmt_str = ""
        separator_str = ""
        # Using tab as a delimiter for printf to column -t
        for (col = 0; col <= 6; col++) {
            fmt_str = fmt_str "%-" max_widths[col] "s" (col < 6 ? "\t" : "\n")
            for (j = 0; j < max_widths[col]; j++) separator_str = separator_str "="
            if (col < 6) separator_str = separator_str "\t" # Tab for separator line too
        }
        
        printf fmt_str, headers[0], headers[1], headers[2], headers[3], headers[4], headers[5], headers[6]
        print separator_str

        for (idx = 0; idx < share_count; idx++) {
            share_name = share_order[idx]
            printf fmt_str, share_name, shares[share_name]["path"], shares[share_name]["readonly"], \
                   shares[share_name]["validusers"], shares[share_name]["createmask"], \
                   shares[share_name]["dirmask"], shares[share_name]["comment"]
        }
    }
    ' | column -t -s $'\t' -n # Tell column to use tab as separator
    echo ""
}


# --- Function to display NFS exports ---
display_nfs_exports() {
    local EXPORTS_FILE="/etc/exports"
    echo -e "${CYAN}${BOLD}--- NFS Export Configuration ($EXPORTS_FILE) ---${NC}"

    if [ ! -f "$EXPORTS_FILE" ]; then
        echo -e "${YELLOW}$EXPORTS_FILE not found. NFS server may not be configured.${NC}"
        echo ""
        return
    fi

    if [ ! -s "$EXPORTS_FILE" ] || ! grep -qE '^[^#]' "$EXPORTS_FILE"; then
         echo "No active exports found in $EXPORTS_FILE (file is empty or all lines are comments)."
    else
        echo -e "${YELLOW}Path Client(s) (Options)${NC}"
        echo "--------------------------------------------------"
        # Print non-comment, non-empty lines
        grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$EXPORTS_FILE"
        echo "--------------------------------------------------"
    fi

    if command -v showmount >/dev/null; then
        echo -e "\n${YELLOW}Active NFS Exports (attempting 'sudo showmount -e localhost'):${NC}"
        if sudo showmount -e localhost 2>/dev/null; then
            : 
        else
            echo "Could not retrieve active exports via 'showmount -e localhost'."
            echo "NFS server might not be running, not exporting to localhost, or rpcbind might be needed."
        fi
    else
        echo -e "\n${YELLOW}'showmount' command not found. Cannot display active exports.${NC}"
        echo "Install nfs-common (or similar package) to use 'showmount'."
    fi
    echo ""
}


# --- Main Script Execution ---
echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}      Filesystem Information Utility     ${NC}"
echo -e "${BOLD}=========================================${NC}"
echo ""

display_lsblk_info
display_df_info
display_fstab_info
display_samba_shares
display_nfs_exports

echo -e "${GREEN}${BOLD}Info gathering complete.${NC}"
echo ""

exit 0
