# Playtest feedback 02 — card interaction and presentation

Date: 15 October 2026  
Status: Captured — implementation and verification pending  
Scope: Improvements to the existing playable Godot game, not a restart or gameplay redesign.

## Authority and interpretation

This file captures the user's latest playtest feedback. Where it conflicts with earlier interaction notes in `playtest-improvements.md` or older build prompts, this file takes precedence for the affected behaviour. Keep the confirmed rules in `decision-register-answers.md` and the existing specification unchanged unless a requirement below explicitly changes presentation/interaction.

**Important correction:** Hover or click may show card details, but **action buttons appear only when a card is click-selected**. This supersedes the earlier request to show actions on hover. The first rough note mentioned summon buttons on hover; the later explicit click-selection rule governs those buttons too. Hover remains useful for details, highlights and combat previews.

All items below are user requests; acceptance checks translate them into observable outcomes. Implementation suggestions are not new game rules. None of these items is marked implemented merely because this document exists.

## F02-01 — Separate card inspection from action selection

**Requested behaviour**

- Continue displaying card details on hover or click.
- Reveal a card's valid action buttons only after the player click-selects that card, not on hover alone.
- Keep action buttons on the card rather than moving gameplay controls back into the right-hand details pane.
- Make the selected card visually distinct from a merely hovered card.

**Acceptance checks**

- Hovering updates details without exposing action buttons.
- Clicking selects the card and reveals its legal actions; buttons remain stable and clickable.
- Changing selection updates actions to the correct card instance. Target selection, response prompts and locked phases do not accidentally activate the selected card's normal actions.
- Hidden opponent cards remain protected from inspection and action disclosure.

## F02-02 — Direct summon-in-stance buttons

**Requested behaviour**

- Replace the extra attack/defense choice inside card options with two direct actions: **Summon Attack** and **Summon Defense**.
- Show them on a click-selected summonable card, following F02-01.
- Each button enters the corresponding summon flow with stance already chosen; preserve any required legal zone/material selection.

**Acceptance checks**

- A normally summonable Hand unit presents both actions when legal, without an extra stance menu.
- The resulting unit enters the chosen stance and pays costs only once.
- Card-specific stance restrictions and special-summon requirements still apply. Do not enable an illegal stance or bypass summon timing/material checks.

## F02-03 — Preserve card proportions and defense orientation

**Requested behaviour**

- All upright card visuals use a **2:3 width-to-height aspect ratio**, using the existing Power cards/zones as a visual guide.
- Square unit slots remain slots; their cards must fit within them without stretching to fill the square.
- Defense-position units rotate horizontally. Rotate the same 2:3 card rather than deforming it, producing a 3:2 on-screen bounding box.
- Preserve card proportions in Hand, Field, pile selectors, details/previews and animations.

**Acceptance checks**

- Upright cards remain 2:3; defense cards are rotated versions of that shape.
- No square, stretched or squashed card art/frames, even inside square unit slots or during resize/tween animation.
- Hit areas, action overlays and readable stats align with actual displayed cards. Zone geometry from the supplied layout reference remains intact.

## F02-04 — Short action labels, full explanations in details

**Requested behaviour**

- Use short, recognizable labels on unit-effect buttons. Example: **Apply Pierce**, not “Apply 1 Pierce to a unit (once per turn)”.
- Keep full effect text, quantities, target restrictions, costs and usage limits in the card-details view.
- Apply a consistent concise naming approach to other effects without making different abilities indistinguishable.

**Acceptance checks**

- Buttons fit their card overlays without long wrapping or clipped text.
- Full rules remain available in details, and legality/once-per-turn checks still work.
- Cards with several effects have distinguishable action labels; shortening text does not merge separate actions.

## F02-05 — Give card details more height and the log less

**Requested behaviour**

- Reduce the game log's default panel height.
- Increase the card-details panel height so normal card inspection requires little or no scrolling.
- Keep the log available for reviewing history; this is a layout change, not a request to remove or truncate stored events.

**Acceptance checks**

- At the normal supported window size, typical full card details are readable without scrolling.
- Unusually long content remains accessible through a sensible overflow fallback; do not shrink text until unreadable or hide content to avoid a scrollbar.
- Log history can still be scrolled/read, and board interactions remain usable.

## F02-06 — AP slots reflect the player's actual allowance

**Requested behaviour**

