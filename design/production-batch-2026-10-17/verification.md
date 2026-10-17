# Production batch 2026-10-17: verification log

## Commands

Run everything from `rldb/`. `<godot>` is `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`.

- **Full suite:** `<godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`
- **f02 live driver:** `timeout 600 <godot> --path . -- --f02-shots=<dir> --no-steam`
- **Series driver:** `timeout 300 <godot> --path . -- --f04-series-shots=<dir> --no-steam`
- **Tutorial driver:** `timeout 420 <godot> --path . -s res://src/tutorial/tutorial_driver.gd -- --tutorial-shots=<dir> --size=1600x900`
- **Networked series:** `timeout 150 <godot> --path . -s res://src/dev/f03_net_series_driver.gd -- <dir> [--client-loses]`
- **Firestore rules, deploy:** `firebase deploy --only firestore:rules --project rldb-b5593` (from `firebase/`)

## Log

| When | What | Result |
| --- | --- | --- |
| 17 Oct | Unauthenticated REST read of Firestore before any change | 404 NOT_FOUND: the database was open (test rules) |
| 17 Oct | Interim deny-all rules deployed; the same request repeated | 403 PERMISSION_DENIED |
| 17 Oct | A7 bot branch: full suite | 621/621 (agent run) |
| 17 Oct | Integrated suite after A1, A2, A4, A5, A6 and A7 | 825/825; one SCRIPT ERROR (toast timer on a freed label) fixed |
| 17 Oct | R3 security review: emulator rules/admin | 18/18; live re-check 403 unauth + owner probe accepted |
| 17 Oct | FINAL integrated suite (everything merged) | **904/904**, 0 script errors |
| 17 Oct | FINAL f02 / net (win, lose) / bot | 75/75 / 8/8, 8/8 / 4/4 |
| 17 Oct | FINAL tutorial / series / deckbuilder / catalogue | 207/207 (after the Arcane-lesson update for F08) / 45/45 / 0 fail / 0 fail |
| 17 Oct | Killing-blow FPS on a quiet machine, 4x MSAA | direct ≥ ~150 fps (1600x900 and 4K); unit lethal minimum 82 fps |
| 17 Oct | Exported exe launch (`--no-steam --telemetry-off`) | no script errors |
| 17 Oct | `python tools/import_cards.py` rerun | cards.json byte-identical (deterministic, dated CSV 8ac4a39a…) |
