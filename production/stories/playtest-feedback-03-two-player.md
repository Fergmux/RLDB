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
| F03-01 Right-click inspection | Implemented — unverified | I + lead | `CardInspector` (big 2:3 card + details panel), `GameInspect`; right-click on Field/Hand/pile rows/browser/deck builder; lead added draft, reward, deck-choice and choice-tray cards (`bab0f2e`). Hidden cards not inspectable; refreshes or closes on new views | `ui_f03_inspect_test.gd` (22); `inspect/01..03` |
| F03-02 Near-full-screen pile browser | Implemented — unverified | I | `PileBrowser`: own Draw/Spent/Exhaust/Extra, `best_layout` grid, Draw in shown-random order, card inspection returns to the same scroll | Tests in `ui_f03_inspect_test.gd`; `inspect/04..08` |
| F03-03 Consistent tags with contained icons | Implemented — unverified | I | One tag height (line height + padding); Type icon sized to the line | `card_details_f03_test.gd` (equal heights) |
| F03-04 Exact Arcane total | Implemented — unverified | R | Exact subset-sum of current costs in authority, availability and picker (`MatchView.multi_pick_error`); "cost total X / exactly N"; bot picks an exact set; old overpayment wording marked superseded in `rules/01`, `05`, `06` | `rules_f03_test.gd` `test_f03_04_*` (11) |
| F03-05 Hide zero-cost Arcane materials | Implemented — unverified | R | Current-cost-0 units not offered (also not legal in the authority; adds 0 so no outcome changes); other Spent lists unchanged | `test_f03_05_*` (3) |
| F03-06 Smaller player panels | Implemented — unverified | B | Plates 300→252 px wide, 89 px tall; `PlayerPlate.PLATE_W` | Rect check: no plate/zone overlap, ~24 px gap at 1600x900; long name / 120 HP / 9 AP fit (`board/plates_*`) |
| F03-07 Power-slot mirroring | Implemented — unverified | B | Reproduced: opponent block was not mirrored. `GameBoardView.power_cell(side, slot)` rotates the display 180°; slot ids unchanged | `power_mapping_test.gd` (4 slots x 2 views); `board/power_before*`, `power_after*` |
| F03-08 Fusion availability highlight | Implemented — unverified | R | Before: Fusion never lit the Extra Deck. `MatchEngine.fusion_methods(p)` reuses the activation checks; `extra_avail` lists methods; full Field needs a Field material | `test_f03_08_*` (11) |
| F03-09 Basic-unit names without Type suffix | Implemented — unverified | R | 35 basic names in `cards.json` and the importer; ids/Type/Race unchanged | `test_f03_09_*` (2); `draft/04_draft_overlay.png` |
| F03-10 Draft composition controls | Implemented — unverified | R + lead | Per-category -/+ steppers in series setup, validation message; lead: Start disabled while invalid (`1b678e1`); host config used online | `test_f03_10_*` (3); `draft/01..04` |
| F03-11 One Extra Deck category (draft, rewards) | Implemented — unverified | R | Draft shows "Extra Deck"; rewards offer one Extra Deck group from Fusion/Ritual/Arcane | `test_f03_11_*`; `draft/04` |
| F03-12 No empty-Hand text | Implemented — unverified | I | Label removed from `game_hand_view.gd` | `inspect/00` |
| F03-13 Victory / defeat presentation | Implemented — unverified | V + lead | `FxGameEnd`: game/series win and loss variants; result modal held until it ends (click skips, 8 s safety). Lead: hot-seat hand-over waits for it (`4ce74a0`) | `fx_f03_test.gd`; win/series-win frames; lead re-ran defeat in a bot game: DEFEAT plays, then the modal |
| F03-14 HP display reset between games | Implemented — unverified | B | Cause: reset only ran on `GameScreen.attach()`, which a series keeps across games. `PlayerPlate.begin_game(save_id:game_no)` resets each new game | `hp_reset_test.gd`; live two-game series still to run |
| F03-15 Guided tutorial | Captured | T | | |
| F03-16 Destroy / Exhaust animations | Implemented — unverified | V | Destroy: flash, cracks, ember dissolve to its pile. Exhaust: front and centre, "EXHAUSTED", violet void ring into Exhaust. Identity only for seats that may see it | `fx_f03_test.gd` (routing, redaction); `fx/destroy_*`, `fx/exhaust_*` |
| F03-17 Special-summon sequences | Implemented — unverified | V | Material ghosts fly from their sources, motes to Spent/Exhaust; Fusion swirl, Ritual light column, Arcane hexagram | `fx_f03_test.gd`; `fx/fusion_*`, `ritual_*`, `arcane_*`; two-client run pending |
| F03-18 Effect arrow from its source | Implemented — unverified | R + lead | Pending choice carries the source position; live arrow starts there; lead: both seats see a short source→target arrow when a chosen target is affected (`2108937`) | `test_f03_18_*` (2); `overextend/opponent_view_arrow*.png` |
| F03-19 Overextend chooses its target | Implemented — unverified | R | Any opposing unit; friendly rejected; -20 ATK until it leaves; no fallback | `test_f03_19_*` (4); live: 24 → 4 ATK on a non-highest unit |
| F03-20 Smaller ATK/DEF badges | Implemented — unverified | V | Badges drawn at 0.86 of their rect with margin | `fx/ready_strip.png`; 3-digit / rotated checks pending |
| F03-21 Animated action glow and bouncing cue | Implemented — unverified | V | Pulsing ready glow, bouncing chevrons; Extra pile too; steady under reduced motion | `fx/ready_strip.png`; Power-card case pending |
| F03-22 No base stats in Modifiers | Implemented — unverified | I | `modifier_parts()` drops the base line; no section when unmodified | `card_details_f03_test.gd`; `inspect/02` |
| F03-23 Protecting tag | Implemented — unverified | I | `protecting` in `match_view.card_view` (reuses `protected_by`); tag beside Protected | `card_details_f03_test.gd` (rear behind / empty / diagonal); `inspect/01` |
| F03-24 Deck builder grid with art | Implemented — unverified | D | Catalogue grid of card images with Type captions, click adds, right-click inspects, in-deck border and count, Rename, replace guard, unsaved marker | `deck_builder_grid_test.gd` (4); live flow 15/15 (`deckbuilder/`) |
| F03-25 Prominent input-required banner | Implemented — unverified | B | Tall narrow banner in the free left column (top-centre fallback), actor tag, pop-in glow, breathing border | Rect test: clear of zones/piles/plates; `board/banner_*` |
| F03-26 Empty-space click closes passive viewer | Implemented — unverified | I | Click reaching the GameScreen root calls `dismiss_passive()`; never cancels a pending choice | `ui_f03_inspect_test.gd`; `inspect/09..10` |
| F03-27 Type-coloured declaration buttons | Implemented — unverified | B | Type choices (kind `mode`, all labels Type names) get Type colour, icon, contrast-checked text | `ui_f03_prompt_test.gd` (Waang 4 Types, Chaos Witch 7, click sets Earth, contrast) |

