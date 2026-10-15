# Session checkpoint — RLDB build

Read this first after compaction/crash.

- Spec: `rules/` 00–09; latest instruction `rules/09-PRODUCTION-QUALITY-PASS.md`.
- Authority for rules: `design/decision-register-answers.md` (user answers) + C-03/C-04 in `design/decision-register.md`.
- Playtest items: `design/playtest-improvements.md` (I-01..I-03 implemented, evidence recorded).
- Godot root `rldb/`; exe `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`.
- Branch `build/rldb-game` (never pushed). Latest: see `git log` (F02 pass after ace0329).
- Settings (project.yaml): rigor full, review full, team studio, qa full, multiplayer true, testing.strict all true.
- Latest work: `design/playtest-feedback-02.md` implemented; checklist `production/stories/playtest-feedback-02.md`; live driver `-- --f02-shots=<dir>`.
- Tests: 392 GdUnit4, all passing (`-a res://tests`, no `-d`). Perf probe: `tests/perf/perf_run.gd` (windowed).
- Evidence: `production/qa/evidence/2026-10-15-ui-v3/` (current), `2026-10-15-export-v3/` (exported build).
- Ledgers: `production/agent-ledger.md` (task/role/model), `production/stories/production-quality-pass.md`, `docs/requirements-checklist.md`.

## Open
- Steam real-environment verification (PQ-11) — needs Steam client running + second account.
- Fatigue default (2 HP/missed draw) awaiting user confirmation of the number.
- F02-13 sound balance awaiting the user's listening test; Plan B zero-target design check.
- Card art from user; optional asset list in `design/art/art-bible.md`.

## 2026-10-16 — Playtest feedback 03 (committed)
All 17 points plus card-kind colours (Trap red, Power light blue, Unit brown, Fusion dark blue, Ritual
purple, Spell green, Arcane grey; one shared back; log names tinted). Checklist:
`production/stories/playtest-feedback-03.md`. Suite 398/398, live driver 66/66 (editor + exported exe).
Open: user's Trap-missing-from-log case (not reproduced); frame-time check, sound balance, two-account
Steam test pending from the user.
