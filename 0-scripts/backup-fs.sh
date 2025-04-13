#!/bin/bash
# # Default exclusions for home directory backup
# EXCLUDE_PATHS=(
#     "$HOME_DIR/backup-fs"
#     "$HOME_DIR/backup-home"
#     "$HOME_DIR/.cache"
#     "$HOME_DIR/.local/share/Trash"
#     "$HOME_DIR/.npm"
#     "$HOME_DIR/.cargo/registry"
#     "$HOME_DIR/.rustup"
# )

set -euo pipefail

# --- CONFIGURATION ---
BACKUP_DIR="$HOME/backup-fs"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SUMMARY_FILE="$BACKUP_DIR/summary-${TIMESTAMP}.txt"
SCRIPT_PATH="$0"
REPORT_SUMMARY=""
TOTAL_SIZE=0
TOTAL_TIME=0

# --- ENSURE BACKUP DIRECTORY EXISTS ---
mkdir -p "$BACKUP_DIR"

# --- FOLDERS TO BACK UP ---
TARGETS=($HOME /etc)  # Add more directories as needed

# --- FILES TO EXCLUDE ---
EXCLUDES=($BACKUP_DIR "$HOME/backup-fs" "$HOME/.cache" "$HOME/.local/share/Trash")

# --- FUNCTION TO BUILD FIND EXCLUDE EXPRESSION ---
build_find_excludes() {
    local expr=""
    for excl in "${EXCLUDES[@]}"; do
        expr+=" -path $excl -prune -o"
    done
    echo "$expr"
}

# --- FUNCTION TO CONVERT SIZE TO HUMAN READABLE ---
human_size() {
    local size=$1
    if (( size > 1099511627776 )); then printf "%.1fT" $(echo "$size / 1099511627776" | bc -l);
    elif (( size > 1073741824 )); then printf "%.1fG" $(echo "$size / 1073741824" | bc -l);
    elif (( size > 1048576 )); then printf "%.1fM" $(echo "$size / 1048576" | bc -l);
    elif (( size > 1024 )); then printf "%.1fK" $(echo "$size / 1024" | bc -l);
    else printf "%dB" "$size";
    fi
}

# --- FUNCTION TO GENERATE REPORT FOR A DIRECTORY ---
generate_report() {
    local target="$1"
    local report_file="$BACKUP_DIR/fs-$(basename "$target")-$TIMESTAMP.txt"
    local start_time=$(date +%s)

    {
        export LC_ALL=C
        find "$target" $(build_find_excludes) -type d -print | while read -r dir; do
            echo -e "\n$dir"
            find "$dir" -maxdepth 1 -mindepth 1 -type f -print0 | sort -z | while IFS= read -r -d '' file; do
                stat_output=$(stat --format='%A %s %Y %n' "$file")
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

# --- RUN REPORT FOR EACH TARGET ---
for target in "${TARGETS[@]}"; do
    generate_report "$target"
done

# --- COPY THIS SCRIPT TO BACKUP DIR ---
cp "$SCRIPT_PATH" "$BACKUP_DIR/backup-fs.sh"

# --- VERIFY AND INJECT INTO CRONTAB ---
CRON_ENTRY="0 0 * * * $BACKUP_DIR/backup-fs.sh"
if ! crontab -l 2>/dev/null | grep -qF "$CRON_ENTRY"; then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
fi

# --- FINAL SUMMARY ---
echo -e "\n--- Backup Summary ---"
echo -e "$REPORT_SUMMARY"
echo "Total size of reports: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
echo "Total time to generate reports: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s"

# --- WRITE SUMMARY TO FILE ---
echo -e "\n--- Backup Summary ---" > "$SUMMARY_FILE"
echo -e "$REPORT_SUMMARY" >> "$SUMMARY_FILE"
echo "Total size of reports: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)" >> "$SUMMARY_FILE"
echo "Total time to generate reports: $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s" >> "$SUMMARY_FILE"
