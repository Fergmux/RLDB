# Decision register — user answers

Companion to [decision-register.md](decision-register.md). Created 15 October 2026.

This file records direct user answers collected one decision at a time. A proposal in the original register remains unconfirmed until answered here. Explanations and implementation implications must be distinguished from confirmed answers. Later corrections explicitly supersede earlier answers rather than silently changing their meaning.

The original register is preserved. This interview records decisions; it does not itself change game code or mode configuration.

## Already marked confirmed in the source register

These are existing source confirmations, not new interview answers:

- C-01: The loser of the previous game chooses who goes first in the next game.
- C-02: After every game, each player picks four rewards in any combination of adding a card, removing a card or changing basic unit type.

## Interview progress

- Answered: P-01; P-02 length, disconnect-victory scope and between-game save/resume; P-03 deck routes/custom limits/draft configuration. P-06 is partly resolved through the same answers.
- Numbered review: P-01 through P-31 covered; qualifications and corrections are recorded under each entry. P-06 resolved via P-02 reconnect answers.
- Current question: None. Interview complete for the original register's P-01 through P-31 and S-01 through S-04.
- All original proposals have been reviewed. Keep qualifications below: draft values remain intentionally unspecified, corrected answers supersede historical replies, and unrelated implementation edge cases have not been silently ratified.

## Important changes from the prototype proposals

- First game starter random; later game starter chosen by previous loser. Best of three default, five/seven selectable.
- After a sixty-second disconnect wait, host may optionally claim the current game, not the series. Save/resume series between games only.
- Existing starters may remain; custom decks unrestricted for now; draft quotas/offers configurable and unspecified.
- Burn after completed, uncanceled battle, not attack declaration. Pierce consumed only when excess HP damage actually applies.
- Existing Cleanse/Curse wins against incoming opposing status. One Cleanse blocks one whole application; distinct debuffs are separate applications in printed order.
- Reset destroyed card's field state after its destruction effects resolve.
- Elemental Mastery stacks: one gives +12 advantage, two +24. Options grants one additional turn-start card per copy; two mean six normal cards.
- Nested Trap/effect chains permitted for the eligible player. Plan B chooses ordered targets up front, resolves each destruction's whole child chain before the next, and heals at the end.
- On Summon effects resolve before summon-response Traps.
- Magic Cylinder's condition is an attack on a friendly unit in the Trap's column; no direct attacks. Other column cards depend on their own wording.
- All effect sources and event triggers count for 'activates an effect' listeners, subject to other conditions and turn legality.
- New Powers main phases only; Nimble main phases only (Battle-permission answer was retracted).
- Response prompts only when a legal response exists; timing leakage accepted.
- Queued attack responses can retain attack-event stats after attacker removal. Generic destruction retrieval cannot select its own source.
- Chains of Binding explicitly optional; Yamata damage mandatory at start of own turn. Mandatory action/trigger text lacking timing needs correction.
- Friends-only Steam lobbies by default, host may list publicly.
- Snunday reversals compose/cancel in pairs; copying/assignment normal; addition/subtraction only, no multiplier inversion; additive self-cost changes reverse too, with zero floor.

This is a design-answer record, not a claim that game code has been updated. The original proposal register remains unchanged. Specific rule/card guidance was updated where requested; the implementation agent must reconcile these answers with older documents and code rather than treating prototype defaults as canon.

## P-01 — First game starter

**Status:** Confirmed by user.

**Source proposal:** A random coin flip performed by the game authority, seeded and logged.

**Question and context:** For the first game in a series, should the game randomly select the starting player, with equal chances for each? This is distinct from C-01: for later games, the previous loser chooses who goes first. A coin flip that chooses who starts is also different from a coin flip that gives the winner the choice of starting or going second.

**User answer:** Option A: randomly choose who goes first, with equal chance for each player.

**Implementation implications:** The game selects the actual starting player for game one; the random winner does not choose first or second. Later games retain C-01 (previous loser chooses). Authority selects one shared result so both clients agree. Seed/log implementation details were not separately confirmed by this answer.

## P-02 — Series length and abandoned series

**Status:** Series length and disconnect-victory scope confirmed; added series save/resume requirement has a follow-up.

**Source proposal:** Default best of three, selectable three/five/seven; immediate defeat prevents ties; leaving player forfeits after host ends reconnection wait.

**Question and context:** First resolve series length: best of three means first to two wins; best of five means first to three; best of seven means first to four. Abandoned series and ending a reconnection wait are distinct decisions and are not accepted by answering the length question.

**User answer — length:** Best of three by default; best of five and best of seven are also selectable.

**Implementation implications — length:** Configure series before starting. Win thresholds are two, three and four game wins respectively. This does not approve the separate abandonment or universal no-tie claims in the source proposal.

**Question — abandonment:** A disconnection pauses play for reconnection under the confirmed rules. If the host explicitly ends that wait, should the disconnected player forfeit the entire series, or should the series end without a winner?

**User answer — abandonment:** If the player has not reconnected after one minute, the host gets the option to declare victory for themself.

**Confirmed implications:** Pause and allow reconnection first. After sixty seconds without reconnection, enable an optional host victory action; do not automatically award victory or end the wait. This qualifies P-06's proposed indefinite wait: the host can continue waiting but gains this option after a minute. This does not change indefinite trap prompts. Whether declaring victory wins the current game or the entire series still needs confirmation. Handling a disconnected host is not covered by this answer.

**Follow-up:** Does declaring victory after the one-minute wait win the entire series, or only the current game?

**User answer — victory scope:** Only the current game within the series. Series must be able to be paused and resumed at a later date.

**Confirmed implications — persistence:** Declaring disconnect victory adds a game win, not an automatic whole-series win; normal configured win thresholds still apply. Preserve series score and deck/reward progression for later resumption. This is a new explicit product requirement, extending the original reconnect-only continuity. Whether saving/resuming includes a game in progress and its pending choices, or only between-game checkpoints, remains unconfirmed.

