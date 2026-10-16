# Playtest feedback F05: implementation and verification checklist

Source: `design/playtest-feedback-05.md` (17 Oct 2026).

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F05-01 Ritual and Arcane lessons | Verified | gameplay-programmer / opus + lead | Lesson 6 Ritual (Runes via Sacred Offerings, tribute the Zealot for The Creeping Null, material to Spent) and Lesson 7 Arcane (exact total 3, zero-cost Drake not offered, over-pay refused with a hint, materials exhausted); Fusion lesson points to them. Lead: guidance card pushes Card Details down instead of covering it, card names in bold body text, arrow from below for tray cards, Arcane card text says "total exactly" | `tutorial_host_test.gd` (+5); tutorial driver 211/211 on the merged build; `2026-10-17-f05/tutorial/` |
| F05-02 Tutorial under Play | Verified | lead | `MainMenu.MENU`: Tutorial is the first item of Play and is gone from Play → Local | Driver check "Tutorial is listed directly under Play" (211/211 run) |
| F05-03 Card hover scaling without reflow | Verified | technical-artist / opus | Cause: the F04-05 lift resized the card, so every frame re-laid the text out. Now the face is laid out at rest and drawn under a lift transform, with text oversampled for its on-screen scale (crisp); unrounded size for smooth motion; scale-animated FX also redraw sharp | `card_lift_reflow_f05_test.gd` (7, watched failing); frame sequences and 4K crops in `2026-10-17-f05/cards/`; hover FPS 959 → 764 (worst frame 9.6 ms) |
| F05-04 30 FPS in the background | Verified | lead | `main.gd`: application focus-out caps `Engine.max_fps` at 30 and focus-in restores the previous cap. Timers and the network keep running | `background_fps_f05_test.gd` |
| F05-05 No-legal-target wording | Verified | lead | "<effect>: no legal target." without "so this part does nothing" (toast and log share the string) | `rules_f02_test.gd` (contains "no legal target") passes; f02 driver toast check |

## Deviations for user review

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |
| F05-01 | One forced Arcane answer | Either Basic Mage + Frost Wyvern or Basic Mage + Hydra is accepted | A single exact answer plus an over-pay option needs a 4-cost card; two answers also teach that several combinations can be legal |
| F05-01 | (not asked) | The Arcane picker's running total now uses current (modified) costs everywhere, matching the rules engine | It used printed costs, which could disagree with Confirm |
| F05-03 | Smooth, crisp scaling | Hovered cards are no longer snapped to whole pixels while they grow | Snapping caused 1 px stepping |

Final verification: GdUnit 593/593, tutorial driver 211/211, exported exe launches with no script errors.
