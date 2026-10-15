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
| P-21 | Sacrifice timing | Main phases only, own turn. |

Sneaky Snunday open cases (stacked reversal, stat setting/copying, multipliers, self-cost
increases): **not reversed** in the prototype — only explicit gain/loss operations flip. Listed
as unresolved in the card-support ledger.