- Do not show four empty AP slots by default for a player whose normal turn allowance is two.
- Show the player's actual AP capacity/allowance, with filled and spent states demonstrating AP use.
- Show additional allowance slots when effects raise normal starting AP, such as Marked by the Abyss granting a three-AP reset.
- Extra AP gained during play must also be represented rather than clipped to the starting allowance.

**Implementation interpretation to preserve the request:** Treat the ordinary per-turn allowance as the baseline display capacity, expand if current AP exceeds it, and keep spent slots visible so usage remains understandable. Reset temporary capacity with the next turn's actual allowance. A suitable capacity is the maximum of effective starting allowance and peak AP reached this turn; this is a proposed display policy, not a new AP cap or resource rule.

**Acceptance checks**

- Ordinary two-AP start: two slots, not four.
- Spend one: one filled and one spent slot. Spend both: two spent slots.
- Effective three-AP starting allowance: three slots, with spending shown accurately.
- Gain AP above allowance: additional AP is visible; no UI-imposed cap and no implied automatic refill. Turn reset still follows confirmed game rules.

## F02-07 — Select field targets directly, with a contextual overlay

**Requested behaviour**

- Remove the right-hand list of field cards used for effect-target selection.
- Highlight valid targets on the board and let the player select them directly.
- Show a contextual overlay/banner explaining what is being selected and for which effect, rather than making the player infer the current prompt.
- Preserve necessary target counts and confirmation/cancel flows for effects that require them.

**Acceptance checks**

- Only valid targets can be chosen; no redundant right-side field-target list is needed.
- The overlay clearly identifies the action, such as selecting a unit for Apply Pierce, and any required number/order of selections.
- The overlay does not cover target cards or their essential stats.
- Selection completion and cancellation return to a valid interaction state. No automatic undo of committed effects is introduced.
- Preserve Plan B's ordered multi-selection and subsequent sequential resolution, rather than turning it into unordered simultaneous destruction.

## F02-08 — Structure the card-details pane

**Requested behaviour**

- Replace the wall-of-text presentation with clear hierarchy and separation.
- Distinguish card identity, category/race/type, costs, ATK/DEF, effect timing, effect text, statuses/counters and current modifiers as applicable.
- Use appropriate spacing, headings, grouped panels, badges or separators within the established visual direction.
- Keep full rules available without duplicating long text in multiple sections unnecessarily.

**Acceptance checks**

- A player can quickly locate the card's effect, timing, current stats and status explanations.
- Long cards are readable and layout scales without overlaps or tiny type.
- Consistent presentation for Units, Spells, Traps, Powers and special-cost Extra Deck cards.
- Preserve dynamic modifier explanations and the taller layout from F02-05.

## F02-09 — Explain effects with no valid target

**Requested behaviour**

- If an effect should trigger but has no valid target, show a short, non-blocking toast explaining that no legal target exists.
- Avoid silently appearing to do nothing.

**Acceptance checks**

- A legitimately triggered effect with no legal target produces an understandable message naming the visible effect/card where permitted.
- Toast does not hang the effect queue, create a fake choice, or alter the established costs/failure rules.
- Do not show toasts for every unavailable card/action that never triggered, and do not reveal hidden card identities or conditions through the message.
- The game log can retain an appropriate explanation for later review; visual toast need not remain indefinitely.

## F02-10 — Click pile cards to choose them

**Requested behaviour**

- In pile-card selection interfaces, clicking the card chooses it. Remove the separate **Choose** button beneath each card.
- Preserve inspection and visibility rules for the permitted selection pool.

**Acceptance checks**

- Single-choice selection works by clicking the card itself.
- Multi-choice flows preserve their required selected state/order and any overall confirmation step; “remove per-card Choose buttons” does not mean prematurely committing a multi-target effect.
- Own Draw inspection does not expose or change actual draw order. Effect-authorized access to an opponent's pile remains scoped correctly.

## F02-11 — Highlight cards that can currently act

**Requested behaviour**

- Use a clear, consistent highlight colour/style to indicate cards with an available action.
- Include playable/summonable Hand cards when AP and other requirements are met, manual Unit/Power effects that can currently activate, and units able to attack during Battle.
- Action availability highlighting is separate from click-selected, hovered, valid-target and opponent-response states.
- Exact highlight colours are not specified; choose a readable scheme consistent with the established art direction.

**Acceptance checks**

