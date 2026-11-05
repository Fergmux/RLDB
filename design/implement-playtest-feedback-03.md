# Implement playtest feedback 03

Copy this prompt into the existing implementation agent's conversation at the RLDB repository root.

---

Implement all 27 items in `design/playtest-feedback-03.md` in the existing Godot game. Continue from the current working implementation, preserving unrelated changes. Deliver integrated, playable improvements with evidence, not just a plan, mockup or report.

## Read and reconcile requirements

Read the complete feedback file, including acceptance checks and the confirmed Overextend clarification. Also read:

- `design/decision-register-answers.md` for confirmed mechanics and superseding corrections.
- `design/playtest-feedback-02.md` and `design/playtest-improvements.md` for previous UI requests, art direction and board-layout reference.
- `rules/09-PRODUCTION-QUALITY-PASS.md` for studio rigor, model routing, visual quality and verification requirements.
- The applicable rules, card data, current stories/tests and support ledger.

The latest explicit feedback overrides older rules only where it changes them. In particular, Arcane materials now require an exact total of current modified costs, with no overpayment. Overextend now chooses any opposing unit, retaining its opponent-summons/three-or-more-units trigger and 20-ATK reduction. Update conflicting live card text, rules, selection/availability logic and tests as part of implementation; preserve historical decision records by marking old decisions superseded rather than erasing them.

Verify the actual repository and Godot resource root before editing. The established layout is repository root `RLDB/` and Godot project `rldb/project.godot`. Preserve the existing engine version and project; do not restart setup or create another project.

## Use skills and specialist subagents

Inspect the installed studio skills and agent definitions. Follow their actual interfaces rather than guessing commands or assuming that mentioning a role spawns it. Use the production-quality instruction's full review/QA approach and verify effective settings, including overrides that might silently restrict team size or evidence requirements.

Use the lead agent to own the plan, shared interfaces, integration, questions and completion ledger. Delegate substantive bounded work to relevant specialists, for example:

- Godot/gameplay: exact Arcane materials, Fusion availability queries, Overextend targeting and HP reset correctness.
- UI/UX: reusable inspection views, pile browsing, consistent tags, player panels, deck builder and required-input prompts.
- Technical artist/UI programmer: card transitions, special-summon sequences, victory/defeat presentation, badges and actionable cues.
- Game designer/gameplay programmer: staged local tutorial, scripted opponent and enforced lesson progression.
- Independent QA: regression tests, two-client perspective/visibility checks, tutorial completion and adversarial interaction testing.

Use `/create-stories`, `/dev-story` and `/story-done` as appropriate. Use installed `/ux-design`, `/team-ui`, `/ux-review`, `/team-polish`, `/team-qa`, `/code-review`, `/regression-suite` and `/test-evidence-review` for their relevant work. Read each invoked skill and use its real argument syntax. Do not merely run review pipelines without implementing their findings.

Run independent work in parallel where useful, with clear file ownership and agreed interfaces. If multiple tasks touch one central UI file, assign one integration owner or serialize those edits. Do not overwrite another agent's work or send every specialist through the same uncoordinated file.

Explicitly route lightweight models to bounded audits, mechanical validation, test runs and evidence summaries; use Sonnet-class models for most implementation and stronger reasoning selectively for difficult architecture, timing, privacy and integration review, subject to actual availability. Keep specialized work and independent review substantive rather than spawning agents ceremonially. Report unavailable tools/model substitutions honestly.

## Plan against the real build, then execute

Create a per-item F03-01–F03-27 checklist with current behaviour, acceptance conditions, owner, status, test/evidence and blockers. Inspect and reproduce reported issues before deciding what needs changes. Fusion highlighting and Power mirroring may already partly work; verify rather than breaking correct behaviour. Do not classify a feature as done merely because a similarly named function exists.

