# Production batch 2026-10-17: final report

Branch `build/rldb-game` (not pushed). Every package and review is merged. The detailed records sit in this folder:
- `coverage.md`
- `decisions.md`
- `verification.md`
- `agents.md`
- `card-ledger.md`

## 1. Outcome by workstream

### Card database update
**Done.**
- All 101 changed cards and their 319 changed cells are reconciled per cell (`card-ledger.md`):
  - 34 behaviour
  - 26 balance
  - 169 wording only
  - 61 reference only
  - 29 already correct
  - 0 pending
- The 82 unchanged cards are retained.
- **Importer changes:**
  - `temp` conditions are stripped, with the raw value kept in `source.raw`.
  - The legacy CONDITION_TO_SUMMON hack (63 and 97) is replaced.
  - The text overrides were audited.
  - The trailing space on 157 is trimmed.
  - The orphan row is removed.
- Removed obsolete handlers:
  - `set_declared`
  - Dante's adjacent-unit targeting
  - Last Foundation's cannot-move flag
  - the old Tag Team, Geolock, Tyde and Solomon behaviours

### Firebase metrics
**Live on Spark.**
- Strict direct-write rules are deployed and verified:
  - An owner create is accepted with HTTP 200.
  - Unauthenticated and canonical-path access returns 403.
- **Client (silent, never blocks gameplay):**
  - The game client signs in anonymously and keeps the same ID across launches.
  - Records go to a durable, bounded outbox first, then upload with backoff.
  - The uploader is duplicate-safe.
- **Collection:** a collector hooked into the rules engine and series records committed events only.
- **Admin tool:** reconciles games as verified / provisional / conflicted, computes the requested metrics, and deletes a player's data on request.
- **Privacy:** a Settings checkbox, a privacy note and a kill switch.

### Feedback F01–F26
**All implemented.** See `coverage.md`.
- F09 (Sanctified Blade) could not be reproduced. The Medic waits for deliberate activation and a target choice. The owner probably saw the Medic status healing at turn start.

## 2. Card source

- **Active input:** `rules/sources/RLDB Master - Card Database (2026-10-17).csv`, SHA-256 `8ac4a39a70069a8586b1e5139e5999a57aa837e8064e83ef365e91b36d693da3`, unchanged.
- **Import proof:** `python tools/import_cards.py` prints `source: RLDB Master - Card Database (2026-10-17).csv 8ac4a39a7006 cards: 183`. A rerun on 17 Oct left `cards.json` byte-identical.
- **Baseline:** `rules/sources/RLDB Master - Card Database.csv` is untouched and never read by the importer.
- **Import tests:** 10 Python tests in `tools/tests/test_import_cards.py` cover `temp`, populated summon fields, unique and renamed IDs, determinism and no orphan card.

## 3. Tests and evidence (final integrated run, 17 Oct)

| Check | Result |
| --- | --- |
| GdUnit full suite | **904 / 904**, no errors, no script errors |
| Per-card coverage manifest | **183 / 183 covered, 0 pending**. Run one card with `-s res://tests/cards/run_card.gd -- --id=N`, or all with `--all` |
| f02 live regression driver | 75 / 75 |
| Tutorial driver (all 7 lessons, from the menu) | 207 / 207 |
| Series driver (deck select, draft order, rewards, prompts, F01/F04/F05/F06/F08/F10) | 45 / 45 |
| Deck builder and catalogue flow drivers | 0 failures each |
| Networked ENet series, client wins and client loses | 8 / 8 both |
| Bot driver | 4 / 4 |
| Firebase emulator rules and admin tests | 18 / 18 |
| Firebase metrics fixtures | 19 / 19 |
| Exported `build/windows/RLDB.exe` launch | no script errors |
| Killing-blow slow motion, quiet machine, 4x MSAA | direct lethal never below about 150 fps (1600x900 and 4K); unit lethal dips to 82 fps for one 0.5 s window |

**Independent reviews:**
- **Gameplay and rules review:** found and fixed two defects:
  - the Fusion self-cost resolved after the response window;
  - the Neva self-exhaust cost could take the card from Spent.
- **UI/UX review:** its findings led to fixes for the method picker, Type icons and grid, gold Arcane coins, the Extra Deck row, the input panel layout, and a camera shake that left the HUD unstable.
- **Security review:** fixed six telemetry issues:
  - outbox path traversal from host-sent IDs (CRITICAL)
  - prototype pollution and crash in the admin tool
  - incomplete erasure of a deleted player
  - outbox robustness
  - environment re-labelling
  - spurious account resets

**Evidence:** under `production/qa/evidence/2026-10-17-batch/`, in `deckbuilder/`, `match-ui/`, `fx-audio/`, `ux-fixes/` and `final/`. More in `production/qa/evidence/2026-10-17-a3-telemetry/` and `production/qa/evidence/2026-10-17-card-migration-f02/`.

## 4. Firebase

### Architecture
- No backend; this is the Spark plan.
- Clients create immutable records only in `users/{uid}/submissions/{kind}_{id}`.
- Canonical games and aggregates are written only by the owner-run admin tool (`firebase/tools/rldb-admin.js`), using Google IAM credentials.

### Exact rules
The rules are in `firebase/firestore.rules`, deployed 17 Oct:
- Create is allowed only for the signed-in owner of that uid, with exactly 11 fields.
- `schema_version` must be 1, and the body's `uid` must match.
- Kind, environment and mode must come from fixed lists.
- The document ID must start with the kind.
- `received_at` must equal the server time.
- The body is a string of at most 200,000 characters.
- The owner may `get` its own document (no `list`); update and delete are denied.
- Everything else is denied to every client.

