#!/usr/bin/env bash

# chop-video.sh — Download & chop YouTube videos by time range, with optional quality & output control
# 1. Download full video from youtube with yt-dlp (fuzzy timings, about 1-2 second offset due to YouTube interval keyframes not aligning)
# 2. Precise timing splits with ffmpeg, e.g., a start time of 1:23.45 (start at 1 minute, 23.45 seconds) for precise cuts works.
# Supports GPU acceleration. If an NVIDIA GPU, use h264_nvenc or hevc_nvenc for video encoding
# Auto-detect whether ffmpeg has NVENC support, fallback to libx264 if not.
# Added a --precise flag to toggle re-encoding (accurate) vs -c copy (fast) for frame-accurate trimming.
# Auto-detect NVIDIA support and use -c:v h264_nvenc if available.
# Auto-detects and uses NVENC (h264_nvenc) if available, otherwise falls back to libx264
# Want to add anything else, like a --preview flag to open the trimmed clip in mpv or vlc after encoding?

set -euo pipefail

# Define ANSI color codes
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# -------- Helper: print usage ----------
usage() {
  cat <<EOF
Usage: $(basename "$0") [-q1|-q2|-q3] [--out /path/to/dir] [--precise] <YouTube URL or ID> <start_time> [end_time]

Examples:
  $(basename "$0") https://www.youtube.com/watch?v=xn4Mr0rbD3U 1:30.25
  $(basename "$0") -q2 --out ~/clips --precise xn4Mr0rbD3U 00:30.75 02:15.50

Options:
  -q1             Low quality (360p)
  -q2             Medium quality (480p)
  -q3             High quality (720p)
  --out DIR       Output directory for .webm and final clip
  --precise       Re-encode output for frame-accurate cuts (slower)
EOF
  exit 1
}

# -------- Helper: parse time formats ----------
parse_time() {
  local input="$1"
  local frac="0"
  if [[ $input =~ \. ]]; then
    frac=".${input##*.}"
    input="${input%.*}"
  fi
  IFS=: read -r a b c <<<"$input"
  if [[ -z $b ]]; then
    echo "$(bc <<< \"scale=3; 10#$a$frac\")"
  elif [[ -z $c ]]; then
    echo "$(bc <<< \"scale=3; 10#$a * 60 + 10#$b$frac\")"
  else
    echo "$(bc <<< \"scale=3; 10#$a * 3600 + 10#$b * 60 + 10#$c$frac\")"
  fi
}

# -------- Detect NVENC support ----------
has_nvenc() {
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc
}

# -------- Start stopwatch ----------
script_start=$(date +%s.%N)

# -------- Parse args ----------
quality="q0"
out_dir="$(cd "$(dirname "$0")" && pwd)"
precise=0
args=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -q1|-q2|-q3) quality="${1#-}"; shift ;;
    --out) out_dir="$2"; shift 2 ;;
    --precise) precise=1; shift ;;
    -h|--help) usage ;;
    *) args+=("$1"); shift ;;
  esac
done

[[ ${#args[@]} -lt 2 ]] && usage

url_or_id="${args[0]}"
start_input="${args[1]}"
end_input="${args[2]:-}"

# -------- Resolve video ID and title ----------
video_id="${url_or_id##*v=}"
video_id="${video_id##*/}"

mkdir -p "$out_dir"

# -------- Check tools ----------
echo "[*] Checking dependencies..."
command -v ffmpeg >/dev/null || { echo "Installing ffmpeg..."; sudo apt install -y ffmpeg; }

if ! command -v yt-dlp >/dev/null || [[ $(command -v yt-dlp) == *"/usr/bin/"* ]]; then
  echo "Installing yt-dlp via curl (to ~/.local/bin)..."
  mkdir -p ~/.local/bin
  curl -sSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o ~/.local/bin/yt-dlp
  chmod +x ~/.local/bin/yt-dlp
  export PATH="$HOME/.local/bin:$PATH"
fi

echo -e "${CYAN}If download issues occur, run: sudo ~/.local/bin/yt-dlp -U${NC}"

# -------- Define filenames ----------
start_sec=$(parse_time "$start_input")
end_sec=${end_input:+$(parse_time "$end_input")}
duration_arg=${end_sec:+-t $(bc <<< "scale=3; $end_sec - $start_sec")}

basename="${video_id}_${start_sec}${end_sec:+-$end_sec}_${quality}${precise:+_precise}"
webm_path="$out_dir/${video_id}_${quality}.webm"
out_path="$out_dir/${basename}.mp4"

# -------- Quality selector for yt-dlp ----------
case $quality in
  q0) format="bestvideo+bestaudio/best" ;;
  q1) format="bv[height<=360]+ba/b[height<=360]" ;;
  q2) format="bv[height<=480]+ba/b[height<=480]" ;;
  q3) format="bv[height<=720]+ba/b[height<=720]" ;;
esac

# -------- Download video (if needed) ----------
echo "[*] Downloading video to: $webm_path"
echo -e "${YELLOW}[*] Current time: $(date +%T)${NC}"

if [[ ! -f "$webm_path" ]]; then
  yt-dlp -f "$format" -o "$webm_path" "https://www.youtube.com/watch?v=$video_id" || {
    echo "Error: yt-dlp failed to download the video."
    exit 1
  }
else
  echo "[*] Skipping download: found existing file $webm_path"
fi

echo -e "${YELLOW}[*] Download complete: $(date +%T)${NC}"

# -------- Chop video ----------
echo "[*] Trimming video from $start_sec sec to ${end_sec:-end}"
echo -e "${YELLOW}[*] Starting cut: $(date +%T)${NC}"

if [[ "$precise" -eq 1 ]]; then
  codec_opts="-c:v $(has_nvenc && echo h264_nvenc || echo libx264) -c:a copy"
else
  codec_opts="-c copy"
fi

ffmpeg -hide_banner -loglevel error -ss "$start_sec" ${end_sec:+-to "$end_sec"} -i "$webm_path" $codec_opts "$out_path" 2>/dev/null

echo -e "[*] Clip written to: ${GREEN}$out_path${NC}"
echo -e "${YELLOW}[*] Finished cut: $(date +%T)${NC}"

# -------- Done --------
script_end=$(date +%s.%N)
runtime=$(bc <<< "scale=2; $script_end - $script_start")
echo "[*] Total script time: ${runtime}s"

