# Playtest feedback 06 (F06)

Captured on 17 Oct 2026. `production/stories/playtest-feedback-06.md` is an older, unrelated round.

## F06-01 — Every modal follows the input-panel design

**Request:** the user loves the design of the player-action input panel on the left (`PromptPlate`, F04-13). Make every modal follow that design, including the card select modal.

**Done when:**
- The card select / choice tray, dialogs, the in-game menu, the inspector, the pile browser, the series modals, the lobby list, the privacy screen and the tutorial cards all share the same layered look: header strip, body plate, accent bar and corner flourishes.
- Behaviour is unchanged.

## F06-02 — New soundtrack with menu and battle playlists

**Request:** replace the existing soundtrack with five tracks supplied by the user (`menu_1`, `menu_2`, `battle_1`, `battle_2`, `battle_3`).
- The two menu songs play on the menu, draft, rewards and similar screens.
- The three battle songs play once a game starts.
- Loop through every appropriate song.
- Fade between songs, and between scenes.

**Done when:**
- The menu playlist plays outside games and the battle playlist plays during a game.
- Each playlist plays its songs in turn and loops.
- Song changes and scene changes crossfade.

## F06-03 — Replace the structure decks

**Request:** remove the existing structure decks and replace them with the 12 decks in the user's sheet: Moving Ocean, Chaos Witch & Rotmaw, Spirit Bomb, Dragons Domination, Basic Beatdown, Zorath / Shapeshifter, Shen / Necrovast, Divine Serpent, Yamata's Fire, Lone Warrior / Revealed, Bahatia Chaos, Auric & Neva.

**Done when:**
- Exactly these 12 decks are offered, with the sheet's ids.
- Every card is implemented.
- Main Deck and Extra Deck routing is correct.

**Notes from the sheet:**
- Deck 10's third Extra Deck card is `#REF!`.
- The Symbiote cards appear as `#N/A`.
- For two Tag Team cards the sheet's ids and names disagree.

## F06-04 — "Change basic units" reward changes all of them together

**Request:** the "Change a basic unit" reward becomes **Change basic units**, and all three basic units change at the same time.

**Done when:**
- The reward is labelled "Change basic units". The player picks a Type and a Race, and every basic unit in their deck becomes that variant in one step.
- There is no per-card choice.
- It still spends one reward pick.

## F06-05 — Choose the draft category order

**Request:** in draft mode, each player can choose the order in which they draft the categories. This needs a good, well-designed UI.

**Done when:**
- Before drafting starts, each player orders their categories (Unit, Spell, Trap, Power, Extra Deck). The order uses the configured counts.
- The draft then follows that player's order.
- Online, each seat sets its own order and the host validates it.

## F06-06 — Basic unit chosen in the draft, not counted

**Request:**
- Remove the option to change how many basic-unit drafts each player gets.
- In the new draft UI, add a **Choose basic unit** button. It lets the player select a Type and a Race, like the change-basic-units reward.

**Done when:**
- The draft composition controls no longer include Basic Unit.
- Each player chooses one basic unit, by Type and Race, and gets `basic_copies` (3) copies of it.
- The chosen basic unit is shown in the draft list.
