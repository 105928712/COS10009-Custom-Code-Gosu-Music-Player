# music_catalog_generator.py

import os
from mutagen.mp3 import MP3
from mutagen.easyid3 import EasyID3

SONGS_DIR = "sounds"
ALBUM_ART_DIR = "media"
OUTPUT_FILE = "albums.txt"

def format_duration(seconds):
    mins, secs = divmod(int(seconds), 60)
    return f"{mins}:{secs:02d}"

albums = {}

for root, dirs, files in os.walk(SONGS_DIR):
    mp3_files = [f for f in files if f.endswith(".mp3")]
    if not mp3_files:
        continue

    album_folder = os.path.relpath(root, SONGS_DIR)
    song_entries = []
    artist = "Unknown Artist"
    year = "0000"

    for i, file in enumerate(mp3_files):
        full_path = os.path.join(root, file)
        rel_path = os.path.relpath(full_path, start=SONGS_DIR)
        rel_output_path = f"sounds/{rel_path.replace(os.sep, '/')}"

        try:
            audio = MP3(full_path, ID3=EasyID3)
            title = audio.get("title", [os.path.splitext(file)[0]])[0]
            if i == 0:
                artist = audio.get("artist", ["Unknown Artist"])[0]
                year = audio.get("date", ["0000"])[0].split('-')[0]
            duration = format_duration(audio.info.length)
        except Exception as e:
            print(f"Error reading {file}: {e}")
            continue

        song_entries.append((title, rel_output_path, duration))

    albums[(artist, album_folder, year)] = song_entries


with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write(f"{len(albums)}\n")
    for (artist, album, year), songs in albums.items():
        f.write(f"{artist}\n{album.replace("_", " ")}\n{year}\n2\n")
        image_path = f"{ALBUM_ART_DIR}/{album.replace(' ', '_')}.png"
        f.write(f"{image_path}\n")
        f.write(f"{len(songs)}\n")
        for title, path, duration in songs:
            f.write(f"{title}\n{path}\n{duration}\n")
