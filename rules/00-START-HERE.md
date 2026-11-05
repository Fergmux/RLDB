# Card game build specification

Prepared 15 October 2026 from the design discussion and the two supplied RLDB CSVs. This is a reconciled specification, not a transcript. Later explicit corrections replace earlier statements.

## Files

**After the current setup phase is complete, read and apply [08-POST-SETUP-FULL-GAME-BUILD.md](08-POST-SETUP-FULL-GAME-BUILD.md) before continuing implementation. If setup is already complete, apply it now without restarting completed work.** It updates the execution approach to use studio skills and a focused specialist team for the complete game.

| File | Contents |
| --- | --- |
| [01-GAME-RULES.md](01-GAME-RULES.md) | Board, turns, costs, combat, type advantage, card destinations, sacrifice, tribute, special summoning, timing and series progression. |
| [02-STATUSES.md](02-STATUSES.md) | All 15 supplied entries, including Rune as a separate counter; corrected Cleanse and Retain behaviour; suppression and reset rules. |
| [03-CARD-CATALOG.md](03-CARD-CATALOG.md) | All 183 named cards with IDs, stats, effects, conditions and artwork references. Incorporates the two confirmed misplaced on-summon effects. |
| [04-VIDEO-GAME-DESIGN.md](04-VIDEO-GAME-DESIGN.md) | Godot/Steam multiplayer, button interactions, response prompts, reconnection, hidden information, dynamic cards, inspection and game log. |
| [05-BUILD-PLAN-AND-ACCEPTANCE.md](05-BUILD-PLAN-AND-ACCEPTANCE.md) | Recommended implementation architecture, milestones and concrete behaviour checks. Recommendations are distinguished from confirmed design. |
| [06-OPEN-DECISIONS-AND-CORRECTIONS.md](06-OPEN-DECISIONS-AND-CORRECTIONS.md) | Unresolved edge cases, configurable mode values, source corrections and import limitations. |
| [07-BUILD-AGENT-PROMPT.md](07-BUILD-AGENT-PROMPT.md) | Copyable implementation prompt for an agent working in the existing Godot repository. |
| [08-POST-SETUP-FULL-GAME-BUILD.md](08-POST-SETUP-FULL-GAME-BUILD.md) | Updated post-setup execution instruction: use studio skills, focused subagents, appropriate standard rigor and full-game verification. |
| sources/ | Unmodified copies of both supplied CSVs. These preserve provenance; their superseded wording is not authoritative over the reconciled rules. |

## How to use

This package is placed in the existing repository's `rules/` folder. Give the implementation agent the text in `07-BUILD-AGENT-PROMPT.md`. The studio template is optional tooling; this specification does not require starting a new repository or replacing `project.godot`.

Verified handoff layout: repository/studio root is `C:/Users/fergm/Documents/code/RLDB`; the existing Godot project is in `rldb/project.godot` below that root. Start Claude Code at the repository root to load the studio tooling, and point engine run/import commands at `rldb/`. Ensure generated game code and resources are inside the actual Godot resource root, or deliberately reconcile the layout without silently creating a second project. The root `src/` folder from the template is outside the existing Godot resource root.

## Authority

**Subsequent user decisions:** Read `design/decision-register-answers.md` at the repository root. It records the completed review of the implementation agent's P-01–P-31 proposals and four Sneaky Snunday questions. Its final confirmed answers and explicit corrections override conflicting prototype proposals and older open notes in this package. Some mode quantities are deliberately unspecified/configurable; do not invent fixed rules for them.

Confirmed rules in files 01, 02 and 04, plus explicit corrections in 06, override conflicting source CSV wording. File 03 preserves card details with stated corrections. File 05 contains engineering recommendations, not newly confirmed game mechanics. File 06 must remain visible: unconfirmed rules must not silently become canon.

The intended product is a two-player game with Steam matchmaking and friend invitations. Earlier single-player examples were illustrative estimates, not the user's chosen product scope. Artwork will be provided separately. This package contains no game implementation or supplied artwork.
