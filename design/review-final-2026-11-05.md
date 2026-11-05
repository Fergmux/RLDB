# Final visual and UX review, L batch (5 Nov 2026)

This is an art-direction and UX pass over the whole game after the L batch was merged on
`build/rldb-game` (sounds, animation queue, sacrifice mode, cursor, status FX and badges, Evolve,
Options, tables, fonts, scoreboard, responding notice, bot, and the polish fixes in d8d252f).

## How it was captured

Every windowed driver in `rldb/src/dev/` was run at 1600x1000, and some at 1920x1080 and
3840x2160:

| Group | Drivers |
|---|---|
| Menus, Options, deck builder, tutorial | `l_menus_shots` |
| Board on each of the four tables | `l_menus_shots --steps=board --table=...` |
| Series, lobby, rewards, Extra Deck offer, game 2 | `l_series_shots` |
| Statuses: badges, FX, cards, board, clock | `l_status_shots`, `l_fx_shots` (cards, badges, status, board, clock) |
| Rules: Hypnotise, Snunday | `l_rules_shots` |
| Evolve and copied art | `evolve_shots` |
| Cursors | `cursor_gallery_shots` |
| Sacrifice mode, Cancel, arrow, responding notice | `--linteract-shots` |
| Draft, rewards, prompts, deck choice | `--f04-series-shots` |
| Older interaction run | `--f02-shots` |
| Bot game | `--bot-shots` |
| Catalogue, inspector, status tips | `card_redesign_shots` |
| Chat and lobby | `lobby_chat_shots` |
| Game end | `eog_shots` |

The 1920x1080 and 4K windows lay out at the logical sizes 1851x1000 or 1778x1000, because the
project stretches `canvas_items` from 1600x1000 with `expand`. The geometry test below therefore
checks those logical sizes.

The scratch captures are in the agent scratchpad. The retained before/after evidence is in
`production/qa/evidence/2026-11-05-l-batch/final-review/`.

## Ranked findings

Rank 1 is the worst. "Fixed" names the commit group on the review branch.

