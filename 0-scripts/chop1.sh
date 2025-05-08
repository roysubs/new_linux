#!/usr/bin/env bash
set -e

# ---------------[ CONFIG ]---------------
outdir="$(dirname "$0")"
quality="0"
output_format="webm"

# ---------------[ ARGS ]-----------------
while [[ "$1" == -* ]]; do
  case "$1" in
    --out) shift; outdir="$1" ;;
    --mp4) output_format="mp4" ;;
    -q[0-3]) quality="${1#-q}" ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

url="$1"; start_sec="$2"; end_sec="$3"

if [[ -z "$url" ]]; then
  echo "Usage: $(basename "$0") [--out DIR] [--mp4] [-q0|1|2|3] <url|id> [start_sec end_sec]" >&2
  exit 1
fi

# Strip YouTube URL to video ID if needed
video_id="${url##*v=}"
video_id="${video_id##*/}"
video_id="${video_id%%&*}"

# Sanitize seconds input
start_sec="${start_sec%%.*}"
end_sec="${end_sec%%.*}"

if [[ -n "$start_sec" && -n "$end_sec" && "$end_sec" -le "$start_sec" ]]; then
  echo "[!] End time must be greater than start time." >&2
  exit 1
fi

# Format seconds into HH-MM-SS
to_hms() {
  local s=$1
  printf "%02d-%02d-%02d" $((s/3600)) $(((s%3600)/60)) $((s%60))
}

# Determine yt-dlp format
case "$quality" in
  0) format='worstvideo+worstaudio/worst' ;;
  1) format='bestvideo[height<=360]+bestaudio/best[height<=360]' ;;
  2) format='bestvideo[height<=480]+bestaudio/best[height<=480]' ;;
  3) format='bestvideo[ext=webm]+bestaudio[ext=webm]/best[ext=webm]/best' ;;
  *) echo "[!] Unknown quality level: $quality" >&2; exit 1 ;;
esac

# Ensure dependencies
echo "[*] Checking dependencies..."
command -v yt-dlp >/dev/null || { echo "Missing yt-dlp"; exit 1; }
command -v ffmpeg >/dev/null || { echo "Missing ffmpeg"; exit 1; }

# Filenames
basefile="$outdir/${video_id}_q${quality}.webm"

echo "[*] Downloading video to: $basefile"
if [[ ! -f "$basefile" ]]; then
  yt-dlp -f "$format" -o "$basefile" "https://www.youtube.com/watch?v=${video_id}" || {
    echo "[!] yt-dlp failed" >&2; exit 1;
  }
else
  echo "[*] Skipping download: found existing file $basefile"
fi

# No trimming requested
if [[ -z "$start_sec" || -z "$end_sec" ]]; then
  echo "[*] No trim requested, download complete."
  exit 0
fi

# Clip trim path
start_label=$(to_hms "$start_sec")
end_label=$(to_hms "$end_sec")
clipfile="$outdir/${video_id}_${start_label}_to_${end_label}_q${quality}.${output_format}"

echo "[*] Trimming video from $start_label to $end_label"
echo "[*] Clip will be written to: $clipfile"

# Cut clip
ffmpeg -hide_banner -loglevel error -y \
  -ss "$start_sec" -i "$basefile" \
  -to $((end_sec - start_sec)) -c copy "$clipfile" || {
    echo "[!] Failed to cut video" >&2; exit 1;
}

echo "[*] Finished cut: $clipfile"

