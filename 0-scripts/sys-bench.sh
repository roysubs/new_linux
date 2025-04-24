#!/bin/bash

# sys-bench.sh - Simple system benchmark script
# Requirements: sysbench, fio, iperf3, curl, jq, smartmontools, lshw

VERBOSE=0
for arg in "$@"; do
  if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
    VERBOSE=1
  fi

done

log() {
  echo -e "$1"
}

vlog() {
  if [[ $VERBOSE -eq 1 ]]; then
    echo -e "$1"
  fi
}

install_if_missing() {
  for pkg in "$@"; do
    if ! command -v "$pkg" &>/dev/null; then
      log "Installing missing dependency: $pkg"
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y "$pkg"
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg"
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm "$pkg"
      else
        log "Package manager not supported. Please install $pkg manually."
      fi
    fi
  done
}

install_if_missing sysbench fio iperf3 curl jq lshw sensors
if ! command -v "smartctl" &>/dev/null; then sudo apt install -y smartmontools; fi

BOLD="\033[1m"
RESET="\033[0m"

log "${BOLD}🖥️  SYSTEM INFO${RESET}"
uname -a
if command -v sudo &>/dev/null; then
  sudo lshw -short -C memory -C processor -C disk 2>/dev/null || lshw -short -C memory -C processor -C disk
else
  lshw -short -C memory -C processor -C disk
fi

echo
log "${BOLD}🧠 CPU${RESET}"
log "Sysbench Time: Testing CPU..."
CPU_OUT=$(sysbench cpu --cpu-max-prime=20000 --time=10 run)
echo "$CPU_OUT" | grep "total time"
log "Duration: 10s"
vlog "$CPU_OUT"

echo
log "${BOLD}🧵 RAM${RESET}"
RAM_OUT=$(sysbench memory --memory-total-size=1G run)
echo "$RAM_OUT" | grep -E 'transferred|operations|avg:'
log "Duration: 1s"
vlog "$RAM_OUT"

echo
log "${BOLD}💾 DISK${RESET}"
for DISK in /dev/sd[a-z]; do
  MODEL=$(lsblk -no MODEL $DISK | head -n1)
  SIZE=$(lsblk -no SIZE $DISK | head -n1)
  MOUNT=$(lsblk -no MOUNTPOINT $DISK | grep -v '^$' | head -n1)
  [[ -z "$MOUNT" ]] && MOUNT="(not mounted)"
  log "📦 $DISK ($MODEL, $SIZE)"

  log "  ➤ Direct I/O test (raw device)..."
  RAW_OUT=$(fio --name=rawtest --filename=$DISK --direct=1 --rw=readwrite --bs=4k --size=10M --numjobs=1 --time_based --runtime=5s --group_reporting 2>/dev/null)
  vlog "$RAW_OUT"

  if mount | grep -q "$DISK"; then
    MOUNTPOINT=$(lsblk -no MOUNTPOINT $DISK | grep -v '^$' | head -n1)
    [[ -z "$MOUNTPOINT" ]] && continue
    log "  ➤ Filesystem test @ $MOUNTPOINT"
    FS_OUT=$(fio --name=fsbench --directory="$MOUNTPOINT" --size=1G --readwrite=readwrite --bs=4k --runtime=10s --time_based --numjobs=1 --group_reporting 2>/dev/null)
    echo "$FS_OUT" | grep -E 'read:|write:|READ:|WRITE:'
    vlog "$FS_OUT"
  fi

done

log "Duration: ~45s"

echo
log "${BOLD}🌐 NETWORK${RESET}"
log "Checking for local iperf3 server (localhost:5201)..."
if iperf3 -c localhost -t 10 &>/dev/null; then
  NET_OUT=$(iperf3 -c localhost -t 10)
  echo "$NET_OUT" | grep -E '\[ *[0-9]+\] +0.00-.* sec'
  log "Duration: 10s"
  vlog "$NET_OUT"
else
  log "iperf3 local server not running. Skipping local bandwidth test."
fi

log "\n${BOLD}🌡️ TEMPERATURES${RESET}"
if command -v sensors &>/dev/null; then
  TEMP_OUT=$(sensors)
  echo "$TEMP_OUT" | grep -E 'Core|temp1'
  vlog "$TEMP_OUT"
else
  log "sensors command not found. Install lm-sensors."
fi

log "\n${BOLD}🚀 INTERNET SPEED TEST${RESET}"
if command -v curl &>/dev/null && command -v jq &>/dev/null; then
  SPEED=$(curl -s https://api.fast.com/netflix/speedtest | jq '.[] | select(.url != null) | .url' | head -n1 | tr -d '"')
  if [[ -n "$SPEED" ]]; then
    SPEED_OUT=$(curl -s -w "\nDownload: %{speed_download} B/s\n" -o /dev/null "$SPEED")
    echo "$SPEED_OUT"
  else
    log "Could not get speed test URL."
  fi
else
  log "Install curl and jq to run internet speed test."
fi

echo
log "🏁 Total Benchmark Duration: ~66s"
