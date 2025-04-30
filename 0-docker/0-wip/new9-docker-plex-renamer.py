#!/usr/bin/env python3
import os
import re
import sqlite3
import sys
from pathlib import Path

# Default known Plex DB location for Docker container
DEFAULT_PLEX_DB = "/var/lib/docker/volumes/plex_data/_data/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"

# Search fallback paths (e.g. if user manually copied DB elsewhere)
FALLBACK_PATHS = [
    os.path.expanduser("~/plex.db"),
    os.path.expanduser("~/Downloads/plex.db"),
]

def find_plex_db():
    if os.path.exists(DEFAULT_PLEX_DB):
        print(f"✅ Found Plex DB at default path: {DEFAULT_PLEX_DB}")
        return DEFAULT_PLEX_DB
    for alt in FALLBACK_PATHS:
        if os.path.exists(alt):
            print(f"⚠️ Using fallback Plex DB: {alt}")
            return alt
    print("❌ Could not find Plex DB. Please check the path or copy it manually.")
    sys.exit(1)

def load_metadata():
    db_path = find_plex_db()
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT media_items.id, media_items.title, metadata_items.title, metadata_items.year
        FROM media_items
        JOIN metadata_items ON media_items.metadata_item_id = metadata_items.id
    """)

    metadata = {}
    for row in cursor.fetchall():
        media_id, media_title, meta_title, meta_year = row
        cleaned = clean_title(media_title)
        metadata[cleaned] = {
            'title': meta_title or media_title,
            'year': meta_year or '',
        }
    conn.close()
    return metadata

def clean_title(title):
    return re.sub(r'[^a-zA-Z0-9]+', '', title or '').lower()

def fallback_title(filename):
    base = os.path.basename(filename)
    name = os.path.splitext(base)[0]
    name = name.replace('.', ' ').replace('_', ' ').title()
    return name.strip()

def rename_files(base_path):
    metadata = load_metadata()
    base = Path(base_path).expanduser().resolve()

    for root, dirs, files in os.walk(base):
        for file in files:
            full_path = Path(root) / file
            if not file.lower().endswith((".mkv", ".mp4", ".avi", ".flac")):
                continue

            cleaned = clean_title(file)
            info = metadata.get(cleaned)

            if info:
                title = info['title']
                year = info['year']
                new_name = f"{title} ({year}){full_path.suffix}" if year else f"{title}{full_path.suffix}"
                reason = "[matched from DB]"
            else:
                title = fallback_title(file)
                new_name = f"{title} (){full_path.suffix}"
                reason = "[fallback]"

            new_path = full_path.with_name(new_name)

            if new_path != full_path:
                print(f"✅ {full_path} => {new_path} {reason}")
                try:
                    os.rename(full_path, new_path)
                except Exception as e:
                    print(f"❌ Failed to rename {full_path}: {e}")
            else:
                print(f"ℹ️ Skipped unchanged: {full_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ./new9-docker-plex-renamer.py /path/to/media")
        sys.exit(1)
    rename_files(sys.argv[1])

