# RLDB

A two-player roguelike deck-builder card game in **Godot 4.6.1 (GDScript)**, built from the
specification in [`rules/`](rules/00-START-HERE.md). Play hot-seat, over LAN (dev harness) or
over Steam (lobbies + friend invites).

## Run it

| What | How |
| --- | --- |
| Exported Windows build | `build/windows/RLDB.exe` (re-export: see *Build* below; `build/` is git-ignored) |
| From source | Open `rldb/project.godot` in Godot 4.6.1, press Play (main scene `res://main.tscn`) |
| Headless/CLI | `godot --path rldb -- --local` (hot-seat), `-- --bot` (vs bot), `-- --host=24680`, `-- --join=127.0.0.1:24680` |

Main menu: **Play vs Bot** (you against the computer; the bot picks a random starter deck),
**Host Steam lobby & invite a friend**, **Find lobbies** (public lobbies only),
**Resume a saved series** (between-game saves), **Local hot-seat match** (optional privacy
screen), **Deck builder** (unrestricted custom decks) and, under *Advanced*, **Host/Join LAN**.
Series length (best of 1/3/5/7) and deck mode (starter/custom decks or draft) are chosen on the menu.

In a match: hover a card to read it (details panel and tooltip); click your card (or press Tab)
to see its legal actions on the card; choices are made in the banner at the top or by clicking
highlighted cards/zones; **Settings** has reduced motion, fast animations, music and sound volume.
Nothing is played from the Hand in the Battle Phase (only cards already on the Field act there).
After each game you pick rewards: add a card (choose its type, then one of three), remove a card,
or change a basic unit's Race and Type. If an opponent disconnects, the host may claim the current
game after 60 seconds (the series continues).

Extra command-line flags (after `--`): `--no-steam`, `--seed=N`, `--draft`, `--bo=5`,
`--no-privacy`, `--shots=<dir>` (scripted UI screenshots), `--net-shots=<dir>` (networked screenshots).

## Steam

- Uses **GodotSteam 4.23 GDExtension** (`rldb/addons/godotsteam`) and **App ID 480** (Valve's
  Spacewar test app) for development. Change `steam_app_id` in `rldb/data/mode_config.json`
  when you have your own App ID.
- The Steam client must be running and logged in before the game starts; otherwise the menu
  says so and the hot-seat/LAN modes still work.
- Host flow: *Host Steam lobby* creates a friends-only lobby and opens the Steam invite dialog.
  A friend who accepts joins automatically (running game: `join_requested`; not running:
  `+connect_lobby <id>` launch argument). Tick *List my lobby publicly* to make it searchable.

**Two-account test (not yet run).** Single-account checks pass (init, lobbies, host socket, search:
`production/qa/evidence/2026-10-15-steam/`). To test two clients you need two PCs (or a PC + VM), each
logged into a different Steam account, the accounts being Steam friends. Copy the whole
`build/windows/` folder (RLDB.exe, RLDB.pck, steam_api64.dll, libgodotsteam…dll, steam_appid.txt) to both.

1. Both: start Steam, log in, run `RLDB.exe`.
2. B: keep RLDB open on the main menu (with dev App ID 480 an invite cannot launch RLDB — Steam would start Spacewar).
3. A: *Play → Play online → Host game* (tick *List my lobby publicly* as a fallback) → *Host and invite* → invite B from the overlay (Shift+Tab if it does not open).
4. B: accept the invite in the Steam overlay/chat → B joins. Fallback: B → *Play → Play online → Join game → Browse public lobbies*.
5. Both pick decks; play a turn each: summon in Defense, use an ability, attack with a combat preview; let A attack into B's set Trap and confirm A's screen says it is waiting while B gets the response prompt.
6. Disconnect B's network ~10 s → A shows *MATCH PAUSED*; reconnect → the same prompt returns. After 60 s A may claim the current game only.
7. Quit and relaunch B, rejoin through *Find lobbies*/invite → B gets its seat back.
8. Finish the series (rewards, loser picks first player, final screen). Note anything that differs between the two screens.

## Bot opponent

