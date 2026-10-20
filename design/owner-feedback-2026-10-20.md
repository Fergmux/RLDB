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
| A1 | Chat button next to Menu opens a text chat box so players can type to each other. Remove the "Steam (connected)" text. | done f8b1688, cfa30e8 |
| A2 | Spectating: anyone who joins (invite or public lobby list) once seats 1 and 2 are taken becomes a spectator. By default a spectator sees neither player's hand or face-down cards. The player menu gets a "Spectators" button: a list of spectators, each with an icon. Tooltip "Allow this player to see your cards"; once allowed, the icon changes and the tooltip reads "Stop this player seeing your cards", which reverts them. An allowed spectator sees almost exactly what that player sees: face-down cards, piles and hand, the same board orientation, and the player's mouse position. They don't see that player's UI prompts (buttons, effect descriptions). | done f8b1688, cfa30e8 |

## B. Rules

| # | Item | Status |
|---|---|---|
| B1 | Hot Stove only activates when a Power's effect is actually activated, not when the Power is played. | done 18 Oct; re-verified 3c8ed10 |
| B2 | Traps that trigger on summon resolve after the On Summon effects. | done 18 Oct; re-verified 3c8ed10 |
| B3 | No Attack/Defense choice when summoning, except on the opponent's turn or in the Battle Phase. Otherwise summon in Attack stance; the player can change stance afterwards. | done 4274d9c |
| B4 | Ambush lets you pick where each summoned card goes. | done df1f0b1 |
| B5 | Divine Serpents' On Summon: the first destruction animation doesn't play (timing). Make sure the unit is visibly summoned, then destroyed. Give this effect its own animation: the Serpents combine and damage the life points. | done 09097a1 |
| B6 | Bot sometimes doesn't attack when it could easily destroy a unit. Investigate and fix. | done 1aa1e45 |

## C. Statistics / telemetry

| # | Item | Status |
|---|---|---|
| C1 | Statistics must not live only on the player's machine. Save them to the database against the user, so they can see them on other machines and devs can access them later. | done 5b9ac66, 2ae4e76 (rules deployed) |
| C2 | A game timer counting up. Track turn time and game time in statistics, mainly for the website. | done 5b9ac66 (website 59944c6) |

## D. Duel UI / feel

| # | Item | Status |
|---|---|---|
| D1 | "Scroll for more" at the bottom of the details panel hides when scrolled to the bottom. | done 3e61d89 |
| D2 | When summoning or setting a card from hand, it shrinks back so it doesn't cover the trap zones. | done f284ee6 |
| D3 | Title text gets shadow or depth so it pops; it currently looks flat. | done 6b1fe73 + app-wide (be131be, aaabfb1, e6f11b1) |
| D4 | The HP bar looks fancier (texture, etc.). | done dffe8b5, plates aa35c88 |
| D5 | Review every margin in the app visually; everything needs room to breathe. | done: spacing tokens (WP-1), sweeps (WP-5), margin-overlay check |
| D6 | Sacrificing a unit gets a fancier animation (not instant). Add sound effects for gaining or losing AP and HP if they're missing. | done 09097a1, c7ceae7 |
| D7 | Game log, game over entry: remove "(<player> reached 0 HP)"; keep "<player> Wins". | done e190532 |
| D8 | Ritual, Arcane and Fusion summon effects become far more epic and impactful, each unique. Keep their current theme; the lethal-blow effect is the quality bar. | done 09097a1 |
| D9 | Hovering a field card's effect button that targets cards previews the valid targets in a toned-down form: keep darkening the invalid ones, with a subtler, unanimated yellow border. | done 244e94e |
| D10 | Improve the Feint sword icon on unit zones (it looks janky). | done 6ca6d97 |
| D11 | Left input pane: shown cards' tooltips list the card effect, not "right click to inspect". Your own cards never appear face down there; your traps show face up. | done c07b336 |
| D12 | Hoverable status words are highlighted in a different colour and underlined everywhere. The tooltip drops "(buff)" / "(debuff)". | done 4fff674 |
| D13 | Trap confirmation dialog: Activate, Skip (renamed from Pass), and a third "Pass for the rest of this turn". | done 4189ec1 |
| D14 | Right-click inspect panel: spells, traps and powers hide the ATK/DEF/Race/Type section (no "No race / ?"). | done 4fff674 |
| D15 | Remove the Inspect button from the card list in the right pane; right-click is enough. | done 4fff674 (catalogue button; pile list had none) |

## E. Post-duel / rewards

| # | Item | Status |
|---|---|---|
| E1 | The "<player> won the game" container on the post-duel screen fits its content, not full width. | done faf25b9 |
| E2 | Improve the chosen-reward lists; no wrapping tags. | done faf25b9 |
| E3 | Big card reward options are all the same size (if one wraps, all grow to match). Picking one hides the option list, so the modal never needs scrolling. | done faf25b9 |

## F. Menus / deck builder

