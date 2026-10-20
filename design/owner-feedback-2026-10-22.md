# Owner feedback, 22 Oct 2026 (playtest of build 0.3.7)

The owner's words for each item are quoted. Owner instruction: "log them and address them one by one, using
subagents and models as appropiate, with our usualy level of full prodcution level polish, no shortcuts, review all
your work visually and with tests, make sure everything looks and behaves as excellently as you can, as well as
keeping an eye out for other fixes/improvements I may not have direclty suggested. Also when you're finished perform a
performence review make sure there are no functions/logic that is noticably slowing down the game, I want to try to
optimise performence, not at the sake of any functionality, but any free wins we should take."

Standing instructions from earlier batches still apply (release quality, no shortcuts, take decisions and list them,
no pausing).

| ID | Owner text | Group | Status |
|---|---|---|---|
| J1 | "on the saved decks list, edit/delete icons are not round, they should be" | F menus | done |
| J2 | "the background image on the mian menu moves ever so slightly up down left right occasionally, it might be to do with the floating orb animation?" | F menus | done |
| J3 | "in the right pile preview it should not expand on hover, it should only expand on click" | C duel panels | done |
| J4 | "the details panel should only show the card details when a card is clicked, not on card hover" | C duel panels | done |
| J5 | "when the scroll for more indicator disappears, the rest of the content jumps, it should be overlaid rather than forming part of the scrollable content" | C duel panels | done |
| J6 | "add a button under your player card to toggle trap response prompts, i.e when the toggle is off, it disables the trap response prompt, to help hide information" | D duel controls | done |
| J7 | "bottom right 'turn x . player name Timer', the player name overlaps with the timer, just remove player name from that, the indicator on the player cards is enough" | C duel panels | done |
| J8 | "also remove the protected/protecting tags from the details pane" | C duel panels | done |
| J9 | "if a user makes the final killing action, other interactions should be disabled, i actived another attack after and it skipped the animation/kept a card on the screen for rewards" | E end of game | done |
| J10 | "if a card is selected when a game ends it sometimes appears above the card reward screen, everything else should be behind that screen" | E end of game | done |
| J11 | "add a button under the player card for 'sacrifice unit' this should be styled cool, and we should remove the option from the card action buttons, to prevent accidental misclicks" | D duel controls | done |
| J12 | "on the reward screen the 'picks' indicator has square corner decoration on a round button, we should make the corner decoration there and everywhere else rounded to fit the buttons" | E end of game | done |
| J13 | "in the menu, concede game should come below return to menu" | E end of game | done |
| J14 | "when a card is able to ritual summon into a card, the button should not say the card name, it should just say 'ritual summon' (even if there are multiple valid targets) and then bring up the card select modal to choose" | D duel controls | done |
| J15 | "on the card rewards screen there is a black dark overlay on the rest of the field but it does not go all the way to the top, it should fill the screen and the two buttons up there should remain above it (z-index above not vertically)" | E end of game | done |
| J16 | "the card hover tooltip should not have the status descriptions in it any more, they just confuse" | C duel panels | done |
| J17 | "the chat button should have an indicator pop up (animated with a sound effect) when there is a new chat" | A lobby/chat | done |
| J18 | "the chat button should be available in the draft screen" | A lobby/chat | done |
| J19 | "remove 'enter sends esc closes' on the chat" | A lobby/chat | done |
| J20 | "the close button top right of the chat should be round and more obvious, and it doesn't work" | A lobby/chat | done |
| J21 | "in the spectator list there should be a mute button which hides their chat/notifications" | A lobby/chat | done |
| J22 | "we should also replace the spectator button with an always present 'view lobby' button which brings up the spectator list, but that should also now have two sections, players/spectators, and for the players they will only have the mute option" | A lobby/chat | done |
| J23 | "do we definitely shuffle the deck before game start?" | D duel controls | done |
| J24 | "when starting a match against a bot, if the 'custom decks' option is selected, we should show a button that says 'choose the bot's deck' which when checked, after selecting your deck, instead of going straight to the game it brings up another deck select screen that allows you to pick a deck for the bot" | F menus | done |
| J25 | "paralyse should stop you manually changing stance as well as movemnt, forced stance changes from other cards are not prevented, update the status description wording" | D duel controls | done |
| J26 | "when setting up a draft game remove the option for how many of each type of card to pick, just use a fixed: 4 unit, 2 spells, 2 traps, 1 power, 3 extra deck" | B draft | done |
| J27 | "on the first draft screen the tabs should keep their bg colour when selected, the whole background of the main section can change to match the tab so it fits in with the tab colour" | B draft | done |
| J28 | "on the draft screen the list on the right should match the pile viewer list styling/information" | B draft | done |
| J29 | "the cards you have drafted so far grid is nice but should show the actual cards, with the nice formatted hover tootlip - like in game" | B draft | done |
| J30 | "when drafting cards, instead of automatically going to the deck locked in screen we should show a 'confirm selections' button first, I want to allow changing basics even after all cards are drafted" | B draft | done |
| J31 | Performance review after the batch: "make sure there are no functions/logic that is noticably slowing down the game ... any free wins we should take" | G perf | done |

