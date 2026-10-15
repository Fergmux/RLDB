# Playtest feedback 02 — implementation and verification checklist

Source: `design/playtest-feedback-02.md` (15 Oct 2026). Rules authority unchanged (`design/decision-register-answers.md`).
Evidence root: `production/qa/evidence/2026-10-15-f02/` — `final/` is the last live run (65/65 checks, `final/f02_report.json`),
`cards/` and `details/` are rendering galleries, `INDEX.md` lists the screenshots. Live runs drive the real game window
with pointer and keyboard events pushed into the viewport (`src/dev/f02_driver.gd`, `-- --f02-shots=<dir>`), from both seats.
Automated: 392 GdUnit4 tests pass (`rules_f02_test.gd` 18, `ui_f02_interaction_test.gd` 7, UI unit suites, QA suites `qa_f02*`).

| Item | Status | Implementation | Verification evidence |
| --- | --- | --- | --- |
| F02-01 Inspection vs action | Verified | Hover lifts + details only; click selects (blue ring + brackets) and shows the legal buttons against the card; second click / table / Esc / right-click deselects; locks hide buttons | Live: hover shows details, no buttons, hover sweep changes no state and sends nothing; click selects; selection change updates the row; response lock hides buttons; opponent seat has no rows off-turn; hidden cards never inspected. Tests: `test_f02_01_*` |
| F02-02 Summon Attack / Defense | Verified | Engine commands carry `stance`; also Ritual/Arcane Attack/Defense; `no_defense` and timing still enforced; network sanitiser accepts `stance` | Live: two buttons, straight to zone choice, unit enters Defense, AP paid once; Arcane Defense from the Extra pile. Tests: 7 rules tests + QA (Bahatia lock, Ritual Runes, Arcane materials, malformed values, ENet two-client) |
| F02-03 2:3 cards, rotated Defense | Verified | All card kinds 2:3; square/landscape zones keep shape; Defense units and Trap/Spell-zone cards are the turned card with stats/name kept upright (UX D1) | Live: proportion check at 1600x1000, 1280x800, 1920x1080; Defense card 128x85 rotated. Gallery `cards/rotated_states.png`, `field.png`. Geometry unit tests |
| F02-04 Short labels | Verified | Ability short-label table (46 entries) + fallback; distinct per card; full text as tooltip and in Rules | Live: "Apply Pierce" on the card, full text in tooltip. Test checks every ability ≤18 chars and unique per card |
| F02-05 Taller details, shorter log | Verified | Details/log stretch 1.75/0.8; prompt panel min height avoids jumps | Live: typical effect unit fits without scrolling at 1600x1000 (overflow 0 px); log still scrolls; screenshots at 3 sizes |
| F02-06 AP slots | Verified | `ap_start`/`ap_peak` in the view; capacity = max(start, peak, current); spent sockets visible | Live: 2 slots at start, 1 filled + 1 spent, expands to 5 after +AP. Tests: rules (Abyss start 3) + `ap_display_test.gd` |
| F02-07 Direct targeting + banner | Verified | No sidebar target list; board/Hand picks; banner in the top strip (Settings/Menu stay visible) with prompt, count/order, non-card options, Confirm/Cancel; ordered badges | Live: zone and ability targets clicked on the board, banner text, state valid after completion. QA: Plan B resolves in click order; stale multi-pick cleared between prompts (QA-F02-01 fixed) |
| F02-08 Structured details | Verified | `CardDetailsPanel`: identity, Race/Type chips with type icon, ATK/DEF tiles with printed values and ▲/▼, modifiers, timing-labelled rules, on-card buttons, statuses, notes | Gallery `details/*.png` (all card kinds, longest text), 9 unit tests, live screenshots |
| F02-09 No-target toast | Verified | Resolving choice with no candidates logs a toast entry (public only if its source is public); plated, non-blocking toast + sound | Live: Shapeshifter Loak toast, queue not stuck. Tests: rules toast test; QA: hidden source shown only to its owner |
| F02-10 Click pile cards | Verified | Pile choices in a tray over the board; click chooses; multi keeps order, commits on Confirm; hover reads | Live: single pick from Spent, ordered 2-pick Arcane materials (badges 2,1), not committed before Confirm. Test: tray click |
| F02-11 Ready highlight | Verified | Lime double ring + chevron badge (distinct from Arcane teal, selection blue, target yellow); counts play/summon/set, manual effects, attacks; Extra chip marker | Live: ready hand unit, attacker in Battle, Defense unit not advertised; hidden cards never marked |
| F02-12 Combat preview | Verified | Authority computes `battle_preview` (shared `battle_values`, immunities, Eternal/guard, Pierce, Burn, no-damage) on attack options; cyan preview badges, verdict-coloured arrow with ✓/✕/= marker, banner outcome with face-down caveat | Live: 14 vs 10 green, stalemate neutral, 10 vs DEF 14 red; restored on exit; no state change or send. Tests: 8 rules tests; QA: 12 preview-vs-battle agreements, 15-pair no-mutation check; guarded Buff-immune/Cursed Warrior fixed (QA-F02-02) |
| F02-13 Sounds | Verified (programmatic); listening by user pending | 20 original synthesised sounds (`tools/gen_sfx.py`), public-event and UI triggers, rate-limited, volume + mute in Settings | Live: select/confirm/cancel/summon/attack/notice/draw started; WAV analysis (peak −6 dBFS, no clipping); 7 unit tests. Subjective balance not judged by a person yet |
| F02-14 Type icons | Verified | `TypeIcons`: 7 distinct vector icons + hollow typeless ring, dark backing disc; Race text separate | Gallery `cards/icons.png`; details Type chip; read at draw time so Type changes update |
| F02-15 ATK diamond | Verified | Red diamond ATK, DEF shield unchanged, fits 3-digit and preview values | Gallery `cards/states*.png` (100/120, previews) |

