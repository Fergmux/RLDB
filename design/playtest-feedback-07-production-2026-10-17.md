# Playtest feedback — production polish and correctness

Date: 17 October 2026
Status: implementation requested. Read with `implement-production-batch-2026-10-17.md`.

## Quality bar and source of truth

The owner explicitly wants the game to look and feel as flashy, polished and professional as possible: full production quality, no shortcuts or prototype substitutes. Preserve the established direction: Hearthstone-like tactile readability and expressive feedback with The Witcher's darker fantasy atmosphere. Use deliberate typography, spacing, composition, animation, sound and responsive controls throughout. Fancy effects must support readable gameplay and must not conceal game state or steal input.

This document includes bugs to investigate, explicit behavior changes and visual improvements. Verify existing behavior before changing it; do not treat a suspected bug as proof. Latest explicit requirements here supersede older conflicting feedback for the same feature. Preserve unrelated confirmed rules and use stable card IDs. Implement in the existing Godot project, not a replacement project. Read earlier inspection, aspect-ratio, hidden-information, exact Arcane-payment and on-card action requirements as context.

## F01 — Stable deck-selection modal

Keep the Choose Your Deck modal's outer maximum dimensions and intended layout consistent across tabs, including empty tabs and tabs with few decks. Content may scroll inside it; switching tabs must not cause the whole modal to collapse or jump. Handle small windows responsively without clipping.

## F02 — Self-buff animation regression

Reproduce the intermittent case where a unit applying a buff to itself causes the whole card to rise with its floating status indicator. Separate the status animation transform from the card's layout/selection transform. After repeated and overlapping self-buffs, the card must remain anchored in its zone, with no cumulative drift, stuck tween or broken hitbox. Check animation interruption and cleanup as well as normal completion.

## F03 — Type-choice icon alignment

Correct vertically misaligned type icons in type-selection buttons, including Waang. Center icon and label consistently; scale icons within fixed button/tag bounds. Check all damage types, supported UI scales and the other type-choice cards. Retain type colors and readable labels.

## F04 — Actionable Extra Deck pile viewer

When the right-hand pile viewer shows Extra Deck cards, always show a Summon button for each currently legal Fusion, Ritual or Arcane summon without requiring selection of that card first. Unavailable cards must not present an enabled action. Use the same authoritative legality checks as the real summon, including phase, materials, AP/effect costs, usable fusion method and destination space after materials leave.

For Fusion, if multiple valid fusion methods are available, open the card-picker modal to choose the method, then continue the normal flow. Do not pick a method arbitrarily. Check existing Ritual/Arcane support and bring it to the same behavior. Revalidate if state changes while the viewer is open. Pile visibility restrictions still apply.

## F05 — Card context in input prompt

When the left input panel requests a decision about a card (for example where to summon it), display that card's image and readable description within the panel as well as the instruction. Use current visible card data and avoid leaking hidden opponent information. Keep the panel usable at supported resolutions.

## F06 — Suppress distracting hover during zone selection

While choosing a summon destination, disable existing field cards' normal hover enlargement/action overlays and related decorative hover motion. Keep legal destination highlighting and essential selection guidance active. Restore ordinary hover reliably on completion, cancellation and interruption.

## F07 — Streamline special-summon confirmation

Remove the redundant extra confirmation screen for special summons. The Attack/Defense stance decision is the final step; its confirmation commits the summon. Put Confirm and Cancel on the same row. Validate legal costs/targets before commitment and handle stale state without spending materials/AP twice. Cancellation before commitment must not consume resources.

## F08 — Exact-cost Arcane material UI

Replace the textual Selected... payment display with empty circles representing the required cost. Selecting a material fills circles equal to its current modified cost; deselecting restores them. Clearly indicate exact payment and remaining cost.

Exclude zero-cost units and any material costing more than the total requirement from initial options, consistent with previous feedback. After a partial selection, visibly disable any further option that would exceed the remaining amount; a disabled-state tooltip should explain “Cannot overpay”. Keep selected items deselectable. Enable continuation only at the exact required total. Never silently allow overpayment. Use the actual current modified costs and authoritative eligibility rules; Extra Deck units cannot pay this material cost. Verify zero-required-cost handling against existing rules rather than inventing a new resource rule.

