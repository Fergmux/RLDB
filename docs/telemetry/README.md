# RLDB gameplay telemetry (Firebase Spark plan)

Implemented 17 Oct 2026 (production batch Stage 3, package A3); schema v2 (game and turn time) and cloud player
statistics added 20 Oct 2026 (owner feedback C1, C2). Records: [schema-v1.md](schema-v1.md).
Player disclosure: [privacy.md](privacy.md). Specification: `design/firebase-game-statistics-request-2026-10-17.md`,
overridden by `design/production-batch-owner-answers-2026-10-17.md` (Spark only, direct writes, indefinite
retention, default-on setting, environment labels).

## Architecture

```
Godot client (rldb/src/telemetry)                     Firestore rldb-b5593 (default)       Owner PC (firebase/tools)
 Series / MatchEngine --note()--> TelemetryCollector   users/{uid}/submissions/{doc}  <---  rldb-admin.js (Admin SDK, ADC)
      (read-only observer)            | records          create-once, rules-validated          reconcile -> canonical_games/
                                 TelemetryOutbox  --->  TelemetryUploader (REST commit) ---->           -> aggregates/
                                 user://telemetry/outbox   TelemetryAuth (anonymous)                    metrics JSON (tools/out)
```

- **No backend.** Spark has no Cloud Functions, so the game writes directly. The rules allow one thing only:
  the signed-in owner creates an immutable, schema-checked document in their own folder.
- **Trust.** Classification as verified, provisional, conflicted, local or abandoned, and all aggregation, run
  only in the owner's admin tool (`firebase/tools/rldb-admin.js`) with Google IAM credentials. A client cannot
  write canonical games or aggregates, or declare anything verified.
- **Who reports.** The process that runs the `Series` (hot-seat, bot, network host) reports both seats: drafts,
  rewards, starting decks, events, results. A network client sends only a `gclient` corroboration report per duel,
  built from its own views.

### Integrity limits (honest)

- Anonymous auth proves only "the same installation". It does not prove that a duel happened. A modified client
  can submit invented reports into its own folder, and the rules check shape and size, not truth.
- `verified` means two different installations reported the same duel identically. Two colluding installs, or one
  person with two installs, can still forge a verified duel. Do not market these as cheat-proof competitive stats.
- A network host sees and reports both seats' hidden cards. That goes only to the database, never to the opponent.
  A malicious host could also misreport the remote seat's draft and deck; the client's corroboration covers only
  the result fields and its own deck.
- There is no App Check: Firebase App Check has no supported attestation provider for native Godot desktop builds,
  and a custom provider needs a backend. Abuse protection is Firebase Auth's per-IP sign-up limits, the rules' size
  caps and the Spark quota itself. If a spammer exhausts the daily free quota, telemetry stops for the day; the game
  is unaffected (uploads just back off).
- Quota abuse (security review, 17 Oct 2026). One uid can create documents without limit, and anonymous
  sign-up lets one person farm many uids, so per-uid caps in rules would not help. The 200,000-character
  body cap means about 5,400 documents fill the 1 GiB Spark store, and with indefinite retention that
  storage stays used until the owner deletes it (`delete-uid --confirm` per spamming uid). Owner GETs of
  own documents also count against the 50k/day read quota that `reconcile` needs. Watch usage in the
  console. Cheap later steps: lower the body cap to the measured 99th percentile (a real game report is
  about 33 KB), and restrict the Web API key to the Identity Toolkit, Token Service and Firestore APIs.
- Bodies are untrusted input to the admin tool. `reconcile.js` type-checks every field it reads and
  rejects records with unsafe map keys or ids (counted under `rejected`), so a crafted body cannot crash a
  run or pollute the tool's process. Provisional duels (one report) are in the default statistics, so a
  single modified client can add invented provisional duels; filter `--statuses=verified` when that matters.
- The network client treats every view field from the host as untrusted. Ids must be plain names before
  they become outbox file names or document ids.

## Client behaviour (silent, never blocking)

