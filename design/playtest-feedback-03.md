# Playtest feedback 03 — two-player session

Implementation handoff: [implement-playtest-feedback-03.md](implement-playtest-feedback-03.md) contains the companion prompt for the build agent, including skill/subagent use, clarification policy and verification coverage.

## Purpose

Feedback from the user's latest playtest with a friend, interpreted and organized for the implementation agent rather than transcribed verbatim. This file captures requests only; it does not claim that fixes have been implemented or verified.

## Capture conventions

- Give each distinct issue a stable ID: F03-01, F03-02, and so on.
- Separate the reported observation from the desired behaviour, implementation implications and acceptance checks.
- Preserve useful reproduction details, player perspective and sequence when supplied. Do not invent a technical root cause from symptoms alone.
- Identify explicit changes to earlier requests or rules. Keep unresolved ambiguity visible and ask a focused clarification where it materially changes the result.
- Keep suggestions distinct from requirements and do not assign priority unless the user specifies it.
- Use statuses: Captured, Needs clarification, In progress, Implemented — unverified, Verified.
- Reconcile implementation with `decision-register-answers.md`, the rules specification and earlier feedback. New explicit feedback supersedes conflicting older feedback only for the affected requirement.

## Feedback items

## F03-01 — Consistent right-click card inspection

**Status:** Captured.

**Requested behaviour**

- Anywhere an inspectable card is displayed, right-clicking it opens an enlarged, front-and-centre inspection view. This includes cards on Field and cards shown in lists, pile browsers and other card displays.
- Show the card large enough to read and include all available card information: artwork, identity, complete effects, current stats/cost, Race/Type, stance where applicable, modifiers, statuses and Rune counters as appropriate.
- Card inspection must also work when the card appears inside the pile-inspection modal described in F03-02.

**Interaction and implementation guidance**

- Inspection is read-only. Right-click must not select an effect target, play a card, spend AP, activate an ability or change pile order.
- Preserve existing left-click selection/action flows and the distinction between card details and gameplay actions.
- Provide a clear close/back path. Closing an individual card opened from a pile should restore the same pile browser, including scroll position and selection context, rather than dropping the user back to the board.
- Preserve 2:3 upright card proportions and readable information; use the enlarged view to avoid tiny text rather than stretching the card.
- Apply established visibility permissions. A hidden opposing card is not inspectable merely because its card back is displayed. Do not reveal unauthorized information in the large view.
- If multiplayer state updates while an inspection view is open, keep displayed data consistent and revalidate any later gameplay selection; inspection does not itself grant a rules-side pause.

**Acceptance checks**

- Right-click a visible Field card, Hand card and card in a list: each opens the same readable large-card inspection experience.
- All relevant card information can be read, including dynamic changes and full effects.
- Right-click a card within a pile browser: its individual inspection opens; closing it returns to the same browser position without altering the pile or choosing the card.
- Inspecting a card never commits an action or bypasses hidden-information restrictions.

## F03-02 — Large, space-efficient pile inspection

**Status:** Captured.

**Requested behaviour**

- Right-clicking a pile such as Spent or Draw opens a near-full-screen modal showing its inspectable contents.
- Display the cards large and readable, arranging the list to fill available space efficiently rather than leaving a narrow column or excessive unused area.
- A responsive wrapped list/grid is an appropriate interpretation of the requested space-efficient list; exact row/column counts are not specified. Preserve card proportions and do not shrink cards until unreadable just to avoid scrolling.
- Cards in this browser support right-click individual inspection under F03-01.

**Interaction and implementation guidance**

- Include clear pile identity, card count and a close/back control. Support scrolling when contents exceed the readable viewport.
- Keep browsing separate from card-selection prompts: inspecting a pile does not make an arbitrary card available for play or transfer. When an effect permits selection, preserve its authorized pool and existing click-to-choose behaviour.
- Respect established permissions: owners can inspect their own piles; opponents' contents remain hidden unless an effect explicitly permits access. Public counts alone do not authorize browsing identities.
- Own Draw inspection shows contents in a randomized presentation order without revealing or changing actual Draw order.
- Preserve layout/readability across supported window sizes. The modal must block accidental clicks through to the board while open.

**Acceptance checks**