## F09 — Sanctified Blade: verify optional Medic activation

The owner observed that Sanctified Blade's Apply Medic ability appeared to activate automatically without allowing them to decide. This is a suspected bug, not a confirmed reproduction. Current card text includes an optional once-per-turn Apply 3 Medic to an Adjacent Unit ability. Inspect the latest reconciled data and actual handler, reproduce it, and test whether it waits for deliberate activation and a legal target choice as its text requires. Verify that it neither auto-activates nor consumes its use from an unrelated event. Preserve its separate on-summon effect. Record the investigation and result, even if existing behavior is already correct.

## F10 — Reward selection by clicking card

In Add a Card rewards, after choosing a category and viewing the three offered cards, clicking a card selects/takes it through the existing reward flow. Remove the redundant Take Card button and click icon below each card. Preserve right-click inspection, legal reward limits and duplicate-click protection.

## F11 — More capable bot stance decisions

Replace the simplistic rule that always chooses Defense when DEF exceeds ATK. Evaluate whether the unit can usefully attack opposing current ATK/DEF, benefit from a protected position, create pressure or improve board safety. Avoid passive stalemates caused purely by the stance heuristic. Consider direct attack opportunities and legal existing stance changes as well. Use bounded, explainable decision scoring; do not grant hidden-information access or change battle rules. Test representative situations and full bot games, including positions where Attack is useful despite DEF being higher.

## F12 — Winning attack cinematic

Extend the existing winning-direct-attack slow-motion/impact presentation to a game-winning attack against a unit. Trigger only after authoritative resolution confirms the win, including trap responses and prevention effects; do not preview a win that fails to occur. Preserve event order and restore time scale/input cleanly on scene changes, cancellation and match end.

## F13 — Default antialiasing

Set default antialiasing to 4x using the actual Godot renderer/viewport path that affects this game. Verify the result rather than changing an irrelevant setting. Preserve existing explicit user preferences if applicable and confirm performance/compatibility on supported renderers.

## F14 — Comprehensive card-catalogue design pass

Redesign the card-list/catalogue page to the same quality as the improved deck builder. Include search, useful filters, clear card browsing and a right-hand selected-card preview pane. Provide strong hierarchy, art, hover/selection feedback, right-click inspection, sensible empty/no-results states and responsive scrolling. This is a complete usability and visual pass, not a cosmetic heading change. Reuse established UI components where appropriate without coupling browsing to deck editing.

## F15 — Remove deck-builder instructional clutter

Remove the 183/183-style catalogue count and Click to... explanatory text beneath the filters entirely. Do not replace them with equivalent clutter.

## F16 — Fixed-width count tags and deck cap

Keep the deck-summary category count tags a consistent width with room for two-digit values through 99; changing counts must not shift surrounding layout. Apply a deck limit of 99 cards. Do not add visible limit labels, explanatory text or new hints about the cap. Use the existing legal-action availability pattern to prevent adding beyond it.

This supersedes the earlier unrestricted custom-deck requirement for the requested cap. Before implementation, establish whether current deck model counts main and Extra Deck separately; the user did not explicitly define whether 99 is combined or per deck. Raise that scope in the upfront questions if it cannot be inferred; if unanswered during unattended work, choose and document a consistent interpretation. Preserve existing oversized saves safely rather than silently deleting cards. Apply the chosen validation consistently across editing/importing/saving/start validation while avoiding unrelated changes to draft/reward rules.

## F17 — Stable deck-card ordering

Sort the cards already in a deck by the same canonical catalogue order, not insertion order. Quantities stay grouped and order remains stable across add/remove, save/load and filtering. Match by stable ID, not current display name.

## F18 — Consolidate add/remove controls

Remove duplicate plus/minus buttons from catalogue/deck card entries; retain add/remove controls only in the middle preview pane. Move the per-card quantity indicator from over the artwork to just below the card, maintaining a clear association. Preserve keyboard focus and inspection behavior.

