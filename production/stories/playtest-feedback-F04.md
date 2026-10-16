# Playtest feedback F04 — implementation and verification checklist

Source: `design/playtest-feedback-04.md` (F04-01..F04-22, 16 Oct 2026).

Quality bar from the user: fancy and production ready, with maximum design quality on every element touched and no shortcuts.

## Work packages (parallel worktrees; the lead reviews every screenshot and merges)

| Pkg | Owner (agent / model) | Items | Files owned |
| --- | --- | --- | --- |
| A | ui-programmer / sonnet | 15, 17, 18, 19, 20, 21 | `deck_builder.gd` |
| B | ui-programmer / sonnet | 08, 09, 10, 11, 12, 14 | `src/tutorial/*`, `main_menu.gd` |
| C | technical-artist / sonnet | 01, 04, 07 | `src/ui/fx/*`, `coin_flip.gd`, `sfx.gd` |
| D | technical-artist / sonnet | 05, 06, 16 | `card_widget.gd`, `src/ui/card/*`, `card_inspector.gd` |
| E | ui-programmer / sonnet | 02, 03, 13 | `game_series_overlay.gd`, `game_reward_panels.gd`, `game_prompt_banner.gd` |
| F | gameplay-programmer / opus | 22 | `src/core/*`, rules tests |

## Items

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F04-01 Coin flip readable | Verified | C | Field dimmed (0.5) with a dark radial pool, warm glow and layered shadow under the coin; result on a gold-bordered plate with outlined text; landing bounce, shockwave, impact sound | `fx/f04-01_*` (coin result plate at 1600 and 4K) |
| F04-02 Pre-game deck select | Verified | E | `deck_select_view.gd`: Structured / Custom tabs with counts, uniform `DeckTile`s (crest, Types, Main/Extra plates, composition bar, signature strips, full-list toggle), smooth-wheel `ScrollArea` with fades, designed waiting plate | F04 series driver 9/9 (wheel scroll, stays on screen); `series/series_0*` |
| F04-03 Rewards modal | Verified | E | 740 px wide (was 1040); gem pips for picks, illustrated choice tiles, real cards with Take and an inspect hint, designed panels for add / remove / basic | `series/rewards_*`; every flow sends the same commands |
| F04-04 Full-screen victory/defeat | Verified | C | `FxGameEnd` covers the whole screen (`UiLayers.GAME_END`), title band with gold rules, soft additive rays | `fx_f04_test.gd` (veil = viewport); `fx/f04-04_*`; ENet run from the client screen 8/8 |
| F04-05 Sharp card names | Verified | D + lead | Cause: the hover lift tweened `scale`, stretching rasterised glyphs. The lift is now a real size change (`lift_k` / `lift_offset`), draft and reward hovers too. Lead fixed a regression: a card hovered mid-move snapped back to its hover-start position (`b963895`) | `card_lift_f04_test.gd` (4; regression watched failing); `cards/lifted-name-before-vs-after-4k.png` |
| F04-06 No colour square before type text | Verified | D | Square removed from Spell / Trap / Power type lines | `cards/type-line-before-vs-after-4k.png` |
| F04-07 Direct attack and killing blow | Verified | C | `FxStrike`: wind-up, lunge at the plate, Type-coloured trail, flash, rings, sparks, shake, big damage number. Lethal: slow motion through tween speed, lock-on sigil, hit-stop, soft-ray blast, capped radial flash, embers, boom, then VICTORY / DEFEAT. Lethal effect damage: FINAL BLOW flourish. Click skips | `fx_f04_test.gd` (9); 116-242 FPS throughout the slow motion (`Engine.time_scale` stays 1); `fx/f04-07_*` |
| F04-08 Tutorial ring under modals | Verified | B | Ring and arrow sit below the inspector, pile browser, game menu, dialogs and popovers | Tutorial driver checks (`ring_under_*`) |
| F04-09 Play tutorial for new players | Verified | B | `PlayerProgress` flag; a fresh profile shows Play tutorial at the top; dev runs use an isolated folder | Tutorial driver check; menu screenshot |
| F04-10 Tutorial arrow direction | Verified | B | Direction chosen once from the arrow's full bob extent | Tutorial driver check (stable arrow) |
| F04-11 Tutorial pane buttons at bottom | Verified | B + lead | Footer band at the bottom of the guidance card; lead moved the bands inside the frame border | Tutorial driver check; `tutorial/tutorial_complete_rounded.png` |
| F04-12 Formatted tutorial text | Verified | B | `TutorialMarkup` tags (keywords, card names, buttons in quotes, line breaks) across every lesson; Arcane says "exactly" | Lesson screenshots |
| F04-13 Input panel fits and has depth | Verified | E | `PromptPlate`: header strip with actor tag, gradient body with weave, gold accent bar, corner flourishes; `fit(w)` re-measures until stable | F04 series driver: height = content for 5 prompt kinds; real zone prompt in the tutorial run |
| F04-14 Lesson complete modal | Verified | B + lead | Header band (lesson n of 5, flourish, progress), summary, "what you learned" list; Next above Replay / Exit. Lead fixed the square corners the user reported (`bea8666`) | `tutorial/lesson_complete_rounded.png`, `corner_crops.png` |
| F04-15 Deck builder preview formatting | Verified | A | Preview uses `CardDetailsPanel`; "In your deck" chip under the details | Flow driver; `deckbuilder/` |
| F04-16 No inspector close hint | Verified | D | Hint removed; Close button with a gold rule | `card_lift_f04_test.gd` |
| F04-17 Saved-deck list | Verified | A | Saved / Starter switch over styled deck tiles (counts, Type icons, loaded state, edit / delete / copy); the list fits its content up to 190 px | Flow driver; `deckbuilder/05_saved`, `03c_name_error` |
| F04-18 Deck contents as card grid | Verified | A | Mini-card grid, xN badges, -/+ strip, Main and Extra sections with totals, right-click inspects | `deck_builder_grid_test.gd`; flow driver |
| F04-19 Catalogue cells without caption box | Verified | A | Cards stand alone; in-deck glow, xN badge and - badge | Flow driver; `deckbuilder/` |
| F04-20 Save error near name field | Verified | A | Inline red error under the name field, red border, shake | `deck_builder_grid_test.gd`; `deckbuilder/03c_name_error` |
| F04-21 Remove limits note | Verified | A | Removed | `deckbuilder/` |
| F04-22 Fusion materials before costs | Verified | F | Every Fusion method: Fusion unit, each material on the board, zone, stance, Confirm; cancellable until Confirm; then cost / self-destruction, recheck, tribute, summon. Sepukku stays on the Field until Confirm | `rules_f04_22_fusion_test.gd` (7, watched failing); f02 driver Fusion walk-through; `2026-10-16-f04-22/` |