**Current follow-up:** May the players save and pause mid-game with exact field/hand/piles and pending choices restored later, or only between games?

**User answer — save checkpoints:** Only between games.

**Implementation implications — saves:** Persist series progress for later-date continuation at between-game checkpoints, not arbitrary mid-game snapshots. In-session disconnect/reconnect still pauses the current game as previously confirmed. Preserve score, series configuration and deck changes; reward-selection completion/checkpoint timing remains to define if needed.

## P-03 — Deck source

**Status:** Confirmed for current test-bed scope; draft quantities intentionally unspecified/configurable.

**Source proposal:** Preselected 20-card starter decks including three copies of an effectless basic unit, with optional draft mode.

**Question and context:** Is twenty cards the initial main-deck size, including three identical basic units, with players choosing a preselected deck or an optional draft? Confirming a starting size does not establish a fixed deck limit after rewards. Extra-deck size and draft quotas are separate choices.

**User answer:** Yes to the proposed starting setup. Existing built decks may remain for now; custom starter decks will be supplied/created later. There must also be a way to create a new deck in any shape, and a draft mode with random selections from each category.

**Implementation implications:** Keep existing starters as provisional content, not final authored starter decks. Provide three entry routes: existing/preselected starters, custom deck building, and category-based random drafting. Main Deck and Extra Deck remain separate. Twenty cards/three identical basics is the accepted starter proposal, not yet a confirmed universal rule for user-created decks. Draft category quotas, offered choices and pool restrictions are not defined by this answer.

**Current follow-up:** Does 'any shape' mean unrestricted custom deck size/category mix/duplicate counts, or should the builder enforce limits?

**User answer — custom limits:** No limits for now.

**Implementation implications — custom builder:** Do not enforce deck-size, category-mix or duplicate-copy restrictions on custom decks for now. Preserve Main Deck/Extra Deck card routing; unrestricted composition does not change summoning or cost rules. Starter templates may still use their accepted twenty-card structure.

**Current follow-up — draft:** Should draft quotas and number of random choices per pick be configurable, with existing prototype values left in place for now, or does the user want to specify those values now?

**User answer — draft configuration:** Configurable and unspecified. This is mostly a test bed, so leave things open.

**Implementation implications — draft:** Expose category pick counts and options-per-pick as configuration rather than fixed design rules. No numerical draft defaults are ratified by this answer; existing temporary implementation values, if needed to run a test, remain labelled prototype settings rather than confirmed rules. Keep configuration easy to change.

## P-04 — Used Trap destination

**Status:** Confirmed by user.

**Source proposal:** Used Traps go to Spent.

**Question and context:** After a Trap activates and resolves, should it leave its shared Trap/Spell zone and go to Spent, available for later recycling, unless its own text explicitly sends it elsewhere (such as Exhaust)?

**User answer:** Traps leave the Field to Spent when used.

**Implementation implications:** After activation/resolution, remove the Trap from its zone and send it to Spent for normal recycling, unless its explicit effect specifies another destination. This answers normal use; negated activation behaviour is not separately settled here.

## P-05 — Sacrificed unit destination

**Status:** Confirmed by user, with a broader destination rule.

**Source proposal:** Sacrificed units go to Spent.

**Question and context:** Sacrifice is distinct from destruction and tribute; it grants its normal one-AP refund plus applicable bonuses. Should the unit then enter Spent, not Exhaust, unless an explicit card effect overrides the destination?

**User answer:** Cards leaving Field, being destroyed, sacrificed or tributed go to Spent unless card text specifically exhausts them. A card saying it is exhausted when it leaves Field is exhausted no matter how it leaves.

**Implementation implications:** Sacrificed units enter Spent by default. Destination alone does not make sacrifice or tribute count as destruction. Apply explicit leave-Field exhaustion across causes, not just battle destruction. A conditional 'if sent from Field to Spent, exhaust' still follows its actual trigger wording, distinct from unconditional 'when leaves Field, exhaust'. Do not silently remove the event needed by such conditional text.

**Remaining edge case (not asked now):** Interaction with any future explicit return-to-Hand/Draw effect should follow specific destination wording; this answer establishes default Spent and the unconditional Exhaust override, not an invented priority for unprovided conflicting cards.

## P-06 — Reconnection wait

**Status:** Confirmed through P-02 discussion; no duplicate question needed.

**User answers:** Pause for reconnection. After one minute without reconnection, the host may choose to declare victory in the current game only; no automatic win. The host may continue waiting. Series can be saved/resumed later only between games.

**Implementation implications:** Replace the source's unrestricted host-end-wait proposal with a sixty-second eligibility threshold for the optional current-game victory. Keep indefinite Trap prompts separate. Disconnected-host handling is not newly specified.

## P-07 — Start-turn order

**Status:** Confirmed by user.