- Right-click own Spent and Draw: a near-full-screen browser opens with large cards using the available area effectively.
- Test empty, small and large piles; layout handles each without clipped cards, broken scrolling or inaccessible controls.
- Draw contents are accurate but actual ordering remains private and unchanged.
- Right-clicking a browser card opens its individual inspection and restores browser context on close.
- Opponent pile contents cannot be revealed through this shortcut without an explicit selection/inspection permission.

**Implementation/verification notes:** Documentation capture only. No UI code changed or functionality verified by these notes.

## F03-03 — Consistent metadata tags with contained icons

**Status:** Captured.

**Reported observation**

Card metadata tags appear in details panels and lists, showing information such as cost and damage Type. Some Type tags include oversized icons that increase the tag's dimensions and disrupt consistency.

**Requested behaviour**

- Keep metadata tags consistently sized and aligned across the UI, including tags with icons and text-only tags.
- Constrain icons to the tag's content area and scale them down to fit, preserving their proportions. An icon's source resolution must not drive the tag's minimum size.
- Use consistent padding, icon bounds and text alignment so adding a Type icon does not make one tag disproportionately taller or larger than its peers.
- Keep the text and icon readable without clipping, stretching or overlapping neighbouring tags.

**Implementation clarification**

The user's requirement is consistent tag sizing rather than uncontrolled growth from icons. Exact pixel dimensions and whether all text labels must occupy identical widths are not specified. Use a shared component/style with uniform height and sizing rules; do not silently truncate longer metadata or force unreadably small text merely to impose a fixed width. Check details views, ordinary lists and the new inspection views for the same issue.

**Acceptance checks**

- Compare cost, Race and Type tags, with and without icons: their shared dimensions/padding remain consistent and rows align.
- Large source Type icons are contained and proportionally scaled; no tag grows solely because its image is large.
- Check all damage Types, normal and enlarged details, card lists, pile browsers and supported UI scales. Metadata remains legible, aligned and free from overflow.

**Implementation/verification notes:** Documentation capture only; no UI code changed.

## F03-04 — Arcane materials must exactly match the requirement

**Status:** Captured — explicit gameplay rule change.

**Supersedes:** The earlier confirmed permission to overpay Arcane material costs, including the 'at least' total in the initial rules and the accepted overpayment example in earlier acceptance tests. This latest user decision takes precedence for this mechanic.

**Requested behaviour**

- The sum of eligible Arcane materials' current modified ordinary AP costs must equal the Arcane summon requirement exactly.
- Reject both underpayment and overpayment. Example: a requirement of two cannot be paid with materials totalling three.
- Retain the other confirmed Arcane rules: only eligible ordinary-AP-cost Units in Spent can contribute; exhaust selected materials on a successful summon; Extra Deck units cannot contribute; no additional Race/Type restrictions; do not pay the requirement again from the player's AP.

**Implementation implications**

- Replace minimum-threshold material validation with exact-total validation in the authoritative rules, selection UI, available-action checks and any material-search/helper logic.
- Show selected total and required total so the player understands which selection is legal. Do not accept an oversized selection and discard a surplus or refund an invented difference.
- Invalid totals must not consume materials or AP, create a unit, or emit successful-summon effects. Preserve normal destination/space validation.
- Reconcile older rules, decision summaries and tests that still approve overpayment when implementing this feedback. Preserve provenance by marking the old answer superseded, rather than pretending it was never given.

**Acceptance checks**

- Requirement 2, materials with current costs 1 + 1: legal if all other requirements hold.
- Requirement 2, material with current cost 2: legal if otherwise eligible.
- Requirement 2, totals 1 or 3: illegal; no resources/cards consumed.
- Modified costs, not printed costs, determine the exact total. Example: a printed-cost-3 eligible Unit reduced to current cost 2 can pay requirement 2.
- Extra Deck units and non-Units remain ineligible even if they display a numeric requirement.
- Both clients agree on eligibility and the authority rejects stale/invalid selection commands.

**Implementation/verification notes:** New design decision recorded for the implementation agent; gameplay code and older source documents have not been edited by this capture.

## F03-05 — Hide zero-cost cards in Arcane material selection

**Status:** Captured.

**Requested behaviour**

- Do not show zero-cost cards in the Arcane material-selection pop-up/list.
- Filter using the current modified cost, consistent with Arcane material valuation, rather than only the printed cost.
- Continue to enforce other material eligibility rules and the exact-total requirement from F03-04.

**Acceptance checks**

