# idiom-beyeler

Zero-shot, audio-to-audio voice conversion built on
[Seed-VC v2](https://github.com/Plachtaa/seed-vc), plus a few helper scripts
for batch generation and post-processing.

`clone_voice.py` takes a **source** recording (the content: words, gestures,
noises, synth stabs…) and re-renders it with the timbre and style of a
**target** voice. No training is needed: you only need the two audio files.

## Repository layout

| Path                   | What it is                                                        |
| ---------------------- | ----------------------------------------------------------------- |
| `clone_voice.py`       | Main voice-conversion script (self-bootstrapping)                  |
| `source.wav`           | Example source audio                                              |
| `target_voice.wav`     | Example target voice                                              |
| `tools/eqcomp.sh`      | EQ + compression + fade, then encode to MP3                       |
| `tools/vstapply.py`    | Apply any VST3/AU plugin (and optional preset) to an audio file   |
| `tools/group_mp3s.sh`  | Sort MP3s into numbered folders of three (`word-N/`)              |
| `tools/snippets.txt`   | Batch-generation loops used to build the sound palettes           |
| `tools/shortening.txt` | Archive of the files removed in the first duration pass           |
| `tools/shortening2.txt`| Archive of the files and word folders removed in later passes     |

## Workflow

These are the steps that turned a small set of hand-made sounds into the
vocabulary of "words" played by the speakers built into the idiom masks.

### 1. Generate a raw vocabulary

`clone_voice.py` is run on hand-crafted **seeds**: short source sounds made
for the project (families named `sktrt`, `sktrt-intrr`, `scrubo`, `fm-stab`,
`opfm`, `asia`, `stutter`…), all cloned onto the same target voice.

Each seed is cloned many times with different settings. The loops vary:

- temperature and top-p, often well beyond the usual speech range
- repetition penalty and length adjust (stretching the output to 1.7–2.0×)
- input level (peak-normalised, then lowered by 0, −6, −9 or −12 dB)
- direction (each seed played forwards and reversed)
- repeat number: the same settings are run several times, since results
  vary from run to run

Because each combination gives a different sound, a limited number of seeds
yields a large and varied pool. The parameters are written into each output
filename, so every sound can be traced back to its seed and settings. For
example, `sktrt-14-rev-t3.5-p0.5-rp0.9-5-norm-6-la2.0.wav` is seed `sktrt-14`,
reversed, temperature 3.5, top-p 0.5, repetition penalty 0.9, run 5,
normalised then −6 dB, length adjust 2.0.

Every generation command used is kept in
[`tools/snippets.txt`](tools/snippets.txt).

### 2. Master for the mask speakers

The resulting sounds go through [`tools/eqcomp.sh`](#toolseqcompsh). It
shapes them for playback on the small speakers embedded in the masks with an
EQ preset for small speakers and a soft compressor, adds short fades to avoid
clicks, and encodes them to MP3. The result is named `<name>-eqcomp.mp3`.

### 3. Group into words

[`tools/group_mp3s.sh`](#toolsgroup_mp3ssh) moves the mastered MP3s into
numbered `word-N/` folders of three files each. The Raspberry Pis in the masks
use this folder structure. The start number lets a new batch continue the
numbering after an existing one instead of overwriting it.

### 4. Trim words that are too long

Some generated sounds turned out too long. To fix this:

1. The file durations were analysed statistically, and the longest files
   were deleted. This was done twice.
2. Some words were still too long after that, so their whole `word-N/` folder
   was removed.

The deleted files and folders are archived as the shell commands that removed
them, so the vocabulary can be reconstructed or audited later:

- [`tools/shortening.txt`](tools/shortening.txt): the first duration pass,
  62 files.
- [`tools/shortening2.txt`](tools/shortening2.txt): the second duration pass,
  95 distinct files (some appear more than once), followed by the 45 `word-N/`
  folders removed entirely.

## Requirements

- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- `git`
- Python 3.10 (uv fetches it if it is missing)
- macOS on Apple Silicon (MPS), or Linux with an NVIDIA GPU (CUDA 12.1).
  The script falls back to CPU, which is much slower.

## Quick start

```bash
uv run clone_voice.py source.wav target_voice.wav
```

The result is written to `./output/<source>-converted-<timestamp>.wav`.

### First run

On the first run the script sets itself up. It:

1. Clones Seed-VC into `./seed-vc/`.
2. Patches two known API mismatches in the Seed-VC source. The patch is
   idempotent and runs again on every start.
3. Creates an isolated virtual environment in `./.venv-vc/` (Python 3.10).
4. Installs PyTorch (the nightly CPU/MPS build on macOS, CUDA 12.1 elsewhere)
   and the other dependencies.
5. Downloads the model weights from Hugging Face (about 500 MB) into
   `./seed-vc/checkpoints/hf_cache/`.

After that, a run starts in a few seconds. All caches stay inside the project
folder, so nothing is scattered across `~/`.

To force the dependencies to reinstall, delete `./.venv-vc/`, or bump
`DEPS_VERSION` in `clone_voice.py`.

## Usage

```
uv run clone_voice.py SOURCE TARGET [options]
```

- **SOURCE**: the audio whose content you want to keep.
- **TARGET**: a clean, single-speaker sample of the voice to imitate.
  10–20 s works best. Anything over 25 s is silently truncated.

### Options

| Option                       | Default | Description                                                                      |
| ---------------------------- | ------- | -------------------------------------------------------------------------------- |
| `-o`, `--output PATH`        | `./output/` | A `.wav` path is used as the exact filename. Anything else is treated as a directory, and the file gets an auto-generated name. |
| `--diffusion-steps N`        | `30`    | Quality versus speed: 10 = fast, 30 = default, 50 = best.                         |
| `--temperature F`            | `0.7`   | Randomness of the autoregressive (AR) model. Lower stays closer to the source.    |
| `--top-p F`                  | `0.7`   | AR nucleus sampling. Lower is more deterministic.                                 |
| `--similarity F`             | `0.7`   | How close the result sounds to the target voice (0.0–1.0).                        |
| `--intelligibility F`        | `0.9`   | Speech clarity (0.0–1.0). Raise it if words sound garbled.                        |
| `--repetition-penalty F`     | `1.5`   | Penalty on repeated AR tokens.                                                    |
| `--length-adjust F`          | `1.0`   | Output duration: below 1.0 is faster, above 1.0 is slower.                        |
| `--no-style`                 | off     | Timbre only. Skips the AR pass, which keeps the source's exact timing and phrasing but does not transfer accent or emotion. |

`--temperature`, `--top-p` and `--repetition-penalty` only matter in the
default (style-transfer) mode. They have no effect with `--no-style`.

Run `uv run clone_voice.py --help` for the full help text and tuning guide.

### Examples

```bash
# Save to a specific file
uv run clone_voice.py speech.wav voice.wav -o result.wav
```

```bash
# Save into a folder, with an auto-generated filename
uv run clone_voice.py speech.wav voice.wav -o ~/Desktop/
```

```bash
# Stay closer to the source content
uv run clone_voice.py speech.wav voice.wav --temperature 0.5 --intelligibility 1.0
```

```bash
# Timbre only, with exact source timing
uv run clone_voice.py speech.wav voice.wav --no-style --similarity 0.85
```

```bash
# Highest quality
uv run clone_voice.py speech.wav voice.wav --diffusion-steps 50
```

### Tuning tips

- **Words garbled or timing drifts:** lower `--temperature` (0.5–0.7), raise
  `--intelligibility` (0.9–1.0), and try `--top-p 0.7`. For exact timing, use
  `--no-style`.
- **Not enough like the target:** raise `--similarity` (0.85–1.0) and use a
  cleaner, longer target sample (within the 25 s limit).
- **Too fast or too slow:** change `--length-adjust` (for example 0.9 or 1.1).
- **Deliberately unstable or abstract results:** for non-speech sources (synth
  stabs, drones, scrubbed material), `tools/snippets.txt` pushes `--temperature`
  well beyond the usual range (1.5–8.5) and uses `--length-adjust` 1.7–2.0.

## Tools

### `tools/snippets.txt`

A collection of shell loops, not a script to run as a whole. Each loop goes
over a set of seed files and a grid of parameters (temperature, top-p,
repetition penalty, length adjust, normalisation gain, forward or reversed
input). It calls `clone_voice.py` for each combination and puts the
parameters in the output filename, for example
`sktrt-14-rev-t3.5-p0.5-rp0.9-5-norm-6.wav`.

Copy the block you need and adjust `STABS` (the seed folder), `TARGET` and
`OUT`. The loops that normalise or reverse their input need
[SoX](https://sourceforge.net/projects/sox/), and one variant uses `ffmpeg`.

### `tools/vstapply.py`

Applies a VST3 or AU plugin to an audio file using
[pedalboard](https://github.com/spotify/pedalboard).

```bash
python tools/vstapply.py in.wav out.wav -p /path/Plugin.vst3 --preset my.vstpreset
```

```bash
python tools/vstapply.py in.wav out.wav -p /path/Plugin.vst3 --params '{"ratio": 15}'
```

```bash
python tools/vstapply.py in.wav out.wav -p /path/Plugin.vst3 --list-params
```

Other options: `--plugin-name` selects one plugin inside a multi-plugin
bundle, and `--tail SECONDS` appends silence so reverb and delay tails are not
cut off. Requires `pip install pedalboard`.

### `tools/eqcomp.sh`

A mastering chain for the generated files. It runs MEqualizer (preset
"smallspeaker"), then MCompressor (preset "comp-softout"), adds a 50 ms fade
in and out, and encodes a 44.1 kHz VBR MP3 (about 160 kbps). The MP3's ID3
title is set to the output filename and the artist to the value of `ARTIST`.

```bash
./tools/eqcomp.sh input.wav    # writes input-eqcomp.mp3 next to the input
```

It needs `ffmpeg`, `ffprobe`, the MeldaProduction plugins and `vstapply.py`.
The plugin and preset paths at the top of the script are hard-coded to the
author's machine, so edit them before use. If `vstapply.py` is not in the
current directory, set `VSTAPPLY`:

```bash
VSTAPPLY="python /path/to/tools/vstapply.py" ./tools/eqcomp.sh input.wav
```

The header of the script shows a loop for processing a whole folder.

### `tools/group_mp3s.sh`

Moves the MP3s in a folder, in sorted order, into subfolders of three named
`word-N`, numbered from a start value:

```bash
./tools/group_mp3s.sh /path/to/sktrt-words 44
```

## Credits

Voice conversion by [Seed-VC](https://github.com/Plachtaa/seed-vc) (Plachtaa).
See that repository for the model licence and terms of use.
