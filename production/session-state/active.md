# Session checkpoint — RLDB build

Read this first after compaction/crash.

- Spec: `rules/` 00–09; latest instruction `rules/09-PRODUCTION-QUALITY-PASS.md`.
- Authority for rules: `design/decision-register-answers.md` (user answers) + C-03/C-04 in `design/decision-register.md`.
- Playtest items: `design/playtest-improvements.md` (I-01..I-03 implemented, evidence recorded).
- Godot root `rldb/`; exe `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`.
- Branch `build/rldb-game` (never pushed). Latest: 4667bda.
- Settings (project.yaml): rigor full, review full, team studio, qa full, multiplayer true, testing.strict all true.
- Tests: 309 GdUnit4, all passing (`-a res://tests`, no `-d`). Perf probe: `tests/perf/perf_run.gd` (windowed).
- Evidence: `production/qa/evidence/2026-10-15-ui-v3/` (current), `2026-10-15-export-v3/` (exported build).
- Ledgers: `production/agent-ledger.md` (task/role/model), `production/stories/production-quality-pass.md`, `docs/requirements-checklist.md`.

## Open
- Steam real-environment verification (PQ-11) — needs Steam client running + second account.
- Fatigue default (2 HP/missed draw) awaiting user confirmation of the number.
- Card art from user; optional asset list in `design/art/art-bible.md`.