## Deviations for user review

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |
| F04-07 | Camera shake | The whole screen node jolts (slightly scaled so edges never show) | There is no separate board container |
| F04-02 | Deck tiles | Placeholder art strips (gradient, glyph, name); one-click "Choose deck" kept | No card art exists yet |
| F04-18 | Deck grid | Count badge bottom-centre (the Type icon is top-right); - badge always visible when in the deck; extra -/+ strip | Reachable without hover |
| F04-20 | Save error | All name-related errors (save, rename, delete) inline by the name field | Consistent placement |
| F04-22 | Choice order | Zone and stance chosen before Confirm; Fusion unit still picked from the Extra Deck tray; a material lost after Confirm fails the summon with the cost paid; Tag Team - S keeps its Yes/No | Put to the user as open questions |

## Agent ledger

| Task | Role | Model | Result |
| --- | --- | --- | --- |
| A deck builder | ui-programmer | sonnet | Done; merged `7ea8e2b` after two lead layout fixes |
| B tutorial | ui-programmer | sonnet | Main work merged `836939c`; stopped by the lead after stuck driver runs; lead fixed the lift regression, the driver watchdog and the corners |
| C FX | technical-artist | sonnet | Done; merged `089d071` after lead review (rays, flash, coin) |
| D card face | technical-artist | sonnet | Done; merged `63847d1` |
| E series / prompt | ui-programmer | sonnet | Done; merged `2175599` |
| F Fusion flow | gameplay-programmer | opus | Done; merged `736d22d` |
