#!/usr/bin/env bash
set -e

# ---------------[ CONFIG ]---------------
outdir="$(dirname "$0")"
quality="3"
output_format="mp4"
use_title=true

# ---------------[ ARGS ]-----------------
while [[ "$1" == -* ]]; do
  case "$1" in
    --out) shift; outdir="$1" ;;
    --no-title) use_title=false ;;
    -q[0-3]) quality="${1#-q}" ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

url="$1"; start_sec="$2"; end_sec="$3"

if [[ -z "$url" ]]; then
  echo "Usage: $(basename "$0") [--out DIR] [--no-title] [-q0|1|2|3] <url|id> [start_sec end_sec]" >&2
  exit 1
fi

# Strip YouTube URL to video ID if needed
video_id="${url##*v=}"
video_id="${video_id##*/}"
video_id="${video_id%%&*}"

# Detect and handle hh:mm:ss or seconds
convert_to_seconds() {
  if [[ "$1" =~ ^([0-9]+):([0-5]?[0-9]):([0-5]?[0-9])(\.[0-9]+)?$ ]]; then
    local h=${BASH_REMATCH[1]}
    local m=${BASH_REMATCH[2]}
    local s=${BASH_REMATCH[3]}
    local f=${BASH_REMATCH[4]:-0}
    echo "$((10#$h * 3600 + 10#$m * 60 + 10#$s))${f}"
  else
    echo "${1%%.*}"
  fi
}

[[ -n "$start_sec" ]] && start_sec=$(convert_to_seconds "$start_sec")
[[ -n "$end_sec" ]] && end_sec=$(convert_to_seconds "$end_sec")

if [[ -n "$start_sec" && -n "$end_sec" && $(echo "$end_sec <= $start_sec" | bc) -eq 1 ]]; then
  echo "[!] End time must be greater than start time." >&2
  exit 1
fi

# Format seconds into HH-MM-SS
to_hms() {
  local s=${1%%.*}
  printf "%02d-%02d-%02d" $((s/3600)) $(((s%3600)/60)) $((s%60))
}

# Determine yt-dlp format
case "$quality" in
  0) format='worstvideo+worstaudio/worst' ;;
  1) format='bestvideo[height<=360]+bestaudio/best[height<=360]' ;;
  2) format='bestvideo[height<=480]+bestaudio/best[height<=480]' ;;
  3) format='bestvideo+bestaudio/best' ;;
  *) echo "[!] Unknown quality level: $quality" >&2; exit 1 ;;
esac

# Ensure dependencies
echo "[*] Checking dependencies..."
command -v yt-dlp >/dev/null || { echo "Missing yt-dlp"; exit 1; }
command -v ffmpeg >/dev/null || { echo "Missing ffmpeg"; exit 1; }
command -v ffprobe >/dev/null || { echo "Missing ffprobe"; exit 1; }

# Title-based filename (default)
if $use_title; then
  echo "[*] Fetching video title..."
  raw_title=$(yt-dlp --get-title "$url")
  title=$(sed 's#[\\x00/<>:"|?*]##g' <<< "$raw_title")
  webmfile="$outdir/${title}_q${quality}.webm"
else
  webmfile="$outdir/${video_id}_q${quality}.webm"
fi

# Download base video (webm)
echo "[*] Downloading video to: $webmfile"
if [[ ! -f "$webmfile" ]]; then
  yt-dlp -f "$format" -o "$webmfile" "https://www.youtube.com/watch?v=${video_id}" || {
    echo "[!] yt-dlp failed" >&2; exit 1;
  }
else
  echo "[*] Skipping download: found existing file $webmfile"
fi

# Determine video orientation for padding
video_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$webmfile")
video_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$webmfile")
if (( video_width >= video_height )); then
  pad_width=1280; pad_height=720
else
  pad_width=720; pad_height=1280
fi

# Output filename
if [[ -n "$start_sec" && -n "$end_sec" ]]; then
  start_label=$(to_hms "$start_sec")
  end_label=$(to_hms "$end_sec")
  if $use_title; then
    clipfile="$outdir/${title}_${start_label}_to_${end_label}_q${quality}.mp4"
  else
    clipfile="$outdir/${video_id}_${start_label}_to_${end_label}_q${quality}.mp4"
  fi
  echo "[*] Trimming video from $start_label to $end_label"
  echo "[*] Clip will be written to: $clipfile"

  ffmpeg -hide_banner -loglevel error -y \
    -ss "$start_sec" -i "$webmfile" \
    -to $(echo "$end_sec - $start_sec" | bc) \
    -vf "scale=w='min(iw\\,${pad_width})':h='min(ih\\,${pad_height})':force_original_aspect_ratio=decrease,pad=${pad_width}:${pad_height}:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -crf 23 -preset fast -c:a aac -b:a 128k "$clipfile" || {
      echo "[!] Failed to cut video" >&2; exit 1;
    }
  echo "[*] Finished cut: $clipfile"
else
  if $use_title; then
    fullfile="$outdir/${title}_full_q${quality}.mp4"
  else
    fullfile="$outdir/${video_id}_full_q${quality}.mp4"
  fi
  echo "[*] No trim requested. Re-encoding full video to: $fullfile"

  ffmpeg -hide_banner -loglevel error -y \
    -i "$webmfile" \
    -vf "scale=w='min(iw\\,${pad_width})':h='min(ih\\,${pad_height})':force_original_aspect_ratio=decrease,pad=${pad_width}:${pad_height}:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -crf 23 -preset fast -c:a aac -b:a 128k "$fullfile" || {
      echo "[!] Failed to re-encode full video" >&2; exit 1;
    }
  echo "[*] Full video saved as: $fullfile"
fi
