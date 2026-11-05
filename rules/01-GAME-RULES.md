# Game rules

## Game and series

A roguelike deck builder played between two players. Start from a preselected deck or draft from category-specific choices and limits. Those quantities are configurable and not yet specified. Each player starts a game at 60 HP. Reduce the opponent to zero HP to win. Healing may exceed 60; no other HP cap is specified.

The envisioned mode is a configurable series, such as best of three or five. Both players choose rewards between games: adding a card, removing a card, or changing the basic unit type. Some modes include three copies of the same effectless basic unit per deck. Reward counts, draft rules and deck limits remain open.

Between games reset HP to 60, all field state, statuses, runes, Exhaust and accumulated cost changes. Only deck/reward changes and the series score carry forward. Exhaustion does not permanently remove a card from the series deck.

## Board and zones

Each player has six unit zones in two rows of three columns, three shared Trap/set-Spell zones behind them, and four Power zones. Players also have Hand, Draw, Spent, Exhaust and Extra Deck.

Units enter face up in Attack or Defense stance. Front-row units are unprotected. A back-row unit is protected only while its matching front-row zone is occupied. Attacks can target any unprotected opposing unit, subject to explicit card restrictions; no general same-column attack restriction was stated.

Adjacent means neighbouring positions on your own six-zone board, including diagonals. Opposing units are never adjacent. Nimble requires an empty destination. Separate simultaneous movement effects can swap two units into each other's zones.

## Turn sequence

1. Start the turn: draw four fresh cards and reset AP to exactly two, modified by explicit effects. Unspent AP does not accumulate. Ordering among start-turn effects is discussed in file 06.
2. Main Phase 1.
3. Battle Phase, except on the very first turn of the game.
4. Main Phase 2.
5. End turn: resolve applicable end-turn effects and discard remaining Hand to Spent, except retained cards. Exact ordering of multiple end-turn events remains open.

The second player may battle on their first turn. Newly summoned units may attack immediately. Four fresh draws are additional to retained cards, not a draw-up-to-four limit. One retained card therefore produces five cards after the normal draw; two produce six.

Ordinary summoning and setting are main-phase actions. Choose stance freely in Main Phase 1. No manual stance changes during battle or Main Phase 2, even for a unit that did not attack. A newly summoned unit may choose its initial stance; choosing initial stance is distinct from changing an existing stance.

## Costs, stats and actions

Pay a card's current AP cost to play it normally. AP costs, ATK and DEF have a floor of zero. Card instances can retain explicitly changed costs across Spent, redraws and replays; turn-limited reductions still expire as written. Such persistent changes reset between games.

Units have ATK, DEF, Race, Type and effects. `?` Type means no type; `?` Race means no race. These are defined values, not undecided data. `?` ATK/DEF means an effect determines the value. Do not interpret dynamic stats as zero. Races and damage types are separate concepts.

When a unit leaves Field, its field stats and buffs/debuffs reset. Moving between unit zones is not leaving Field. Explicit persistent cost changes are an exception. Counter reset and destruction-trigger snapshots require the implementation decisions in file 06.

### Sacrifice and tribute

Sacrifice refunds one AP, independent of original unit cost. A unit summoned this turn cannot be sacrificed. It must have remained on board until a later turn. Exact control-change and phase rules are open.

Tribute means using a card for another card's summon, including Fusion, Ritual and Arcane. Tribute is not destruction or sacrifice and has no default AP refund. Newly summoned units may be tributed immediately. Normal summon timing still applies unless an effect permits an exception.

Printed AP bonuses add to sacrifice's default refund. Cliff the Flying Bison gives three AP when sacrificed (one default plus two printed), but two when tributed from Field. Mumen's Bounty gives two when sacrificed, one when tributed from Field. Their field effects do not trigger from Spent when used for Arcane.

## Cards and legal timing

### Effect activation terminology — confirmed in decision interview

Conditions such as 'if your opponent activates an effect' include effects from Units, Powers, Spells and Traps, including event-triggered effects such as On Summon and On Destruction. Do not restrict these listeners to manually activated abilities. Apply the listener's other conditions and existing turn restrictions: Traps still cannot activate on their owner's turn. An effect activation is distinct from recomputing an already-active continuous modifier. See `design/decision-register-answers.md`, P-24, for the confirmed answer; it supersedes the prototype register's exclusion of summon/destruction triggers.

| Action/effect | Own Main 1 | Own Battle | Own Main 2 | Opponent's turn |
| --- | --- | --- | --- | --- |
| Normal summon or set card | Yes | No | Yes | No, unless effect permits |
| Change stance manually | Yes | No | No | No |
| Cast Spell from Hand | Yes | Yes | Yes | No |
| Activate set Spell | Yes | Yes | Yes | No |
| Manually activate unit/Power ability | Yes | Yes | Yes | Only explicit timing exception |
| Activate Trap | No | No | No | When its condition is met |
| Mandatory/optional event trigger | When event occurs | When event occurs | When event occurs | When event occurs, unless restricted |

Set Traps face down. Spells may be cast immediately or set face down in the shared zones. Pay AP when setting; do not charge again when activating. A Spell may be set and activated in the same turn. Card effects can cause summons or other normally restricted actions during battle; this does not unlock ordinary manual summoning.

On Summon, On Destruction and battle-destruction triggers apply on either player's turn when their event occurs. A defender that destroys a weaker attacker by battle still receives its appropriate battle-destruction trigger.