## Decisions for review

**Lobby / chat**
- J17: a new message (chat closed) pops a speech-bubble preview under the Chat button for ~4 s (hover holds it, click opens the chat) with a new `chat_pop` sound; the badge is larger and ripples in. Your own messages raise nothing.
- J18: the Chat button was already in the draft's top strip but the open box could not be clicked there (clicks fell through to the draft's dim). Fixed rather than adding a second button.
- J19: hint removed; Enter / Esc still work (named in the tooltips).
- J20: new round gold close medallion; it now works over the draft and every series modal (root cause: Godot routes clicks by tree order, not draw order).
- J21: mute is local, per session, keyed by spectator id (a rejoin comes back unmuted; matching by name would mute every "Guest"). System lines such as "X is now spectating" stay.
- J22: View lobby is always shown online (players and spectators); Players section (You / Mute) and Spectators section (Mute + the eye permission for players).

**Menus**
- J1: the deck builder's rows stretched the icons to 28x36 ovals; now 28x28 discs drawn anti-aliased, and the rename icon is a real pencil. The pre-game deck stage has no icon buttons.
- J2: not the orb: the backdrop's slow 40 s zoom (1.000-1.006) made pixel snapping jump the painting by 1 px every few seconds. The zoom is removed (motes and light shaft keep the screen alive). Probe: 239 positions / 19 jumps -> 1 / 0.
- J24: two-step flow with "Step 1 of 2 / Step 2 of 2" and a "Your deck" chip; Back or Esc returns; the bot screen opens on your last tab; mirror matches allowed; the checkbox is remembered per profile.

**End of game**
- J9: from the killing view until the end presentation has played, clicks (except wheel) and keys (except chat typing) are swallowed; the kill and victory now always play out (3-5 s, no click-to-skip). Safety release after 8 s+.
- J10: the series modal moved above every board layer (hover, arrows, FX, damage numbers, lifted cards) and board interactions (selection, action row, hover, inspector, status tip) clear when the kill arrives.
- J12: corner brackets now bend in a quarter arc that follows the rounded shape; applied to all panels, tiles, the Picks plate, and the card / target / pile selection brackets. Panel bodies no longer leave dark square corners.
- J13: Settings, Return to menu, divider, Concede game, Quit to desktop. Concede now hides between duels.
- J15: the rewards dim fills the window; the top strip (Menu, Chat) rises above it while the modal is up. After a game it also covers the sidebar; on the deck choice it stops at the sidebar (the draft list lives there).

**Duel panels**
- J3: pile rows open on click, close on a second click; hover shows a gold rim only.
- J4: details follow clicks only (hover still lifts the card and shows the tooltip). Clicks that answer a prompt (targets, tray picks) keep the acting card in the panel. Empty state reads "Click a card to read it".
- J5: the "Scroll for more" cue is an overlay (34 px fade over the last lines) so nothing moves when it fades.
- J7: "Turn X" only. J8: Protected / Protecting chips removed ("Controlled until" stays). J16: no status descriptions in the hover tooltip.

