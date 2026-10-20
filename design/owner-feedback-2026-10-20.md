# Owner feedback, 20 October 2026 (release-readiness batch)

Source: owner message, 20 Oct 2026. Goal: make the game ready for release. Every change must be as
professional and polished as possible, with no shortcuts. It's a fantasy game, so nothing should look
flat or plain: sound, animation and texture everywhere it fits. Anything else seen along the way that
could be better is fixed too.

Working rules for this batch:
- The owner checks the feedback and answers questions first, then work runs unsupervised.
- Don't pause to ask. Take executive decisions and list them under "Decisions for review" (bottom).
- If blocked (permissions etc.), work around it and report it at the end.
- Delegate to the matching specialist subagents. Use a cheaper model (sonnet / haiku) for light
  tasks and opus for heavy ones.
- Branch `build/rldb-game`. Commit per item, never push. Run the full suite before export. Never export
  while RLDB is running (memory: no-export-while-running).
- UI items need retained screenshots in `production/qa/evidence/2026-10-20-release-batch/`.
- Card data CSV: `C:\Users\fergm\Downloads\RLDB - Full Updated Card Database.csv` (wording only,
  no effect changes).

Status key: `todo`, `wip`, `done` (with commit), `n/a` (already done / not needed).

## A. Online / social

| # | Item | Status |
|---|---|---|
| A1 | Chat button next to Menu opens a text chat box so players can type to each other. Remove the "Steam (connected)" text. | todo |
| A2 | Spectating: anyone who joins (invite or public lobby list) once seats 1 and 2 are taken becomes a spectator. By default a spectator sees neither player's hand or face-down cards. The player menu gets a "Spectators" button: a list of spectators, each with an icon. Tooltip "Allow this player to see your cards"; once allowed, the icon changes and the tooltip reads "Stop this player seeing your cards", which reverts them. An allowed spectator sees almost exactly what that player sees: face-down cards, piles and hand, the same board orientation, and the player's mouse position. They don't see that player's UI prompts (buttons, effect descriptions). | todo |

## B. Rules

| # | Item | Status |
|---|---|---|
| B1 | Hot Stove only activates when a Power's effect is actually activated, not when the Power is played. | n/a, done 18 Oct (feedback item 15); re-verify |
| B2 | Traps that trigger on summon resolve after the On Summon effects. | n/a, done 18 Oct (item 16); re-verify, including Trap Hole and the other summon traps |
| B3 | No Attack/Defense choice when summoning, except on the opponent's turn or in the Battle Phase. Otherwise summon in Attack stance; the player can change stance afterwards. | todo |
| B4 | Ambush lets you pick where each summoned card goes. | todo |
| B5 | Divine Serpents' On Summon: the first destruction animation doesn't play (timing). Make sure the unit is visibly summoned, then destroyed. Give this effect its own animation: the Serpents combine and damage the life points. | todo |
| B6 | Bot sometimes doesn't attack when it could easily destroy a unit. Investigate and fix. | todo |

## C. Statistics / telemetry

| # | Item | Status |
|---|---|---|
| C1 | Statistics must not live only on the player's machine. Save them to the database against the user, so they can see them on other machines and devs can access them later. | todo |
| C2 | A game timer counting up. Track turn time and game time in statistics, mainly for the website. | todo |

## D. Duel UI / feel

| # | Item | Status |
|---|---|---|
| D1 | "Scroll for more" at the bottom of the details panel hides when scrolled to the bottom. | todo |
| D2 | When summoning or setting a card from hand, it shrinks back so it doesn't cover the trap zones. | todo |
| D3 | Title text gets shadow or depth so it pops; it currently looks flat. | todo |
| D4 | The HP bar looks fancier (texture, etc.). | todo |
| D5 | Review every margin in the app visually; everything needs room to breathe. | todo |
| D6 | Sacrificing a unit gets a fancier animation (not instant). Add sound effects for gaining or losing AP and HP if they're missing. | todo |
| D7 | Game log, game over entry: remove "(<player> reached 0 HP)"; keep "<player> Wins". | todo |
| D8 | Ritual, Arcane and Fusion summon effects become far more epic and impactful, each unique. Keep their current theme; the lethal-blow effect is the quality bar. | todo |
| D9 | Hovering a field card's effect button that targets cards previews the valid targets in a toned-down form: keep darkening the invalid ones, with a subtler, unanimated yellow border. | todo |
| D10 | Improve the Feint sword icon on unit zones (it looks janky). | todo |
| D11 | Left input pane: shown cards' tooltips list the card effect, not "right click to inspect". Your own cards never appear face down there; your traps show face up. | todo |
| D12 | Hoverable status words are highlighted in a different colour and underlined everywhere. The tooltip drops "(buff)" / "(debuff)". | todo |
| D13 | Trap confirmation dialog: Activate, Skip (renamed from Pass), and a third "Pass for the rest of this turn". | todo |
| D14 | Right-click inspect panel: spells, traps and powers hide the ATK/DEF/Race/Type section (no "No race / ?"). | todo |
| D15 | Remove the Inspect button from the card list in the right pane; right-click is enough. | todo |

## E. Post-duel / rewards

| # | Item | Status |
|---|---|---|
| E1 | The "<player> won the game" container on the post-duel screen fits its content, not full width. | todo |
| E2 | Improve the chosen-reward lists; no wrapping tags. | todo |
| E3 | Big card reward options are all the same size (if one wraps, all grow to match). Picking one hides the option list, so the modal never needs scrolling. | todo |

## F. Menus / deck builder

| # | Item | Status |
|---|---|---|
| F1 | Main menu: replace "Steam ready as fergmux (App ID ...)" with "Logged in as Fergmux" and "Build version 0.3.6" (or the real version). | todo |
| F2 | Deck builder: hovering a card shows its details in the middle pane (not on click). Remove the Add one / Remove one buttons from the middle pane. | todo |
| F3 | Saved decks and Starter decks become tabs, like the pre-game deck screen. Fix those tabs too: the selected tab joins the pane below it; unselected tabs keep the border under them; tabs start after a left margin, like folder tabs. Use the same tabs in the deck builder. | todo |
| F4 | Game options setup: "Starter decks" becomes "Custom decks". | todo |
| F5 | Deck selection screen: "Structured decks" becomes "Structure decks". | todo |

## G. Card data

| # | Item | Status |
|---|---|---|
| G1 | Apply the updated wording from the new CSV, with no effect changes. Report any row whose change would alter an effect instead of applying it. | done a308eab (Mirror Force kept counting cards, flagged) |

## H. Full design review

| # | Item | Status |
|---|---|---|
| H1 | Spend real time on a full design review of every screen: ugly formatting, cheap styles or effects, flat or plain surfaces, tight margins, missing sound or animation. Fix everything that doesn't look extremely well made. Record findings and fixes in `design/design-review-2026-10-20.md` with before/after screenshots. | todo |

## Owner answers (asked before starting)

- **C1 identity:** "Unverified Steam link". Cloud stats are keyed to a salted one-way hash of the
  Steam ID that the client reports (no Netlify ticket check). The owner accepts that a modified client
  could write under someone else's hash. This explicitly supersedes the earlier rule "do not trust a
  freely supplied Steam ID" for statistics only (never for match authority). Raw Steam IDs are still
  never stored.
- **A2 chat:** "Yes, everyone chats". Players and spectators share one chat; each message shows its
  sender and marks spectators.

## Decisions for review

(executive decisions taken while unsupervised are listed here and repeated in the final report)

## Blockers worked around

(none yet)
