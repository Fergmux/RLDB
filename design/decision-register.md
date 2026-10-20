# Decision register

Authority: `rules/` files 01, 02, 04 and 06 are confirmed design. Entries here are either
**CONFIRMED** (stated by the user after the spec was written) or **PROPOSAL** (prototype
default chosen to keep the build moving — not canon; change in `rldb/data/mode_config.json`
or by updating this file).

## Confirmed after the spec (2026-10-15)

| ID | Decision |
|----|----------|
| C-01 | The loser of the previous game chooses who goes first in the next game. |
| C-02 | After every game, each player picks **4 rewards**, in any combination of: add a card, remove a card, change basic unit type. |
| C-03 | Damage Conversion, like Magic Cylinder, triggers only on an attack on one of your units in its column; never on direct attacks. |
| C-04 | Fatigue: each draw that cannot be made (Draw and Spent both empty) costs HP; amount configurable (`fatigue_damage`, default 2 — the value is a proposal). |

> **2026-10-15:** `design/decision-register-answers.md` holds the user's answers to P-01–P-31 and S-01–S-04 and supersedes the proposals below wherever they differ. Proposal rows are kept for history only.

## Prototype proposals (file 06 open items)

| ID | Topic | Proposal |
|----|-------|----------|
| P-01 | First game starter | Coin flip by the authority (seeded, logged). |
| P-02 | Series length | Best of 3 by default; 3/5/7 selectable. Ties impossible (immediate defeat). Abandoned series: the player who left forfeits after the host ends the wait. |
| P-03 | Deck source | Preselected 20-card starter decks (including 3 copies of an effectless basic unit), with an optional draft mode. |
| P-04 | Used Trap destination | Spent. |
| P-05 | Sacrificed unit destination | Spent. |
| P-06 | Reconnect wait | Indefinite; the host may end the match manually. |
| P-07 | Start-turn order | Reset AP to 2, then apply delayed AP modifiers, then draw 4, then start-of-turn triggers (active player's cards first). |
| P-08 | End-turn order | End-turn triggers (active player first), then Poison/Paralyse/Debilitate decrements, then discard (Retain checked per card). |
| P-09 | Stat changes without an explicit end time | Last while the unit stays on Field. |
| P-10 | Rune counters on leaving Field | Cleared, like other field state. |
| P-11 | Destruction triggers | Use a last-known-state snapshot taken just before the card leaves Field. |
| P-12 | Pierce with no positive excess | Not consumed. |
| P-13 | Burn timing | Resolves at attack declaration, before trap responses. |
| P-14 | Cleanse vs Curse collision | Whichever application arrives later checks the other; batch applications are checked one at a time in listed order. |
| P-15 | Fusion materials | Each material must be a distinct card instance, checked against current (modified) stats. |
| P-16 | Full board on a special summon | The summon fails, and its materials and costs are not consumed (checked before payment). |
| P-17 | Recycle yields only extra-deck cards | Return them to Extra Deck; the draw is then skipped without penalty. |
| P-18 | Effect-driven stance changes | Allowed in any phase (only manual stance changes are restricted). |
| P-19 | Repeated replacement effects (e.g. Elemental Mastery) | Don't stack; the highest value applies. |
| P-20 | Nested responses | One response window per triggering event; traps may not respond to traps. Owner chooses order. |
| P-21 | Sacrifice timing | Main phases only, own turn. J11 (owner, 22 Oct): started from the Sacrifice Unit button under the plate (pick a unit, confirm), no longer from the card's action row. |

### Added during implementation

| ID | Topic | Proposal |
|----|-------|----------|
| P-22 | Summon response vs On Summon | Trap window for "opponent summons" resolves first; the unit's On Summon effect then resolves if it is still on the Field. |
| P-23 | "Attack in this Column" | The column of the attacked unit (columns face each other); for a direct attack, the attacker's column. |
| P-24 | "Activates an Effect" | Casting/activating a Spell, using a manual unit/Power ability, or playing a Power. On Summon/On Destruction triggers are not activations. |
| P-25 | Playing a Power | Main Phases only (like other cards played to the board); its abilities may be used in Battle. |
| P-26 | Nimble move timing | Any of the owner's phases (Main 1, Battle, Main 2), once per turn. |
| P-27 | Hidden response windows | Whenever a player holds a face-down card they get a response prompt for each respondable event, even if no Trap qualifies (they just Pass). This hides whether an eligible Trap exists, at the cost of more prompts. Configurable: `hidden_response_windows`. **Superseded by the user's answer:** prompt only when a legal response exists (default off). Accepted consequence: the pause itself reveals that the opponent holds an eligible Trap (never which card). **J6 (owner, 22 Oct):** each player now has a Trap Prompts toggle under their plate (saved per viewer, sent as their seat's own setting). On (the default): hidden windows for that seat, asked whenever they hold a face-down card set before this turn and some Trap of the card pool could answer the event, so the pause reveals nothing. Off: never asked (their Traps stay down). Bots, tests and the tutorial keep "prompt only when a legal response exists". |
| P-28 | Last-known state in responses | Effects that read an attacker's ATK use its ATK at attack declaration if it has since left the Field (extends P-11). |
| P-29 | Self-recovery on destruction | "Add a Warrior from Spent" style On Destruction effects cannot pick the destroyed card itself. |
| P-30 | Optional "Once per turn" abilities | Abilities without "you can" (Chains of Binding, Yamata) are still player-activated, once per turn, not forced. |
| P-31 | Steam lobbies | Friends-only by default (joined by invite); host may list publicly so "Find lobbies" can see it. |

Sneaky Snunday open cases (stacked reversal, stat setting/copying, multipliers, self-cost
increases): **not reversed** in the prototype — only explicit gain/loss operations flip. Listed
as unresolved in the card-support ledger.
