import sys
import os
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, APIC
from PIL import Image
from io import BytesIO

if len(sys.argv) != 2:
    print("Usage: python extract_album_art.py <song.mp3>")
    sys.exit(1)

mp3_path = sys.argv[1]
filename = os.path.splitext(os.path.basename(mp3_path))[0]
output_file = os.path.join(os.getcwd(), f"{filename}_cover.png")

try:
    audio = MP3(mp3_path, ID3=ID3)
    for tag in audio.tags.values():
        if isinstance(tag, APIC):
            img = Image.open(BytesIO(tag.data))
            img.save(output_file, "PNG")
            print(f"✅ Album cover saved to: {output_file}")
            break
    else:
        print("❌ No album art found in this MP3.")
except Exception as e:
    print(f"❌ Error: {e}")