`rldb/src/ai/bot_brain.gd` is a heuristic opponent, not machine learning. For each legal move it
plays the move on a private copy of the match (`MatchEngine.clone_for_sim`), lets effects resolve,
and scores the position: HP difference, each side's units (ATK/DEF, a stance that suits the stats,
buffs minus debuffs, runes), Powers, set cards and hand size. It makes the best move while that beats
doing nothing, otherwise it moves to the next phase; its own targets, zones and Trap responses are
chosen the same way. It only scores public information (in its simulations you always pass on Traps,
and your hand is only counted). `bot_player.gd` drives the seat with a 0.8–1.3 s pause before every
move, waits for animations, and thinks on a worker thread. Weights and delays are constants at the top
of both files. Live check: `godot --path rldb -- --bot-shots=<dir>`.

## Tests

```
godot --headless --path rldb -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
```

434 GdUnit4 tests (rules, decisions, cards, series, UI stores, network, adversarial QA): rules acceptance checks from `rules/05`, Sneaky Snunday checks, statuses,
summons, per-card behaviour (every effect card), series flow, review regressions, and
two-client ENet integration tests (trap suspension, illegal input, payload redaction,
reconnect during a pending prompt, duplicate-command replay, and complete best-of-3 /
best-of-5 draft series played by two network clients using only their own views).
Do not pass `-d` headless: the debugger pauses on script errors.

## Layout

| Path | Contents |
| --- | --- |
| `rldb/src/core/` | Deterministic rules authority: `game_core` → `effect_engine` → `effect_ops` → `special_ops` → `fusion_ops` → `battle_ops` → `summon_ops` → `match_engine`; `card_scripts` (all 183 cards as typed ops), `match_view` (per-player redaction), `series` (decks/draft/rewards/score) |
| `rldb/src/net/` | `net_session` (ENet/Steam transport, pause/reconnect, sequence numbers), `steam_bridge`, `local_host` (hot-seat) |
| `rldb/src/ui/` | Code-built UI: `main` (screen flow), `game_screen` (match coordinator), `card_widget`, `deck_builder`, `ui_style`, `zones`, `ui_layers` |
| `rldb/src/ui/game/` | Game screen components: board, hand, hover, selection, targeting, prompt banner, action row, sidebar, log, details, series overlay, reward panels, in-game menu, plus the board drawing classes |
| `rldb/src/ui/card/` | Card widget parts: geometry, layouts, painter, art, text layout, stat badges, chips, overlays, back |
| `rldb/src/ui/menu/` | Main menu, menu items, session options/launcher, saved-series list, lobby list, card list, screen fader |
| `rldb/src/ui/fx/` | `fx_player` (effect queue) and its effects: bursts, rune rings, spotlight, banners, card and resource effects |
| `rldb/src/ui/widgets/` | Shared widgets such as `confirm_dialog` |
| `rldb/src/ai/` | `bot_brain` (one-ply look-ahead heuristic), `bot_player` (threaded driver) |
| `rldb/src/dev/` | Windowed screenshot/check drivers (`--f02-shots`, `--bot-shots`, `--shots`, `--deckbuilder-shots`) |
| `rldb/data/` | `cards.json` (generated), `mode_config.json`, `starter_decks.json` |
| `tools/` | `import_cards.py` (CSV → JSON with confirmed corrections), `card_ledger.py` |
| `docs/card-support-ledger.md` | Per-card implementation/test status and interpretation notes |
| `design/decision-register.md` | Confirmed decisions (C-xx) and labelled prototype proposals (P-xx) |
| `production/qa/evidence/` | Screenshots from real runs of the game |

## Artwork

Placeholders are drawn from each card's Type/Race. Drop supplied art into
`rldb/art/cards/` using the source filenames (`image` field, e.g. `170.png`); cards pick it up
automatically. Live stats/statuses are overlays and are never baked into art.

## Trust model

The host process is the single authority: it validates every command, resolves randomness and
sends each player only their redacted view (hidden cards never leave the host). A modified host
can see everything; a modified client cannot see hidden cards or act for the other seat.
Host migration and recovering a series after the host process exits are not implemented
(open decision in `rules/06`).

## Build

Export templates for 4.6.1 must be installed (Editor → Manage Export Templates). Then:
`godot --headless --path rldb --export-release "Windows Desktop" ../build/windows/RLDB.exe`