## Interpretations recorded (no rule changes)
- **Action placement (F02-01):** buttons sit against the selected card (above a lifted hand card, below a field card), not over its art, so the name, stats and statuses stay visible.
- **Trap/Spell zone (F02-03):** cards there are the turned 2:3 card, as the zone is landscape in the layout reference.
- **AP display (F02-06):** uses the display policy proposed in the feedback. AP rules are unchanged.
- **Ready highlights (F02-11):** stance changes and sacrifices do not count as "can act", because they are always available in Main 1 and would light up every unit.
- **Combat preview verdicts (F02-12):**
  - **Favourable:** the target is destroyed and the attacker survives.
  - **Unfavourable:** the attacker is destroyed, or you take damage while nothing is destroyed.
  - **Even:** everything else. This covers trades, stalemates, and attacks where Eternal or a guard saves the target.
- **Ritual and Arcane summons:** these also get Attack/Defense buttons. They are reached by clicking the card in the Extra Deck pile. Before this change no summon button for them could be reached in the UI.

## Defects found and fixed during verification
- **Script error when hand cards leave:** two hand cards leaving at once while one was hovered threw a stale-key script error. The regression test was seen failing before the fix.
- **Keyboard (pre-existing gap):** Tab and the arrow keys never reached the game while a button had focus. Game keys are now handled before focus navigation.
- **QA-F02-01:** a multi-pick carried over into the next prompt.
- **QA-F02-02:** the preview over-promised a Mans Best Friend guard for a unit that cannot receive Eternal.
- **QA-F02-03:** a stance probe on a hidden card returned a distinguishing error.
- **UX review:** D1 and D2 (high), and D3–D9, D12, D13 and D15–D17 fixed; see `production/qa/ux-review-f02-2026-10-15.md`.

## Open
- **F02-13:** the sound balance has not been judged by ear. Please listen and say which sounds need adjusting.
- **Plan B:** user decided (15 Oct) it must destroy at least one card and is only offered when you control another card; implemented with tests seen failing first.
- **Frame time:** in the last windowed perf run it was 5.4 ms average and 19.0 ms at the 99th percentile, up from about 16.9 ms recorded before this pass. Machine load differed and the baseline could not be re-run.
