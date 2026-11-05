# Build plan and acceptance

This file recommends an engineering approach. It does not add unconfirmed game rules.

## Architecture recommendations

Keep card definitions separate from per-game card instances. Definitions retain stable source IDs, text, art references and explicit cost kind. Instances own current zone, owner/controller, current/persistent costs, counters, modifiers and use limits. Never mutate a shared definition to change one card instance's cost.

Use a deterministic rules layer independent of Godot UI. Player input produces validated commands; resolved events update state and drive presentation and history. Have one authority decide legality, randomness, costs, responses and outcomes. Clients request actions and render authorized state. Record random seeds/order internally for reproducible tests while keeping Draw order private.

Use typed effects/operations, explicit trigger events, modifier lifetimes and a resumable pending-choice state. Do not attempt to execute unrestricted English card descriptions at runtime. Preserve original descriptions for inspection, but map each supported card to validated behaviours. Share operations across cards and keep exceptional logic explicit. Current Type/Race/stat/cost copy semantics need the decisions in file 06.

A pending choice identifies controller, permitted responses and the suspended action. Revalidate a command against current state and authority before committing. Keep prompt/phase state synchronized across clients. Distinguish optional trigger ordering from response windows and nested resolution.

Use Godot scenes/Controls for presentation and reusable card widgets. Use Resources or validated data files for card definitions as appropriate to the repository. Respect the existing project structure, installed engine and repository instructions. Verify current official Godot and chosen Steam integration documentation before coding version-sensitive APIs.

## Milestones

1. **Inspect and scaffold:** verify `project.godot`, engine version, renderer, source structure and framework setup. Add a runnable main scene without replacing existing project settings. Import all source records and apply explicit reconciliation rules.
2. **Rules and complete local match:** implement zones, turn phases, AP, targeting, combat, spent/exhaust recycling, immediate defeat and a small representative card set. Provide a development harness for two local seats so the rules can be exercised before external networking is available.
3. **Responses and statuses:** implement all statuses, Rune counters, trigger ordering, indefinite trap prompts and visibility-aware game history. Verify suspend/resume behaviour before adding more effects.
4. **Special summons and full catalogue:** implement Fusion/Ritual/Arcane rules, revivals, persistent costs, dynamic stats, control changes and exceptional effects. Import all 183 definitions early; expand tested gameplay support incrementally. Maintain an explicit per-card supported/untested/blocked ledger; never present inert cards as fully implemented.
5. **Network authority:** run two actual clients, synchronize validated commands/events, prevent out-of-turn/racing inputs and redact hidden state. Add reconnect pause/resume with pending choices intact. Keep transport isolated for local testing and Steam integration.
6. **Steam flow:** integrate matchmaking and friend invitations with a verified compatible integration. Exercise creation/join/invite and reconnect using actual Steam-capable sessions. Report environment/credential blockers concretely without pretending local transport proves Steam works.
7. **Deck/draft/series:** add configurable modes, deck selection, drafting, both-player rewards, series score and full between-game resets. Keep proposed prototype defaults documented separately from confirmed rules.
8. **Presentation and release candidate:** dynamic cards, detail panels, legible buttons, clear prompts, log navigation and eventual supplied art. Run two-client complete series tests and produce an actual runnable export with clear run/setup instructions.

The final requested product includes all confirmed multiplayer and progression requirements. A milestone prototype is useful progress, not a reason to label the entire project complete.

## Required behavioural checks

