# Playtest feedback F05: implementation and verification checklist

Source: `design/playtest-feedback-05.md` (17 Oct 2026).

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F05-01 Ritual and Arcane lessons | In progress | gameplay-programmer / opus (worktree) | | |
| F05-02 Tutorial under Play | Implemented, unverified | lead | `MainMenu.MENU`: Tutorial is the first item of Play and is gone from Play → Local; the tutorial driver enters through Play → Tutorial | Driver check "Tutorial is listed directly under Play" (to run with F05-01) |
| F05-03 Card hover scaling without reflow | In progress | technical-artist / opus (worktree) | | |
| F05-04 30 FPS in the background | Verified | lead | `main.gd`: application focus-out caps `Engine.max_fps` at 30 and focus-in restores the previous cap. Timers and the network keep running | `background_fps_f05_test.gd` |
| F05-05 No-legal-target wording | Verified | lead | "<effect>: no legal target." without "so this part does nothing" (toast and log share the string) | `rules_f02_test.gd` (contains "no legal target") passes; f02 driver toast check |