- Ordinary AP-cost Units whose current cost is zero are absent from the Arcane material-choice list, including cards reduced to zero by cost modifiers.
- Eligible positive-cost Units remain available when appropriate; a printed-zero card with a positive current cost is evaluated using that current value.
- Do not hide zero-cost cards from unrelated Spent inspection or other effects' selection lists. This is specific to Arcane material selection.
- This request filters offered materials; do not silently introduce unrelated restrictions on zero-cost cards or other summon systems.

**Implementation/verification notes:** Documentation capture only; no UI/rules code changed.

## F03-06 — Reduce player-info panels to avoid field overlap

**Status:** Captured.

**Reported observation**

The local player's information panel at bottom left and the opponent's at top right are slightly oversized and encroach on the field zones.

**Requested behaviour**

- Make both player-info panels slightly smaller so there is visible space between them and the field zones.
- Preserve legible player information, HP/AP and any existing controls; do not solve overlap by clipping contents or shrinking text excessively.
- Keep the intended bottom-left/top-right placement and the existing board geometry.

**Acceptance checks**

- Both panels have a clear visible gap from nearby field zones at supported window sizes/scales.
- Neither the panel graphics nor their input regions overlap/intercept clicks intended for field zones.
- Information remains readable with larger HP/AP values and longer player names; no content is clipped.
- Check both client perspectives, not only the hosting player's board.

**Implementation/verification notes:** Documentation capture only; no UI code changed.

## F03-07 — Correct Power-slot mapping across player perspectives

**Status:** Captured — mirror both axes; implementation needs comparison against the actual board.

**Reported observation**

User reports Power placements are not being mirrored correctly between player views. Their initial top-left/bottom-right explanation was ambiguous; the clarifications below define the desired behaviour and supersede any reading of bottom-right as inherently wrong. Actual current rendering has not been independently reproduced during feedback capture.

**Requested outcome**

- Present the same authoritative Power placement in the intended symmetric slot across both player perspectives.
- Keep Power-block placement consistent with the approved board reference (own block right, opponent block left). Correcting block position and mapping the four internal slots are separate concerns.
- Do not change card ownership, rules or authoritative slot identity just to correct presentation.

**Confirmed mapping and spatial meaning**

**User clarification:** Owner top-left should appear as bottom-right in the opponent's view. This is the desired mapping and supersedes the initial interpretation that this particular mapping was unwanted.

The user further confirms mirroring both vertically and horizontally. Preserve physical relationships to the unit rows: the Power slot closest to the owner's front unit row remains closest to that same front row when the opponent views the board. Do not reorder slots in isolation from the whole mirrored player board.

**Resulting transform:** Mirror both axes (equivalent to a 180-degree rotation of the two-by-two slot arrangement):

| Owner's view | Opponent's view |
| --- | --- |
| Top-left | Bottom-right |
| Top-right | Bottom-left |
| Bottom-left | Top-right |
| Bottom-right | Top-left |

This defines slot arrangement, not a request to rotate card text upside down. Test current behaviour before editing: do not invert an already correct mapping merely because the initial report labelled it a mismatch.

**Acceptance checks**

- Test each of the four source slots from both clients, with identifiable cards, against the confirmed mapping table.
- Clicking/selecting/removing each displayed Power must act on the correct underlying card and slot after the visual correction.
- Reconnection and board refresh preserve the same mapping; no card jumps into a different displayed slot.

**Implementation/verification notes:** Documentation capture only. The intended transform is now specified; current code has not been changed or independently verified.

## F03-08 — Highlight Extra Deck for a genuinely available Fusion summon

**Status:** Captured — verify existing behaviour, implement only missing/inconsistent checks.

**Reported observation**

The Extra Deck highlights when a Ritual or Arcane summon is available. User is unsure whether Fusion is covered correctly. Fusion requires both matching materials and a currently usable way to perform Fusion, not materials alone.

**Requested behaviour**

- Include Fusion in the Extra Deck's available-action highlight whenever at least one legal Fusion summon can actually be performed now.
- Require a matching Fusion card in Extra Deck, a valid distinct material selection, and an available Fusion-enabling Spell/card ability/effect that permits that summon.
- Evaluate the method's actual current legality: applicable source location, timing, costs/AP, usage limits, suppression/status restrictions and explicit material-source exceptions. Merely owning a Fusion method somewhere inaccessible is not sufficient.
- Account for summon space after Field materials leave, and preserve the rule allowing newly summoned units to be tributed while disallowing Debilitated units as materials.
- Do not highlight a Fusion-only opportunity when no method can be activated or no valid complete material assignment exists.

