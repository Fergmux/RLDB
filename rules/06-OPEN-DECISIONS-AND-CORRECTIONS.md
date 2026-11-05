# Open decisions and source reconciliation

## Subsequent confirmed decisions

Read `design/decision-register-answers.md` at the repository root before implementing items that were open here. The user has now reviewed P-01 through P-31 and the four Snunday topics. That companion file's final answers and corrections override conflicting older proposals/open notes here; it does not claim all unrelated edge cases or numerical draft settings have been specified. Do not rely on `design/decision-register.md` prototype defaults when its answer differs.

## Confirmed corrections and interpretations

- **Decision interview P-24:** 'Activates an effect' covers Unit, Power, Spell and Trap effects, including On Summon and On Destruction triggers. The prototype's manual-only definition is rejected. Listener conditions and turn restrictions remain in force. See `design/decision-register-answers.md` for subsequent confirmed decisions; the original proposal register must not override those answers.

- Rune is a separate counter, not a buff. Curse and buff checks do not affect it.
- Cleanse consumes one Cleanse, not one Curse. One use clears all existing debuffs or prevents a debuff application.
- Retain decrements when preventing end-turn discard, not at next-turn start.
- Necrovast's Exhaust-to-Draw effect is an intentional exception to exhaustion.
- The Last Foundation's `Apply Reveal to all facedown cards` belongs in On Summon, not condition.
- The Legendary Swordsman's `Apply 3 Cleanse to this Unit` belongs in On Summon, not condition.
- `?` Type/Race means no type/race, not undecided. `?` ATK/DEF is dynamic and explained by an effect.
- Roma's `?R` uses all Runes on its tributed unit, minimum one.
- Arcane materials are ordinary AP-cost units in Spent only, using current modified costs and permitting overpayment **[superseded 16 Oct 2026 by F03-04: the total must equal the requirement exactly]**. Special-cost extra-deck units cannot contribute.
- Tribute includes Fusion, Ritual and Arcane materials. Field-only material triggers do not activate from Spent. Tribute has no default sacrifice refund.
- Magic Cylinder does not destroy attackers; the spoken destruction example was corrected to Mirror Force.
- Manual abilities and Spells are allowed during the owner's Battle Phase. Earlier main-phase-only and optional-trigger bans were retracted. Manual summons/setting remain main-phase-only; normal stance changes remain Main Phase 1 only.
- Costs persist through redraw/replay within a game, but reset between games. Ordinary field stats reset on leaving Field.
- The final product scope includes multiplayer and Steam. Earlier single-player estimates were assumptions, not requirements.

## Sneaky Snunday — confirmed special behaviour

**Further confirmation in decision interview S-03:** Reversal is limited to additive/subtractive gains and losses. Multiplication is not reversed: doubling does not become halving. Stat assignment/copying is not converted into a reversible numerical delta. See `design/decision-register-answers.md` for the current interview answers and later corrections.

Reverse numerical gains/losses from card effects, including HP, AP and ATK/DEF changes. Preserve targets. Do not reverse statuses/counters, AP paid to play cards or normal combat damage. Do not retroactively reverse an instantaneous change already resolved before activation.

Assign reversal when a card is played: Delayed Gratification played under reversal locks in next-turn -1 AP, even after Snunday expires. Continuous modifiers are recalculated while reversal is active: Divine Serpent - Body's adjacent +10 DEF becomes -10 DEF, then returns when reversal ends. New Shimmer Serum +16 ATK becomes -16; its Blind application remains normal. Divine Serpent's damage reverses to healing for the same opponent.

Do not implement a global sign flip over every numeric field. The decision interview now settles these former open cases: two overlapping reversals cancel; stat-setting/copying stays normal as a one-time assignment; multiplication/division is not reversed; additive self-cost changes reverse, respecting zero floor. Shimmer Serum played under reversal applies -16 ATK and changes its own cost by -1 rather than +1, without turning its actual payment into an AP refund. Read the answer file for attribution rules and the distinction between live continuous changes and previously resolved values. Other unspecific interactions must not be invented.

## Remaining decisions

