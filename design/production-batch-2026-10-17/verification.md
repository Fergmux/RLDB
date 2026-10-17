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
