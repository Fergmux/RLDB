# Playtest feedback 04 — checklist (user feedback, 16 Oct 2026)

Goal from the user: "I want this game looking as professional as possible." Each item is listed
in the user's order with what was done.

**Verification:** GdUnit 405/405; live driver (`-- --f02-shots=<dir>`) 72/72 in the editor and in
the exported `build/windows/RLDB.exe`; series screenshots (`-- --shots=<dir>`) and the card
gallery. Evidence: `production/qa/evidence/2026-10-16-fb4/` (`series/` and `cards/` subfolders).

| # | Request | Status | Implementation / evidence |
| --- | --- | --- | --- |
| 1 | Piles the same size as the Power zones | Verified | `pile_stack.gd`: the bottom card fills the 85x128 zone rect; up to 6 thin layers rise above it. `01_board_start.png` |
| 2 | ATK/DEF badges taller (more square), same shapes | Verified | `card_widget.gd` geometry: hand 34x32 / 32x31, board 36x33 / 33x32, big 56x53 / 52x50 (was ~0.85 height ratio). `cards/kinds.png` |
| 3 | Type icons readable on dark backgrounds; cost gem the same size as the type icon | Verified | `type_icons.gd`: ivory outline instead of black, type-coloured pip rim; pip outer radius = gem radius on every layout. Spells/Traps/Powers and typeless units no longer show an empty ring. `cards/kinds.png` |
| 4 | Details: "printed" -> "Base:" | Verified | Stat tiles read "Base: 8". `07_ability_target_banner.png` |
| 5 | Details: no Notes section; nothing shown when there are no statuses | Verified | Notes section removed; "No statuses." removed. `card_details_test.gd` |
| 6 | Details: no "Summoned this turn" / "Attacked this turn" tags | Verified | Removed (Protected / stance / control chips stay) |
| 7 | Details: no "Race:" / "Type:" prefixes | Verified | Chips read "Mage", "Water" (or "No race" / "No type") |
| 8 | Details: category not in capitals | Verified | "Basic Unit", "Spell", … |
| 9 | Coin-flip animation for who goes first | Verified | `src/ui/fx/coin_flip.gd`: coin spins, lands on the first player's initial, "You go first" / "<name> goes first"; once per series (game 1). `00_coin_flip.png` |
| 10 | Hand: whole rules text fits; hover tooltip with the effect on every card | Verified | `_fit_para` steps the text size down until all of it fits; native tooltip (name + rules) on hand, board, tray and pile cards. `23_fusion_zone_pick.png` shows a tooltip |
| 11 | Extra Deck summon buttons say "Summon Attack" / "Summon Defense" | Verified | `match_view.gd` labels for Ritual and Arcane; live driver clicks "Summon Defense" |
| 12 | Deck pile renamed Draw; count overlaid on the pile | Verified | Big count in the middle of the top card, name plate at its foot |
| 13 | "Can act" highlight: only the outer green ring | Verified | Inner ring removed; the card keeps its kind-coloured frame; chevron badge kept |
| 14 | Top banner: margin from the top, narrower, toast-like | Verified | Rounded panel with shadow, 10 px from the top, centred between the seat label and the opponent's plate, max 640 px |
| 15 | Bug: Fusion stance prompt named Tag Team - S / Polymerisation | Fixed + regression test | `pick_stance` / `pick_slot` take `for` (the unit being placed); Fusion and special summons pass it. `test_fusion_zone_and_stance_prompts_name_the_fusion_unit` (watched failing on the old code). `24_fusion_stance_banner.png` |
| 16 | Fusion zone pick: highlight the whole zone, not the card | Verified | `ZoneRing` over occupied zones being chosen; the card itself is not highlighted. `23_fusion_zone_pick.png` |
| 17 | "On-card buttons" replaced by timing-style blocks | Verified | Rules starting "Once per turn" get an ONCE PER TURN caption with the effect below; abilities not stated in the rules get the same block ("Once per turn · 1 AP"). Section "On-card buttons" removed |
| 18 | Own face-down set cards: name upright while the card stays turned | Verified | Name plate drawn in screen orientation over the turned back. `cards/kinds.png` |
| 19 | Fusion material prompt: "Choose a <material> for the summon of <card>" | Verified | e.g. "Choose a Fire Mage for the summon of …"; requirements read as noun phrases |
| 20 | New rule: no Spells, Powers or Traps from the Hand in the Battle Phase | Verified | `cast` now Main Phase only ("Spells in your Hand can only be cast in a Main Phase."); set/power/summon were already Main only; set Spells, abilities and Traps on the Field still act. `test_battle_phase_forbids_playing_anything_from_hand` |
| 21 | End of turn: hand cards animate to Spent | Verified | Engine emits a public `discard` effect; your cards fly face up, the opponent's as backs; hot-seat waits for it before switching seats. `26_end_turn_discard.png` |
| 22 | "Opponent is responding" in the middle of the board | Verified | Breathing notice on the centre line while the opponent decides. `16_waiting_on_opponent_response.png` |
| 23 | Arcane material prompt: no "in the order picked" | Verified | Multi-pick status reads "Selected 1 of 2 · cost total …" |
| 24 | Plates without hand counts; "Opponent hand" above the cards | Verified | Plate "Hand n" removed; label above the opponent's card backs, no number |
| 25 | Remove small unexplained icons | Verified | "Attacked" slashed-circle mark and Protected shield removed from cards; empty "no type" ring no longer drawn |
| 26 | Rewards: card type first, then one of three; the pick is spent, no backing out | Verified | `reward_type` command spends the pick and offers 3 cards of that type; nothing else is allowed until one is taken. Series + network tests. `series/09_rewards.png`, `series/09b_reward_offer.png` |
| 27 | Basic unit change: Race and Type rows, then Confirm | Verified | `reward_basic` accepts `to_race`; UI: choose the unit, a Race and a Type, then "Confirm: Basic Dragon (Fire)" |
| 28 | Replace "View the final board and log of game N" with "View your deck" | Verified | Opens your current deck (each card once with ×copies) on the rewards and first-player screens |

Also fixed while testing: the network command filter rejected the new `category` / `to_race`
fields ("Unknown command field."), which would have broken rewards in LAN/Steam games.
