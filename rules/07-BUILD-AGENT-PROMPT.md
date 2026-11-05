# Build-agent prompt

Copy the prompt below into an implementation agent opened at `C:/Users/fergm/Documents/code/RLDB`. The accompanying specification is in `rules/`. The existing Godot resource root is the nested `rldb/` folder containing `project.godot`; account for that in run/import commands and generated resources. The studio template's root `src/` is outside that Godot resource root. Do not silently create a second Godot project.

---

Build the card game defined by the accompanying specification in this existing Godot repository. Deliver a playable, tested game in working increments and continue toward the full confirmed scope. Work from the actual project and installed engine. Preserve existing Git history, `project.godot` and useful project settings. Do not create a nested repository or replace this project with a different engine or web demo.

## Read these files

**Setup completion checkpoint:** Once the current setup phase is complete, read and apply `rules/08-POST-SETUP-FULL-GAME-BUILD.md` before proceeding with implementation. If setup is already complete, apply it now. It supersedes the earlier minimal-rigor recommendation for the post-setup build. Preserve existing work and continue toward the full playable game using studio skills and specialist subagents.

- `00-START-HERE.md`: file map, authority and package context.
- `01-GAME-RULES.md`: confirmed board, turns, combat, AP, types, destinations, summons, timing and series rules.
- `02-STATUSES.md`: all statuses and Rune counters with corrected consumption and suppression behaviour.
- `03-CARD-CATALOG.md`: all 183 cards, stable IDs, source stats, effects, requirements and art references.
- `04-VIDEO-GAME-DESIGN.md`: button-driven UX, Steam multiplayer/invites, dynamic card displays, visibility, reconnect, response prompts and game log.
- `05-BUILD-PLAN-AND-ACCEPTANCE.md`: recommended architecture, ordered milestones and concrete acceptance scenarios.
- `06-OPEN-DECISIONS-AND-CORRECTIONS.md`: unresolved settings and edge cases, exact source corrections and Sneaky Snunday semantics.
- `sources/`: unmodified source CSVs for provenance and import verification. Confirmed specification corrections override superseded CSV wording.

First inspect repository instructions, engine version, existing scenes and source layout. Finish current setup without restarting completed work. Then follow `rules/08-POST-SETUP-FULL-GAME-BUILD.md`: use installed studio skills and a focused specialist team, with standard rigor where useful, keeping this game specification authoritative. Avoid extensive process documentation before producing runnable code. Do not switch the user to a new repository or repeatedly ask permission for routine reversible implementation work already authorized by this request.

## Product requirements

The game is a two-player roguelike deck builder with configurable series and rewards for both players between games. It needs Godot networking integrated with Steam matchmaking and friend invites. A local development harness is useful for verification but does not fulfil the Steam requirement. Individual artwork will be supplied later; use attractive, readable placeholders without blocking the rules implementation.

Use buttons and explicit selections, never drag-and-drop. Automatically calculate all legal actions, costs, damage, HP, modifiers, triggers and statuses. Display current card stats and status counts live, with a full details view. Provide a readable scrollable game log for reviewing past actions, resolution order and public calculations.

Pending opponent trap responses must suspend active-player progression indefinitely until the choice resolves; no automatic pass. Multiple eligible traps are ordered by their owner. Disconnects pause the match and permit reconnection. Do not duplicate an action, payment or trigger when reconnecting.

Respect hidden information in the UI, log and network payloads. Opponent Hand, Spent, Exhaust, Extra Deck, Draw and unrevealed set cards are hidden, though counts are public. Owners inspect their own piles. Own Draw inspection reveals contents in a randomized display order without exposing or changing actual Draw order. An effect requiring selection from a hidden pile reveals that entire pile only to the chooser for the selection.

## Engineering approach

Keep a deterministic rules model separate from presentation, networking and card art. Use stable definitions and independent card instances. Encode effects as validated reusable operations with explicit exceptional behaviours; do not rely on unrestricted interpretation of English text during play. Make costs typed: ordinary AP, Ritual and Arcane requirements are distinct.

Use one authority to validate commands and resolve randomness/effects. Clients request legal actions rather than mutating game state. Keep pending choices, trigger ordering, effect steps and state changes explicit and resumable. Validate ownership, phase, AP, material eligibility and targets when committing commands. Redact unauthorized state per player. Document the trust limits of any player-hosted design.

Use suitable Godot UI scenes and data formats compatible with the existing project. Check current official Godot and chosen Steam integration documentation for version-sensitive APIs. Do not install arbitrary integrations or assume credentials exist. Isolate transport so rules tests and two-client local tests can run before Steam setup is available. Continue independent implementation if an external setup item is blocked, and report the specific missing item honestly.

Import all 183 definitions, preserve IDs, and exclude the unnamed orphan source row. Apply confirmed corrections from file 06. Track which cards have working, tested behaviours; do not silently treat unimplemented effects as blank cards. Build shared effect primitives first, then verify each card's mapping and exceptional cases.

## Execution

Start with a short implementation plan and identify only the decisions that block the immediate increment. Resolve routine engineering choices independently. For undefined mechanics, keep a visible decision register and configurable prototype defaults; label them as proposals rather than confirmed rules. Ask targeted questions only when the next step truly depends on an answer. Do not silently redesign the card game.

Deliver a complete runnable match with representative cards first, then complete statuses, special summons and all cards, network synchronization, Steam flows, reconnection, drafting/decks, both-player rewards, configurable series and visual polish. Do not stop after a scaffold, design document or prototype if required work remains. Do not claim the complete game is finished while Steam integration, card effects or progression are still stubbed.

## Verification and completion

Exercise the acceptance examples in file 05 with meaningful rules tests. Run two-client tests for response suspension, illegal/out-of-turn inputs, hidden-state redaction and reconnect during a pending prompt. Launch the game and inspect board layout, selection flows, response prompts, details, log and game/series end screens. Capture screenshots where useful. Parse/import success alone does not establish playability.

Special care: preserve the confirmed battle timing changes; retain one stack per prevented discard; keep runes outside buffs; distinguish sacrifice/tribute/destruction; apply type advantage to either combatant; preserve persistent costs within a game but reset between games; return extra-deck cards during Spent recycling; and implement Sneaky Snunday with the exact scoped reversal behaviour rather than a global sign flip.

Finish each increment with what runs, how to run it, what was verified and the remaining work. For final delivery provide the runnable project/export, concise setup instructions, actual test results, card-support coverage and any remaining decisions or external blockers. Never describe untested Steam matchmaking or reconnection as verified.