- **Start-up.** `Telemetry.boot()` is the one line in `main.gd`. GdUnit runs never boot it, so the static entry
  points (`attach_series`, `client_view`, `net_pause`) are no-ops there. The dev drivers resolve to environment
  `test` with target `none`, so they collect nothing.
- **Hooks.** These are additive `note()` calls in `game_core.gd`, `match_engine.gd`, `summon_ops.gd`,
  `effect_engine.gd` and `series.gd`, plus one-line attach points in `local_host.gd` and `net_session.gd`. The
  observer is null unless the service attached it. Bot look-ahead copies (`clone_for_sim`) never carry it. UI clicks
  and animations are never hooked.
- **Outbox.** `user://telemetry/outbox` holds one JSON file per record. Writes go to a temp file, then a rename;
  the previous version is kept as `.bak` until the rename succeeds and is restored at load. Defaults:
  400 items / 8 MiB. Eviction order: sessions and profiles, then the per-event list of the oldest game reports
  (counters, opportunities and the result are kept, and `completeness.events_dropped` is set), then drafts and
  rewards, then game and series reports, and open records last. Quarantine: 25 entries, oldest dropped, each with
  a redacted 300-character diagnostic. Open records (a duel or draft in progress) are rewritten at each turn or pick
  and become `abandoned` reports at the next start-up once they are 12 h old.
- **Uploader.** One HTTPS request at a time, ticked once a second. It uses `documents:commit` with
  `currentDocument.exists=false` and a `REQUEST_TIME` transform.
  - 200 is accepted.
  - 409 means the document already exists (a lost acknowledgement), so it counts as a duplicate and is
    acknowledged.
  - 401 triggers one token refresh, then backoff.
  - 403 triggers an owner GET: if the document exists it is a duplicate, otherwise it is quarantined.
  - Other 4xx are quarantined and never retried.
  - Offline, timeout, 408, 429 and 5xx back off: `min(900 s, 5 s · 2^n) · U(0.5, 1)` across the whole uploader, so
    there are no retry storms.
  - When idle, the uploader polls every 60 s; a newly finished record triggers an immediate attempt.
- **Auth.** `accounts:signUp` runs once per install. The refresh token is stored in
  `user://telemetry/credential.cfg` (emulator identities in `credential_emulator.cfg`) and never logged. ID tokens
  live in memory and are refreshed through `securetoken.googleapis.com`. A revoked refresh token falls back to a new
  anonymous account, so the uid changes.
- **Errors** never reach the player. Bounded diagnostics (`Telemetry.diagnostics`, 50 lines, redacted) and the
  developer tool are the only outputs.

## Player setting

The setting is in Settings (main menu and in-game): "Share anonymous gameplay statistics", on by default, with a
privacy note. It is stored in `user://ui_settings.cfg` `[privacy] share_gameplay_stats`.

Turning it **off** has these effects:
- the collector detaches;
- the uploader stops;
- **the local queue of unsent records is deleted**, so nothing collected before opting out is sent later;
- the identity file is kept, so turning it back on resumes with the same uid.

Records already uploaded stay until the owner runs `delete-uid`.

## Environments and kill switch

| Run | `environment` | Target |
|---|---|---|
| Editor (`OS.has_feature("editor")`) | `dev` | live |
| Exported build | `playtest` | live |
| Exported `RLDB-dev.exe` (any executable named `*-dev`), written to `build/windows-dev/` by `addons/rldb_export` beside every Windows export | `dev` | live |
| Public release | set `"environment": "production"` in `rldb/data/telemetry_config.json` for that build | live |
| GdUnit, every `-s` script run (dev drivers, tools), user args with `shots` / `driver`, `--telemetry-env=test` | `test` | none (add `--telemetry-emulator` or `--telemetry-live`) |

- Every Windows export (editor or `--export-release`) writes two builds from the same files: `build/windows/RLDB.exe` (`playtest`) and `build/windows-dev/RLDB-dev.exe` (`dev`). The name check beats the shipped `environment` value, so the dev copy stays `dev` in a production build; `dev.cfg` and `--telemetry-env=` still override it. `RLDB.exe --telemetry-status` prints the label a build uses and quits.
- The environment is stamped on every record when it is queued, so a later build never relabels old records.
- The admin tool partitions by environment and defaults to `production`. Labels are not a security boundary, and
  they share one database and one quota. Separate Firebase projects would be the stronger option and are not
  configured.
