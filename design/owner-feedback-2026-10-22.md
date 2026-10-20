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
| J1 | "on the saved decks list, edit/delete icons are not round, they should be" | F menus | open |
| J2 | "the background image on the mian menu moves ever so slightly up down left right occasionally, it might be to do with the floating orb animation?" | F menus | open |
| J3 | "in the right pile preview it should not expand on hover, it should only expand on click" | C duel panels | open |
| J4 | "the details panel should only show the card details when a card is clicked, not on card hover" | C duel panels | open |
| J5 | "when the scroll for more indicator disappears, the rest of the content jumps, it should be overlaid rather than forming part of the scrollable content" | C duel panels | open |
| J6 | "add a button under your player card to toggle trap response prompts, i.e when the toggle is off, it disables the trap response prompt, to help hide information" | D duel controls | open |
| J7 | "bottom right 'turn x . player name Timer', the player name overlaps with the timer, just remove player name from that, the indicator on the player cards is enough" | C duel panels | open |
| J8 | "also remove the protected/protecting tags from the details pane" | C duel panels | open |
| J9 | "if a user makes the final killing action, other interactions should be disabled, i actived another attack after and it skipped the animation/kept a card on the screen for rewards" | E end of game | open |
| J10 | "if a card is selected when a game ends it sometimes appears above the card reward screen, everything else should be behind that screen" | E end of game | open |
| J11 | "add a button under the player card for 'sacrifice unit' this should be styled cool, and we should remove the option from the card action buttons, to prevent accidental misclicks" | D duel controls | open |
| J12 | "on the reward screen the 'picks' indicator has square corner decoration on a round button, we should make the corner decoration there and everywhere else rounded to fit the buttons" | E end of game | open |
| J13 | "in the menu, concede game should come below return to menu" | E end of game | open |
| J14 | "when a card is able to ritual summon into a card, the button should not say the card name, it should just say 'ritual summon' (even if there are multiple valid targets) and then bring up the card select modal to choose" | D duel controls | open |
| J15 | "on the card rewards screen there is a black dark overlay on the rest of the field but it does not go all the way to the top, it should fill the screen and the two buttons up there should remain above it (z-index above not vertically)" | E end of game | open |
| J16 | "the card hover tooltip should not have the status descriptions in it any more, they just confuse" | C duel panels | open |
| J17 | "the chat button should have an indicator pop up (animated with a sound effect) when there is a new chat" | A lobby/chat | open |
| J18 | "the chat button should be available in the draft screen" | A lobby/chat | open |
| J19 | "remove 'enter sends esc closes' on the chat" | A lobby/chat | open |
| J20 | "the close button top right of the chat should be round and more obvious, and it doesn't work" | A lobby/chat | open |
| J21 | "in the spectator list there should be a mute button which hides their chat/notifications" | A lobby/chat | open |
| J22 | "we should also replace the spectator button with an always present 'view lobby' button which brings up the spectator list, but that should also now have two sections, players/spectators, and for the players they will only have the mute option" | A lobby/chat | open |
| J23 | "do we definitely shuffle the deck before game start?" | D duel controls | open |
| J24 | "when starting a match against a bot, if the 'custom decks' option is selected, we should show a button that says 'choose the bot's deck' which when checked, after selecting your deck, instead of going straight to the game it brings up another deck select screen that allows you to pick a deck for the bot" | F menus | open |
| J25 | "paralyse should stop you manually changing stance as well as movemnt, forced stance changes from other cards are not prevented, update the status description wording" | D duel controls | open |
| J26 | "when setting up a draft game remove the option for how many of each type of card to pick, just use a fixed: 4 unit, 2 spells, 2 traps, 1 power, 3 extra deck" | B draft | open |
| J27 | "on the first draft screen the tabs should keep their bg colour when selected, the whole background of the main section can change to match the tab so it fits in with the tab colour" | B draft | open |
| J28 | "on the draft screen the list on the right should match the pile viewer list styling/information" | B draft | open |
| J29 | "the cards you have drafted so far grid is nice but should show the actual cards, with the nice formatted hover tootlip - like in game" | B draft | open |
| J30 | "when drafting cards, instead of automatically going to the deck locked in screen we should show a 'confirm selections' button first, I want to allow changing basics even after all cards are drafted" | B draft | open |
| J31 | Performance review after the batch: "make sure there are no functions/logic that is noticably slowing down the game ... any free wins we should take" | G perf | open |

## Decisions for review

## Blockers and workarounds
