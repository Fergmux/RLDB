# Requirements checklist

Requirement-by-requirement status against `rules/` (01–08), from an independent QA audit plus
the gaps closed after it. Evidence: GdUnit4 tests (309, all passing — see README for the
command) and screenshots in `production/qa/evidence/2026-10-15-ui-v3/` (current) and `2026-10-15-final/` (before the production pass).

Legend: **Done** = implemented and tested · **Done (manual)** = implemented, verified by
running the game/screenshots, no automated test · **Partial** · **Blocked** = needs something
outside this repo.

## Game rules (01) and statuses (02)

| Requirement | Status | Evidence |
| --- | --- | --- |
| 60 HP, immediate defeat, ordered HP loss, healing above 60 | Done | rules_cards (ordered loss, Cylinder lethal), rules_status (Medic) |
| Board: 6 unit / 3 Trap-Spell / 4 Power zones, protection, adjacency | Done | rules_combat (protection), rules_status (Nimble) |
| Turn flow: AP reset to 2, draw 4 + retained, no battle on turn 1 | Done | rules_turn |
| Main-phase summoning/setting; stance changes only in Main 1 | Done | rules_combat, review regressions |
| Costs (current, floored, persistent within a game), `?` stats/types | Done | rules_status, card tests |
| Sacrifice / tribute (incl. Cliff 3/2, Mumen 2/1, summon-turn rule) | Done | rules_summon |
| Timing table (Spells/abilities on own turn incl. Battle; Traps on opponent's turn) | Done | rules_combat, rules_cards |
| Trigger ordering: active player first, controller orders own; trap owner orders traps | Done | rules_cards |
| Combat table, type advantage (+6 / +12), Pierce, Eternal, direct attacks, Blind, Infiltrate, Burn | Done | rules_combat, rules_status |
| Destinations, Spent recycling (extra-deck → Extra Deck), skipped draws, Necrovast exception | Done | rules_turn, rules_cards |
| Fusion / Ritual (Roma) / Arcane rules | Done | rules_summon, card tests |
| All 14 statuses + Rune counter, corrected Cleanse/Retain | Done | rules_status, rules_turn |
| Series: configurable best-of, deck selection or draft, full reset between games | Done | series_flow, net_full_series |
| Rewards: 4 per player per game, any combination (C-02) | Done | series_flow |
| Loser chooses who goes first (C-01) | Done | series_flow |

## Cards (03, 06)

| Requirement | Status | Evidence |
| --- | --- | --- |
| All 183 cards imported with stable IDs; orphan row kept as a note | Done | tools/import_cards.py, series_flow |
| Confirmed corrections (Last Foundation, Legendary Swordsman, signs, Rune ≠ buff, …) | Done | card tests c063/c097, rules_status |
| Working behaviour for every card + ledger | Done | docs/card-support-ledger.md (148 effect cards tested, 35 effectless basics) |
| Every clause of multi-clause cards individually tested | Partial | ledger notes; main clauses tested, some secondary clauses not |
| Sneaky Snunday scoped reversal (all six checks) | Done | rules_cards |

## Video-game design (04)

| Requirement | Status | Evidence |
| --- | --- | --- |
| Buttons only, legal choices with reasons, cancel before commit | Done | rules_summon (cancel); screenshots 02–05 |
| Live stats/statuses/costs, details with modifier breakdown | Done (manual) | screenshots 02, 03 |
| Trap prompt suspends opponent indefinitely; owner orders traps | Done | rules_cards, net_two_client |
| Hidden information in UI, log and network payloads | Done | rules_visibility, review regressions, net_two_client (raw payloads) |
| Own Draw inspection without changing real order | Done | rules_visibility (display order is by random uid, independent of Draw order) |
| Hidden-pile selection revealed only to the chooser | Done | rules_visibility |
| Scrollable, ordered, explained game log | Done | rules_cards (log order), screenshots |
| Disconnect pauses; reconnect restores the pending choice; no duplicates | Done | net_two_client (incl. drop during a trap prompt), net_full_series |
| Host may stop waiting; absent player forfeits (P-02/P-06) | Done | net_two_client |
| Steam matchmaking and friend invites | Blocked | Implemented (`net_session.gd`, `main.gd`); needs two real Steam accounts — see README checklist |
| Steam reconnect | Blocked | Same transport-independent logic as ENet (tested); Steam itself unverified |
| Supplied artwork | Blocked | Waiting on the user; placeholders + `rldb/art/cards/` drop-in path |

## Build plan, verification and process (05, 07, 08)

| Requirement | Status | Evidence |
| --- | --- | --- |
| All file-05 behavioural checks (33 rows) | Done | rules_* suites (audit mapped every row) |
| Two-client tests: response suspension, illegal input, redaction, reconnect | Done | net_two_client (6 tests) |
| Complete matches and series between two clients | Done | net_full_series (best of 3; best of 5 with draft), both with a mid-game reconnect |
| Launch and inspect the real game; screenshots | Done | production/qa/evidence/2026-10-15-final (exported build + networked run) |
| Runnable export + setup instructions | Done | build/windows/RLDB.exe (git-ignored), README |
| Independent specialist reviews, fixes verified | Done | commit df7d450 + rules_review_regressions (each seen failing first) |

## Open items for the user

1. **Steam verification** — run the README's two-account checklist.
2. ~~Possible endless games~~ — resolved by C-04 fatigue damage (default 2 HP per missed draw; confirm the number).
3. **Open decisions in `rules/06`** — prototype answers are listed as P-xx in
   `design/decision-register.md`; review and confirm or change them.
4. **Artwork** — drop files into `rldb/art/cards/` using the source image filenames.

## Production-quality pass (rules/09, 2026-10-15)

| Requirement | Status | Evidence |
| --- | --- | --- |
| Decision answers P-01..P-31, S-01..S-04 reconciled in the engine | Done | `rules_decisions_test.gd` (each changed decision seen failing first), commit ab59612 |
| C-03 Damage Conversion = Magic Cylinder condition; C-04 fatigue damage | Done | decision + turn tests |
| Reworded card texts shown in game (MC, DC, Chains, Options, Yamata) | Done | `tools/import_cards.py` TEXT_CORRECTIONS |
| 60 s host claim of the current game only (P-02/P-06) | Done | `test_host_can_claim_current_game_only_after_wait`, QA series suite |
| Between-game series save/resume (hot-seat, LAN, Steam host), seat bound to original player | Done | series save tests, QA `qa_net_series_test.gd` |
| Custom deck builder (unrestricted) + starter + draft routes | Done | deck builder tests, ui-v2/deckbuilder |
| I-01 board layout from reference image, seat-relative | Done | ui-v3, independent UX review: MEETS |
| I-02 legal actions on hovered card; details inspection-only; keyboard fallback | Done | ui-v3 02a/02a2/02b/02c/02d |
| I-03 visual direction, animation, reduced motion | Done (art pending) | ui-v3, art bible, perf probe |
| Studio settings: rigor full, review full, team studio, QA full, multiplayer, strict evidence | Done | `project.yaml`, resolved via yaml-helper |
| Independent reviews (security, UX, adversarial QA) with fixes re-verified | Done | `production/agent-ledger.md`, `production/qa/qa-adversarial-2026-10-15.md` |
| Steam in a real environment — single account | Done | `tests/steam/steam_probe.gd` → `production/qa/evidence/2026-10-15-steam/steam_probe_report.json`: init (App ID 480), friends-only lobby, lobby data, host socket, invite overlay call, public lobby found by search |
| Steam friend join, P2P play and reconnect between two accounts | Blocked | Needs a second Steam account/PC (README checklist) |