For effects triggered by the same event, the active player resolves their effects first, then the opponent. Each controller chooses their own internal ordering. Trap owner chooses the order of multiple eligible trap responses. Detailed response windows/nested effects remain open.

Attack-declaration responses happen before battle resolves. Magic Cylinder deals its listed HP damage first, then the attack continues if still legal and the game has not ended. It does not destroy the attacker. Mirror Force can destroy the attacker before combat, so that battle does not resolve.

## Combat

Only Attack-stance units can attack, once per unit per turn. No stance changes during battle. A normal direct attack is allowed only when the opponent has no units. An explicit direct-attack ability, such as Diggie or Flying Sandworm, bypasses opposing units. Direct damage equals the attacking unit's ATK, subject to explicit damage-prevention effects.

| Defender | Comparison | Destruction | HP loss |
| --- | --- | --- | --- |
| Attack stance | Attacker ATK > defender ATK | Defender destroyed | Defender's controller loses the difference |
| Attack stance | Equal ATK | Both destroyed | None |
| Attack stance | Attacker ATK < defender ATK | Attacker destroyed | Attacker's controller loses the difference |
| Defense stance | Attacker ATK > defender DEF | Defender destroyed | None by default; Pierce is an exception |
| Defense stance | Equal | Neither destroyed | None |
| Defense stance | Attacker ATK < defender DEF | Neither destroyed | Attacker's controller loses the difference |

Apply type bonuses to the relevant compared stat before calculating the result. Damage in card descriptions means HP damage. The Illusionist can destroy units normally but its attacks do not deal HP damage. Eternal prevents destruction only; normal battle HP damage still resolves.

### Type advantage

| Type | Effective against |
| --- | --- |
| Water | Fire |
| Fire | Earth |
| Earth | Lightning |
| Lightning | Water |
| Heavenly | Necrotic |
| Necrotic | Physical |
| Physical | Heavenly |
| No type | Nothing |

The advantaged unit receives +6 to its relevant ATK or DEF for this battle's comparison, whether attacking or defending. There is no additional -6 penalty for the disadvantaged unit. Do not permanently change stats. Type advantage affects the comparison and resulting excess HP damage. Elemental Mastery explicitly changes its controller's advantage to +12.

Example: Water ATK 8 attacks Fire ATK 10. Compare 14 against 10: Fire is destroyed and its controller loses four HP. If Fire ATK 10 attacks Water ATK 8 in Attack stance, Water compares at 14; Fire is destroyed and Fire's controller loses four HP.

### Immediate defeat

End the game immediately when a player reaches zero HP. For ordered text such as 'you lose HP and then your opponent loses HP', resolve the first loss and check defeat before the next step. If the first player reaches zero, the second loss never occurs. Magic Cylinder lethal damage also ends the game before the pending battle.

## Destinations and recycling

Discarded cards, used Spells and destroyed units enter Spent unless an explicit effect changes the destination. Exhaust is separate and normally cannot return to play. Necrovast the Undying is an intentional exception: its destruction effect can move a card from Exhaust to Draw.

When a draw is required and Draw is empty, recycle Spent. Ordinary cards shuffle into Draw; Fusion, Ritual and Arcane cards return to Extra Deck instead. If no drawable cards are available, skip that draw without penalty. Complete multi-card draws as far as available cards allow.

Extra-deck units can be revived from Spent by effects whose restrictions they meet. They do not match ordinary AP-cost restrictions: 2R or 2A is not ordinary cost two, and a Fusion's blank AP cost is not zero.

## Special summoning

### Fusion

Meet the Fusion unit's specified material requirements and use a Fusion-enabling Spell or ability. Base materials are units on Field, with explicit card exceptions allowing other locations. Send ordinary Field materials to Spent as tributes. Pay costs required by the enabling effect; there is no universal additional Fusion AP cost specified. Materials from Hand used under Unstable Fusions are exhausted as its text requires. Use card-specific requirements, not arbitrary AP totals.

### Ritual

Tribute a unit with enough Rune counters for the Ritual unit's requirement. Send it to Spent and summon the Ritual unit from Extra Deck into any eligible free unit zone, not necessarily the material's old zone. Runes are separate counters, not buffs; Curse does not affect them.

Roma requires at least one Rune on its material and uses the material's full available Rune count, not a chosen smaller amount. Roma's ATK and DEF each become twelve times the number used. Do not require choosing the highest-rune unit anywhere on Field; that was not specified.

### Arcane

Exhaust ordinary AP-cost units from Spent whose current modified AP costs total at least the Arcane requirement. Overpayment is allowed. **[Superseded 16 Oct 2026 by F03-04 in `design/playtest-feedback-03.md`: the current modified costs must total the requirement exactly; under- and over-payment are rejected. Zero-cost units are not offered as materials (F03-05).]** No additional Race or Type requirements apply. Pay no AP for the summon itself. Extra-deck units cannot be materials because they have no ordinary AP cost. Material use counts as tribute, but on-Field tribute effects do not trigger from Spent. Summon only when normal summoning is allowed or an effect permits it.

## Card-specific reconciliation

See file 02 for status behaviour, file 03 for card text, and file 06 for open decisions. In particular, Sneaky Snunday's precise reversal rules are recorded in file 06; do not implement it by negating every number in the game.
