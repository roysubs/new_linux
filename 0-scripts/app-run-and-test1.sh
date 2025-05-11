#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

APP="$1"
if [ -z "$APP" ]; then
    echo -e "${RED}Usage: $0 <app_command>${NC}"
    exit 1
fi

before=$(mktemp)
after=$(mktemp)
stats=$(mktemp)
peak_stats=$(mktemp)

echo -e "${CYAN}📂 Scanning files in your home directory... (this may take a moment)${NC}"
start_fscheck=$(date +%s.%N)
find ~ -type f -printf '%T@ %p\n' 2>/dev/null | sort > "$before"
before_size=$(du -sb ~ | awk '{print $1}')
end_fscheck=$(date +%s.%N)
fscheck_time_before=$(echo "$end_fscheck - $start_fscheck" | bc)

# System usage before
mem_before=$(free -m | awk '/Mem:/ {print $3}')
cpu_before=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

echo -e "${CYAN}🕹️  Launching $APP now. Play a bit, then exit the game normally.${NC}"
read -p "Press Enter to launch $APP..."

# Start monitoring peak usage in the background
(
    peak_mem=0
    peak_cpu=0
    pid=""
    while [ -z "$pid" ]; do
        pid=$(pgrep -n -x "$APP")
        sleep 0.1
    done
    while kill -0 "$pid" 2>/dev/null; do
        mem=$(ps -o rss= -p "$pid")
        cpu=$(ps -o %cpu= -p "$pid")
        [ "$mem" -gt "$peak_mem" ] && peak_mem="$mem"
        awk "BEGIN {if ($cpu > $peak_cpu) exit 1; exit 0}" && peak_cpu="$cpu"
        sleep 0.2
    done
    echo "$peak_mem $peak_cpu" > "$peak_stats"
) &

start_app=$(date '+%Y-%m-%d %H:%M:%S')
$APP
end_app=$(date '+%Y-%m-%d %H:%M:%S')

# System usage after
mem_after=$(free -m | awk '/Mem:/ {print $3}')
cpu_after=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

echo -e "${CYAN}🔍 Scanning again to detect new/changed files...${NC}"
start_fscheck2=$(date +%s.%N)
find ~ -type f -printf '%T@ %p\n' 2>/dev/null | sort > "$after"
after_size=$(du -sb ~ | awk '{print $1}')
end_fscheck2=$(date +%s.%N)
fscheck_time_after=$(echo "$end_fscheck2 - $start_fscheck2" | bc)

# Wait for peak monitor to finish
wait

# Read peak stats
read peak_mem peak_cpu < "$peak_stats"

# Files created or modified
changed_files=$(comm -13 "$before" "$after" | cut -d' ' -f2- | uniq | wc -l)

# Display results in a colorized table
printf "\n${YELLOW}%-30s${CYAN}%-25s${CYAN}%-25s${NC}\n" "Metric" "Before" "After"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Filesystem check time (s)" "$fscheck_time_before" "$fscheck_time_after"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Filesystem size (bytes)" "$before_size" "$after_size"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Memory used (MB)" "$mem_before" "$mem_after"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "CPU used (%)" "$cpu_before" "$cpu_after"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Number of changed files" "$changed_files" "-"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "App start time" "$start_app" "-"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "App end time" "$end_app" "-"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Peak memory (KB)" "-" "$peak_mem"
printf "${GREEN}%-30s${NC}%-25s%-25s\n" "Peak CPU (%)" "-" "$peak_cpu"
printf "${NC}\n"

# Clean up
rm "$before" "$after" "$stats" "$peak_stats"