- Kill switches:
  - `"enabled": false` in `telemetry_config.json`;
  - `user://telemetry/dev.cfg` `[dev] enabled=false` (developer override, which can also set `environment` or
    `target`);
  - the `--telemetry-off` argument;
  - the environment variable `RLDB_TELEMETRY=off`.

## Developer tool (no player UI)

Run it from `rldb/` with the editor console binary:

```
godot --headless --path . -s res://src/dev/telemetry_tool.gd -- --inspect
godot --headless --path . -s res://src/dev/telemetry_tool.gd -- --flush --telemetry-live
godot --headless --path . -s res://src/dev/telemetry_tool.gd -- --test-upload --telemetry-live      # env test; exit 0 = accepted
godot --headless --path . -s res://src/dev/telemetry_tool.gd -- --sim-series --telemetry-emulator   # bot Bo3 draft series
godot --headless --path . -s res://src/dev/telemetry_tool.gd -- --purge
```

## Security rules (deployed 20 Oct 2026; `firebase/firestore.rules`, committed LF file sha256 `1c4235c7…5708`)

- `users/{uid}/submissions/{docId}`:
  - **create** only if `request.auth.uid == uid`, all 11 envelope fields are present and nothing else, `uid`
    equals the path uid, `schema_version` is 1 or 2, the kind, environment and mode are from fixed lists, `docId`
    starts with `<kind>_`, the content hash is 64 hex, `received_at == request.time`, and `body` is a string of 2 to
    200,000 characters;
  - **get** only by the owner;
  - **list, update and delete** always denied.
- `stats_links/{uid}` (cloud statistics): **create / update** only by that uid signed in **anonymously**, with
  exactly {steam_hash (32 lowercase hex), linked_at == request.time}; **get** by that uid; **list, delete** denied.
- `player_stats/{hash}`: **get** only by an anonymous uid whose link names `hash`; **create** (rev 1) and
  **update** (rev = previous + 1) only by such a uid (checked with `getAfter`, so a link and the first write may
  share one commit), with exactly the 8 fields of [schema-v1.md §2b](schema-v1.md), `steam_hash` equal to the path,
  `uid` equal to the caller, `updated_at == request.time` and a body of 2 to 200,000 characters; **list, delete**
  denied.
- Every other path, including `canonical_games`, `aggregates` and `admin`, is denied to every client. The Admin
  SDK bypasses rules, so the admin tool is tested separately (`firebase/tests/admin.test.js`).
- `firestore.indexes.json` exempts the large `body` strings from single-field indexing, which saves storage.

## Owner operations

Install once with `cd firebase && npm install`. Java 21 must be on PATH for the emulators.

- Everything except the end-to-end runs: `npm test` (fixture tests, then rules and admin tests on the emulators).
- Rules and admin tests on the emulators:
  `npx firebase emulators:exec --only firestore,auth --project rldb-b5593 "node --test --test-concurrency=1 tests/rules.test.js tests/admin.test.js"`
- Godot end-to-end on the emulators (`npm run test:e2e`): `tests/e2e_godot.js` (a bot draft series, uploaded and
  reconciled, with turn times) and `tests/e2e_stats.js` (two simulated computers sync one Steam account's statistics
  through the real client: 2 + 1 duels give 3 on both).
- Fixture metric tests (no emulator): `node --test tools/test/*.test.js` (`timing.test.js` covers schema v2).
- Players' cloud statistics: `node tools/rldb-admin.js player-stats` (one summary line per player: duels, W-L, average
  duel and turn; one read per player document) or `player-stats <hash>` (the decoded record). These are
  self-reported under an unverified link. `delete-stats <hash> [--confirm]` erases one record and every link to it;
  `delete-uid --confirm` now also erases the record that uid's link names.
