# Status effects and counters

Source: supplied status CSV, reconciled with explicit clarifications. There are 14 statuses plus Rune, a separate counter. Buffs and debuffs stack additively. Remove a status at zero. Each status consumes/decrements according to its own rule, not a universal turn timer. Rune must not be classified as a buff despite the source CSV label.

| Entry | Classification | Behaviour | Consumption/timing |
| --- | --- | --- | --- |
| Rune | Separate counter | A unit with sufficient Runes can be tributed for a Ritual summon. No inherent stat modifier. Not affected by Curse or buff checks. | No automatic decrement specified; used with the tributed material. |
| Retain | Buff | Keep this card instead of discarding it at turn end. Normal next-turn draws are additional. | Consume one stack each time it prevents end-turn discard. Two stacks protect across two discard steps. This supersedes the CSV's start-turn decrement. |
| Reveal | Debuff | Card is face up. | No decrement/duration specified. It is not an automatic one-turn effect. |
| Eternal | Buff | Prevent the next destruction of this unit. Battle HP damage still resolves. | Consume one stack when destruction is prevented. Source says first destruction; multiple stacks follow stacking/consumption rule. |
| Burn | Debuff | If this unit attacks, its controller loses HP equal to its Burn count. | Remove all Burn when this occurs. Exact attack-declaration/response ordering remains open. |
| Pierce | Buff | When attacking a Defense-stance unit, excess ATK deals HP damage to the opponent. | Consume one when attacking a Defense-stance unit, per supplied text; exact no-excess case is open. |
| Cleanse | Buff | Immediately remove all existing debuffs, or prevent an incoming debuff application. Remaining stacks protect against later applications. | Consume one Cleanse per use. One stack clearing existing debuffs is consumed and disappears. CSV reference to reducing Curse is a typo. |
| Paralyse | Debuff | Cannot declare an attack or move zones. | At end of controller's turn, decrement by one. No stance-change prohibition is stated by the status text. |
| Medic | Buff | At start of controller's turn, controller gains HP equal to Medic count. | Then decrement Medic by one. Healing may exceed starting HP. |
| Curse | Debuff | Remove all buffs or prevent a buff being applied. Does not affect Rune counters. | Consume one Curse per use. No special interaction with Cleanse beyond ordinary buff/debuff interactions; collision priority remains open. |
| Poison | Debuff | At end of controller's turn, controller loses HP equal to Poison count. | Then decrement Poison by one. |
| Infiltrate | Buff | This unit may attack protected units. | Consume one when attacking a protected unit. |
| Blind | Debuff | Choose attack target randomly among all otherwise legal targets. Respect protection and targeting exceptions such as Infiltrate. | Consume one when the unit attacks. Does not make an illegal target legal. |
| Nimble | Buff | Once per turn this unit may move to an adjacent empty unit zone. Friendly adjacency includes diagonals. | Consume one per such move. Does not permit swapping occupied zones; separate simultaneous-move effects may swap. |
| Debilitate | Debuff | Cannot be sacrificed or tributed. Treat the card as having no activated, triggered or passive effects; suppress ongoing effects and prevent new ones. | At end of controller's turn, decrement by one. Does not undo an instantaneous effect already resolved, such as a prior +4 granted elsewhere. |

## Reset and visibility

Unit field stats and statuses reset when it leaves Field. All runes and statuses reset between games. Explicit self cost changes persist through redraw/replay within a game. Moving between Field zones is not leaving Field. Precise rune clearing on within-game zone transitions and destruction-trigger last-known-state handling are listed as open decisions.

Display statuses and current counts live. Card details explain what each status does and when it decrements. Hidden opponent cards must not leak their identity through status displays or inspection.

## Acceptance examples

- Retain 1: at turn end keep the card, reduce Retain to zero, remove the status; next turn draw four additional cards. At the next end turn the card is discarded unless Retain is reapplied.
- Retain 2: keep the card through two end-turn discard steps, consuming one each time.
- Poison 3: at the appropriate end turn lose three HP, then Poison becomes two.
- Cleanse 1 on a unit with multiple debuffs: remove all debuffs, consume the one Cleanse, leaving no Cleanse.
- Cleanse 3 on that unit: remove all debuffs once, leaving Cleanse 2 for future prevention.
- Debilitate on an aura source suppresses its ongoing aura; it does not undo a previous instantaneous grant to another unit.
- Eternal on an Attack-stance unit does not prevent excess combat HP damage; the unit survives the destruction event instead.