Use a short dependency-aware implementation plan, then act on it. A sensible sequence is shared interaction/inspection foundations; rule/targeting fixes; board/details/deck-builder UI; animation/feedback; tutorial; integrated regression and polish. Keep runnable increments. Organize combined tasks where it improves implementation, but retain item-by-item coverage.

Ask focused questions when a material ambiguity cannot be resolved from the supplied documents or a missing asset/credential blocks the next step. Explain the concrete consequence and offer sensible alternatives. Do not re-ask answered questions, invent gameplay rules, or hold all independent work while waiting. Routine reversible implementation and faithful wording/layout choices are already authorized. Mark inferred choices as such rather than pretending the user approved them.

## Important integration constraints

- Right-click inspection is read-only and consistent everywhere, including inside the new near-full-screen pile browser. Returning from a single-card view restores browser context. Preserve hidden-information and randomized Draw-presentation rules.
- Existing click-selected card actions remain click-selected; the latest feedback does not restore action buttons on mere hover. Basic-unit name cleanup changes display names, not stable card identity or Type.
- Match exact Arcane validation across the authority, material picker, action highlights and tests. Hide zero-current-cost cards only from the Arcane material picker, not unrelated pile inspection.
- Power placements mirror both axes across perspectives and preserve physical relationships to unit rows. Do not rotate text upside down or change authoritative slot identity to fix display mapping.
- Targeting arrows originate at the effect source, including Overextend. Do not reuse an unrelated selected unit as the source.
- Healing above 60 remains legal; reset the next game's HP reference/display capacity correctly rather than introducing a healing cap.
- Draft category counts are configurable. Drafting and rewards use a combined Extra Deck category, while Fusion/Ritual/Arcane remain distinct gameplay types.
- Keep animations expressive and clear within the established dark-fantasy direction. Show correct material destinations without changing tribute/sacrifice/destruction semantics. Do not reveal hidden card identities to unauthorized players through centred animations, logs or network payloads.
- Separate presentation animations from authoritative effect resolution. Preserve nested triggers, pending choices, immediate defeat, response locks and reconnect safety. Avoid duplicated costs, triggers or rewards during animation completion and resynchronization.
- Build the tutorial with premade scenarios, a scripted opponent, highlighted guidance and enforced player steps using actual rules. A text slideshow or unrestricted bot match is insufficient. Keep tutorial-only restrictions out of normal play.
- Inspect and test UI changes, including smaller panels/badges, tag sizing, deck-builder thumbnails/grid, Protecting tags, Type-coloured choices and prominent input prompts. Do not substitute a generic recolour for the specific feedback.

## Verification and completion

Use meaningful automated tests for rules changes and regressions, including exact Arcane under/exact/over totals, modified costs, Overextend choosing a non-highest opposing unit, and HP display reset between games. Test shared availability logic against actual legal actions.

Launch and interact with the real game. Exercise all new inspectors, closing/back behaviour, pile selection, empty-space dismissal and prompt flows. Run two-client matches through a subsequent game to check Power mapping, hidden information, animations, target arrows, HP resets and result transitions. Complete the tutorial from its menu entry using the expected forced actions, and test restart/exit.

Capture relevant screenshots or short recordings under `production/qa/evidence/`. Review UI at intended window sizes with actual interactions, not just static screenshots. Have independent QA identify failures, fix them and rerun affected checks. If visual testing or Steam sessions are unavailable, state the precise limitation and continue other work; never claim that headless success verifies visual quality or real Steam multiplayer.

Continue until all applicable items are implemented and verified or a specific external/user decision blocks them. Do not stop after the easiest items or after delegating work. Keep incomplete/unverified items visible, with reasons. Finish with an F03 item-by-item result summary, test/evidence locations, how to run the build, any asset needs and remaining blockers. Update the feedback checklist truthfully; do not change Captured to Verified without verification.

Begin now by reading the feedback and latest decisions, inspecting the current build, and allocating the first bounded tasks to the appropriate specialists.