- Deploy: `firebase deploy --only firestore:rules,firestore:indexes --project rldb-b5593`
- **Admin credentials** (choice: IAM via Application Default Credentials, *not* an allowlisted email/password
  account). Run `gcloud auth application-default login` with the owner Google account, or set
  `GOOGLE_APPLICATION_CREDENTIALS` to a service-account key stored outside the repository
  (`firebase/.gitignore` also blocks `*.key.json` and `service-account*.json`). Why this choice: an allowlisted
  password account would have to open read-everything rules to one client identity, and anyone holding that
  password could read or overwrite all data. IAM keeps the rules closed to every client.
- Reconcile and metrics:
  `node tools/rldb-admin.js reconcile --env=production [--modes=lan,steam] [--statuses=verified,provisional] [--player=u:<uid>] [--from=2026-11-01] [--content-hash=<hex>] [--write]`.
  - The output goes to `tools/out/metrics-<env>.json` (ignored by git).
  - `--write` stores only changed `canonical_games/{env}__{game_id}`, deletes canonical games whose submissions
    are gone, and writes `aggregates/{env}__default`.
  - The run is idempotent: aggregates are always recomputed from the full canonical set, never incremented.
  - Defaults are human network duels, verified plus provisional (provisional is flagged and filterable), with
    conflicted, abandoned, bot and hot-seat duels excluded. Pass `--modes=bot,local --statuses=local` for local
    play.
- Deletion: `node tools/rldb-admin.js delete-uid <uid>` lists the documents; add `--confirm` to erase the uid:
  its submissions, its anonymous Auth account, every filtered aggregate naming it, then a rebuild of every
  environment's canonical games and default aggregate. Delete local `tools/out/*.json` copies by hand.
- Health: `node tools/rldb-admin.js health --env=production` reports accepted and rejected counts by reason, each
  classification count, and network duels missing a client report.

## Cost and quota (Spark: 20,000 writes/day, 50,000 reads/day, 20,000 deletes/day, 1 GiB stored)

Measured on a real Bo3 bot draft series (`tests/e2e_godot.js`): 11 documents.

| Record | Count | Size |
|---|---|---|
| draft | 2 | about 4.1 KB each |
| game | 3 | up to 33 KB each |
| reward | 4 | about 1.4 KB each |
| series | 1 | 1.2 KB |
| session | 1 | 0.6 KB |

That totals about 88 KB of body, roughly 100 KB stored with overhead. A network series adds one `gclient` per duel
(about 1 KB). Launches add a session each (about 0.6 KB).

| Load | Writes/day | Storage growth |
|---|---|---|
| Playtest: 20 players × 3 series/day | about 700 (3.5 % of quota) | about 6 MB/day |
| Daily write ceiling | about 1,800 Bo3 series | |
| 1 GiB with indefinite retention (owner decision) | | about 10,000 Bo3 series (about 30,000 duels) |

- Monitor storage in the Firebase console. If it grows too fast, lower `collect.max_events_per_game`: the event
  list is about 70 % of a game report, and the counters and opportunities alone support every metric.
- Reads: a full `reconcile` reads every submission once. That fits the 50k/day read quota up to about 50,000
  documents (about 4,500 series). Beyond that, run it on alternate days, or add an incremental mode or export
  (future work).
