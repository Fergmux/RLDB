# RLDB: handoff for the next agent (2026-11-04)

Read this, then `production/session-state/active.md` (the running checkpoint) and `CLAUDE.md`. This is a summary.
Where it disagrees with the repo, the repo wins.

## 1. What RLDB is

- An original two-player roguelike deck-building card game. It is played as a series (Bo3 by default). Between games
  each player picks 4 rewards: add a card, remove a card, or change their basic unit's type.
- Board, per player:
  - 6 unit zones in 2 rows of 3 columns. Slots 0-2 are the front row, 3-5 the back row. A back-row unit is protected
    while the zone in front of it is occupied.
  - 3 Trap/Spell zones and 4 Power zones.
  - Hand, Draw, Spent, Exhaust, and the Extra Deck (Fusion, Ritual and Arcane cards).
- Turn: draw 4, AP resets to 2. Then Main 1, Battle (not on the very first turn), Main 2, and end of turn.
- Players start at 60 HP.
- Modes: online play over Steam P2P (GodotSteam, AppID 480 for dev), a bot opponent, a tutorial, a draft, a deck
  builder, chat and spectators. Stats go to Firebase (Spark plan only).
- The rules spec is `rules/00-09`. The owner's rulings are in `design/decision-register-answers.md` and in the dated
  `design/owner-feedback-*.md`, `design/playtest-feedback-*.md` and `design/card-database-update-*.md` files.

## 2. Repo, tools, commands

- **Branch:** `build/rldb-game`. Never push. Commit verified increments with Conventional Commits.
- **Godot:** 4.6.1, GDScript. The project root is `rldb/` (not the repo root).
  - Exe: `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`.
- **Code:** `rldb/src/core` (rules engine), `rldb/src/net`, `rldb/src/ui` (screens, board, fx, `audio/`) and
  `rldb/src/dev` (screenshot drivers).
- **Rules engine:**
  - Card behaviour is declarative, keyed by card ID, in `rldb/src/core/card_scripts.gd`.
  - The engine is split across `effect_engine.gd`, `effect_ops.gd`, `summon_ops.gd`, `fusion_ops.gd`,
    `special_ops.gd`, `battle_ops.gd`, `match_engine.gd` and `game_core.gd`.
- **Card data:**
  - `tools/import_cards.py` turns the pinned CSV (see `rules/sources/active-card-source.json`) into
    `rldb/data/cards.json`. There are 191 cards.
  - Wording corrections live in `TEXT_CORRECTIONS`, `NAME_CORRECTIONS` and `COST_CORRECTIONS` in the importer.
- **Tests:**
  - gdUnit4, from `rldb/`, run without `-d`:
    `$G --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a <res://tests/...> --ignoreHeadlessMode -c`.
    Check the exit code, not just the summary.
  - Importer: `python -I -X utf8 -m unittest discover -s tools/tests -p "test_import_cards.py"`.
- **Export:**
  - **First** check `Get-Process RLDB*`. Overwriting the pck under a running game breaks its art loading.
  - Then run, from `rldb/`, `$G --headless --path . --export-release "Windows Desktop" ../build/windows/RLDB.exe`.
  - The `rldb_export` plugin writes `build/windows-dev/RLDB-dev.exe`. Copy the pck as `RLDB-dev.pck` if it was not
    updated.
  - Rebuild `build/RLDB-friends.zip` with Python `zipfile`. It holds RLDB.exe, RLDB.pck,
    `libgodotsteam.windows.template_release.x86_64.dll`, `steam_api64.dll` and `steam_appid.txt`.
  - Bump `config/version` in `rldb/project.godot`.
- **Evidence:** screenshots go in `production/qa/evidence/<date-batch>/` as JPG q88, at most 1600 px (PNG made `.git`
  balloon to about 6 GB once).

## 3. Standing rules from the owner (do not break)

- **Never:**
  - push;
  - use `git stash` (worktree agents share it);
  - export while RLDB is running.
