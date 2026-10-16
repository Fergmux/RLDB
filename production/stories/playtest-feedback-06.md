# Playtest feedback 06 — polish and juice (user feedback, 16 Oct 2026)

Work split: a technical-artist subagent owned `card_widget.gd`, `fx_player.gd`, `pile_stack.gd`
and `player_plate.gd` (card visuals and animations); everything else was done in the main
session. Evidence: `production/qa/evidence/2026-10-16-fb6/`.

| # | Request | Implementation |
| --- | --- | --- |
| 1 | Juicier, smoother target arrow; animation going the right way; anti-aliasing | `GameScreen.ArrowLayer`: curved arc, glow, tapering body, chevrons flowing toward the target, bevelled head, all anti-aliased; anti-aliased drawing throughout the cards, effects, piles and plates (2D MSAA is not available in the Compatibility renderer) |
| 2 | No faint overlay over the previewed stat number | CardWidget preview decor: fill removed, border kept (subagent) |
| 3 | No shortcut on "Resume saved series" | Count moved to the tooltip |
| 4 | Selecting a card closes the pile list | `_select` closes the pile list (and any card opened from the log) |
| 5 | Pile list header does not scroll | Hint + Close pinned above the scrolling rows |
| 6 | Hovered hand card keeps its coloured border | Inner white ring removed (subagent) |
| 7 | All card action buttons styled alike | No special first button; same gold-edged style with shadow |
| 8 | Flash when changing race/type on the rewards screen | The modal no longer snaps to full size on each re-render; it keeps its size and fits after layout |
| 9 | Confirm for removing a card | Choose a card, then "Remove <card>" |
| 10 | Rewards: three reward buttons, panel shown on demand | Add a card / Remove a card / Change a basic unit; the chosen panel opens below and closes after confirming |
| 11 | No (1)/(2) on the first-player buttons | Removed |
| 12 | Hover glow/scale clipped at modal edges | Inner margins inside scrolling panels (`_glow_room`) |
| 13 | Polymerization not castable without a Fusion target | `_spell_target_check` checks `fusion_candidates`; regression test |
| 14 | Card-action hover scaled from the corner | JuicyButton sets its pivot to the centre before every tween |
| 15 | Race left / Type right, no icon in the subtext | `_race_type_line` (subagent) |
| 16 | Dante's Cleanse could not be applied | Legality check now runs the adjacency step before checking targets; regression test (watched failing) |
| 17 | Card names in the log open the card | Names are links (`card:<id>`); click shows the card in the details panel |
| 18 | Stance changes animated; ATK/DEF upright in Defense | Engine emits `stance` fx; rotation animation and upright badges (subagent) |
| 19 | Pile count badge size constant up to 99 | PileStack (subagent) |
| 20 | Selected card: corners + glow only, corners pulse | CardWidget overlays (subagent) |
| 21 | Spells/Traps shown large in the centre when played | Engine emits `spotlight` fx (cast, set Spell, Trap); FxPlayer spotlight (subagent) |
| 22 | Unit effect visibly triggers | Engine emits `trigger` fx for triggered effects and abilities; FxPlayer pulse (subagent) |
| 23 | Turn panel at the bottom, log at the top, nicer log | Sidebar order swapped; log gets padding, line spacing, centred turn dividers |
| 24 | No "Counter" tag on runes | Removed |
| 25 | Animate HP, AP and other changing values | PlayerPlate tweens (subagent) |
| 26 | Battle-target banner shows only the target name, coloured | Green / red / purple target name; full breakdown stays in the tooltip |
