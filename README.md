# RLDB

A two-player roguelike deck-builder card game in **Godot 4.6.1 (GDScript)**, built from the
specification in [`rules/`](rules/00-START-HERE.md). Play hot-seat, over LAN (dev harness) or
over Steam (lobbies + friend invites).

## Run it

| What | How |
| --- | --- |
| Exported Windows build | `build/windows/RLDB.exe` (re-export: see *Build* below; `build/` is git-ignored) |
| From source | Open `rldb/project.godot` in Godot 4.6.1, press Play (main scene `res://main.tscn`) |
| Headless/CLI | `godot --path rldb -- --local` (hot-seat), `-- --host=24680`, `-- --join=127.0.0.1:24680` |

Main menu: **Host Steam lobby & invite a friend**, **Find lobbies** (public lobbies only),
**Resume a saved series** (between-game saves), **Local hot-seat match** (optional privacy
screen), **Deck builder** (unrestricted custom decks) and, under *Advanced*, **Host/Join LAN**.
Series length (best of 1/3/5/7) and deck mode (starter/custom decks or draft) are chosen on the menu.

In a match: hover a card (or press Tab) to see its legal actions on the card; click/right-click a
card to inspect it in the details panel; number keys pick prompt options; **Settings** toggles
reduced motion and fast animations. If an opponent disconnects, the host may claim the current
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

**Not yet verified with real Steam accounts** (the build machine had no running Steam client).
To verify, use two PCs (or two Steam accounts) with the exported build:

1. Both start Steam, launch `RLDB.exe`; the menu shows "Steam ready as …".
2. A: *Host Steam lobby & invite a friend* → invite B from the overlay.
3. B accepts → B's game joins; both pick decks; play to a trap response; confirm B waits.
4. Disconnect B's network for ~10 s; A shows *MATCH PAUSED*; reconnect; the same prompt returns.
5. Quit and relaunch B's game, rejoin via invite → B reclaims the seat (token persisted).
6. Finish the series (rewards, loser picks first player, final screen).

## Tests

```
godot --headless --path rldb -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
```

309 GdUnit4 tests (rules, decisions, cards, series, UI stores, network, adversarial QA): rules acceptance checks from `rules/05`, Sneaky Snunday checks, statuses,
summons, per-card behaviour (every effect card), series flow, review regressions, and
two-client ENet integration tests (trap suspension, illegal input, payload redaction,
reconnect during a pending prompt, duplicate-command replay, and complete best-of-3 /
best-of-5 draft series played by two network clients using only their own views).
Do not pass `-d` headless: the debugger pauses on script errors.

## Layout

| Path | Contents |
| --- | --- |
| `rldb/src/core/` | Deterministic rules authority: `game_core` → `effect_engine` → `special_ops` → `match_engine`; `card_scripts` (all 183 cards as typed ops), `match_view` (per-player redaction), `series` (decks/draft/rewards/score) |
| `rldb/src/net/` | `net_session` (ENet/Steam transport, pause/reconnect, sequence numbers), `steam_bridge`, `local_host` (hot-seat) |
| `rldb/src/ui/` | Code-built UI: `main` (menu), `game_screen`, `card_widget` |
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