**Source proposal:** Reset AP to two, apply delayed AP modifiers, draw four, then start-of-turn triggers (active player's effects first).

**Question and context:** Reset to the normal AP allowance (two, or three under eligible Marked by the Abyss), apply scheduled AP changes such as Delayed Gratification, draw the normal fresh cards (four unless a replacement such as Options applies), then resolve start-turn card/status effects such as Medic and Rune generation. Does this order fit the intended rules? This means the fresh hand is known before those start-turn choices occur.

**User answer:** Yes, that order is correct.

**Implementation implications:** Reset AP allowance first, accounting for ongoing allowance modifiers; apply delayed AP changes; perform normal draw with explicit draw replacements; then offer/resolve start-turn effects. Fresh hand is available for start-turn choices. Retain is not decremented here (it is consumed when preventing end-turn discard). Preserve controller-selected order and active-player priority where multiple effects qualify.

## P-08 — End-turn order

**Status:** Confirmed by user.

**Source proposal:** End-turn triggers (active player first), then Poison/Paralyse/Debilitate decrements, then discard with Retain checked per card.

**Question and context:** Resolve end-turn card effects first, then end-turn status processing (Poison deals HP loss using its current count before losing a stack; Paralyse and Debilitate lose a stack), and finally discard the remaining Hand, consuming Retain where it prevents discard. This makes end-turn effects happen while the existing Hand is still present and before expiring end-turn statuses are removed. Poison must not be processed twice as both a generic trigger and a status step.

**User answer:** Yes, correct.

**Implementation implications:** Resolve end-turn card effects first, status processing second, and Hand discard last. Poison deals HP loss at its pre-decrement count then decrements; Paralyse/Debilitate decrement during status processing. Consume Retain only when it prevents discard. Check immediate defeat between resolved HP changes; do not continue to discard after a lethal Poison result. Relative ordering within simultaneous status events still follows confirmed ordering rules where applicable.

## P-09 — Stat changes without an explicit end time

**Status:** Confirmed after distinguishing numerical stats from stance.

**Source proposal:** A stat change with no explicit duration lasts while the unit remains on Field.

**Question and context:** A resolved instantaneous ATK/DEF grant or reduction with no expiry wording persists across turns until its recipient leaves Field. Explicit 'until end of turn' changes expire as written. Continuous auras remain conditional on their source and are recalculated, rather than becoming permanent grants. This is distinct from persistent card-cost changes, which already survive redraw/replay within the game.

**User answer — clarification needed:** Answer began with yes, then discussed cards changing attack/defense stance instantaneously, owner being able to change stance on their turn, and effects being for that turn unless future cards specify longer. This may concern stance-changing effects rather than numerical ATK/DEF modifiers. Do not mark the numerical duration proposal confirmed or rejected until distinguished.

**Follow-up:** For numerical changes specifically, such as a unit gaining four ATK with no duration stated, does the bonus expire at end of turn or remain until that unit leaves Field?

**Confirmed user answer:** If it does not say for this turn, it is permanent by default.

**Implementation implications:** Resolved numerical ATK/DEF changes with no stated duration do not expire at turn end. They persist while the affected unit remains on Field, consistent with the already confirmed reset on leaving Field. Explicit durations and conditional continuous auras retain their own rules. 'Permanent' here does not override field-exit or between-game resets. The preceding stance explanation is not a reversal of the Main Phase 1-only manual stance rule.

## P-10 — Rune reset on leaving Field

**Status:** Confirmed by user.

**Source proposal:** Clear Rune counters when the unit leaves Field, like other field state.

**Question and context:** Rune counters are not buffs, so the buff/debuff reset rule alone does not settle them. Should they also clear on leaving Field, so revival starts with no carried Runes? Ritual summoning can still read the material's pre-tribute Rune count for its requirement or Roma's stats.

**User answer:** Runes clear when the unit leaves Field.

**Implementation implications:** Reset Rune counters on field exit, including destruction/sacrifice/tribute and other field-exit moves. Moving between unit zones is not field exit. Record/validate pre-tribute Rune count before resetting it so Ritual requirements and Roma's stats are correct. Revived units do not carry old Rune counts.

## P-11 — Last-known state for destruction effects

**Status:** Confirmed with explicit reset timing supplied by user.

**Source proposal:** Destruction effects use a snapshot taken just before the card leaves Field.

**Question and context:** Cards reset field state when they leave, but destruction effects may need their previous Type, stats, counters or active effects. Should an On Destruction effect use the destroyed card's state immediately before field exit, rather than its reset Spent state? For example, Mirrorflesh Construct's destruction effect needs the Type it copied on Field. This does not automatically freeze unrelated targets or the whole board.

**User answer:** The reset should happen after destruction-triggered effects have resolved.

**Implementation implications:** Preserve the destroyed instance's relevant field state through its destruction-effect resolution, then perform its field-exit reset. A snapshot may implement this without changing confirmed observable behaviour, but do not expose reset values to those effects. This answer establishes reset timing, not permission to keep the destroyed unit occupying its field zone or projecting live auras; physical zone removal/aura lifecycle should remain distinct from retained effect context. Explicit persistent self-cost changes still survive as previously confirmed.

## P-12 — Pierce with no positive excess

**Status:** Confirmed with actual-HP-damage consumption rule.

**Source proposal:** Do not consume Pierce when there is no positive excess damage.

**Question and context:** Pierce enables excess battle HP damage against Defense stance. If ATK does not exceed DEF, no excess is available. Should the unit keep its Pierce stack in that case, consuming a stack only when the attack has positive excess damage?

**User answer:** Pierce decrements only when excess damage is applied to HP. Equal ATK/DEF does not reduce Pierce.

**Implementation implications:** Consume one Pierce only when it actually inflicts positive excess HP damage from an attack against Defense stance. Equal/lower ATK keeps the stack. Actual damage application, rather than merely a positive comparison result, governs consumption; this also matters for explicit no-damage effects such as The Illusionist.

## P-13 — Burn timing

**Status:** Declaration-timing proposal rejected; post-resolution timing confirmed.

**Source proposal:** Burn resolves at attack declaration, before trap responses.

**Question and context:** Declaring an attack with a burned unit causes its controller's Burn HP loss and clears Burn before the opponent chooses attack-response Traps. A lethal Burn loss would end the game before any response or battle. If the unit survives, later cancellation/destruction by a Trap would not undo the already applied Burn damage. Is that the intended timing?

**User answer:** Burn only resolves after a successful attack and battle resolution.

**Confirmed implications:** Do not apply or clear Burn merely on declaring an attack. A canceled attack that never reaches battle resolution does not satisfy the stated timing. This supersedes source P-13.

**Follow-up:** Does 'successful' mean any attack that completes combat, even when the attacker loses the comparison, or only an attack that wins? Survival, direct attacks and immediately lethal combat may require their precise sequencing to be recorded once this is clear.

**User clarification:** Successful means the attack was not negated or canceled. A losing attack still completed successfully.

**Implementation implications:** Burn applies after completed attack/battle resolution regardless of winner. A canceled/negated attack does not apply or clear Burn. Preserve relevant attack context so destruction/field-state reset cannot silently suppress Burn for a completed losing attack. Already confirmed immediate defeat still ends the game before later effects; direct-attack handling and detailed post-battle event ordering should not be invented if a conflict arises.

## P-14 — Cleanse and Curse collisions

**Status:** Existing-status priority, whole-application Cleanse prevention and printed-order multiple-debuff processing confirmed.

**Source proposal:** Incoming application checks existing opposing prevention; batches processed one at a time in listed order.

**Question and context:** Cleanse is a buff and Curse a debuff. When applying Curse to a unit already protected by Cleanse, the existing Cleanse would block it and consume one Cleanse; when applying Cleanse to a unit already bearing Curse, the existing Curse would block it and consume one Curse. This gives existing protection priority rather than letting the incoming effect remove its blocker first. Batch ordering/stack quantities are a follow-up distinct from the two single-application cases.

**User answer:** The existing status effect takes priority; the incoming one is negated by it.

**Implementation implications:** Existing Cleanse prevents incoming Curse; existing Curse prevents incoming Cleanse. Consume the existing preventing status by one per its confirmed use rule. Do not first install the incoming opposing status and let it remove its blocker. This settles priority, not how many prevention uses a multi-stack application constitutes.

**Current follow-up:** Does one Cleanse block an entire single application of four Poison stacks, or only one stack with the other three applied?

**User answer — prevention unit:** It blocks the full stack. One use of Cleanse blocks one application of a debuff.

**Implementation implications:** Applying four Poison in one operation consumes one Cleanse and applies zero Poison; do not treat the four stacks as four separate prevention events. Sequential separate applications can consume separate Cleanse uses. The symmetric multi-stack Curse prevention rule is not expressly answered here. Multiple different debuffs in a single effect require application ordering, addressed next.

**Current follow-up — multiple status types:** If a single effect applies Paralyse and Burn, should these count as separate applications in printed order, so one Cleanse blocks the first but the second gets through?

**User answer — multiple status types:** Yes; those are two applications.

**Implementation implications:** Process separate debuff types as separate operations in printed order. Existing Cleanse 1 blocks the entire first debuff application, consumes itself, and the second debuff applies normally unless another prevention effect intervenes. Source wording 'one at a time' means one application, not one stack. Multi-stack Curse symmetry remains unasked; do not silently claim an express answer.

## P-15 — Fusion materials

**Status:** Confirmed by user on both points.

**Source proposal:** Each material must be a distinct card instance; check current modified stats.

**Question and context:** A recipe 'Beast Unit + Fire Unit' requires two separate units even if one unit satisfies both labels. A minimum-ATK/DEF requirement uses the unit's current modified value at selection/commit, not the printed base. This lets buffs enable a qualifying Fusion material and reductions disqualify it. Ordinary legality must still be rechecked before committing materials.

**User answer:** One unit cannot fill both material requirements. Stat requirements use modified values for eligibility.

**Implementation implications:** Match each recipe slot to a distinct card instance. Use current modified ATK/DEF for numeric requirements, not printed values. Do not reset material stats before validating a summon that requires them. Race/Type changes should likewise be evaluated from the applicable current card state under the existing effect rules.

## P-16 — Full board on special summoning

**Status:** Accepted with explicit Fusion/Ritual material movement clarification.

**Source proposal:** Reject special summon before payment if there is no room; consume neither materials nor costs on failure.

**Question and context:** Field materials for Fusion/Ritual leave their zones as part of summoning, so they may themselves create the necessary space on a currently full board. Arcane materials from Spent do not create field space. Should space checks account for zones freed by selected materials, and reject the summon without consuming costs/materials only when there will still be no legal destination?

**User answer:** Yes. Fusion and Ritual materials are moved before summoning, creating space.

**Implementation implications:** Validate projected post-material-removal occupancy rather than rejecting based solely on a currently full board. Move Fusion/Ritual materials before placing the summoned unit. Do not physically consume materials just to test hypothetical legality. The question's no-cost/no-material-consumption failure rule was accepted with the yes; Arcane from Spent cannot create a free field zone. Intervening material-trigger effects still require normal resolution and legal-destination rechecking.

## P-17 — Recycling only extra-deck cards

**Status:** Confirmed by user.

**Source proposal:** Return them to Extra Deck; skip unavailable draw without penalty.

**Question and context:** If Draw is empty and every card in Spent is Fusion/Ritual/Arcane, recycling moves all of them to Extra Deck and produces no drawable cards. Should the game simply skip the draw without penalty, consistent with the already confirmed empty-pile rule, rather than loop the recycle step or draw an extra-deck unit?

**User answer:** Yes, correct.

**Implementation implications:** Return all extra-deck cards to Extra Deck on recycling. If Draw remains empty, skip unavailable draws without penalty; do not loop forever or put extra-deck cards into Hand via the normal draw.

## P-18 — Effect-driven stance changes

**Status:** Confirmed by user.

**Source proposal:** Card effects may change stance in any phase; restrictions apply to manual stance changes.

**Question and context:** Normal stance-changing actions are Main Phase 1 only. Can a legally activated/resolving effect change stance in Battle or Main Phase 2 as an exception, even after that unit attacked? This does not make the card's own activation timing legal on an otherwise prohibited turn, nor permit further manual stance changes.

**User answer:** Yes, that can happen.

**Implementation implications:** A legally resolving card effect can change stance during Battle or Main Phase 2, even after the affected unit attacked. Normal manual stance changes remain Main Phase 1 only. Changing stance by effect does not itself reset the once-per-turn attack allowance.

## P-19 — Repeated replacement effects

**Status:** Source non-stacking proposal rejected; stacking confirmed.

**Source proposal:** Replacement effects do not stack; highest replacement value applies.

**Question and context:** Effects saying a value 'is now' a number replace a rule rather than adding a bonus. Two Elemental Mastery Powers would each set advantage to twelve, not add to twenty-four. Likewise repeated Options would set the normal draw to five, not add multiple extra draws. For different competing replacements, source proposes highest value. This does not decide stacking of additive wording such as '+4 ATK'.

**User answer:** Two Elemental Masteries give twenty-four type advantage; two Options give six cards. They should stack.

**Implementation implications:** Do not apply highest-only replacement to these cards. Preserve exact confirmed outputs: base advantage 6, one Mastery 12, two Masteries 24; base draw 4, one Options 5, two Options 6. These examples use different stacking semantics, so do not implement a universal 'sum printed numbers' or universal 'multiply by two per copy' rule. Natural extensions (Mastery 12 per active copy, Options +1 per copy) are implementation interpretations, not separate express confirmations of three/four-copy outcomes. Competing differently named effects should not be assigned an unconfirmed highest-only policy.

**Additional user correction — Options wording:** Reword Options to say 'draw plus one card at the start of your go.'

**Reconciled card text:** At the start of your turn, draw one additional card.

**Implementation implications — Options:** Each active copy adds one card to normal turn-start draws: four plus number of active copies (absent other explicit effects). This replaces the source 'You now draw 5 cards during your Draw Phase' wording and resolves the formerly inferred +1-per-copy interpretation as explicit intent. Preserve P-07: turn-start draw occurs before subsequent start-turn effect choices. Do not create both an increased normal draw and a second duplicate extra-draw trigger. Record this as a card-text correction without changing the source CSV during this answers-only interview.

## P-20 — Nested responses

**Status:** Trap-on-trap prohibition rejected; same-player chaining, depth-first per-card resolution, up-front ordered selection and final healing confirmed.

**Source proposal:** One response window per event; Traps cannot respond to Traps; owner orders responses.

**Question and context:** Distinguish choosing several Traps for the original event from creating a new response to a Trap activation. The proposal permits the first but prohibits the second. Existing rules allow Trap activation only on opponent's turn, so the active player cannot activate their own Trap as a counter. Effects/cards that reference an activation may still raise nested-event questions. Ask whether a Trap activation itself can ever open a new response window rather than accidentally promising both players can chain Traps in violation of the turn restriction.

**User answer:** Trap effects can chain into other Traps for one player. Players still cannot chain Traps back and forth across turns/players.

**Implementation implications:** A qualifying Trap activation/effect may create a new response opportunity for that same player. Preserve the rule that Traps activate only on opponent's turn; do not let the active player counter with their Traps. Source proposal 'one window/no Trap responds to Trap' is superseded. Distinguish trigger detection from effect-resolution order, which is not settled by the word chain alone.

**Current follow-up:** When Trap B responds to Trap A, does B resolve first before A finishes, or does A finish resolving before B resolves?

**User answer — nested resolution using Plan B/Shared Fate:** Plan B processes cards one at a time. Destroy the first card, resolve its On Destruction effects, then other cards listening to that destruction such as Shared Fate, then effects listening to those events. Fully resolve the nested sequence before returning to Plan B and processing its next card. Repeat for the second/third and subsequent cards.

**Implementation implications:** Effects are resumable sequences, not indivisible batches. Use depth-first resolution of child events and responses before continuing the parent effect's next target. Offer newly eligible responses during each step. Plan B does not destroy every selected card simultaneously before processing triggers. A used Shared Fate follows its normal one-use departure to Spent; do not automatically reuse it for every later destruction. Preserve immediate defeat checks throughout. The explicit local order is destroyed card's own effects before other listening cards; cross-player ordering within such groups remains subject to the existing active-player rule unless a later answer further specifies precedence.

**Selection detail:** User says Plan B lets the player select multiple cards but first selects one. Whether later selections are committed up front or chosen after previous resolution is not settled by this answer; do not silently enforce a fixed preselected target list if the game must permit sequential choices.

**Current follow-up — Plan B healing:** Gain ten HP immediately after each destruction before child effects, or only once all chosen destructions and their nested effects have finished?

**User clarification — selection and healing:** Player selects multiple cards together and clicks Confirm. Resolve their destructions sequentially in the order selected, including each card's On Destruction effects, eligible Trap prompts such as Shared Fate, and all knock-on effects before the next selected card. Apply Plan B's healing at the end after the selected destructions and chains finish.

**Final implementation implications:** Preserve an ordered list of chosen card instances during the initial Plan B selection UI; do not ask the player to select each next Plan B destruction after seeing earlier outcomes. Three cards was the example, not a fixed cap; source still says any number. Resolution can still pause for legitimate optional triggers/Trap responses. After child chains fully resolve, resume at the next committed target, then award ten HP per card actually destroyed by Plan B, not per requested target or unrelated destruction caused by Shared Fate. Counting invalidated/protected targets follows actual destruction events; do not assume every selected target is guaranteed destroyed. Immediate defeat can end the game before final healing. No speculative generalized first-in/last-in queue policy replaces this explicitly described sequence.

## P-21 — Sacrifice timing

**Status:** Accepted; opponent-turn prohibition explicitly reiterated.

**Source proposal:** Sacrifice only during your own Main Phase 1 or Main Phase 2.

**Question and context:** Sacrifice is a normal action converting an eligible unit into AP, separate from playing an effect that explicitly sacrifices something. Should the normal action be disallowed during Battle and opponent's turn, even though many abilities and Spells are now allowed during own Battle? Existing same-turn-summoned restriction still applies.

**User answer:** Yes; you cannot sacrifice on your opponent's turn.

**Additional explicit confirmation:** User adds 'or in battle phase'. Own-main-phases-only timing is fully explicit, not just inferred from the initial yes.

**Implementation implications:** The yes accepts the proposed own-main-phases-only normal sacrifice action, with explicit emphasis on opponent-turn prohibition. Do not unlock ordinary sacrificing during Battle merely because manual unit abilities can be activated then. This is about the normal AP-refund action; separately worded card effects retain their explicit timing/legality.

## P-22 — Summon response versus On Summon

**Status:** Source Trap-first proposal rejected; On Summon first confirmed.

**Source proposal:** Opponent's summon-response Trap window resolves first; then summoned unit's On Summon effect resolves only if it is still on Field.

**Question and context:** Should opponent get a chance to respond to the summon before the unit's own On Summon effect occurs, potentially removing or debilitating it first? This is distinct from resolving an effect after it already began: the proposal delays its initial On Summon effect and requires it still be present. Existing active-player-first trigger order may instead suggest unit's On Summon first, so do not automatically ratify the prototype ordering.

**User answer:** On Summon effects should happen first.

**Implementation implications:** Resolve the summoned unit's On Summon effects before the summon-response Trap window. Do not suppress that initial effect by letting a later summon-response Trap destroy/disable the unit first. Preserve nested event resolution from P-20 and normal effect legality; this answer does not erase response opportunities produced inside the On Summon sequence itself.

## P-23 — Attack in this column

**Status:** Trap's own column anchor, card-specific interpretation and Magic Cylinder unit-target-only condition confirmed.

**Source proposal:** For an attack targeting a unit, use the target's column; for direct attack, use attacker's column.

**Question and context:** Units may attack across columns, so attacker's and target's columns can differ. A Trap saying 'opponent declares an attack in this Column' needs one definition. Should its relevance be the target's column rather than the attacker's, with attacker's column as fallback for a direct HP attack?

**User answer:** A Trap saying 'in this column' means the Trap's own column, not the column of whichever unit the effect refers to.

**Confirmed implications:** Interpret deictic 'this column' relative to the source Trap's board position. Do not dynamically relocate its column to a selected/attacking/defending unit. A unit the effect summons 'in this column' must enter the Trap's actual column.

**Remaining distinction:** For trigger text 'opponent declares an attack in this column', anchoring to Trap column does not yet determine whether the attacker, target, either, or attack path must match that column. Use a concrete cross-column example rather than restating the abstract proposal.

**Current follow-up:** If enemy in column one attacks your unit in column three, is an attack-column Trap eligible in your column one or column three?

**User clarification:** It depends on the wording of the Trap. Do not impose a universal attacker-column or defender-column rule on every card.

**Current concrete follow-up:** Magic Cylinder's condition is 'If your opponent declares an attack in this Column'. With Magic Cylinder set in column three, does an enemy in column one attacking your unit in column three satisfy that exact condition?

**User answer — Magic Cylinder:** Yes. Reword its condition to 'If your opponent declares an attack on one of your units in this column'. Attacking into column three satisfies Magic Cylinder in column three, regardless of attacker's column.

**Reconciled condition:** If your opponent declares an attack on one of your units in this Column:

**Implementation implications:** Match target friendly unit's column to source Trap's fixed column. Preserve HP-loss and persistent self-cost-increase effects from original text. Do not automatically apply this specific card rewording to every Trap; use each card's stated condition. Source P-23's attacker-column fallback for direct attacks is not confirmed by this answer and appears incompatible with the new unit-target condition.

**Current follow-up:** Does this rewording mean Magic Cylinder cannot respond to a direct HP attack, because no friendly unit is being attacked?

**User answer — direct attacks:** Yes, a direct attack does not trigger Magic Cylinder. Source position does not matter.

**Final implications:** Magic Cylinder responds only to attacks targeting a friendly unit in its own column; no direct-attack fallback. Preserve per-card wording for other column effects rather than generalizing all Traps to this card's specific condition.

## P-24 — Activates an effect

**Status:** Confirmed broad effect coverage; source trigger exclusion rejected.

**Source proposal:** Spell activation, manual unit/Power ability use and playing a Power count; On Summon/On Destruction triggers do not.

**Question and context:** Cards such as Energy Capture and Energy Dispel listen to the opponent activating an effect. Decide whether automatic/event-triggered effects count as activations too. Trigger conditions and opponent-turn Trap limits still apply; this is a classification question, not permission to activate Traps on own turn.

**User answer:** Any effect counts, whether a unit, Power, Spell or Trap effect. Anything listening for an activated effect includes all those. User explicitly requests adding this to the rules and card/database guidance Markdown.

**Implementation implications:** Include triggered effects such as On Summon and On Destruction, not only manually chosen activations. Apply the listening card's remaining conditions, ownership and turn restrictions. This does not permit Trap activation on own turn or opponent-only listeners to respond to own effects. Distinguish an actual effect activation/trigger from recomputing an already-active continuous modifier; do not generate an infinite event loop merely by recalculating UI or derived stats. Exact treatment of initial persistent-Power play can be clarified alongside P-25 if needed.

**Documentation updated:** `rules/01-GAME-RULES.md`, catalogue guidance in `rules/03-CARD-CATALOG.md`, and `rules/06-OPEN-DECISIONS-AND-CORRECTIONS.md`. Original CSVs and implementation code are unchanged by this answer.

## P-25 — Playing a Power

**Status:** Confirmed by user.

**Source proposal:** Playing a Power to its zone is main-phases-only; its abilities can be used in Battle.

**Question and context:** Distinguish placing a new Power from Hand onto the board (paying its card cost) from activating an already-present Power's ability. The latter is already allowed during own Battle. Should playing the Power itself remain restricted to Main Phase 1 or 2?

**User answer:** Yes, correct.

**Implementation implications:** Playing a Power from Hand to its board zone is allowed only during own Main Phase 1 or Main Phase 2, not Battle. Once on Field, its manually activated abilities may be used during own Battle when their other conditions/costs allow; triggered effects keep their established timing. Do not conflate Power play with ability activation.

## P-26 — Nimble move timing

**Status:** Corrected by user: Main Phases only, not Battle.

**Source proposal:** Nimble may move once per unit per turn in any owner's phase: Main 1, Battle, Main 2.

**Question and context:** Should Nimble's once-per-turn move be usable during own Battle and Main Phase 2 as well as Main Phase 1? Existing rules still require an adjacent empty friendly unit zone, consume a stack, and forbid movement while Paralyse applies. This does not reset an attack already used or create permission to move on opponent's turn.

**User answer:** Yes.

**Implementation implications:** Nimble move is available in own Main Phase 1, Battle and Main Phase 2, once per unit per turn, consuming one Nimble stack. Destination must be adjacent and empty; Paralyse prohibits movement. Does not reset attack allowance or allow opponent-turn manual moves.

**Superseding correction:** User immediately retracts the Battle permission: 'Nimble shouldn't be moveable during battle.'

**Final implementation rule:** Nimble can be manually used during own Main Phase 1 or Main Phase 2, not Battle or opponent's turn. Retain once-per-turn, stack consumption, adjacent-empty-zone and Paralyse restrictions. The preceding Battle-permitting answer and implementation paragraph are historical and superseded; do not implement them. This correction concerns Nimble, not all other legally timed movement effects.

## P-27 — Hidden response windows

**Status:** Source dummy-response proposal rejected; legal responses only.

**Source proposal:** If a player controls any face-down card, prompt them on every respondable event, including events where no Trap qualifies; only Pass then available. On by default for network play, off for hot-seat; configurable.

**Question and context:** Prompting only for legal Trap responses can reveal through pauses that a hidden card has a matching condition. Prompting whenever any face-down card exists hides that signal but creates extra manual Pass decisions; prompts wait indefinitely under the confirmed rule. Need user tradeoff, not automatic privacy assumption. This is about response visibility, not revealing hidden card identities.

**User answer:** Only prompt when there is a legal response. Some information revealed by the pause does not matter too much.

**Implementation implications:** Do not generate an indefinite Pass-only prompt merely because the opponent has a face-down card. Open response selection only for actual legal responses. Accept eligibility leakage through visible pausing as the user's chosen tradeoff; do not leak card identities or other hidden contents. Disable prototype hidden-response dummy windows for intended play rather than preserving the proposed network default.

## P-28 — Last-known attacker stats in responses

**Status:** Confirmed by user.

**Source proposal:** An effect reading attacker's ATK uses its attack-declaration value if the attacker has since left Field.

**Question and context:** Several responses can originate from the same declared attack. One may remove the attacker before another resolves, while the later effect still refers to its ATK. Should the later effect be allowed to use the recorded declaration ATK, or become invalid when the attacker leaves? This is distinct from P-11's reset-after-destruction-effects rule and from whether fresh response opportunities remain legal after the attack is interrupted.

**User answer:** Both responses should be able to trigger. If one needs the attack value that was on Field, save and remember that value.

**Implementation implications:** Keep attack-event context including attacker identity and its recorded on-Field ATK at declaration for eligible queued responses. Removal by an earlier response does not alone invalidate the later response or erase its required stat. Do not resolve the original battle if its attacker is gone; response continuation and battle legality are separate. Other target conditions still apply; this answer does not make newly illegal targets legal.

## P-29 — Self-recovery on destruction

**Status:** Self-retrieval exclusion confirmed in the supplied example.

**Source proposal:** A generic On Destruction retrieval effect cannot select the destroyed source itself from Spent.

**Question and context:** Solomon, the Captain can add a Warrior from Spent to Hand on destruction, and is itself a Warrior. Once destroyed and in Spent, should it be eligible to retrieve itself, absent wording saying another/different card? Source proposes excluding itself, but that exclusion is not in the card's generic wording. Distinguish source availability/location from field-state reset timing already settled in P-11.

**User answer:** It cannot retrieve itself.

**Implementation implications:** Exclude the destroyed source instance when selecting a card for its generic On Destruction retrieval effect, as illustrated by Solomon. Another copy is a different instance and can qualify if otherwise eligible. Do not remove explicitly written self-return effects such as Dante's scheduled self-revival; this decision concerns generic retrieval wording, not cancellation of named self-recovery exceptions.

## P-30 — Once-per-turn abilities without 'you can'

**Status:** Blanket optional-ability interpretation rejected; specific card corrections and invalid-text rule confirmed.

**Source proposal:** These are player-activated optional abilities, not forced activations.

**Question and context:** Chains of Binding says 'Once per turn, Apply 1 Paralyse to a Unit'; Yamata says 'Once per turn: your opponent loses -6 HP'. Neither says 'you can', but neither specifies an automatic triggering event. Should the player choose whether and when to activate them on their turn, instead of the game forcing them to resolve automatically? Explicit event-based triggers keep their own mandatory/optional wording.

**User answer:** These are inconsistencies. Chains of Binding should say 'you can'. Yamata should trigger at the start of your turn (user corrected an initial end-of-turn slip). Other mandatory effects with no timing are incorrect.

**Reconciled text — Chains of Binding:** Once per turn, you can apply 1 Paralyse to a Unit.

**Reconciled text — Yamata, Spirit of the Flame:** At the start of your turn, your opponent loses 6 HP. Other On Summon/On Destruction abilities remain unchanged.

**Implementation implications:** Chains is an optional manual ability with existing turn/phase legality. Yamata's opponent HP loss is a mandatory start-turn trigger, processed in the confirmed start-turn-effects step. Do not leave it as an optional anytime button or use end-turn timing. Do not infer a universal rule making every untimed mandatory effect optional. Flag invalid mandatory triggered/action text lacking an event/timing for correction. Valid ongoing passive effects are not invalid merely because they continuously apply without an activation event.

## P-31 — Steam lobbies

**Status:** Confirmed by user.

**Source proposal:** Friends-only lobbies by default, joinable through invitations; host may list publicly for Find Lobbies.

**Question and context:** Default visibility determines whether strangers can discover games. Should new lobbies default to friends-only/invite joining, with a host option to make them public and discoverable? Exact Steam visibility/join flags must be checked during implementation; do not conflate friends-only visibility with private invite-only behaviour if user needs a distinction.

**User answer:** Yes.

**Implementation implications:** Friends-only is the default lobby visibility, invitations are supported, and host may make a lobby publicly discoverable. Exact Steam flags/join capabilities require integration verification; this answer does not promise arbitrary strangers can enter friends-only lobbies.

## S-01 — Overlapping Sneaky Snunday reversals

**Status:** Two overlapping reversals cancel, confirmed by user.

**Source note:** Prototype does not reverse unresolved stacked-reversal cases.

**Question and context:** Playing two copies during the same turn could either apply one shared reversal while any copy is active, or two sign flips that cancel. Existing rules still assign reversal to newly played cards and dynamically recalculate ongoing modifiers; targets, statuses, ordinary battle damage and AP payments remain unaffected.

**User answer:** Two Sneaky Snundays reverse each other.

**Implementation implications:** Apply sign-reversal composition, not highest-only/shared nonstacking reversal. Two overlapping copies yield normal direction for newly attributed effects and live continuous-modifier recalculation. Existing delayed/instantaneous effects retain their already attributed transformation under the earlier confirmed play-time rule; do not retroactively flip completed or locked-in effects. Odd/even composition for more copies is the natural implementation extension, not an independent express example from the user.

## S-02 — Stat setting and copying

**Status:** Normal one-time assignment/copy behaviour accepted; no retroactive reversal.

**Source note:** Prototype does not reverse stat-setting/copying.

**Question and context:** Reversal clearly flips '+16 ATK' to '-16 ATK', but 'becomes this other unit's ATK/DEF' is an assignment, not a signed gain/loss. Should copied or assigned values stay normal, without treating their difference from current stats as a reversible delta? This covers Mimic and Mirrorflesh-style assignments; it does not decide multipliers yet.

**User answer:** Yes. These changes are instanced on summon, not ongoing. Sneaky Snunday only affects new and ongoing applications.

**Implementation implications:** Copy/set examples discussed remain normal assignments, rather than manufacturing a sign-reversed difference from previous stats. Snapshot these values when the relevant summon effect resolves; do not continuously track the copied source or retroactively reverse a completed assignment when Snunday toggles. This does not exempt every instantaneous numerical grant: earlier explicit examples still reverse new '+16 ATK' grants and newly attributed delayed gains/losses while reversal applies. User distinguishes completed effects from new/ongoing applications; preserve that along with assignment semantics, not a blanket 'on-summon effects immune' rule.

## S-03 — Multipliers

**Status:** Confirmed: multiplication is outside reversal scope.

**Source note:** Prototype does not reverse multipliers.

**Question and context:** Does a numerical effect phrased as 'double ATK' remain doubling under Snunday, or become its inverse (halving)? Existing status/counter exclusions still apply; this is numerical stat multiplication, not doubling Poison or other status stacks. If inversion chosen, rounding also needs definition where division is fractional.

**User answer:** Not yet provided.

**User context question and verified finding:** User asks whether any card doubles ATK. No named card in the supplied 183-card database does. One unnamed trailing row says 'At the start of your turn: Apply 1 Infiltrate to this Unit. If your HP is lower than your opponents, double this Units ATK.' The implementation also retains this as orphan text, not a verified named playable card. Ultimate Dragon and Mimic double debuffs rather than attack; statuses are already excluded from Snunday reversal. Do not describe this as a currently identified attack-doubling card or make this hypothetical case block existing-card implementation.

**User answer — operator scope:** It would not apply: Snunday specifically affects gains/losses, meaning addition/subtraction, not multiplication.

**Implementation implications:** Reverse signed additive/subtractive card-effect changes only, within previously confirmed exclusions. Do not turn doubling into halving, negate multipliers, or manufacture a gain/loss delta from assignments/copies. Division likewise is not an additive/subtractive operation. Existing statuses/counters and ordinary battle/AP-payment exclusions remain in force.

## S-04 — Self-cost increases

**Status:** Confirmed: additive self-cost changes reverse.

**Source note:** Prototype does not reverse self-cost increases.

**Question and context:** Magic Cylinder and Shimmer Serum increase their own future AP cost by one after activation; some units increase cost when destroyed. These are additive changes caused by card effects, distinct from AP payment itself (which never reverses). Should applicable Snunday reversal change such a +1 cost effect to -1, floored at zero? Existing play-time attribution/delayed-event rules must still determine when reversal is assigned.

**User answer:** Yes. Playing Sneaky Snunday and then Shimmer Serum reverses its attack grant to minus sixteen and its own cost change to minus one AP.

**Implementation implications:** Shimmer Serum applies -16 ATK rather than +16; its self-cost change becomes a reduction of one rather than an increase of one. Retain the zero cost floor: source cost zero remains zero after -1, not negative and not an AP refund. Its status application is not reversed. Actual AP paid to activate the card remains unchanged under the earlier confirmed exclusion. Additive future self-cost changes are within reversal scope; determine attribution from the already confirmed effect timing, not by blindly negating printed cost fields.

## Completion and handoff

The original register's thirty-one numbered proposals and four unnumbered Snunday topics are reviewed. Later answers in this file override conflicting prototype proposals. This record deliberately preserves earlier questions/replies for traceability; use each section's final confirmed answer and superseding correction, plus the summary above. No gameplay code, mode configuration or source CSV was changed as part of the interview. Rule guidance updated during the interview is documentation only. Follow-up implementation should audit each decision against the current game and test it rather than assuming these answers are already implemented.