These do not prevent a representative prototype, but affected features must be documented or clarified before claiming full rules fidelity. Prototype defaults are proposals, not confirmed rules.

### Mode configuration

- Deck sizes, duplicate limits, category draft quotas, number of offered choices, draft order and who starts a game.
- Reward count, offered pool, sequence, final-game rewards and whether changing a basic unit changes all three copies.
- Series lengths supported and ties/abandoned series behaviour.
- Whether dedicated single-player AI is desired. It was not confirmed as a requirement.

### Core resolution and card edge cases

- Exact ordering of AP reset, drawing and simultaneous start/end-turn triggers. Delayed AP modifiers must survive the normal reset rather than be overwritten.
- Whether sacrifice itself is allowed during Battle; its destination, use limits and age/control-change timing. Summon age restriction is confirmed; no general sacrifice phase permission was supplied.
- Duration of stat changes without explicit end time; base/current copy values; snapshot versus continuously updated copied stats; modifier layers before zero clamping.
- Rune reset when a unit leaves Field within a game, and last-known-state snapshots for destruction effects that inspect its previous counters/stats.
- Response opportunities between attack declaration and calculation, nested response handling, optional effect cancellation and rechecking trap eligibility as earlier responses alter state. Owner ordering is settled; detailed queue policy is not.
- Cleanse/Curse collision order and batched status prevention; Pierce consumption when there is no positive excess; exact Burn timing relative to responses.
- Same-turn once-per-turn use after leave/reenter, ownership transfer or copied effects.
- Fusion material distinctness, modified-stat material checks, and special material source exceptions. The recipe is not permission to count one unit twice.
- Exact-card search ordering/shuffling, direct transfer of extra-deck units to Hand/Draw, and what happens if recycling Spent returns only extra-deck cards while Draw stays empty.
- Used Trap and sacrificed-unit destinations were not expressly confirmed. Spent is a reasonable proposed prototype rule, but must be labelled as such until accepted.
- Whether card-effect stance changes bypass the Main Phase 2 restriction. Normal/manual stance changes do not.
- Forced attack targets versus protected targets; full-board summon failure; return of a temporarily controlled unit when its owner's board is full.
- Whether zero-HP checks ever require a tie rule for effects not expressed in ordered steps. Ordered damage is immediate defeat as confirmed.
- Whether Marked by the Abyss's zero-cost deck check includes Extra Deck and uses printed/current costs; its conditional allowance is +1 at turn reset, not recurring free AP on each state update.
- Whether multiple copies of replacement effects such as Options/Elemental Mastery stack. Do not convert 'now +12' into additive +12 automatically.

### Multiplayer and product

- Supported platforms, Steam application setup, selected transport/integration, authority trust model and host migration.
- Reconnect grace period and process-restart recovery. Match pause/reconnect is confirmed; exact timeout/persistence is not.
- Unit/Power response UI windows during own Battle and whether explicit opponent-turn activation cards need a generalized response window.
- Log export/replay, post-game visibility, whether hidden selected cards are publicly revealed, and accessibility/input preferences.

## Source data handling

There are 183 named cards with unique nonblank IDs. Categories: 35 Basic Units, 61 Units, 16 Spells, 17 Traps, 19 Powers, 17 Fusion Units, 10 Ritual Units and 8 Arcane Units. There are 15 status-table rows including Rune.

The card CSV contains two entirely blank trailing rows and one unnamed row containing: 'At the start of your turn: Apply 1 Infiltrate to this Unit. If your HP is lower than your opponents, double this Units ATK.' Preserve it as an unassigned source note, not a playable card, until its intended owner is identified.

Original CSVs are copied unchanged under sources/. The catalogue applies only the two confirmed misplaced summon-effect corrections. Source English includes unusual signs such as 'lose -6 HP' and 'spend -1 AP': interpret these as loss/payment of the magnitude, not subtraction of a negative granting resources. Keep this distinction explicit when compiling effects. This semantic interpretation is consistent with all spoken examples.

Source image references are not supplied artwork. No images were fabricated or downloaded. Original spelling of card names and source IDs is preserved so later art can be mapped reliably.