- Admin writes: only changed canonical games plus one aggregate per run.
- Cloud statistics (C1): about 2 reads per game start (the stats read plus the rules' link check) and per Statistics
  dialog refresh (at most once a minute), 1 write per changed record (a finished duel or series, debounced 4 s),
  plus 1 link write once per install and Steam account. One document per player; its body is gzip + base64, about
  350 characters for 3 duels and an estimated 50 to 90 KB at the 500-duel cap (hard cap 200,000 characters), so 1,000
  active players use under 90 MB. 20 players × 10 duels/day is about 200 writes and 500 reads/day (1 % of quota).
- Monthly cost: £0 (Spark, no billing enabled). Quota exhaustion only pauses uploads, which back off and resume
  the next day with nothing lost locally, within the 400-item / 8 MiB outbox budget.

## Identity

- One anonymous Firebase uid per installation (per target), reused across launches through the stored refresh
  token. It is per install, not per human: a reinstall or second device is a new profile, and the metrics say
  "profiles", not "players".
- Hot-seat: seat 0 is the profile; seat 1 is an unlinked guest (`guest_<series id>`). Bots are `kind: "bot"`.
- The Steam hash is computed once Steam is up. Until 20 Oct 2026 the service booted before `SteamBridge.init()`, so
  `steam_hash` was always empty in released records; it now boots after Steam and also picks up a Steam client that
  starts later.
- **A verified Steam link is not possible on Spark.** It would need a trusted server that checks a Steam auth
  ticket with a publisher Web API key, plus the owner's own App ID; the game uses Spacewar 480. The fallback is a
  salted one-way hash of the Steam ID marked `steam_link: "unverified"`. It is used for grouping only, never as
  proof: any client can send any value. Because SteamIDs are enumerable and the salt ships in the game, anyone
  holding both the salt and the data can reverse it. Adding a verified link later (own App ID plus a trusted
  service) needs no change to what is collected.

## Cloud statistics (owner feedback C1, 20 Oct 2026)

The player's own statistics (Decks > Statistics, `PlayerStats`) follow their Steam account to any computer.

- **Identity: an unverified Steam link (owner decision).** The key is the salted one-way hash of the Steam ID the
  client reports. It is never the raw Steam ID. Any modified client can claim any hash (`stats_links/{uid}`) and so
  read or overwrite that player's statistics; the owner accepted this for statistics only. Nothing in these
  documents is used for match authority, the competitive metrics or the website's duel statistics.
- **Client** (`rldb/src/stats/stats_sync.gd`, ticked by the Telemetry node, one request at a time): link the uid to
  the hash once (remembered in `user://telemetry/stats_sync.cfg`), read `player_stats/{hash}` at start-up and when
  the dialog opens (at most once a minute), merge it into the local record, and write back whenever the shared part
  differs, with an `updateTime` precondition (`exists=false` for the first write). A lost race (another computer
  wrote first) is a precondition failure: read, merge, write again. Offline, 408, 429 and 5xx back off like the
  uploader; three refusals in a row stop the cloud copy for that run. Never blocks, never shows an error.
- **Merge** (`PlayerStats.merge`, a CRDT): duels and series are grow-only sets of rows with random ids (the newest 500
  and 300 kept); draft counters are kept per writer (each local file has its own device id) and merged by maximum.
  Merging is commutative and idempotent, so two computers converge whatever the order. A cloud copy is sanitised
  field by field before it is merged (it may have been written by a modified client).
- **Local copy** (`user://player_stats.json`) stays the offline cache and works without any network. Old v1 files
  migrate in place. If another Steam account signs in on the same computer, the current record is set aside in
  `player_stats_<hash>.json` and that account's own record becomes active, so accounts never mix. A record that was
  never linked is adopted by the first account.
- **Fallbacks: local only** without Steam, with sharing off, with the kill switch, or in any automated run (the
  service never syncs `PlayerStats.TEST_PATH`, and every `-s` run resolves to `test` with no target).
- **Dialog**: the plate's corner reads "Synced" or "This computer"; a status line under the list (gold dot: "Synced
  with your Steam account · 2 min ago"; slow amber pulse: syncing or waiting to go online; bronze ring: "Kept on this
  computer only · <reason>"). The list refreshes in place when a merge arrives.
- **Opt-out**: turning sharing off stops syncing at once. The cloud copy is not deleted automatically (like
  submissions); the owner erases it with `delete-stats <hash>` or `delete-uid <uid>`.
- Dev tool: `telemetry_tool.gd -- --stats-sync --telemetry-emulator --machine=a --fake-steam=<id> [--duels=n] [--wipe]`
  simulates one computer (its own identity, settings and stats file).

## Retention

- Server: indefinite, with no age-based deletion (owner decision). The deletion process is `delete-uid` (above).
- Local: the bounded outbox as described above. Delivered records are deleted from the device after
  acknowledgement.
