# Owner feedback, 21 Oct 2026 (playtest of build 0.3.6)

The owner's words for each item are quoted. Owner opening: "Really good changes well done, I've been testing it
and have a few more things for you to change". Standing instructions from the 20 Oct batch still apply
(release quality, no shortcuts, take decisions and list them, no pausing).

| ID | Owner text | Group | Status |
|---|---|---|---|
| H1 | "custom decks tab in the pre game deck selector should be first, structure decks second" | C panels | done |
| H2 | "the card action buttons should have better styling" | C panels | done |
| H3 | "remove the /60 hp bit at the end of the hp bar" | D perf | done |
| H4 | "the numbers on the piles should be centrered on the card (ignoring the name) so they match up with the circle on the card back" | B board | done |
| H5 | "I like the idle floating specs of light on the field but they should be a little moore faint, slightly too distracting as it stands" | D perf | done |
| H6 | "in the pile inspector on the list of cards, we should show race and cost on the preview list item beore it is expanded (iuncluding fusion material cost), also units should say the type of unit (Unit/Fusion/Ritual/Arcane), also instead of just the art we should use a small version of the cared like we do in the left input panel" | C panels | done |
| H7 | "I'm only getting like 80 fps, before I was getting 240?" | D perf | done |
| H8 | "the card tooltip should have some colour (that matches the details panel) for the seperate effects/info" | C panels | done |
| H9 | "pass for the rest of this turn should say skip for the rest of this turn" | C panels | done |
| H10 | "in the left pane input preview thing, a card in there can have its effect wording overflow the card, it should be correctly concatenated" | A card face | done |
| H11 | "in the right details panel make the atk/def sections shorter so more stuff can fit in the panel, also make the game log a bit shorter by default, with a collpase/extend button/indicator which toggles it between this new size and a size slightly larger than before, rather than being medium height all the time" | C panels | done |
| H12 | "when you click on a card and it has the selected corner indicators, one part of it does not have glow, also they are appearing underneath the zone sometimes" | A card face | done |
| H13 | "I like the sword icon thing on the unit zones, but now the trap/power ones are out of keeping, update them to match that new style" | B board | done |
| H14 | "cards on the field should display their full title, instead of and elipses we should shrink the name to fit" | A card face | done |
| H15 | "the draw/extra/spent/exhaust indicators on the pile I don't really like their design, can we update them please, make the match the name container on a facedown card (but at the bottom still)" | B board | done |
| H16 | "on the cards, the card art has a square brown border which is surrounded by a coloured rounded border, the card border should be a bit darker and also match the rounded outer border so it doesn't cut off the outer border" | A card face | done |
| H17 | "The cost/type/atk/def indicators on cards could look better, please make them look more fantasy and elaborate, I really like what you did with the AP gems so use that style as inspiration" | A card face | done |
| H18 | "When a pile is empty the amount of cards indicator should reamin the same size/position as when there are cards in it" | B board | done |
| H19 | "instead of wrapping card names on cards we should instead shrink them to fit on one line" | A card face | done |
| H20 | "the cards themselves could have a bit more visual flourish as well, a little too flat for my liking" | A card face | done |
| H21 | "the power trap inidcators on card should stay on the left not the center" | A card face | done |
| H22 | "the I go first and my opponent goes first buttons are too close together, give them some margin" | C panels | done |
| H23 | "when i killing blow an opponent the hitpoints lost appears underneath their player card" | B board | done |
| H24 | (deck builder, middle pane) "the atk/def should be smaller" | E deck builder | open |
| H25 | "the rules should ben split out into sections like in the game right preview pane, I don't want to have to scroll that middle pane ever" | E deck builder | open |
| H26 | "also remove the 'in your deck' tag under the card image" | E deck builder | open |
| H27 | "the in this deck section at the bottom should not have three empty by default, it should show one empty, and fill it when one is in, and add more filled gems when more are added, not this +2 or whatever after the three have been filled" | E deck builder | open |
| H28 | "ALSO THE ARCAN SUMMON COMPLETE SOUND EFFECT IS A BIT JARRING CAN ME MAKE IT MORE MYSTICAL AND COOL" | F audio | open |

## Decisions for review

- H1: the deck stage opens on Custom when you have a saved deck, otherwise on Structure; your tab choice then sticks for the session.
- H2: each action button has its own glyph and accent colour; buttons are 34 px tall (was 30).
- H3: max HP moved into a hover tooltip on the vial ("Health: 45 of 60"), since max HP can change.
- H4/H18: the count coin is exactly the card-back ring's size (covers it); an empty pile's "0" keeps the same size/place, a little dimmer.
- H5: motes about 20% fainter, slightly smaller, 14 instead of 16 (30% made the table look empty). Menu motes unchanged.
- H6: the "list" changed is the right-panel pile list (rows expand on hover); the big pile browser is a card grid and was left as is. The row card is 56x84, 7/8 of the left pane's 64x96, to keep rows compact.
- H7: idle duel ~172 fps and played duel ~190-200 fps uncapped on this machine (was ~80-100); see the perf table in the merge report. Remaining headroom: draw calls (~4000).
- H8: tooltip statuses appear only when the card text names them; a kind line was added.
- H11: log sizes are 22% / min 150 px (short) and 34% / min 220 px (tall; old was 28% / 180 px); remembered per viewer.
- H14/H19: very long names (e.g. "Anduras, Fisherman of the Ocean Tribe") are condensed sideways then shrunk, so on a field card they become tiny (~6 px). Alternative: a minimum size with a two-line fallback.
- H15: pile labels use the face-down card's plate, in normal case ("Draw", not "DRAW").
- H17: AP cost gem keeps dark numerals on the bright topaz; other gems use white with an outline. Field cost gem slightly larger.
- H20: strong foil only on Fusion / Ritual / Arcane; others a faint sheen.
- H12: brackets' halo slightly stronger on all parts.
- H23: damage numbers draw above struck plates but under the victory/defeat veil.

## Blockers and workarounds

- Agents' 20-turn limits: resumed repeatedly; no lost work.
- No in-duel "before" shots for the card face (no stash allowed); the card gallery covers every kind before/after.
- The perf baseline (18 Oct) played duel is not like-for-like (older rules and lighter screens).