| # | Item | Status |
|---|---|---|
| F1 | Main menu: replace "Steam ready as fergmux (App ID ...)" with "Logged in as Fergmux" and "Build version 0.3.6" (or the real version). | done c08b598 |
| F2 | Deck builder: hovering a card shows its details in the middle pane (not on click). Remove the Add one / Remove one buttons from the middle pane. | done 2e74385 |
| F3 | Saved decks and Starter decks become tabs, like the pre-game deck screen. Fix those tabs too: the selected tab joins the pane below it; unselected tabs keep the border under them; tabs start after a left margin, like folder tabs. Use the same tabs in the deck builder. | done 2e74385 |
| F4 | Game options setup: "Starter decks" becomes "Custom decks". | done 35ce426 |
| F5 | Deck selection screen: "Structured decks" becomes "Structure decks". | done 35ce426 |

## G. Card data

| # | Item | Status |
|---|---|---|
| G1 | Apply the updated wording from the new CSV, with no effect changes. Report any row whose change would alter an effect instead of applying it. | done a308eab (Mirror Force kept counting cards, flagged) |

## H. Full design review

| # | Item | Status |
|---|---|---|
| H1 | Spend real time on a full design review of every screen: ugly formatting, cheap styles or effects, flat or plain surfaces, tight margins, missing sound or animation. Fix everything that doesn't look extremely well made. Record findings and fixes in `design/design-review-2026-10-20.md` with before/after screenshots. | done: review b3a3745 + WP-1..WP-10 merged; see design/design-review-2026-10-20.md |

## Owner answers (asked before starting)

- **C1 identity:** "Unverified Steam link". Cloud stats are keyed to a salted one-way hash of the
  Steam ID that the client reports (no Netlify ticket check). The owner accepts that a modified client
  could write under someone else's hash. This explicitly supersedes the earlier rule "do not trust a
  freely supplied Steam ID" for statistics only (never for match authority). Raw Steam IDs are still
  never stored.
- **A2 chat:** "Yes, everyone chats". Players and spectators share one chat; each message shows its
  sender and marks spectators.

## Decisions for review

Card data (G1)
- Mirror Force: the 20 Oct sheet says "Controls 4 or more Units"; the rule has always counted cards.
  Kept counting cards (no effect changes), with the new sentence shape. Tell us which you meant.
- Texts that started lowercase after a find-and-replace ("change the Stance") are capitalised.

Chat and spectators (A1, A2)
- 2 players + 6 spectators per game.
- A spectator nobody has allowed watches seat 0 and can switch with "Watch <other>". Allowing a
  spectator turns their board to your side. Permission ends when the spectator leaves.
- Join/leave/permission lines are posted in chat for everyone (so an opponent knows a spectator can
  see your cards). Late joiners get no earlier chat. Bracketed text like "[afk]" is stripped.
- Between duels spectators see public progress only. A non-player joining a resumed series becomes a
  spectator instead of being kicked.
- The "Connected (steam)" text is gone; only "Paused" / "Opponent not connected" remain.

Rules (B3, B4, B6, D13)
- The stance choice remains on the opponent's turn, in the Battle Phase and in the End Phase. A unit
  summoned in the Recovery Phase may change stance in that phase.
- Ambush summons Hand units first, then Draw, asking a zone for each. In the Battle Phase it asks a
  stance for each.
- The bot never uses "Pass for the rest of this turn". The opponent is not told you passed.
- Skip and Pass sit side by side under Activate when they fit, stacked when the column is narrow.

Statistics (C1, C2)
- Cloud stats are keyed by a salted hash of the Steam ID (unverified, as agreed). The new Firestore
  rules are deployed to rldb-b5593. Custom deck names go into your own cloud record (for "Favourite
  deck"), never into match telemetry.
- A turn's time includes the opponent's responses during it. Each screen's clock is local; the host
  records the times used for statistics.
- During development a test run wrote test data into your real cloud stats document; it was deleted
  and the cause fixed (any -s script run is now always a test run).

Look and feel (D, E, F, H1)
- Summon set pieces have their own palettes: Fusion royal blue/violet, Ritual violet/gold, Arcane
  silver-cyan.
- Status words are lavender and underlined everywhere. The game-over log line is
  "GAME OVER: <player> Wins".
- Deck builder: the middle pane keeps the last hovered card; Starter Decks tab renamed Structure
  Decks to match the deck screen. The deck builder never had drag-and-drop.
- The Inspect button removed was the catalogue's (the pile list never had one).
- Status tips stay instant (18 Oct feedback) with a new look and fade.
- Build version is 0.3.6, shown under "Logged in as".
- Title tiers, spacing and button families follow design/design-review-2026-10-20.md; deviations
  from its exact values are listed in the agents' commits (e.g. 16 px button padding, softer zone
  pick fill, 16 px sidebar top/bottom margins).

Blockers worked around
- Agents ran in parallel worktrees; net tests share port 24721, so parallel suites occasionally
  clashed (always green when rerun alone).
- The headless test run segfaulted at exit after the motion pass (suspended coroutines on freed
  panels); fixed in 974f90e.
- The "F06 field hover returns after cancel" driver check depends on the real mouse position and
  still flakes now and then.
- Evidence screenshots grew the repo (.git is about 6 GB); later agents saved JPGs.