| Scenario | Expected result |
| --- | --- |
| Normal turn refresh with 1 AP unused | AP becomes exactly 2; draw 4 fresh cards. |
| One retained card | Keep it, consume one Retain at discard prevention, draw 4 more next turn. |
| First overall turn | No Battle Phase; second player's first turn permits battle. |
| Water ATK 8 attacks Fire ATK 10 | Compare 14 vs 10; destroy Fire; its controller loses 4 HP. |
| Fire ATK 10 attacks Attack-stance Water ATK 8 | Defending Water compares at 14; Fire destroyed; attacker controller loses 4 HP. |
| Equal ATK against Attack stance | Destroy both; no HP damage. |
| ATK 8 against DEF 10 | Destroy neither; attacker controller loses 2 HP absent type/modifier changes. |
| Attacker wins against Defense | No excess HP damage unless Pierce applies. |
| Eternal saves losing Attack-stance defender | Normal excess HP loss still occurs; destruction prevented, Eternal consumed. |
| Diggie with occupied opposing field | Direct HP attack is legal; a normal unit's direct attack is not. |
| Blind with protected enemies | Random selection only among legal targets; Infiltrate can expand legality. |
| Sacrifice Cliff / tribute Cliff from Field | +3 AP / +2 AP respectively. |
| Newly summoned material | Tribute is allowed; sacrifice is not. |
| Arcane requirement 3A; eligible Spent units current costs 2 and 2 | Legal overpayment; exhaust both, no AP payment. **[Superseded by F03-04: illegal — 2 + 2 = 4 is not exactly 3; nothing is consumed.]** |
| Extra-deck unit with apparent numeric special cost | Not eligible as ordinary AP Arcane material or ordinary cost-2 target. |
| Roma using unit with 3 Runes | Consume its full count through tribute; Roma starts at 36 ATK/DEF. Zero-Rune material illegal. |
| Extra-deck card in recycled Spent | Returns to Extra Deck, not Draw. |
| Draw and Spent unavailable | Skip unavailable draws; no fatigue damage or loss. |
| Necrovast destruction effect | Can move exhausted card to Draw; ordinary effects cannot bypass exhaustion without explicit permission. |
| Cleanse 1 on multiple debuffs | Remove all debuffs and consume Cleanse completely. Rune unaffected. |
| Debilitate on aura source after earlier instant grant | Suppress aura, preserve earlier resolved instant grant. |
| Unit leaves Field | Reset field stats/statuses; preserve explicit persistent self-cost changes. |
| Magic Cylinder responds to attack | Resolve its HP loss first; continue battle if still legal and no defeat. |
| Mirror Force removes attacker | Pending battle does not resolve. |
| Own HP reaches zero in 'you lose HP and then opponent loses HP' | Lose immediately; second step never resolves. |
| Active Narzyl destroys Gaping Crevasse | Narzyl Rune trigger first; Crevasse Paralyse trigger second. |
| Own-turn Battle actions | Cast Spell/use allowed ability; normal summon/set/stance change illegal. |
| Set Spell then activate same turn | Pay once on setting; legal own-turn activation later. |
| Trap prompt pending | Other client cannot progress action/phase; waits indefinitely. |
| Disconnect during prompt | Pause; reconnect restores same choice without duplicate resolution. |
| Own Draw inspection | Correct contents, randomized display order, actual Draw order unchanged. |
| Opponent log/inspection | No hidden identities/order leak; counts remain visible. |
| New game after rewards | HP 60, no old statuses/runes/exhaust/cost changes; chosen deck/reward changes persist. |

## Sneaky Snunday checks

- Shimmer Serum's +16 ATK becomes -16, floored at zero, while its status application remains unchanged.
- Divine Serpent's 30 damage becomes 30 healing to the same opponent.
- Delayed Gratification played under reversal causes -1 AP next turn even after reversal expires.
- Already-resolved instantaneous bonuses do not flip retroactively.
- Existing continuous adjacent +10 DEF aura becomes -10 DEF while reversal is active and returns according to normal aura recalculation afterward.
- Ordinary battle damage and AP payments do not reverse.

## Verification evidence

Use meaningful automated rules tests and a two-client integration test for pending choices, hidden information and reconnect. Launch the game and inspect UI at actual window sizes; retain screenshots of board, target selection, response prompt, details and history. Parse/import success alone is not proof of a playable game. Verify log order matches resolved event order and that redaction is enforced in payloads, not just visible text. Record unverified Steam/export checks honestly.