- **Firebase:** "Use Spark only; do not upgrade to Blaze or enable billing." Never use `allow read, write: if true`,
  broad authenticated access, or a client-supplied admin flag.
- **Secrets:** never put service-account keys, Admin SDK credentials, refresh tokens or API keys (**this includes the
  ElevenLabs key**) in checked-in files or logs.
- **Steam:** do not trust a freely supplied Steam ID. No Steam persona names, raw Steam IDs, chat or device
  fingerprints in telemetry. A salted hash of the Steam ID is allowed.
- **Card wording:** copy the owner's wording verbatim. Fix only wrong sentence-start capitalisation. Keep the
  capitalised keywords.
- **Hands off:** leave the `../yugiohsandbox` repo (admin stats dashboard) and `CrawlV3Card.vue` alone unless asked.
- **Tests:** automated runs must use TEST paths for user files (DeckStore, PlayerStats). Tests once wiped the owner's
  decks.
- **Speed:** "skip unnecessary tests, only what is required to validate the new cards or whatever, no full regression
  suite etc, I'll manually test instead". This still holds for small batches.
- **Deviations:** if an implementation beats the owner's *suggestion*, keep it and list it under "Deviations for your
  review". Confirmed rules are followed exactly.
- **Agent batches:**
  - one worktree per agent, with an explicit file-ownership list and the shared brief
    `production/release-batch-brief.md`;
  - resume capped agents with SendMessage;
  - parallel net tests clash on ENet port 24721 (rerun them alone).

## 4. Current state (2026-11-04)

- **Version 0.3.10.** HEAD is `a98467f`.
- **Builds:** `build/windows/RLDB.exe` (playtest telemetry), `build/windows-dev/RLDB-dev.exe` (dev telemetry) and
  `build/RLDB-friends.zip`. All three are the same build.
- **Last batch: the 3 Nov card sheet ("JB Edit").** The source is
  `rules/sources/RLDB Master - Card Database (2026-11-03).csv`. Full change list and owner answers:
  `design/card-database-update-2026-11-03.md`. Also done:
  - three new cards:
    - 189 Owlbear Druid
    - 190 Snow Tiger Paladin
    - 191, a Trap ("Do Not Open Box")
  - owner wording fixes:
    - Magic Cylinder and Damage Conversion: "if your opponent's Unit in this Column declares an Attack"
    - Damage Conversion now costs 1
    - Overextend: "One of your opponent's Units Permanently loses -20 ATK."
    - Mirror Force counts cards
    - Demented Apparition: "Your opponent's Units cannot attack other Units if they can attack this Unit."
  - Snow Tiger Paladin: both of its effects apply at turn start; Traps cannot be protected
  - follow-up fixes:
    - Void Basilisk (67) and Seppuku (68) **can** be their own Fusion material. When they are, their "then
      exhaust/destroy this Unit" does not happen.
    - A Dragon Rider (135) summoned behind a Dragon enters in Defense with no stance prompt.
  - K1 (Spell/Trap spotlight sounds) and K4 (attack waits for the Trap) from `design/owner-feedback-2026-10-23.md`.
- **Tests:**
  - The new card suite passes: `rldb/tests/unit/cards/cards_db_update_2026_11_03_test.gd`, 57 tests.
  - About 50 **older tests still pin pre-3-Nov stats or behaviour and fail.** They were deferred on the owner's speed
    instruction and need updating, not deleting.
  - The full suite, online play and a real bot match were **not** re-verified after this batch.

### Open items

- Card art for 189, 190 and 191. The owner will supply it; art lives in `rldb/assets/art/cards/<id>.webp`, imported
  with `tools/godot/import_card_art.gd`.
- Google Sheet sync is unanswered. Option A: fetch the sheet live at game start. Option B: a one-command sync before
  a build.
- Snow Tiger Paladin: whether to hide the "cannot be destroyed (Snow Tiger Paladin)" log line, which tells the
  opponent the face-down card is a Trap. Offered, not answered.
