#!/bin/bash

set -e

# === Colors ===
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

# === Start time ===
SCRIPT_START=$(date +%s)
echo -e "${GREEN}Script started at $(date '+%H:%M:%S')${NC}"

# === Reminder for yt-dlp update ===
echo -e "${GREEN}If you have trouble downloading from YouTube, try running:${NC}"
echo -e "${GREEN}  sudo yt-dlp -U${NC}"

# === Required tools ===
for cmd in yt-dlp ffmpeg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: '$cmd' is not installed.${NC}"
        exit 1
    fi
done

# === Default quality (fast stream copy) ===
QUALITY="-c copy"
QUALITY_SUFFIX="-q0"

# === Default output dir ===
OUTDIR="$(dirname "$(realpath "$0")")"

# === Parse args ===
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -q0) QUALITY="-c copy"; QUALITY_SUFFIX="-q0"; shift ;;
        -q1) QUALITY="-crf 32 -preset veryfast"; QUALITY_SUFFIX="-q1"; shift ;;
        -q2) QUALITY="-crf 25 -preset medium"; QUALITY_SUFFIX="-q2"; shift ;;
        -q3) QUALITY="-crf 20 -preset slow"; QUALITY_SUFFIX="-q3"; shift ;;
        --out)
            OUTDIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: yt-split.sh [options] <video_url_or_id> <start_time> [<end_time>]"
            echo "Options:"
            echo "  -q0        Fast stream copy (default)"
            echo "  -q1        Fast re-encode (lower quality)"
            echo "  -q2        Medium quality re-encode"
            echo "  -q3        High quality re-encode"
            echo "  --out DIR  Output directory"
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"
if [[ $# -lt 2 ]]; then
    echo -e "${RED}Error: Missing required arguments.${NC}"
    echo "Usage: yt-split.sh [options] <video_url_or_id> <start_time> [<end_time>]"
    exit 1
fi

VIDEO_INPUT="$1"
START_TIME="$2"
END_TIME="$3"

# === Normalize YouTube ID ===
if [[ "$VIDEO_INPUT" =~ ^https?:// ]]; then
    VIDEO_ID=$(echo "$VIDEO_INPUT" | sed -n 's/.*v=\([^&]*\).*/\1/p')
else
    VIDEO_ID="$VIDEO_INPUT"
fi

# === File paths ===
mkdir -p "$OUTDIR"
VIDEO_FILE="$OUTDIR/${VIDEO_ID}.webm"
BASENAME="${VIDEO_ID}_${START_TIME//:/-}"
if [[ -n "$END_TIME" ]]; then
    BASENAME+="_to_${END_TIME//:/-}"
fi
BASENAME+="$QUALITY_SUFFIX"
OUT_FILE="$OUTDIR/${BASENAME}.webm"

# === Check if already downloaded ===
if [[ -f "$VIDEO_FILE" ]]; then
    echo -e "${GREEN}Found existing download: $VIDEO_FILE${NC}"
else
    echo -e "${GREEN}Starting download at $(date '+%H:%M:%S')...${NC}"
    yt-dlp -f bestvideo+bestaudio --merge-output-format webm -o "$VIDEO_FILE" "https://www.youtube.com/watch?v=$VIDEO_ID"
    echo -e "${GREEN}Download finished at $(date '+%H:%M:%S')${NC}"
fi

# === Run ffmpeg trim ===
echo -e "${GREEN}Starting trim at $(date '+%H:%M:%S')...${NC}"
FFMPEG_CMD=(ffmpeg -hide_banner -loglevel error -ss "$START_TIME" -i "$VIDEO_FILE")
[[ -n "$END_TIME" ]] && FFMPEG_CMD+=(-to "$END_TIME")
FFMPEG_CMD+=(${QUALITY} -y "$OUT_FILE")

"${FFMPEG_CMD[@]}"
echo -e "${GREEN}Trim finished at $(date '+%H:%M:%S')${NC}"
echo -e "${GREEN}Output saved to:${NC} $OUT_FILE"

# === Done ===
SCRIPT_END=$(date +%s)
RUNTIME=$((SCRIPT_END - SCRIPT_START))
echo -e "${GREEN}Total runtime: $RUNTIME seconds${NC}"