- Highlights respond immediately to AP spending/gain, phase changes, use limits, status restrictions, targets and prompt locks.
- A unit that has attacked, is in Defense, or is Paralysed does not falsely advertise a legal attack.
- Effects requiring an unavailable target/material are not presented as freely actionable.
- The highlight does not reveal opponent hidden-card actions. Retain accessible shape/icon cues where practical rather than relying only on colour.

## F02-12 — Preview type-adjusted combat on target hover

**Requested behaviour**

- While selecting an attack target, hovering a prospective target temporarily displays the type-advantage-adjusted combat stats on the relevant card visuals.
- Show the values actually compared: attacker's ATK and defender's ATK or DEF according to stance, with advantage applied to the appropriate side.
- Colour the targeting arrow to communicate a favourable or unfavourable battle outcome. Use green for a clear win and red for a clear loss; ties/neutral cases need a distinct treatment rather than being mislabeled.
- Treat colours as preview information, not a new gameplay rule. Clearly distinguish a preview from a committed stat change.

**Acceptance checks**

- Water ATK 8 hovering Fire ATK 10 shows 14 versus 10 under normal advantage; the reverse attack shows the defending Water's adjusted value.
- Use actual modifiers, including stacked Elemental Mastery, the relevant current stance and immunity/prevention effects. Do not hardcode every advantage to six.
- Represent equal Attack/Attack mutual destruction and Defense stalemates honestly. Avoid calling an outcome a simple win when a relevant effect changes it; add explanatory text/neutral treatment where needed.
- Preview values and arrow update when the hovered target changes, and restore on hover exit/cancel/commit without mutating authoritative stats or consuming actions/statuses.
- Preview only known/current state. Unknown opponent Traps can change the result; do not leak their identity or promise a guaranteed outcome after hidden responses.

## F02-13 — Add action sounds

**Requested behaviour**

- Add suitable sounds to gameplay actions and UI feedback, supporting the tactile dark-fantasy presentation.
- Cover meaningful events such as card play/draw, selection/confirmation, attacks, damage/healing, destruction and effect/status feedback as appropriate.

**Acceptance checks**

- Audio is perceptible but balanced, does not fire repeatedly every frame/hover recalculation, and does not overwhelm multi-effect sequences.
- Do not reveal hidden events/card identities through audio cues.
- Use existing audio controls or provide a practical mute/volume control; make needed external sound assets explicit and use appropriately licensed assets.
- Animations/audio do not delay indefinite response handling incorrectly or affect network game rules.

## F02-14 — Improve damage-type icons

**Requested behaviour**

- Replace/improve damage-type symbols on cards with clear, cohesive, higher-quality icons for Water, Fire, Earth, Lightning, Heavenly, Necrotic and Physical.
- Keep damage Type visually distinct from Race. Represent typeless cards consistently rather than assigning a fake type.

**Acceptance checks**

- Icons are readable at normal card size, visually distinguishable and stylistically consistent.
- Tooltip/details retain text identification; gameplay information does not depend solely on colour.
- No missing-texture placeholders or mismatched icons after a card's Type changes dynamically.

## F02-15 — Use a diamond behind ATK

**Requested behaviour**

- Change the ATK stat badge/background from a shield to a diamond shape.
- Keep the numerical value legible and consistent across normal, rotated, selected and combat-preview card states.

**Acceptance checks**

- ATK has a clearly diamond-shaped badge; do not also change DEF solely because ATK was changed.
- Badge handles larger values and type-adjusted previews without clipping, overlap or ambiguity.

## Implementation and verification handoff

Implement this feedback on top of the current game. Reconcile it with `design/decision-register-answers.md`, earlier layout/polish feedback and the production-quality build instructions. Do not resurrect superseded hover-action behaviour.

Use separate but coordinated tasks for interaction state, responsive layout/card rendering, details/AP panels, targeting/combat preview, and audio/icons. Avoid concurrent conflicting edits to the same central UI file. The lead remains responsible for integration and an end-to-end playtest.

Keep a per-item status/evidence checklist. Launch and inspect the actual Godot game, exercise both players' perspectives, and retain screenshots or short recordings where useful. Test rules-side calculations independently of visual previews; test that hover is read-only and network/prompt locks remain authoritative. Do not mark items verified merely because the project parses or a screenshot exists without the interaction being exercised.

No game code, source CSV or runtime setting has been changed by creating this feedback file.
