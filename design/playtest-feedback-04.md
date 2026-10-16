# Playtest feedback 04 (F04) — polish to production quality

Captured 16 Oct 2026 from the user's playtest after the F03 batch. The user's direction for
the whole batch: **"I want the game looking fancy and production ready, so try to maximise
design quality for all elements you touch, no shortcuts."** Every item is held to that bar:
layered panels (backgrounds, borders, shadows, flourishes) in the established dark-fantasy
gold style, formatted text rather than plain text, and animation where it adds clarity.

Note: `production/stories/playtest-feedback-04.md` is an older, unrelated round; this batch is
tracked in `production/stories/playtest-feedback-F04.md`.

Statuses: Captured → In progress → Implemented — unverified → Verified.

## Board and match

### F04-01 — Coin flip readable over the field
**Report:** The "goes first" coin-flip text and animation blend into the field.
**Wanted:** A darker backdrop, shadow or similar treatment so the coin and its text stand out.
**Acceptance:** The coin flip and its result text read clearly over any board state at
1600x900 and 4K. The treatment fits the art direction rather than looking like a plain black box.

### F04-02 — Pre-game deck select screen
**Report:** The deck selection before a series needs to be better.
**Wanted:**
- Consistent formatting for every deck.
- Separate tabs for structured (starter) decks and custom (saved) decks.
- Good scrolling behaviour.

**Acceptance:**
- Both tabs list their decks in the same tile format.
- A long list scrolls smoothly within the panel, and the panel never overflows the screen.
- Choosing a deck works from both tabs, for both seats and online.

### F04-03 — Rewards modal
**Report:** The rewards modal is too wide and its layout is plain.
**Wanted:** A narrower modal with better design and layout. As a rule, avoid plain text unless it is necessary.
**Acceptance:**
- The modal is narrower.
- Reward choices, picks remaining and actions are presented as designed elements (cards, chips, icons, panels), not text lines.
- Every reward flow still works: add, remove, change basic, skip, view deck.

### F04-04 — Victory / defeat presentation fills the screen
**Report:** The victory animation is clipped to the field's bounding box.
**Wanted:** Full-screen victory and defeat presentation.
**Acceptance:** The veil, rays and text cover the whole window, including the sidebar, at 1600x900 and 4K.

### F04-05 — Sharp card names
**Report:** Card names look blurry.
**Wanted:** Find the cause and sharpen them. Use real font sizes instead of scaling.
**Acceptance:** Name text on cards is crisp at every card size (mini, hand, big, inspector, deck builder), with the cause documented. No visual regressions in layout.

### F04-06 — No colour square before Spell/Trap/Power type text
**Wanted:** Remove the green/red/blue square shown next to the card type text on Spell, Trap and Power cards.
**Acceptance:** Card faces and every other place showing that text have no square. Category stays recognisable through the card's colours and frame.

### F04-07 — Direct attack and killing-blow effects
**Wanted:**
- The direct-attack animation is bigger, with fancy effects.
- When it is the killing blow, it goes into slow motion with a big magic explosion before the victory animation and screen.

**Acceptance:**
- A direct attack reads as a big, satisfying hit.
- A lethal hit (direct, or any lethal damage where practical) plays the slow-motion explosion, then the F03-13 victory/defeat presentation.
- The sequence plays once, can be skipped by a click, and never changes the outcome or timing of the rules.

## Tutorial

### F04-08 — Tutorial target ring stays under modals
**Report:** The tutorial's highlight ring appears above some modals and card popovers.
**Wanted:** The highlight never draws above modals, popovers, inspectors or dialogs.
**Acceptance:** With the inspector, pile browser, game menu, confirm dialog or card popover open during a lesson, the ring and arrow are hidden or beneath them.

### F04-09 — "Play tutorial" for new players
**Wanted:** For a player who has not played a game yet, the top of the main menu shows **Play tutorial** instead of **Resume**.
**Acceptance:**
- A fresh profile (no saves, no completed games, no tutorial run) shows Play tutorial at the top, which opens the tutorial.
- Once the player has played, Resume behaves as before.

### F04-10 — Tutorial arrow direction
**Report:** When the arrow's bob animation pushes it slightly off screen, it flips direction.
**Wanted:** Choose the direction once, from the full space the arrow takes up over its whole animation.
**Acceptance:** No flicker or flip near screen edges at either window size.

### F04-11 — Tutorial pane buttons at the bottom
**Wanted:** The tutorial info pane's buttons (Restart, Exit, Next) sit at the bottom of the box.

### F04-12 — Formatted tutorial text
**Wanted:**
- Key words formatted for visual interest with colour, bold or font as appropriate: phases ("Battle Phase"), stats ("ATK", "DEF", "AP"), card names and so on.
- Button names in quotes ("Go to Recovery").
- Newlines to split up walls of text.

**Acceptance:** Every lesson step uses consistent formatting, and no step is an unbroken wall of text.

### F04-14 — Lesson complete modal
**Wanted:**
- Better formatting with visual layers.
- The Next button placed above the other two buttons.

## Prompts

### F04-13 — Input panel fits content and gains depth
**Report:** The left input-required panel is sometimes very tall. It is flat text.
**Wanted:**
- Fit to its content in every case.
- Layered design: backgrounds, flourishes, depth.

**Acceptance:** In every prompt kind (zone, target, Type, Trap response, multi-pick, waiting), the panel hugs its content and looks designed, at both window sizes.

## Card inspector

### F04-16 — No close hint
**Wanted:** Remove the "Esc or click outside to close" text from the inspector.

## Deck builder

### F04-15 — Preview pane formatting
**Wanted:** The preview pane text below the image is formatted like the in-game card details pane.

### F04-17 — Saved-deck list
**Wanted:** Nicer formatting and UI for the list of decks on the right.

### F04-18 — Deck contents as a card grid
**Wanted:** The cards in your deck are shown as a grid of card images, not a list of text rows.
**Acceptance:**
- Counts are visible.
- Main and Extra Deck are separate.
- Add/remove still works, and right-click still inspects.

### F04-19 — Catalogue cells without the caption box
**Wanted:** Remove the container with the card-type caption and the brown border that extends below each catalogue card.
**Acceptance:**
- Cards stand on their own.
- Same-name basic variants stay distinguishable (Type icon).
- The in-deck count and remove control remain usable.

### F04-20 — Save error near the name field
**Wanted:** The "give your deck a name before saving" error appears next to the name input, not at the bottom left.

### F04-21 — Remove the limits note
**Wanted:** Remove the text "No limits on size, mix or duplicates. Fusion, Ritual and Arcane cards go to the Extra Deck automatically."

## Rules flow

### F04-22 — Fusion material selection before costs (Sepukku and all Fusion methods)
**Report:**
- Fusing with Sepukku first brought up the card-select modal for the first material.
- It then destroyed Sepukku.
- It then asked for a Field card with the arrow coming from where Sepukku had been.

**Wanted:**
1. Select the first material from the Field.
2. Select the second material from the Field.
3. Confirm.
4. Then Sepukku is destroyed.
5. Then the Fusion summon and its animation.

The whole action stays cancellable right up until Confirm. Make sure the other Fusion mechanics behave the same way: materials chosen and confirmed before any cost or self-destruction is applied.

**Acceptance:**
- For Sepukku and every other Fusion method, all material choices happen first, on the board where the materials are.
- Cancelling at any point before Confirm leaves the game exactly as it was: no cost paid, no card moved or destroyed.
- After Confirm, costs and self-destruction resolve, then the summon.
- Arrows originate from the method's source while it is still on the Field.
- Rules tests cover each Fusion method's cancel and confirm paths.
