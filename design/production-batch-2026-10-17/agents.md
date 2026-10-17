# Production batch 2026-10-17: agents

Each agent works in its own git worktree, `.claude/worktrees/agent-<id>`, on the branch `worktree-agent-<id>`. The lead reviews and merges into `build/rldb-game`.

To resume an agent, send it a message by id. To check one without opening its transcript: `git log build/rldb-game..worktree-agent-<id>` and `git -C .claude/worktrees/agent-<id> status`.

## Wave A

| Pkg | Scope | Owner (role / model) | Files owned | Depends on | Status |
| --- | --- | --- | --- | --- | --- |
| A1 (`aefa1abc63ad47a97`) | Card migration: importer audit, new CSV source, 101 changed cards, per-card ledger, F07 (stance is the final summon step), F09 Sanctified Blade investigation | gameplay-programmer / opus | `tools/import_cards.py`, `rldb/data/cards.json`, `rldb/src/core/*`, rules tests | none | starting |
| A2 (`a302452d8c724d078`) | F26 per-card behaviour test framework: manifest, runner, fixtures, tests for the 82 unchanged cards first, then the changed cards once A1 lands | qa-tester / opus | `rldb/tests/cards/**`, `tools/card_test_manifest*` | A1 for the changed cards | starting |
| A3 (`abc07819e076bb6dd`) | Firebase telemetry on Spark: client telemetry, outbox, auth, schema documentation, strict rules, emulator tests, admin aggregation tool, Settings toggle, privacy note | network-programmer / opus | `rldb/src/telemetry/**`, `firebase/**`, `docs/telemetry/**`, minimal hooks | engine events | starting |
| A4 (`a7111c475be729d87`) | Deck builder and catalogue: F14–F21, F23, F24, plus the deck caps (99 combined, 15 Extra) | ui-programmer / opus | `deck_builder.gd`, `card_list_screen.gd`, `deck_store.gd` validation | none | starting |
| A5 (`a06cc4ab41d42321b`) | Match and series UI: F01, F03, F04, F05, F06, F08, F10, Q8 (remove draft drag) | ui-programmer / opus | `game_series_overlay.gd`, `deck_select_view.gd`, `game_reward_panels.gd`, `game_prompt_banner.gd`, `game_details.gd`, `game_hover_controller.gd`, `basic_unit_picker.gd` | none | starting |
| A6 (`ae522dc7774407d2c`) | FX and audio: F02, F12, F13, F22, F25 | technical-artist / opus | `src/ui/fx/**`, `sfx.gd`, `tools/gen_sfx.py`, `juicy_button`, the AA settings in `ui_style.gd` | none | starting |
| A7 (`a2fb176b0092f52a5`) | Bot stance decisions: F11 | ai-programmer / sonnet | `rldb/src/ai/**`, bot tests | none | starting |

## Stalls and recoveries

- **All agents:** hit 10–20 turn limits repeatedly and were resumed each time, with nothing lost because of commit-as-you-go instructions.
- **A1, A6:** each reported the same status twice; checked by git, both were making real progress (uncommitted work), so they were told to commit WIP.
- **Tutorial driver hang (F04 era):** fixed with a watchdog and per-step limits.
- **A6:** used 7 windowed runs, against 5 allowed.
- **No orphan Godot processes found at checks.**