**Reuse existing rules logic**

User notes that cards enabling Fusion already check summon targets and materials, and suggests reusing those checks. Treat this as a code-inspection lead, not independently verified implementation evidence. Inspect those existing action/target/material validators and share a common authoritative eligibility query where practical. The Extra Deck highlight and the actual Fusion-card activation should agree; avoid a second approximate algorithm based on card text/name guesses.

**Interaction and state updates**

- Highlight is an availability cue, not permission to summon without the required method or pay no activation costs. Preserve the existing method/material/zone selection flows.
- Recalculate as relevant state changes: AP, phase, cards in Hand/Field/Extra Deck, material stats/Types/Races/statuses, method use limits and pending-choice locks.
- If another valid Ritual/Arcane action remains, overall Extra Deck availability may stay highlighted even when Fusion becomes unavailable. Distinguish per-method availability internally so the cue is not mistaken for Fusion-specific proof.
- Retain the new exact-total Arcane requirement from F03-04 when sharing/generalizing Extra Deck availability checks.

**Acceptance checks**

- Fusion recipe/materials present but no usable method: no Fusion availability signal.
- Method available but missing/invalid materials or matching Extra Deck target: no Fusion availability signal.
- Complete legal method, materials and target: Extra Deck highlights and activation actually succeeds through normal choices.
- A method that is unaffordable, already used, suppressed, inaccessible or illegal in the current phase does not create a false positive.
- Explicit material-source exceptions work through the same validators as activation. Each recipe slot still requires a distinct unit and uses current modified requirements.
- Full Field with usable Field materials can still qualify if their removal creates a legal zone. No-space Arcane or other illegal summons remain blocked.
- A state change removes or adds Fusion availability immediately; no extra information about the opponent's hidden cards is revealed.

**Implementation/verification notes:** Documentation capture only. Current Fusion-highlight implementation has not been inspected or modified during this feedback session; agent must establish what already works before making changes.

## F03-09 — Remove redundant Type suffixes from basic-unit names

**Status:** Captured.

**Requested behaviour**

- Remove bracketed damage-Type suffixes from basic-unit names. For example, display `Basic Mage` rather than `Basic Mage (Water)`.
- Let the existing Type icons, tags and metadata communicate the unit's Type instead of repeating it in the name.
- Apply the naming presentation consistently across cards, details, inspection views, pile/deck lists and other player-visible references to these basic units.

**Implementation guidance**

- Preserve each distinct card's stable ID, actual Type, Race, art mapping and gameplay identity. Water/Fire/etc. basic variants may share the same display name without becoming the same card definition.
- Do not infer Type by parsing a display-name suffix or remove Type from the underlying card data.
- Preserve separate entries/choices for different variants in deck building, drafting and selection; their visible Type identifiers should remain sufficient to distinguish them.
- Restrict this normalization to basic-unit Type suffixes. Do not strip meaningful parentheses from unrelated named cards.

**Acceptance checks**

- Each basic-unit variant displays its base name without the Type suffix while showing the correct Type identifier.
- Multiple same-name variants remain distinct by stable identity and selectable correctly.
- Type-changing effects update the Type display without needing to rewrite the card name; rules, sorting, art lookup and references do not break because of the name cleanup.

**Implementation/verification notes:** Documentation capture only; source database and UI code unchanged.

## F03-10 — Configure draft deck composition before starting

**Status:** Captured.

At initial draft setup, expose deck-composition controls so players can choose how many cards they may draft from each category. These values are user-configurable, not new hardcoded deck restrictions. Preserve the test-bed decision that draft quotas are unspecified until configured and custom deck building has no composition limits for now.

**Acceptance checks:** Set different category counts, start a draft and verify exactly those quotas are used and shown clearly. Explain incomplete/invalid configuration rather than silently substituting unrelated counts. Preserve separate Main Deck/Extra Deck routing. Host/client configuration must agree before drafting.

## F03-11 — One Extra Deck category in drafting and rewards

**Status:** Captured.

Replace separate Fusion, Ritual and Arcane draft categories with a single **Extra Deck** category. Apply the same grouping on the rewards page. Offer eligible cards from all three special-summon types within this group; retain their individual types, requirements and inspection information.

**Acceptance checks:** Both draft composition and rewards display one Extra Deck group instead of three separate groups. Configured Extra Deck picks draw from the combined eligible pool. This is a category/UI change, not removal of distinct summon systems or mixing these cards into ordinary Draw.