## F19 — Simpler deck-builder stats

In the middle card preview, show prominent ATK and DEF labels/values without separate Base and Current versions: this is deck construction, where those values are the same. Render dynamic/unknown printed stats appropriately. Do not remove needed base/current distinctions from live-match inspection.

## F20 — Saved/Starter deck selector buttons

Make Saved Decks and Starter Decks buttons match the proportions, visual style and spacing of other established buttons; they currently look too thin and wide. Remove counts in parentheses from their labels. Check selected/focus/hover states and small-window layout.

## F21 — Escape navigation and unsaved changes

When no inspection modal is open, Escape in the deck builder invokes exactly the same Back flow as the Back button, including any existing unsaved-change handling. When inspection is open, Escape closes that first and does not also leave the screen. Avoid duplicate navigation from propagated input.

## F22 — Navigation sound

Going back from any screen plays a consistent appropriate sound. Include Back button and Escape/controller equivalents where supported. Integrate with centralized UI audio so one action produces one sound rather than both a generic click and duplicate back sound.

## F23 — Delete only saved decks

Hide Delete for unsaved/new deck state. Show it only when there is an actual saved deck to delete, preserving existing confirmation and correct state after save/delete/switch. Starter deck handling must follow its actual editability rules.

## F24 — Animated and audible deck edits

Adding/removing cards must have polished, readable animation and an appropriate sound instead of an instantaneous visual jump. Update canonical data correctly and promptly; presentation cannot cause lost clicks, negative quantities, duplicate edits or stale lists. Handle rapid edits and scrolling gracefully, retain stable catalogue order and quantity indication, and respect audio settings.

## F25 — Consistent button-click audio

All actionable buttons should have a small, polished click sound. Consider coordinated but distinct sounds for yellow versus brown button families if it strengthens the existing design. Wire through shared components rather than hand-maintaining inconsistent signals. Disabled buttons do not sound like successful actions. Prevent accidental double playback, respect mute/volume, and use licensed existing or appropriately sourced assets. Do not substitute random unrelated sounds.

## F26 — Reusable per-card behavior tests

Add a maintainable, runnable test suite for every identified card in the reconciled catalogue (currently 183 stable IDs), including basic cards and all Extra Deck categories. Create a card-ID-to-test coverage manifest and a focused runner so the agent can execute individual card tests or the complete suite when appropriate. Assert gameplay outcomes rather than merely snapshotting description strings or checking that a handler exists.

Cover applicable timing, optional versus mandatory activation, legal/illegal targets, costs and persistent cost changes, durations, counters/statuses, zone transitions, once-per-turn limits, summon/material conditions and relevant interactions. Card-specific behavior needs card-specific assertions; shared parameterized tests are welcome where the semantics are genuinely shared. Include explicit regressions for Sanctified Blade and changed cards. If text remains materially unresolved, mark the exact behavior pending and report it rather than claiming coverage with an empty/skipped assertion. Avoid excessive combinatorial tests: prioritize meaningful boundaries and known interactions, backed by system tests.

## Cross-cutting acceptance

- All F01–F26 have an implementation or verified-already-correct result and reproducible evidence.
- Perform repeated running-game visual reviews, screenshots and interaction checks; headless tests alone do not establish visual production quality.
- Preserve 2:3 card proportions, horizontal Defense orientation, existing inspection/hidden-information rules and the no-drag-and-drop input model.
- Test overlapping animations, rapid input, cancellation, multi-client view consistency, phase changes and screen transitions.
- Exercise real bot/local matches plus networked smoke tests where available. Inspect logs and independently look for related gameplay bugs, clipping, alignment, missing feedback, stuck overlays and inconsistent controls.
- Implement closely related defects found during verification; log materially unrelated discoveries separately. Do not use a polish pass as justification for uncontrolled redesign of game rules.
- No placeholder assets, fake metrics, untested shortcuts or declaration of production readiness based solely on successful compilation. Report concrete evidence, outstanding risks and any missing assets honestly.
- See the companion master instructions for upfront questions, unattended decisions, context recovery and subagent/debug-session liveness checks.