## Deviations for user review

Where an implementation departs from a suggestion in the feedback (not a confirmed rule), it is kept and listed here for the user to review.

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |
| F03-25 | Banner slightly lower, narrower and taller (top of screen) | Tall narrow banner in the free left column below the opponent's hand; top centre only when that column is narrower than 220 px | At 900 px height a top banner cannot clear the Trap/Spell row; the side column covers no zones |
| F03-02 | Opponent piles browsable where permitted | No browser for opponent piles (the view only gives their counts) | Nothing to show without revealing hidden cards |
| F03-16 | Distinct destroy / Exhaust outcomes | Burn orange for destruction, cold violet for Exhaust | No palette was given; constants in `fx_pile_effects.gd` |
| F03-16 | Who sees an exhausted card | The owner and the effect's controller see its identity | The controller picked it from a revealed pile; owner-only is a one-argument change |
| F03-17 | Materials consumed into the summon | A glowing mote carries each material to its pile, not the card itself | Avoids a card visibly passing through the summon slot |
| F03-13 | Victory / defeat then the result modal | Game end plays its own sound; the old top game-over banner is no longer used | One presentation per outcome |
| F03-24 | Responsive grid | Fixed "hand"-size cards; the hover Preview column kept; removal via "-" buttons (right-click now inspects); Rename and a replace-deck guard added | Right-click is inspection everywhere |
| F03-10 | Configurable counts | -/+ steppers (cap 40 per category, a sanity limit, not a deck rule) | Matches the button style |
| F03-05 | Hide zero-cost cards in the picker | Also not legal in the authority | They add 0 to an exact total, so no outcome changes |
| F03-08 | Fusion availability | With Hand-only materials on a full Field, the Fusion is refused before anything is paid | Follows the confirmed "check space before paying" decision |

## Agent ledger

| Task | Role | Model | Result |
| --- | --- | --- | --- |
| Lobby browser fix (user report) | lead | opus | Fixed, `b43562f` |
| Package B (06, 07, 14, 25, 27) | ui-programmer | sonnet | Done, 455/455 on branch, merged `8524b8b` |
| Package I (01, 02, 03, 12, 22, 23, 26) | ui-programmer | sonnet | Done, 475/475 on branch, merged `76e93f1` |
| Package V (13, 16, 17, 20, 21) | technical-artist | sonnet | Done, 450/450 on branch, merged `6097b19`; defeat re-checked by lead |
| Package D (24) | ui-programmer | sonnet | Done, 490/490 on branch, merged `88cab9b` |
| Package R (04, 05, 08, 09, 10, 11, 18, 19) | gameplay-programmer | opus | Done, 480/480 on branch, merged; integrated suite 532/532; live f02 driver 73/73 |