## F03-12 — Remove empty-Hand placeholder text

**Status:** Captured.

When Hand is empty, leave the Hand area visually empty instead of displaying 'Your hand is empty' or equivalent placeholder text. Preserve the intended layout/spacing and any legitimate turn/action prompts elsewhere.

**Acceptance checks:** Play/discard the last Hand card and start with an empty Hand: no placeholder sentence appears, no stale card remains and no layout jump or broken selection occurs.

## F03-13 — Impactful victory and defeat presentation

**Status:** Captured.

Add a clear, rewarding victory animation and an equally clear defeat animation when a game ends, then transition to the existing victory/loss modal. Make each player's own outcome unmistakable using movement, visual treatment and suitable audio within the established art direction.

**Acceptance checks:** Winner and loser see the correct distinct presentation before their result modal. Immediate rules-side defeat still stops gameplay at the correct moment; the animation does not defer or reverse the actual outcome. Run once per game, avoid duplicate rewards/transitions, and distinguish game victory from series victory. Check normal lethal, effect lethal and reconnect/refresh handling. Keep text legible and avoid excessive delays or motion that obscures meaning.

## F03-14 — Reset HP display capacity between games

**Status:** Captured — reported bug.

**Observation:** Healing can raise the displayed maximum/reference HP during a game. At the next game's start, current HP resets to 60 but the old increased maximum remains, making the player appear to start with missing health.

**Requested fix:** Reset the HP display's maximum/reference capacity along with current HP when a fresh game starts, so 60 is displayed as full starting health. Healing above 60 remains legal within a game; do not introduce a cap to hide this bug.

**Acceptance checks:** Heal above 60, finish the game and start the next game in a series. Both players start at 60 with full-looking health displays, no inherited enlarged denominator/bar capacity, and no stale wounded appearance. Verify both clients, game-start initialization and between-game resume. Inspect the actual state/presentation cause rather than assuming the user-observed 'max HP' corresponds to a specific code field.

## F03-15 — Guided, staged tutorial under Play Local

**Status:** Captured.

Add a tutorial entry within **Play Local**. Teach core play through several staged scenarios with pre-made decks, a scripted opponent and guided player actions. Cover the basic flow of turns, playing cards, summoning, stances and battle; include a dedicated Extra Deck summon lesson as a desired extension. It need not teach every status individually.

Instructions can appear in a top-of-screen guidance modal/panel. Clearly highlight the required card, control, zone or target. Enforce the lesson's required player actions and script the opponent's moves so the example reliably demonstrates the intended mechanic, rather than expecting an uncontrolled opponent to cooperate.

**Implementation guidance:** Keep tutorial scripting separate from normal match rules and multiplayer. Use the real rules engine and legal actions, with lesson-specific gating and deterministic setup. Provide clear progression and an exit/restart route; exact lesson count and wording are not specified. Avoid a mere text slideshow or generic AI opponent as a substitute for the requested walkthrough.

**Acceptance checks:** A new player can enter from Play Local, follow highlighted steps, and complete each scenario without reaching a state the script cannot recover from. Unrelated actions cannot derail a forced step. Opponent behaviours, prompts and completion conditions are deterministic. Test tutorial replay/restart and verify no lesson restrictions leak into ordinary play.

## F03-16 — Clear, impactful destruction and Exhaust animations

**Status:** Captured.

Give important card movements such as destruction and exhaustion stronger, clearer animations. For an effect such as **Into the Void**, present the affected card front and centre with a distinct Exhaust animation so players understand which card was removed and what happened. Destruction and exhaustion should read as different outcomes, not interchangeable generic movement.

**Visibility constraint:** The affected card may originate in a hidden pile. Existing permissions remain in force: animate the full identity only for a player authorized to see it, unless the user explicitly adds a public-reveal rule. Other players can receive appropriately anonymous movement feedback. This request is not automatic permission to expose hidden piles/card identities.

**Acceptance checks:** The authorized player can identify the exhausted/destroyed card and its destination; the effect is not mistaken for discard or a failed action. Preserve resolution order, selection prompts and immediate defeat rules. Reconnecting or replaying a state update does not reapply the underlying effect or leak private cards.

## F03-17 — Special-summon material and arrival sequences

**Status:** Captured.