- The about 50 stale tests (section 4).
- Older open items:
  - the F02-13 sound balance (the owner's listening test);
  - a two-account Steam test;
  - the fatigue default (2 HP per missed draw) awaiting confirmation;
  - the known F06 real-mouse flake in the series driver.

## 5. Audio: what is there (relevant to ElevenLabs)

- **SFX:** `rldb/src/ui/audio/sfx.gd` (class `Sfx`).
  - It plays `res://assets/audio/sfx/<name>.wav`, where `<name>` must be in `Sfx.NAMES`.
  - **Only `.wav` is loaded.** A name with no file is silent. Files use pooled voices, a rate limiter and the runtime
    `SFX` bus.
  - UI sounds have a priority table, `UI_PRIORITY`: one user action plays exactly one UI sound.
  - The card-hover and UI-hover cues are jittered and rate-limited.
- **Current SFX:** about 60 cues, **all procedurally generated** by `tools/gen_sfx.py` (Python stdlib, fixed seed,
  written to `rldb/assets/audio/sfx/`). Running that script overwrites every name it knows. If you replace a cue with
  an ElevenLabs file, make `gen_sfx.py` skip it (or move generated cues elsewhere), or the next regen erases it.
  `assets/audio/sfx/README.md` says the files are original/CC0-style; update it to record ElevenLabs provenance and
  licence (paid plans give commercial rights; the free tier does not).
- **Cue names, grouped:**
  - Cards and actions: card_draw, card_play, card_set, card_slam, card_hover, summon, sacrifice, exhaust, destroy.
  - Combat and stats: attack, impact, damage, heal, buff, debuff, boom, charge, ap_gain, ap_loss, hp_low_heartbeat.
  - Set pieces: fuse, fusion_vortex, fusion_impact, ritual, ritual_choir, ritual_impact, arcane, arcane_shimmer,
    arcane_impact, serpent_coil, serpent_strike, spell_cast, trap_spring.
  - Flow: turn, phase, notice, victory, victory_big, defeat, reward_reveal, reward_pick, step_done.
  - UI: select, confirm, cancel, deny, click_primary, click_secondary, back, tab, toggle_on, toggle_off, panel_open,
    panel_close, ui_hover, deck_add, deck_remove, chat, chat_pop.
- **Music:** `rldb/src/ui/audio/music.gd` (class `Music`). Playlists `menu` (menu_1-2.ogg) and `battle`
  (battle_1-3.ogg) in `rldb/assets/audio/music/`. They crossfade over 3 s on the `Music` bus. The owner supplied
  these tracks; do not replace them without asking.
- **Tools available:** ffmpeg 8.1 is on PATH (convert ElevenLabs mp3 to 44.1 kHz 16-bit wav:
  `ffmpeg -i in.mp3 -ar 44100 -sample_fmt s16 out.wav`). uv/uvx 0.13.5 is installed. After adding files run
  `$G --headless --path rldb --import`.
- **Suggested workflow:**
  - Generate into a staging folder **outside `rldb/`**, so Godot does not import trial takes. For example
    `production/audio-staging/`, gitignored or kept small.
  - Let the owner listen.
  - Then convert and copy the chosen take to `rldb/assets/audio/sfx/<existing name>.wav`.
  - New cue names must be added to `Sfx.NAMES` and wired at the event that plays them.
  - Sounds are presentation only. They must never reveal hidden information; for example, no cue may differ by the
    identity of a face-down card.
- **Credits:** ElevenLabs generation costs credits. Say what you will generate (how many cues and takes) before you
  run large batches.

## 6. Where the history is

- Session checkpoint: `production/session-state/active.md`.
- Batch logs by date: `design/owner-feedback-2026-10-{18,20,21,22,23}.md`, `design/card-database-update-2026-11-03.md`.
- Agent ledger: `production/agent-ledger.md`. Requirements: `docs/requirements-checklist.md`. Card support:
  `docs/card-support-ledger.md` (regenerate with `tools/card_ledger.py`).
- Art direction: `design/art/art-bible.md`. Board UX: `design/ux/match-board.md`.
