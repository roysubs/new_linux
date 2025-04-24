#!/bin/bash

# === USAGE ===
# ./filebot-myfiles.sh <path> [-tv | -film] [-commit]

# === DEFAULTS ===
MODE="film"
DRY_RUN=true
INPUT="$1"
shift

# === PARSE SWITCHES ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    -tv)
      MODE="tv"
      shift
      ;;
    -film)
      MODE="film"
      shift
      ;;
    -commit)
      DRY_RUN=false
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# === CHECK INPUT ===
if [[ -z "$INPUT" ]]; then
  echo "Usage: $0 <file|folder> [-tv|-film] [-commit]"
  exit 1
fi

if [[ ! -e "$INPUT" ]]; then
  echo "Error: '$INPUT' does not exist."
  exit 1
fi

# === SELECT METADATA DB AND FORMAT ===
if [[ "$MODE" == "tv" ]]; then
  DB="TheTVDB"
  FORMAT="{n}/Season {s}/{n} - S{s00}E{e00} - {t}"
else
  DB="TheMovieDB"
  FORMAT="{n} ({y})"
fi

# === SELECT ACTION ===
if [[ "$DRY_RUN" == true ]]; then
  ACTION="test"
  echo "[DRY RUN] Showing planned renames only..."
else
  ACTION="move"
  echo "[COMMIT] Actually renaming files..."
fi

# === BUILD FILEBOT COMMAND ===
if [[ -f "$INPUT" ]]; then
  filebot -rename "$INPUT" \
    --db "$DB" \
    --format "$FORMAT" \
    --action "$ACTION" \
    -non-strict
elif [[ -d "$INPUT" ]]; then
  filebot -rename "$INPUT" \
    --db "$DB" \
    --format "$FORMAT" \
    --action "$ACTION" \
    -non-strict \
    --output "$INPUT"
else
  echo "Unsupported input type."
  exit 1
fi

