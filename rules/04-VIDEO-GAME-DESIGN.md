# Video-game design

## Confirmed product scope

Build in Godot with Godot networking integrated with Steam matchmaking and friend invitations. This is a two-player multiplayer product. The exact Godot version, networking transport, Steam integration and deployment credentials must be verified in the implementation environment. Do not claim Steam matchmaking works based only on a local network test.

The user will provide card art separately for each card. Existing image fields are references, not proof that artwork files are present. Use readable placeholders while awaiting art.

## Interaction

No drag-and-drop. Use buttons and explicit prompts for playing cards, selecting zones, choosing stances, selecting attack/effect targets, using abilities, choosing materials, responding to traps, selecting trigger order, inspecting piles and advancing phases.

Present only legal choices, or disable illegal ones with a useful reason. The game calculates legal timing, damage, HP, type advantage, modifiers, triggers and status changes automatically. Players should not manually compute or adjudicate them.

Use clear confirmation and cancel/back behaviour for selections that have not committed. Do not allow a cancel action to refund or undo an already resolved action without an explicit undo rule.

## Responses and pending choices

When a Trap is eligible, prompt its controller to activate or pass. Pause the active player's progression while the prompt is pending. Do not allow attacks, phase transitions or unrelated actions to race past an unresolved response. Wait indefinitely: no timeout or automatic pass.

If multiple Traps qualify, their owner chooses which to activate and their order. Resolve responses before the pending original action continues, if it is still legal and the game has not ended. Follow active-player-first ordering for same-event card triggers; do not conflate that rule with permission for an active player to bypass an opponent's trap prompt.

Unit and Power manual abilities default to their controller's turn, including Battle. Spells may be cast or activated only on their owner's turn, including Battle. Traps activate only on opponent's turn. Event-triggered effects can resolve on either turn. Detailed nested response policy remains open in file 06.

## Dynamic card presentation

Render artwork separately from live overlays for current ATK, DEF, effective cost, stance, status stacks and Rune counters. Update the display after each state change and aura recalculation. Explain current modifiers in card details rather than showing only a final number. Do not permanently bake runtime stats into artwork images.

A card-details button shows full effect text, current stat modifiers and status explanations for cards the player is allowed to inspect. Maintain visual distinction between Race, Type, ordinary AP costs, Rune requirements and Arcane requirements. Show typeless/raceless values clearly rather than as missing data. Dynamic stats must show their calculated result while retaining an explanation of their source.

## Visibility

| Information | Owner | Opponent |
| --- | --- | --- |
| Hand identities | Visible | Hidden |
| Own unrevealed set-card identity | Visible | Hidden until legitimately revealed |
| Face-up field cards | Visible | Visible |
| Spent, Exhaust and Extra Deck contents | Inspectable | Hidden unless effect grants selection access |
| Draw contents | Inspectable in randomized display order | Hidden unless effect grants access |
| Actual Draw order | Hidden except explicit knowledge effect | Hidden |
| Hidden-pile and Hand counts | Visible | Visible |

Draw inspection must not reveal or mutate the true Draw order. When an effect requires choosing from an otherwise hidden pile, show the whole relevant pile to the chooser for that selection. Example: choosing a card from opponent's Spent to exhaust. Do not permanently make that pile public or reveal it to uninvolved players.

The same visibility policy must apply to tooltips, selection previews, network messages and the game log. Do not send hidden information to a non-authoritative opponent client merely because the UI chooses not to render it. A player-hosted authority may inherently hold full state; document that trust limitation rather than promising resistance to a malicious host.

## Game log — confirmed requirement

Provide a scrollable history of game events that players can refer back to. Record phase/turn changes, committed actions, responses, resolved effect steps, damage/healing, AP changes, public summons/destructions, status/counter changes, zone transitions, pending choices and game/series outcomes as visibility permits.

Represent exact resolution order, including response-before-battle and immediate lethal outcomes. Prefer concise explanations such as 'Type advantage +6; 14 versus 10; 4 HP lost' for public combat rather than unexplained totals.

Preserve hidden information: a public draw entry gives a count, not card identity; setting a hidden card must not reveal its name; private search contents must not appear in the opponent's log. If an internal full-state diagnostic log exists, keep it separate from player-visible history. Whether players can export logs or review them after a match is not specified.

## Multiplayer continuity

Steam matchmaking and friend invitation flows lead into the same validated game setup. On disconnect, pause and wait for reconnection rather than immediately forfeiting. Preserve the authoritative match state, pending response and whose choice is required. Resume without duplicate costs, effects, draws or attacks. Reconnect timeout, host migration and process-restart recovery are open.

## Match setup and progression

Support preselected decks and a drafting flow, configurable series length, applicable basic-unit configuration, and between-game rewards for both players. Keep undefined deck sizes, draft offerings and reward counts in clearly named mode configuration rather than hardcoding them as rules. Begin with placeholder UI and a narrow local validation scenario while progressing to the full network product; local testing is a recommended development tool, not a replacement for Steam multiplayer.
