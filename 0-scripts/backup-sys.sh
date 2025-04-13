#!/bin/bash
# backup-sys.sh — System and config summary snapshot tool
# Saves file metadata and system information without copying actual binaries or data.

set -euo pipefail

# -------------------[ CONFIG ]--------------------

SCRIPT_PATH="$(readlink -f "$0")"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
MODE="full"
TARGETS=()
SAFE_MODE=false
USER_MODE=false

# -------------------[ FUNCTIONS ]--------------------

print_help() {
cat <<EOF
Usage: $(basename "$0") [--safe | --user | -h|--help]

Creates a detailed filesystem and system config summary under:
  ~/backup-sys/yyyy-mm-dd-hhmmss/

Modes:
  --full     Default. Collects all useful system data. Requires sudo.
  --safe     Skips sensitive folders (/root, /etc/ssl/private, etc).
  --user     Only collects from user home dir. No root needed.
  -h, --help Show this help.

What it collects:
  ✓ Permissions, timestamps, and size of each file
  ✓ Installed packages (dpkg -l)
  ✓ Systemd services (systemctl)
  ✓ Kernel and hardware info
  ✓ Copies this script

This is for archival and diagnostic purposes — does NOT copy actual files.
EOF
exit 0
}

human_size() {
    local size=$1
    if (( size > 1099511627776 )); then printf "%.1fT" $(echo "$size / 1099511627776" | bc -l);
    elif (( size > 1073741824 )); then printf "%.1fG" $(echo "$size / 1073741824" | bc -l);
    elif (( size > 1048576 )); then printf "%.1fM" $(echo "$size / 1048576" | bc -l);
    elif (( size > 1024 )); then printf "%.1fK" $(echo "$size / 1024" | bc -l);
    else printf "%dB" "$size";
    fi
}

build_find_excludes() {
    local expr=""
    for excl in "${EXCLUDES[@]}"; do
        expr+=" -path $excl -prune -o"
    done
    echo "$expr"
}

generate_report() {
    local target="$1"
    local report_file="$BACKUP_DIR/fs-$(basename "$target")-$TIMESTAMP.txt"
    local start_time=$(date +%s)

    {
        export LC_ALL=C
        find "$target" $(build_find_excludes) -type d -print 2>/dev/null | while read -r dir; do
            echo -e "\n$dir"
            find "$dir" -maxdepth 1 -mindepth 1 -type f -print0 2>/dev/null | sort -z | while IFS= read -r -d '' file; do
                stat_output=$(stat --format='%A %s %Y %n' "$file" 2>/dev/null || true)
                [[ -z "$stat_output" ]] && continue
                perm=$(echo "$stat_output" | awk '{print $1}')
                size=$(echo "$stat_output" | awk '{print $2}')
                ts=$(echo "$stat_output" | awk '{print $3}')
                base=$(basename "$file")
                datestr=$(date -d "@$ts" +"%Y_%m_%d_%H%M%S")
                hsize=$(human_size "$size")
                printf "%-10s %6s %s %s\n" "$perm" "$hsize" "$datestr" "$base"
            done
        done
    } > "$report_file"

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local report_size=$(du -h "$report_file" | cut -f1)
    local report_bytes=$(du -b "$report_file" | cut -f1)
    TOTAL_SIZE=$((TOTAL_SIZE + report_bytes))
    TOTAL_TIME=$((TOTAL_TIME + elapsed))
    REPORT_SUMMARY+="$report_file $report_size ${mins}m ${secs}s\n"
}

collect_system_info() {
    echo "Collecting system info..."
    uname -a > "$BACKUP_DIR/uname.txt"
    lscpu > "$BACKUP_DIR/lscpu.txt"
    free -h > "$BACKUP_DIR/memory.txt"
    df -h > "$BACKUP_DIR/disk-usage.txt"
    systemctl list-units --type=service > "$BACKUP_DIR/systemd-services.txt"
    dpkg -l > "$BACKUP_DIR/dpkg-list.txt"
}

# -------------------[ MODE DETECTION ]--------------------

for arg in "$@"; do
    case "$arg" in
        --safe) SAFE_MODE=true ;;
        --user) USER_MODE=true ;;
        -h|--help) print_help ;;
        *) echo "Unknown argument: $arg"; print_help ;;
    esac
done

# Determine real user and home
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")
BACKUP_DIR="$USER_HOME/backup-sys/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

TOTAL_SIZE=0
TOTAL_TIME=0
REPORT_SUMMARY=""

# -------------------[ TARGETS & EXCLUDES ]--------------------

