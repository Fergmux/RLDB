# Playtest feedback 03 — checklist (user feedback, 15–16 Oct 2026)

Decisions from the user's answers: targets are picked before costs are paid (cancellable until
then); all choices live in the top banner; a set Trap shows face up when face up or under Reveal;
pile stacks are Deck / Extra / Spent / Exhaust beside the unit zones for both players; the Steam
invite button belongs to the pregame lobby only.

Status key: **Verified** = full suite green (398/398), live driver 66/66 in the editor and in the
exported exe, screenshots in `production/qa/evidence/2026-10-16-fb3/`.

| # | Request | Status | Implementation |
| --- | --- | --- | --- |
| 1 | Hover shows details immediately | Verified | Details update on hover start (no 200 ms delay) |
| 2 | Horizontal cards = upright card rotated; own set Traps face down with name; face up when revealed; no status marker | Verified | `card_widget.gd`: landscape layout removed; own face-down set card = back + name; face up if `face_up` or Reveal; no SET/Reveal chip |
| 3 | Fusion/Ritual actions only when a summon is possible | Verified | Fusion abilities illegal with "No Fusion unit can be summoned." (pool excludes the paying unit); Ritual/Arcane already checked; illegal actions are not shown |
| 4 | "Steady Pulse" backing track, separate music volume | Verified | `assets/audio/music/steady_pulse.mp3` (user-supplied), `src/ui/audio/music.gd` loops it across menu and game; Music + Sound sliders/mute in main menu and in-game Settings |
| 5 | Remove "Attacks happen in the Battle Phase" button | Verified | Action rows show legal actions only; reasons stay in the details notes |
| 6 | Trap activations missing from the log | Could not reproduce; highlighted | Activation line is logged publicly and reaches both seats' on-screen log (`ui_log_trap_test.gd`); now bold in the Trap colour. Need the user's exact case if still missing |
| 7 | Deck/Extra/Spent/Exhaust as pile stacks beside units (mirrored), hand count kept | Verified | `src/ui/board/pile_stack.gd`; 2x2 grid mirroring the Power grid; height grows with count; own piles open on click; Extra ring when a Ritual/Arcane summon is available; hand count on the player plate; plate pile chips removed |
| 8 | Only-direct attackers: "Attack Direct", no target select | Verified | Action label and no target prompt when the only legal target is a direct attack |
| 9 | Remove the box above card details | Verified | Prompt panel removed; all my choices (targets, Trap responses, ordering, yes/no, Skip, Confirm, Cancel) are in the top banner (second row of buttons when needed); opponent-choosing shown in the turn chip |
| 10 | Thinner type-icon border | Verified | Rim about one third of the previous width |
| 11 | No Defense indicator on cards | Verified | Stance tab and Defense tint removed |
| 12 | Direct attack animates to the middle of the enemy side | Verified | Lunge targets the centre of the defender's unit block |
| 13 | Smaller ATK/DEF, smaller effect text with more room | Verified | Smaller badges; hand text 10.5 px with an extra line, big 13 px |
| 14 | Remove number-key shortcuts and "1 ·" labels | Verified | Digit keys removed everywhere; option buttons have no numbers |
| 15 | Trap destruction shows the destroy animation | Verified | Hot-seat seat switches no longer discard the effects that happened on the other seat's screen (the animation cursor survives the switch within a game) |
| 16 | Single targets still picked; cancel for optional actions; targets before costs | Verified | No auto-pick for effect targets or zones; abilities/Spells ask their leading target/mode choices first (cancellable), then pay; Fusion abilities choose the Fusion unit first (cancellable); optional effects keep Skip |
| 17 | Full status names, slightly smaller | Verified | Chips read "Pierce 1", "Paralyse 2", … |
| — | Steam invite only in the pregame lobby | Verified | Invite button + waiting message on the deck-selection screen while the host waits; never during a game |

| 18 | Card-kind colours: Trap red, Power light blue, Unit brown, Fusion dark blue, Ritual purple, Spell green, Arcane grey; one shared back; same colours in the log | Verified | `UIStyle.CATEGORY_COLORS` (frames, pills, deck builder); `CardWidget.draw_back_art` used by every back and the pile stacks (no kind stripe on set backs); log card names tinted by kind, Trap / set-Spell activation lines in the Trap / Spell colour |

## Verification
`--headless ... GdUnitCmdTool.gd -a res://tests` 398/398; live driver 66/66 (editor and exported
`build/windows/RLDB.exe`); card gallery regenerated in `production/qa/evidence/2026-10-16-fb3/cards/`.