### What is live
- The rules and the index exemption are deployed.
- A real `test`-environment upload was accepted.
- Exported builds stamp `playtest`, editor runs `dev`, and automated runs `test` (never uploaded unless explicitly pointed at the emulator or live).

### Retry and retention
- **Retry:** backoff with jitter. 401 refreshes the token; 409 or a 403 that reads back counts as a duplicate; other 4xx are quarantined with a redacted diagnostic.
- **Local outbox:** at most 400 items or 8 MiB; completed games are kept longest.
- **Server data:** kept indefinitely, as the owner asked. Deletion: `node tools/rldb-admin.js delete-uid <uid> --confirm`.

### Identity and privacy limits
- One anonymous UID per install.
- The Steam link is a salted one-way hash marked unverified. The salt ships in the game, so the hash is pseudonymous, not anonymous.
- A verified Steam-linked identity needs a trusted server and the owner's own App ID, so it is not possible on Spark.
- The rules check a record's shape, not whether the game happened. "Verified" means two installs agreed.

### Owner steps
1. Install the Google Cloud CLI and run `gcloud auth application-default login`, or keep a service-account key outside the repo. The admin tool needs one of these to read live data.
2. In the Google Cloud console, restrict the Web API key to the Identity Toolkit, Token Service and Firestore APIs.
3. Before a public release, set `production` in `rldb/data/telemetry_config.json` and review `docs/telemetry/privacy.md`.

**Cost:** £0 on Spark. Measured on a real best-of-3 draft series: 11 records, about 88 KB. That allows about 1,800 series a day, and the 1 GiB limit holds about 10,000 series kept indefinitely. Full detail is in `docs/telemetry/README.md`.

## 5. Decisions I was unsure about, assumptions and open items

The full list is in `decisions.md`. The ones most worth the owner's attention:

### Card readings
- **Chaos Witch (13):** while it is typeless it does nothing to Mages. Once its Type changes, every Mage takes that Type.
- **Two Chaos Witches:** each takes the other Witch's Type.
- **Tag Team W (10):** the search is mandatory.
- **Magentric:** its Pierce applies only when it is tributed from the Field for a Fusion or Ritual summon.
- **"Spell or Trap":** excludes Powers.
- **Tyde:** its Rune-destroy can target units on either side.
- **Symbiote Larva:** the discard is mandatory.
- **Agent-chosen readings, never owner-confirmed:**
  - Stormcaller hits both sides.
  - Dante's "any unit".
  - The Illusionist's "your Exhaust, current cost ≤ 1".
  - `temp` treated as editorial.

### Rules questions raised by the gameplay review
- Should every "this unit" self-cost pay before the response window? Fusion costs already do.
- Should the Magical Council and Saboteurs Guild discounts stack per copy?

### UI deviations
- The deck builder adds a card by select-then-Add (F18), not click-to-add.
- Hover no longer changes the deck-builder preview.
- Rename hides with Delete.
- A legacy saved 8x AA setting becomes 4x.
- The back sound is chosen by button label.

### Telemetry
- Opting out deletes unsent records.
- Tutorial games are not collected.
- The host's report includes the opponent's hidden cards, in the database only.

### Missing assets
- **Card art:** none exists in the repo, so every card uses the placeholder gradient-and-cross art. This is the biggest gap against "no placeholder assets". The 20 changed `card_img` values are kept as references only.
- **Sounds:** all sounds are synthesised in `tools/gen_sfx.py`. The new click, back, deck add/remove, boom and charge sounds are level-checked but have not been listened to.

### Not yet done
- The UI review items deferred to a later pass:
  - the deck builder's "Your deck" grid text size (about 7 px at 1600x1000), and the Starter list cut-off;
  - the deck-select tab count badges;
  - the F12 damage number, which partly passes behind the lifted HP plate.
- At a 1600x1000 window the compact top-strip input panel still overlaps a sliver of the opponent's back row.
- The Lone Warrior / Revealed structure deck has 2 Extra Deck cards; the third is `#REF!` in the owner's sheet.

## 6. Stalls, incidents and cleanup

- **Turn limits:** every agent hit its 10–20 turn limit repeatedly and was resumed. The commit-as-you-go instructions meant nothing was lost.
- **Suspected stalls:** two apparent stalls (identical status twice) turned out to be real progress when checked against git.
- **Wrong tool:** the UI/UX reviewer type had no shell, so it reviewed screenshots and code statically. A ui-programmer agent verified and fixed its findings live.
- **Window budget:** the FX/audio agent used 7 windowed runs against the 5 allowed.
- **Incident: lost decks.** The owner's saved custom decks (`user://decks.json`) were lost. Tests and drivers in several worktrees shared the real file through backup and restore. Fixed in `DeckStore`: automated runs now use `user://test_decks.json`, with a regression test. "Deck 3 - Spirit Bomb" was recreated from the structure deck. The 4-card "test" deck could not be recovered.
- **Cleanup:**
  - No task-owned Godot or RLDB process is left running.
  - Agent worktrees remain under `.claude/worktrees/`. All are merged and safe to delete with `git worktree remove`.
  - An untracked `tools/__pycache__/` is left behind.

## 7. How to verify and run

Run from `rldb/`. `<godot>` is `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe`.
- **Full suite:** `<godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`
- **One card's tests:** `<godot> --headless --path . -s res://tests/cards/run_card.gd -- --id=61`
- **Live drivers:** see `verification.md`.
- **Game:** `build/windows/RLDB.exe`. Add `--telemetry-off` to disable stats for a session.
- **Firebase:** see `docs/telemetry/README.md`, "Owner operations".
