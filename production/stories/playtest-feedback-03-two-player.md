# Playtest feedback F03 (two-player session) — implementation and verification checklist

Source: `design/playtest-feedback-03.md` (F03-01..F03-27, 16 Oct 2026). Handoff: `design/implement-playtest-feedback-03.md`.
Note: `production/stories/playtest-feedback-03.md` is an older, unrelated round; this file tracks the F03 batch.

Rules authority: `design/decision-register-answers.md`, superseded where F03 says so (F03-04 exact Arcane total,
F03-19 Overextend chooses any opposing unit).

Status key: Captured → In progress → Implemented — unverified → Verified (automated test and/or live run with
retained evidence under `production/qa/evidence/2026-10-16-f03/`).

## Work packages (wave 1 runs in parallel worktrees; the lead merges)

| Pkg | Owner (agent / model) | Items | Files owned |
| --- | --- | --- | --- |
| R | gameplay-programmer / opus | 04, 05, 08, 09, 10, 11, 18, 19 | `src/core/*`, `data/*`, `game_targeting.gd`, `arrow_layer.gd`, draft setup in `main_menu.gd`/`session_options.gd`, rules tests |
| I | ui-programmer / sonnet | 01, 02, 03, 12, 22, 23, 26 | new `src/ui/inspect/*`, `card_details_panel.gd`, `card_chips.gd`, `game_details.gd`, `game_hand_view.gd`, `game_selection.gd`, `game_hover_controller.gd` |
| V | technical-artist / sonnet | 13, 16, 17, 20, 21 | `src/ui/fx/*`, `card_widget.gd`, `src/ui/card/*`, `pile_stack.gd`, `sfx.gd` |
| B | ui-programmer / sonnet | 06, 07, 14, 25, 27 | `player_plate.gd`, `game_board_view.gd`, `game_prompt_banner.gd` |
| D | ui-programmer / sonnet (wave 2, needs I) | 24 | `deck_builder.gd` |
| T | gameplay-programmer / opus (wave 2) | 15 | new `src/tutorial/*`, Play Local entry |
| QA | qa-tester / sonnet + lead | all | regression tests, two-client and tutorial runs |

## Items

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F03-01 Right-click inspection | In progress | I | | |
| F03-02 Near-full-screen pile browser | In progress | I | | |
| F03-03 Consistent tags with contained icons | In progress | I | | |
| F03-04 Exact Arcane total | In progress | R | | |
| F03-05 Hide zero-cost Arcane materials | In progress | R | | |
| F03-06 Smaller player panels | Implemented — unverified | B | Plates 300→252 px wide, 89 px tall; `PlayerPlate.PLATE_W` | Rect check: no plate/zone overlap, ~24 px gap at 1600x900; long name / 120 HP / 9 AP fit (`board/plates_*`) |
| F03-07 Power-slot mirroring | Implemented — unverified | B | Reproduced: opponent block was not mirrored. `GameBoardView.power_cell(side, slot)` rotates the display 180°; slot ids unchanged | `power_mapping_test.gd` (4 slots x 2 views); `board/power_before*`, `power_after*` |
| F03-08 Fusion availability highlight | In progress | R | | |
| F03-09 Basic-unit names without Type suffix | In progress | R | | |
| F03-10 Draft composition controls | In progress | R | | |
| F03-11 One Extra Deck category (draft, rewards) | In progress | R | | |
| F03-12 No empty-Hand text | In progress | I | | |
| F03-13 Victory / defeat presentation | In progress | V | | |
| F03-14 HP display reset between games | Implemented — unverified | B | Cause: reset only ran on `GameScreen.attach()`, which a series keeps across games. `PlayerPlate.begin_game(save_id:game_no)` resets each new game | `hp_reset_test.gd`; live two-game series still to run |
| F03-15 Guided tutorial | Captured | T | | |
| F03-16 Destroy / Exhaust animations | In progress | V | | |
| F03-17 Special-summon sequences | In progress | V | | |
| F03-18 Effect arrow from its source | In progress | R | | |
| F03-19 Overextend chooses its target | In progress | R | | |
| F03-20 Smaller ATK/DEF badges | In progress | V | | |
| F03-21 Animated action glow and bouncing cue | In progress | V | | |
| F03-22 No base stats in Modifiers | In progress | I | | |
| F03-23 Protecting tag | In progress | I | | |
| F03-24 Deck builder grid with art | Captured | D | | |
| F03-25 Prominent input-required banner | Implemented — unverified | B | Tall narrow banner in the free left column (top-centre fallback), actor tag, pop-in glow, breathing border | Rect test: clear of zones/piles/plates; `board/banner_*` |
| F03-26 Empty-space click closes passive viewer | In progress | I | | |
| F03-27 Type-coloured declaration buttons | Implemented — unverified | B | Type choices (kind `mode`, all labels Type names) get Type colour, icon, contrast-checked text | `ui_f03_prompt_test.gd` (Waang 4 Types, Chaos Witch 7, click sets Earth, contrast) |

## Deviations for user review

Where an implementation departs from a suggestion in the feedback (not a confirmed rule), it is kept and listed here for the user to review.

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |
| F03-25 | Banner slightly lower, narrower and taller (top of screen) | Tall narrow banner in the free left column below the opponent's hand; top centre only when that column is narrower than 220 px | At 900 px height a top banner cannot clear the Trap/Spell row; the side column covers no zones |

## Agent ledger

| Task | Role | Model | Result |
| --- | --- | --- | --- |
| Lobby browser fix (user report) | lead | opus | Fixed, `b43562f` |
| Package B (06, 07, 14, 25, 27) | ui-programmer | sonnet | Done, 455/455 on branch, merged `8524b8b` |
