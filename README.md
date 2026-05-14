# Running the script
`uv run clone_voice.py source.wav target_voice.wav`

# Options
```
--diffusion-steps N     10=fast, 30=default, 50=best quality
--temperature F         AR randomness 0.7–1.5 (higher = more varied)
--similarity F          Voice closeness to target 0.0–1.0 [0.7]
--intelligibility F     Speech clarity 0.0–1.0 [0.7]
--length-adjust F       Output speed (<1.0 faster, >1.0 slower)
--no-style              Timbre-only mode, skips accent/emotion transfer
--output DIR            Output folder [./output]
-o                      same as --output
--repetition-penalty
```