| # | Finding | Where | Status |
|---|---|---|---|
| 1 | **Sacrifice mode's hint pill was hidden under the series scoreboard.** Both sat in the middle of the top strip, so only "SAC… (+1 AP)" showed around the plaque. This is the collision the brief asked about in (d). | `linteract/02_sacrifice_engaged` | **Fixed**: the scoreboard steps aside (fades out and ignores the mouse) while the mode is on, and returns when the mode ends or resets. A geometry test covers the scoreboard, hint, responding notice and Menu/Chat at every logical size, with long names and best of 5. |
| 2 | **Status badge glyphs were faint at field-card size (16-20 px).** Light glyphs sat on light enamels: Eternal, Pierce, Cleanse and Paralyse had a glyph/enamel contrast of 1.0-1.4. The 3.8-unit outline drew under one pixel, the glyph took only 0.66 of the badge, Cleanse's "sparkles" field turned into a grain of dots, and the Curse pentagram lines vanished. (a) | `status/field_cards_after`, badge sheets | **Fixed** in the generator: glyph 0.74 of the badge (0.66-0.70 for diagonal glyphs), a 7-unit outline, a dark halo behind the glyph, and deeper light enamels that keep their hue. Cleanse now uses RLDB's own bold sparkle, and the Curse and Reveal lines are thicker. A Python test pins the rules and checks the committed SVGs. |
| 3 | **A status's floating name covered the card in the row above.** "BURN" rose from the top edge of its card and, for about a second, read as "BURN6" over the neighbour's ATK/DEF. | `fx_status/status_burn_0x` | **Fixed**: the name now rises inside its own card, under the badge stamp, and shrinks to fit the card. |
| 4 | **Popovers closed inconsistently.** The in-game menu closes with `panel_close` and a motion, on click-off or Esc (L13). The in-game Settings vanished silently. The Lobby list (opened from the menu) and the Chat box vanished with "back" and no motion. The Lobby did not close on click-off and ignored Esc. (e) | code review and tests | **Fixed**: `HousePanel.dismiss()` gives every in-game popover the same cue and motion, and the Lobby list closes on click-off and on Esc. The Chat box keeps no click-off on purpose (see Decisions). |
| 5 | **The card details pane named every status in generic buff green or debuff red**, while the badge, the tip and the FX all use the status's own colour. (b) | details pane | **Fixed**: the pane uses `CardStatusIcons.accent()`. The Buff/Debuff tag and the badge shape still give the kind without colour. |
| 6 | **The Options panel jumped between leaves.** Settings and Customisation were 788 px tall, while Credits was about 150 px shorter and re-centred, so the frame and the Close button moved. | `menus/02`, `03`, `07` | **Fixed**: all Options leaves share one minimum height, and the Credits scroll fills it. |
| 7 | **`FxCardEffects.status` was dead code** after FxStatus (L8). (c) | `fx_card_effects.gd` | **Fixed**: removed. |
| 8 | The responding notice, once docked under the opponent's plate, covers the top of the opponent's Spent/Exhaust piles. The owner chose this dock in L16, and the notice fades while hovered. | `linteract/14_responding_settled` | Left. The strip to the right of the piles is about 195 px wide, too narrow for a legible notice. Worth an owner decision. |
| 9 | The score shows three times while a series modal is up: the modal header, the sidebar "Series" medallion and the top-strip scoreboard. The top strip is raised above the dim on purpose (J15), and the L26 point pop plays there. | draft and reward shots | Left (by design). Hiding the strip under modals is an option for the owner. |
| 10 | The Evolve prompt's "now → evolves into" thumbnails in the left panel are about 40 px cards, too small to read. The details pane and inspector carry the full preview. | `evolve/l23_06` | Left. Larger tiles would push Evolve/Skip below the fold at 1280x800. A candidate for a later pass. |
| 11 | On the scoreboard, the "BEST OF n" caption and the game dots are cramped in the centre cartouche. The dots (3.4 px) nearly touch its lower rim. | top-strip crops | Left (minor). |
| 12 | Credits body text is small (13 px muted on leather), and the licence URL wraps mid-path ("creativecommons.org/ / licenses/by/3.0/"). | `menus/07_credits` | Left (minor). |
| 13 | Mini cards in the Extra Deck offer let long rules text touch the bottom rim (Raging Inferno). | `series/a07` | Left: card text fitting belongs to the card painter. |
| 14 | The deck builder catalogue grid has large row gaps and a ragged right margin at 1600x1000. | `menus/12_deck_builder` | Handed to the POLISH agent's density ladder (d8d252f, merged). Not re-reviewed here. |
| 15 | Older drivers report FAIL lines unrelated to visuals: `f02_driver` (18) and `f04_series_driver` (3) pin pre-3-Nov cards and decks, so B3/F02-12/F08 cascade. In the first run, `cursor_gallery` (8) and `linteract` (1) failed because the real mouse was over the window. Both are clean on rerun. | driver logs | Left: driver staleness, not a game bug. |

## Checked and fine

- **Main menu.** It looks good.
- **Options Settings and Customisation.** The table tiles have a hover state, a check and blurbs.
- **The four tables.** Every table keeps the board readable, and the leather table's brass corners frame it well.
- **4K.** The layout scales cleanly with no clipping.
- **Rewards and the F/R/A Extra Deck offer.**
- **Lobby panel.** It is now closed by click-off, Esc and its close disc.
- **Evolve.** The inspector "Evolves into" chain reads well.
- **Hypnotise zone pick.**
- **Prompt Cancel button.**
- **The arrow hides on a pick.**
- **Cursor gallery.** It passes on rerun.
- **Chat and the spectator views.**
- **Reduced motion.** The new code uses `UIStyle.dur` and `tween_out`. The badge stamp, scoreboard yield and dismiss all fall back to instant or a short fade.
- **L30.** No keyboard hint was added anywhere.
