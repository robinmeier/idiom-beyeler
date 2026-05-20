#!/usr/bin/env python3
"""Apply a VST3/AU plugin (optionally with a preset) to an audio file."""
import argparse, json, sys
from pedalboard import load_plugin
from pedalboard.io import AudioFile

def main():
    p = argparse.ArgumentParser(description="Apply a VST/AU plugin to an audio file.")
    p.add_argument("input", help="Input audio file (wav/aiff/flac/mp3/ogg)")
    p.add_argument("output", help="Output wav file")
    p.add_argument("-p", "--plugin", required=True, help="Path to .vst3 or .component")
    p.add_argument("--preset", help="Path to a .vstpreset / .fxp / .aupreset file")
    p.add_argument("--params", help='JSON dict of param overrides, e.g. \'{"ratio": 15}\'')
    p.add_argument("--plugin-name", help="For multi-plugin bundles")
    p.add_argument("--list-params", action="store_true",
                   help="Print parameter names and exit")
    p.add_argument("--tail", type=float, default=0.0,
                   help="Seconds of silence to append (reverb/delay tails)")
    args = p.parse_args()

    plugin = load_plugin(args.plugin, plugin_name=args.plugin_name) \
             if args.plugin_name else load_plugin(args.plugin)

    if args.list_params:
        for k in plugin.parameters.keys():
            print(k)
        return

    if args.preset:
        try:
            plugin.load_preset(args.preset)
        except RuntimeError as e:
            sys.exit(f"Preset load failed (likely a proprietary format): {e}")

    if args.params:
        for k, v in json.loads(args.params).items():
            setattr(plugin, k, v)

    with AudioFile(args.input) as f:
        audio = f.read(f.frames)
        sr = f.samplerate

    if args.tail > 0:
        import numpy as np
        pad = np.zeros((audio.shape[0], int(args.tail * sr)), dtype=audio.dtype)
        audio = np.concatenate([audio, pad], axis=1)

    effected = plugin(audio, sr)

    with AudioFile(args.output, "w", sr, effected.shape[0]) as f:
        f.write(effected)
    print(f"Wrote {args.output} ({effected.shape[1]/sr:.2f}s @ {sr}Hz)")

if __name__ == "__main__":
    main()