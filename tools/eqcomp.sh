#!/usr/bin/env bash
# eqcomp.sh — apply MEqualizer + MCompressor presets, fade, and encode to mp3.
#
# Usage:  ./eqcomp.sh input.wav
# Output: input-eqcomp.mp3  (next to the input file)
# 
# OR:
# 
#
# FOLDER='/Users/robin/Library/CloudStorage/Dropbox/huyghe idiom beyeler/_shared/song'           
# for f in "$FOLDER"/*.wav; do
#   [ -e "$f" ] || { echo "No .wav files in $FOLDER"; break; }
#   echo "=== $f ==="     
#   "$EQCOMP" "$f"                       
# done   
# The final mp3 filename (without extension) is written into the ID3 title
# tag so the original name survives a later rename.

set -euo pipefail

# ---- configuration ---------------------------------------------------------
VSTAPPLY="${VSTAPPLY:-python vstapply.py}"   # override if vstapply.py lives elsewhere
EQ_PLUGIN="/Library/Audio/Plug-Ins/VST3/MeldaProduction/EQ/MEqualizer.vst3"
EQ_PRESET="/Users/robin/Documents/GitHub/idiom-voice/puredata/smallspeaker.vstpreset"
CO_PLUGIN="/Library/Audio/Plug-Ins/VST3/MeldaProduction/Dynamics/MCompressor.vst3"
CO_PRESET="/Users/robin/Documents/GitHub/idiom-voice/puredata/comp-softout.vstpreset"
FADE=0.05            # seconds, applied to both in and out
SAMPLERATE=44100     # output mp3 sample rate (Hz)
VBR_QUALITY=4        # libmp3lame VBR: -q:a 4 ≈ 160 kbps average
ARTIST="Robin Meier Wiratunga 2025"  # for ID3 tag; override if you want something else
# ---------------------------------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 input.wav" >&2
  exit 1
fi

input="$1"
[[ -f "$input" ]] || { echo "No such file: $input" >&2; exit 1; }

dir=$(dirname "$input")
fname=$(basename "$input")
stem="${fname%.*}"
out_base="${stem}-eqcomp"
final="${dir}/${out_base}.mp3"

# scratch dir, cleaned up on exit (even on error)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

eq_wav="$tmp/eq.wav"
co_wav="$tmp/comp.wav"

echo ">> EQ  (MEqualizer / smallspeaker)"
$VSTAPPLY "$input"  "$eq_wav" -p "$EQ_PLUGIN" --preset "$EQ_PRESET"

echo ">> Comp (MCompressor / comp-softout)"
$VSTAPPLY "$eq_wav" "$co_wav" -p "$CO_PLUGIN" --preset "$CO_PRESET"

echo ">> Fade ${FADE}s in/out + encode to ${SAMPLERATE}Hz VBR mp3"
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$co_wav")
fo_start=$(awk "BEGIN{print $dur - $FADE}")

ffmpeg -hide_banner -loglevel error -y -i "$co_wav" \
  -af "afade=t=in:st=0:d=${FADE},afade=t=out:st=${fo_start}:d=${FADE}" \
  -ar "$SAMPLERATE" \
  -codec:a libmp3lame -q:a "$VBR_QUALITY" \
  -metadata title="$out_base" \
  -metadata artist="$ARTIST" \
  "$final"

echo ">> Done: $final"