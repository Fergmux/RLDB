# SFX

**Provenance.** Generated with ElevenLabs Sound Effects (`eleven_text_to_sound_v2`), November 2026, for RLDB
(owner feedback L1, `design/owner-feedback-2026-11-05.md`). Each cue was generated as several takes from the
prompts in `design/audio/sfx-cues.json`. The chosen take was mastered by `tools/sfx_master.py`, which trims
it, removes DC and rumble, fades it, sets its loudness for its tier and limits it to -1 dBTP, then writes
44.1 kHz 16-bit WAV. Godot imports these files with QOA compression. The prompts, the chosen take for each cue
and the reasons are in `design/audio/sfx-design-2026-11-05.md`.

**Licence.** ElevenLabs grants commercial use of generated sound effects only on a paid plan, and the plan in
force *at generation time* is what counts. **The owner should confirm which plan the account was on on
5 Nov 2026.** On the free tier the output is for non-commercial use and needs attribution to ElevenLabs.
Credits: `rldb/data/credits.json` and `rldb/assets/CREDITS.md`.

**Swapping a take.** The alternates are kept outside the game in `production/audio-staging/<cue>/` (gitignored,
on the machine that made them; `production/audio-staging/index.md` lists them). To swap a take:

1. Set the cue's take in `design/audio/sfx-selection.json`, for example `"attack": {"take": "b3.mp3", ...}`.
2. Run `uv run --no-project --with numpy --with scipy python -I tools/sfx_master.py master attack`.
3. Run `$G --headless --path rldb --import`.

**Do not run `tools/gen_sfx.py` into this folder.** It is the retired procedural generator (F02-13 to K1), and
it now refuses to write here.

**Names.** Each file is `<name>.wav`, where `<name>` is in `Sfx.NAMES` (`src/ui/audio/sfx.gd`). A name with no
file is silent. `Sfx.asset_path` also accepts `<name>.ogg`, but the whole set ships as WAV so that every test
and tool reads it the same way.