Add energetic, polished special-summon animations showing selected materials being consumed and the resulting unit arriving. Cover Fusion, Ritual and Arcane, using the correct material sources and destination semantics for each.

The spoken 'sacrificed or tributed' describes the visual event, not a rule change: Fusion/Ritual materials are tributed and normally enter Spent; Arcane materials exhaust from Spent. Do not generate sacrifice refunds or destruction triggers because an animation resembles those actions.

**Acceptance checks:** Materials are visually connected to the resulting summon, with correct destinations and a readable result. Trigger chains, field-space creation and exact Arcane payment remain authoritative. Animations do not combine sequential rule events into false simultaneous destruction, duplicate costs or bypass pending choices. Both clients see a coherent sequence using only information they may see.

## F03-18 — Effect targeting arrow must originate at its source

**Status:** Captured — reported bug.

When **Overextend** requests a target to lose ATK, its targeting arrow currently appears to originate from a unit instead of the Trap. Anchor the effect arrow to Overextend itself. Inspect the targeting-source plumbing so other effect selections likewise show the actual source card, distinct from attack arrows.

**Acceptance checks:** Activating Overextend produces a source-to-target arrow beginning at the Trap's location, including in the opponent view. The arrow remains tied to the correct source if source presentation is transitioning; preserve a valid visual source context rather than borrowing an unrelated selected/attacked unit. Do not change which card owns or resolves the effect.

## F03-19 — Overextend chooses its ATK-reduction target

**Status:** Captured — explicit card-behaviour change; opposing-unit choice confirmed by user.

Replace Overextend's automatic highest-ATK target with a player-selected unit. Preserve the existing opponent-summons trigger and 20-ATK reduction unless separately changed.

**Confirmed reconciled wording:** If your opponent Summons a Unit and now has 3 or more Units on the Field: choose an opponent's Unit; it loses 20 ATK.

**User confirmation (16 October 2026):** Overextend may choose any opposing unit, retaining its existing trigger and 20-ATK reduction. Friendly units are not eligible. Preserve the normal zero stat floor and persistent-until-field-exit duration.

**Acceptance checks:** The controlling player receives a legal opposing-unit target choice, can select a non-highest-ATK unit, and that unit receives the reduction. The arrow follows F03-18. Update the card's full displayed text, effect mapping, target eligibility and tests so old automatic-highest logic does not remain active. An invalid/stale target does not silently redirect to a highest-ATK unit.

## F03-20 — Smaller ATK/DEF badges with breathing room

**Status:** Captured.

Reduce the on-card ATK and DEF indicators slightly; they currently feel oversized. Leave deliberate margin around them so the card looks less crowded. Preserve the previously requested ATK diamond treatment and clear distinction from DEF.

**Acceptance checks:** Both indicators are smaller and balanced, readable at ordinary card size, and do not crowd edges/art/controls. Test large values, previews, rotated Defense cards, selected actions and enlarged inspection. Do not solve crowding by clipping digits or shrinking text beyond readability.

## F03-21 — Animated actionable-card glow and bouncing cue

**Status:** Captured.

Make the existing yellow available-action border more obvious with an animated glow. Animate the small arrows/chevrons above an actionable card with a subtle bounce. Apply both the glow and cue to Power cards with a usable effect and to Extra Deck availability when a legal summon exists, not only ordinary units/cards.

**Acceptance checks:** Available attacks, manually activated effects and legal plays/summons are discoverable without clicking every card. Highlights accurately update with AP, phase, statuses, use limits, valid targets/materials/methods and response locks. The Extra Deck's cue must include F03-08's complete Fusion validation and F03-04's exact Arcane sum. Powers follow their actual activation legality. No cue for an unavailable action, no overlap that blocks clicks, no information leak from hidden opponent actions. Keep the animation readable and restrained rather than flashing aggressively.

## F03-22 — Remove base stats from the Modifiers section

**Status:** Captured.

Keep the useful Modifiers section in card details but remove the redundant base-stat entries from that section. Show actual active changes there; retain base/current stats in their appropriate existing stat area when needed. Do not delete underlying base values or remove modifier explanations.

**Acceptance checks:** Modifiers lists meaningful bonuses, reductions and effects without presenting base ATK/DEF as if they were modifiers. Cards with no changes do not show a misleading base-stat modifier list. Dynamic changes remain understandable and full card inspection remains informative.

## F03-23 — Add a Protecting tag

**Status:** Captured.