**Duel controls and rules**
- J6: Trap Prompts toggle (bell + gem lamp) under your plate, on by default, saved per viewer (per seat in hot-seat), local to the seat online, never logged or shown to the opponent. On: asked only when one of your Traps can respond (owner, 22 Oct: "if prompts are on only show the prompt when a valid trap is activatable, it's okay for some information to be given"). Off: never asked, your Traps stay down and the opponent never sees a pause. Turning it off mid-prompt answers Skip. The engine keeps an unused "always" mode (asked with any face-down card).
- J11: Sacrifice Unit button (forged, ember glyph) under the plate, plate-wide; pick a unit, then a red Sacrifice confirm or Cancel / Esc. Removed from the card action row. The hand shifts right to make room (squeezes slightly at 8+ cards).
- J14: one "Ritual Summon" button; it always opens the tray, even with one valid Ritual unit, so the flow is the same each time.
- J23: **yes, every real mode shuffles** (bot, local, online, every series game, custom and drafted decks: `MatchEngine.setup` shuffles each Draw pile from the series seed; online, the host shuffles). Only the tutorial uses a fixed order, on purpose. Now proven by tests.
- J25: Paralyse blocks manual stance changes too (the stance button is hidden); forced changes still happen. Status text updated in the game; `data/status_source.json` comes from your source sheet and still has the old wording, so its next export should add "or change stance".

**Draft**
- J26: fixed 4 Unit / 2 Spell / 2 Trap / 1 Power / 3 Extra (in `data/mode_config.json`); with 3 basics the deck is 15 cards. The menu shows a read-only "Each player drafts" chip row instead of steppers.
- J27: the open tab keeps its colour and the whole main section takes it (soft dark fade at the bottom for readability), fading across on switch. Deck and builder tabs unchanged.
- J28: draft list rows reuse the duel's pile row (small card, kind, cost, race / type, Fusion materials, same tooltip).
- J29: the drafted grid shows the real cards (56x84) with the duel tooltip and right-click inspect; the newest pick lifts into its slot.
- J30: after the last pick a "Your draft is complete" panel shows the basic unit (Change basic unit), the picks per category and a big Confirm selections button; both seats confirm online; the bot confirms at once. A finished but unconfirmed draft is reported to telemetry as abandoned.

**Integrator**
- Nearby: the CTA sheen on the turn button dropped corner slivers that failed to triangulate (console error in the tutorial); blocked stance notes read "Cannot change to defense".

**Performance (J31)** (1600x1000, vsync off; evidence in `production/qa/evidence/2026-10-22-batch/perf/`)

| Screen | Before batch | After | Draw calls |
|---|---|---|---|
| Idle duel | ~167 fps | 199-224 fps | 4043 -> 1331 |
| Played duel | ~136-187 fps | 266-324 fps | ~4150 -> 1460-1682 |
| Deck choice | ~253 fps | 362-403 fps | 4182 -> 1832 |
| Rewards | ~183 fps | 230-255 fps | ~5200 -> 2159-2717 |
| Draft | ~170 fps | 454-477 fps | 4034 -> 1686 |

- Fixes: the seat view reuses settled log rows (a command in a long game ~1.8 ms cheaper; the cost used to grow with the log); the draft grid and pips repaint only the breathing piece; the empty details engraving breathes by alpha; card overlay rings share one style box; each empty board zone is drawn as one cached triangle list (Godot's own tessellation, same blend order) instead of ~92 draw calls.
- Deviation: a texture bake was tried for the zones and rejected (it shifted 28% of zone pixels and badly wrong under a dim); the merged geometry differs on under 0.05% of zone pixels by at most 2/255 at four window sizes.
- A zone being picked still draws the old way (~100 extra draw calls while a pick is open), because the old drawing is not frame-stable there under MSAA.
- Guards: draw-call budget (`perf_screens --budget`, idle duel <= 2000), no-idle-redraw tests for the new widgets, a cached-log vs rebuilt-log equality test.
- Not done (next headroom): pile stacks are now most of the remaining idle draw calls (~1200 of 1331); the pulsing ready-card overlays and the plate rim / phase pips cost ~0.9 / 0.5 / 0.3 ms but an exact split needs more layers. The slowest 5% of idle frames above ~220 fps are unexplained (possibly the compositor); not felt at normal refresh rates.

## Blockers and workarounds

- Specialist agents stopped every 20 turns (`maxTurns` in `.claude/agents/*.md`); raised to 150 at the owner's request.
- Parallel test runs share `user://test_player_stats.json`, so one stats test failed once while two suites ran at once; it passes alone (3/3).
- `data/status_source.json` (from the owner's sheet) still has the old Paralyse wording; the game text is updated.
- Series driver: the known "F06 field hover returns after cancel" real-mouse flake.