if [[ "$USER_MODE" == true ]]; then
    TARGETS=("$USER_HOME")
    EXCLUDES=("$USER_HOME/.cache" "$USER_HOME/.local/share/Trash")
elif [[ "$SAFE_MODE" == true ]]; then
    TARGETS=("/etc" "/usr" "/var/log" "$USER_HOME")
    EXCLUDES=("/etc/ssl/private" "/etc/sudoers.d" "$USER_HOME/.cache" "$USER_HOME/.local/share/Trash")
else
    # Full mode (default)
    if [[ "$EUID" -ne 0 ]]; then
        echo "Please run as root: sudo $0"
        exit 1
    fi
    TARGETS=("/etc" "/usr" "/var" "/boot" "/root" "$USER_HOME")
    EXCLUDES=("/proc" "/sys" "/dev" "/run" "$USER_HOME/.cache" "$USER_HOME/.local/share/Trash")
fi

# -------------------[ RUN REPORTS ]--------------------

echo "Starting file metadata collection..."
for target in "${TARGETS[@]}"; do
    generate_report "$target"
done

if [[ "$USER_MODE" != true ]]; then
    collect_system_info
fi

# -------------------[ SUMMARY ]--------------------

SUMMARY_FILE="$BACKUP_DIR/summary-${TIMESTAMP}.txt"
echo -e "\n--- Backup Summary ---"
echo -e "$REPORT_SUMMARY"
echo "Total size of reports: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
echo "Total time to generate reports: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s"

# Save summary
echo -e "\n--- Backup Summary ---" > "$SUMMARY_FILE"
echo -e "$REPORT_SUMMARY" >> "$SUMMARY_FILE"
echo "Total size of reports: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)" >> "$SUMMARY_FILE"
echo "Total time to generate reports: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s" >> "$SUMMARY_FILE"

# Copy self
cp "$SCRIPT_PATH" "$BACKUP_DIR/"

echo "Backup complete. Files saved in $BACKUP_DIR"

# 🔧 1. /etc — System Configuration
# Contains almost all system-wide configuration files.
# 
# Includes:
# 
# /etc/pacman.conf, /etc/pacman.d/ – Arch package manager config.
# 
# /etc/systemd/ – Systemd service definitions and targets.
# 
# /etc/fstab, /etc/hostname, /etc/hosts, /etc/resolv.conf, etc.
# 
# 💡 Definitely back this up – it's like the brain of your system's configuration.
# 
# 📦 2. /var/lib/pacman/ — Package Database (Pacman)
# This is where pacman keeps records of what is installed.
# 
# Especially:
# 
# /var/lib/pacman/local/ – directories for each installed package, including version, install files, etc.
# 
# 💡 Use pacman -Qe or pacman -Qet to get an install list of explicitly installed packages.
# 
# 📜 3. /usr — User Binaries, Libraries, Docs
# /usr/bin/ – most user-space programs.
# 
# /usr/lib/ – libraries.
# 
# /usr/share/ – man pages, icons, fonts, etc.
# 
# /usr/local/ – user-installed stuff not managed by pacman (sometimes used for custom builds or installs).
# 
# 💡 If you're analyzing installed software, these are key folders.
# 
# 🧱 4. /opt — Optional Software (3rd-party apps)
# Contains large, typically third-party apps installed outside the package manager, e.g., Chrome, VMware.
# 
# 💡 Backup if you installed software there manually.
# 
# 🪄 5. /boot — Bootloader & Kernel
# Includes:
# 
# Kernel images (vmlinuz-linux)
# 
# Initramfs images
# 
# Bootloader files (GRUB or systemd-boot)
# 
# 💡 Needed if you're reconstructing the system or migrating it.
# 
# 📋 6. /lib, /lib64 — Essential Libraries
# These are needed during boot and for basic system operation.
# 
# ⚙️ 7. /sbin, /bin — Essential system binaries
# Now mostly symlinks to /usr/bin on modern systems, but may still be important for chroot recovery and minimal systems.
# 
# 📝 Bonus Tips:
# 💾 Installed packages list:
# 
# bash
# Copy
# Edit
# pacman -Qqe > pkglist.txt
# Later, reinstall with:
# 
# bash
# Copy
# Edit
# pacman -S --needed - < pkglist.txt
# 🧠 Systemd services:
# 
# bash
# Copy
# Edit
# systemctl list-unit-files --state=enabled > enabled-services.txt
# 🔌 Networking config (often in /etc/NetworkManager/ or /etc/systemd/network/)