Alongside the existing **Protected** tag for a rear unit shielded by a front unit, add **Protecting** for a front-row unit that currently has a friendly rear unit directly behind it in the same column.

**Acceptance checks:** Tag updates on summons, movement, removal and control changes. A front unit with an empty rear zone does not display Protecting merely because it occupies the front row. Preserve column protection rules; diagonal adjacency does not create protection. Use the consistent tag/icon sizing from F03-03.

## F03-24 — Review and improve the deck builder

**Status:** Captured.

Include card images in the deck-builder catalogue, even if thumbnail-sized, with hover highlighting and the new right-click inspection behaviour. Review the overall deck-building flow and make it easier to use. A responsive card grid instead of the current list is the user's suggested direction, not a fixed row/column count.

**Acceptance checks:** Cards are recognizable through imagery and key metadata; users can hover/inspect and add/remove the intended card without confusing same-name basic variants. Catalogue layout uses space effectively, remains readable and handles larger pools with scrolling. Keep Type/Race/category distinctions, Main/Extra Deck routing and the intentionally unrestricted custom-deck composition. Retain any useful existing search/filter/count controls; verify the complete create/edit/save/select flow rather than only restyling a screenshot. Do not introduce deck legality limits the user deliberately left open.

## F03-25 — Make required-input guidance unmistakable

**Status:** Captured.

The current top input-required banner is too easy to miss. Review its UI and make it more prominent, with an animated treatment and clearer hierarchy. Suggested geometry: slightly lower on screen, narrower and taller. Exact dimensions/effect are left to the UI pass.

**Acceptance checks:** Players immediately understand that input is required, which player must act and what to select/do. Guidance remains visible without covering legal cards/targets or action buttons. Highlight required targets/controls where useful; do not turn an informational banner into a second conflicting choice flow. Both player perspectives, nested choices and the tutorial use readable, consistent prompts. Indefinite response waits and rules-side locks remain unchanged.

## F03-26 — Empty-space click dismisses passive right-pane inspection

**Status:** Captured.

Clicking empty board/background space should close the pile inspector or viewer in the right pane, consistent with dismissing ordinary card selection/details. A click on a real card, control or interactive zone must not be misclassified as empty space.

**Acceptance checks:** Opening a passive right-pane pile/card viewer and clicking empty background dismisses it cleanly, clears stale highlights and does not trigger a gameplay action. Do not silently cancel a mandatory effect/response selection or commit a choice by treating empty space as dismissal. Near-full-screen/right-click inspection modals retain a clear intentional close/back path; this feedback specifically mentions passive right-pane viewers rather than overriding unresolved mandatory modal behaviour.

## F03-27 — Type-coloured declaration buttons

**Status:** Captured.

When a player declares/chooses a Type for cards such as **Waang, Bender of Elements** or **Chaos Witch**, style each Type button using its established Type colour. Keep text/icon identification and legibility rather than relying on colour alone.

**Acceptance checks:** Available choices reflect each card's actual permitted Types; colours match the game's Type identifiers, text remains readable in normal/hover/selected states, and clicking a button selects the correct Type. Do not present unsupported Types merely to fill a colour palette. Check all Type-selection contexts, including triggered effects and both player views.

## Implementation handoff and verification

This batch is complete through F03-27. Read this file alongside `design/decision-register-answers.md`, earlier feedback and `rules/09-PRODUCTION-QUALITY-PASS.md`. The exact-total Arcane change explicitly supersedes earlier overpayment permission. Overextend's new chosen-target behaviour supersedes its automatic highest-ATK behaviour; keep the other card rules unless clarified.

Use the installed studio skills and relevant specialists for interaction/state flow, UI review, animations/technical art, tutorial design and independent QA. Coordinate shared-file ownership and keep the lead responsible for integration. Distinguish actual defects from requests to verify a feature that may already work, particularly Power mirroring and Fusion availability highlights.

Maintain an item-by-item status/evidence checklist. Validate rules independently, run actual two-client matches and a subsequent game, test the local tutorial, and inspect every changed screen/animation at intended window sizes. Preserve hidden information, event order, prompt suspension and network authority. Record screenshots or short captures, but do not call an item verified based only on code import or a static image.

**Capture limitation:** No game code, source CSV, mode configuration or older rule document has been modified during this feedback capture. The implementation agent must reconcile affected text/rules/tests while making the changes. All reported observations remain user reports until reproduced or otherwise verified.
