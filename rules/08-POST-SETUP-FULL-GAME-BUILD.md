# After setup: build the complete game with studio skills and subagents

This is the user's updated execution instruction. Read and apply it once the current setup phase is complete. If setup is already complete, apply it now. Preserve completed work and continue from the current state; do not restart setup.

## Outcome

Finish the setup currently underway, then use Claude Code Game Studios' skills and specialist subagents to build the complete playable game described in `rules/`.

The intended outcome is the full game, not just a scaffold or a small prototype. A representative playable match is the first milestone, not the final deliverable.

## After setup

1. Read the installed studio workflow and agent definitions. Use its actual skills for design gaps, architecture, stories, implementation, QA and review. Do not assume skill names or capabilities.
2. Move to standard rigor where useful. Keep documentation concise and spend most effort on implementation and verification. This instruction supersedes the earlier recommendation to remain on minimal rigor throughout implementation.
3. Have the lead agent own architecture, shared interfaces, integration and progress. Delegate bounded tasks to relevant Godot, gameplay, UI, networking and QA specialists. Run independent tasks in parallel when their interfaces and file ownership are clear.
4. Use independent specialist review for combat calculations, effect timing, hidden information, multiplayer synchronization and reconnection. Resolve findings and verify fixes rather than merely collecting reviews.

Treat the reconciled `rules/` specification as authoritative. Preserve confirmed rules and corrections. Track unresolved decisions explicitly; ask only when a decision blocks meaningful progress, and continue independent work meanwhile.

## Complete scope

- Core match flow, combat, statuses, effects and all three extra-deck summon systems.
- Working behaviours for all 183 cards, with an explicit implementation and verification ledger.
- Button-based interactions, target/material selection, live stats, card details and the game log.
- Trap-response prompts that pause progression and wait indefinitely.
- Correct hidden-information handling in UI, logs and network messages.
- Two-player networking, Steam matchmaking, friend invitations, and pause/reconnect behaviour.
- Deck selection, drafting, configurable series and between-game rewards for both players.

Use milestones that produce runnable, integrated improvements. Do not leave specialist work isolated or substitute planning documents for working features. Placeholder artwork is acceptable until the user provides the art; missing artwork must not block gameplay.

## Verification

Run meaningful rules tests, launch and inspect the actual Godot game, and test two clients through complete matches and a series. Include interrupted connections and pending trap responses. Verify Steam features in a suitable environment; clearly identify external blockers without claiming untested functionality works.

Continue beyond the first playable milestone until the agreed scope is implemented and verified, or a concrete blocker requires user input. Maintain a clear checklist of completed, incomplete and blocked features. Before calling the project complete, perform a requirement-by-requirement review against `rules/` and fix the remaining gaps.

Use a small, purposeful team rather than spawning every available agent. Give concise progress updates explaining what is playable, what was tested, and what remains.
