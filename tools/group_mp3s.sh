#!/bin/bash
# group_mp3s.sh — distribute MP3 files into subfolders of 3
# Usage: ./group_mp3s.sh <folder> <start_number>
# Example: ./group_mp3s.sh /path/to/sktrt-words 44

FOLDER="${1:-.}"
START="${2:-1}"

if [ ! -d "$FOLDER" ]; then
  echo "Error: '$FOLDER' is not a directory." >&2
  exit 1
fi

# Build sorted list of mp3 filenames into a temp file (bash 3.2 compatible)
tmpfile=$(mktemp)
ls "$FOLDER"/*.mp3 2>/dev/null | sort | xargs -I{} basename {} > "$tmpfile"

total=$(wc -l < "$tmpfile" | tr -d ' ')

if [ "$total" -eq 0 ]; then
  echo "No MP3 files found in '$FOLDER'." >&2
  rm "$tmpfile"
  exit 1
fi

echo "Found $total MP3 files. Starting at word-$START."

folder_num=$START
i=0

while IFS= read -r file; do
  files[$i]="$file"
  i=$((i + 1))
done < "$tmpfile"
rm "$tmpfile"

i=0
while [ $i -lt $total ]; do
  dest="$FOLDER/word-$folder_num"
  mkdir -p "$dest"
  for j in 0 1 2; do
    idx=$((i + j))
    if [ $idx -lt $total ]; then
      mv "$FOLDER/${files[$idx]}" "$dest/"
    fi
  done
  count=$(ls "$dest" | wc -l | tr -d ' ')
  echo "  word-$folder_num  ($count files)"
  i=$((i + 3))
  folder_num=$((folder_num + 1))
done

echo "Done. Created $((folder_num - START)) folders."