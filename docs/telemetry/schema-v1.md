# RLDB telemetry schema v1 and v2: records and field dictionary

Status: v1 implemented 17 Oct 2026 (production batch, Stage 3); v2 added 20 Oct 2026 (owner
feedback C2: game and turn time). Source of truth for
`rldb/src/telemetry/telemetry_collector.gd` (producer), `firebase/firestore.rules` (envelope
validation) and `firebase/tools/lib/reconcile.js` / `metrics.js` (consumer). Any change to a field
meaning bumps `schema_version`. The rules accept `schema_version` 1 and 2 (deployed 20 Oct 2026),
and reconcile and metrics read both.

## 0. Version history

| Version | Date | Changes |
|---|---|---|
| 1 | 17 Oct 2026 | First release. |
| 2 | 20 Oct 2026 | `game.turn_times`, `game.turn_ms`, `game.turn_times_truncated`, `game.clock`; `decks[seat].name` for structure decks. Additive only: every v1 field keeps its meaning. A v1 record has no turn times; metrics leave it out of turn-time figures (never count it as zero) but still use its `active_ms` for duel length. |

## 1. Document envelope (validated by the security rules)

Path: `users/{uid}/submissions/{docId}`. Created once, never updated or deleted by a client.

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | int | `1` or `2` (new records are `2`) |
| `kind` | string | `profile`, `session`, `draft`, `reward`, `game`, `gclient` or `series`. `docId` must start with `<kind>_` |
| `env` | string | `dev`, `playtest`, `production` or `test`, stamped when the record is queued (never re-labelled later) |
| `build` | string ≤ 48 | `telemetry_config.json` build, plus `-editor` in editor runs |
| `content_hash` | 64 hex | SHA-256 of `rldb/data/cards.json` (card data and rules content version) |
| `mode` | string | `local` (hot-seat), `bot`, `lan`, `steam`, or `none` (session/profile). The tutorial is not collected |
| `uid` | string | Firebase anonymous uid; must equal the path uid and the auth uid |
| `created_at` | int | Client time (ms) when the record was first queued; kept across retries and restarts |
| `seq` | int | Per-install monotonic record sequence |
| `received_at` | timestamp | Server `REQUEST_TIME` (rules require `== request.time`): server first-seen |
| `body` | string ≤ 200,000 chars | JSON of the kind-specific body below; its schema is checked by the admin tool, not by the rules |

Every body also carries `meta` = {schema_version, env, build, content_hash, session_id, created_at, seq, updated_at},
plus `ids`, `mode` and `flags` = {tutorial, bot, local, network}.

## 2. Stable identifiers

| Id | Form | Scope and origin |
|---|---|---|
| uid | Firebase uid | One per install and target (live or emulator). Stored as a refresh token in `user://telemetry/credential.cfg` |
| participant_id | `pp_<32 hex>` | Gameplay identity of this install's profile, kept separate from the auth uid. The admin tool keys players by the submitting uid (`u:<uid>`) |
| guest participant | `guest_<series id>` | Second hot-seat seat. Unlinked, different per series |
| bot | `bot` | The bot seat (`kind: "bot"`), never a human uid |
| session_id | 32 hex | One per application launch |
| series_id | 32 hex | `Series.telemetry_ids.series`, random, saved with the series (`telemetry_series_id`), sent in views |
| game_id | 32 hex | `Series.telemetry_ids.game`, new for each duel (not for each reconnect; a duel restarted after a crash gets a new id) |
| draft_id | `<series_id>_d<seat>` | One draft per seat per series |
| deck snapshot id | `<game_id>_s<seat>` | Starting deck of a seat in a duel |
| action id | `<game_id>:<event seq>` | One per committed play |
| opportunity token | `o<n>` | One per hand stay, unique within a duel (globally `<game_id>/o<n>`) |
| card definition | `cards.json` id | Never names or CSV rows |
| card instance | engine uid | Random per duel, as the rules engine creates it |

Document ids: `game_<game_id>`, `gclient_<game_id>`, `draft_<draft_id>`,
`reward_<series_id>_g<n>_s<seat>`, `series_<series_id>`, `session_<session_id>`,
`profile_<participant_id>`.

## 2b. Cloud statistics (C1, 20 Oct 2026; not a submission)

The player's own statistics (Decks > Statistics) are kept per Steam account, separately from the
submissions above. They are self-reported and never feed the competitive metrics.

`stats_links/{uid}` (one per anonymous uid; create or update by its owner):

| Field | Type | Meaning |
|---|---|---|
| `steam_hash` | 32 lowercase hex | The salted Steam-ID hash (`Telemetry.hash_steam_id`) this install claims. Unverified |
| `linked_at` | timestamp | Server `REQUEST_TIME` |

`player_stats/{steam_hash}` (read and written only by a uid whose link names `steam_hash`):

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | int | `1` (the stats document format; independent of the submission schema) |
| `steam_hash` | 32 hex | Equals the document id |
| `uid` | string | The last writer's anonymous uid (equals the auth uid) |
| `rev` | int | `1` on create, previous `+ 1` on every update |
| `enc` | `gzip64` or `json` | Body encoding: base64 of a gzip stream (the client writes `gzip64`) |
| `raw_len` | int ≤ 4 MiB | Length of the decoded JSON |
| `updated_at` | timestamp | Server `REQUEST_TIME` |
| `body` | string ≤ 200,000 chars | The shared record below |

Shared record (decoded body): {version: 2, duels: [row], series: [row], devices: {device id: {draft_picks: {card id: n},
drafts_completed}}}. A duel row is {id (16 hex), t (unix s), s (order within the second), mode, won (bool or null for
hot-seat), turns, ms (duel time), tms (time of your own turns), tn (your turns), deck (deck name ≤ 40), cards (your
starting deck {id: copies}), plays {id: n}, summons, spells, damage, best_hit}; a series row is {id, t, s, mode, won,
score}. At most 500 duels and 300 series (the newest), 16 device counter sets and 160 cards per map; the client
trims the oldest rows until the encoded body fits. Merge rules: rows are a grow-only set by id; each device's
counters have one writer and merge by maximum (a CRDT), so the order of syncing never changes the result.

## 3. Bodies

### profile / session
`profile`: {participant_id, created_at, steam_hash, steam_link}, queued once per install and target.
`session`: {session_id, started_at, participant_id, steam_hash, steam_link, platform (OS family), end_tracked: false}.
Session end is not inferred. "Last seen" is the latest session `received_at`.

`steam_hash` = first 32 hex of HMAC-SHA256(salt, "steam:<SteamID64>") when Steam runs, otherwise "".
`steam_link` is `"unverified"` or `"none"`. See README §Identity.

### draft
`draft`: {draft_id, series_id, seat, participant, category_order, quota, offer_size, basic_unit, basic_copies,
status: `in_progress` | `complete` | `abandoned`, started_at, finished_at, rerolls_supported: false,
picks: [{n, category, offered: [card ids], offered_counts: {id: copies}, selected, selected_count, status: "picked", t}]}.
The basic-unit copies are setup choices, not picks. The draft is checkpointed on the device after each pick and uploaded
when complete or abandoned (series ended, session left, or an open record older than 12 h at startup).
Drafts are separate from prebuilt and custom decks: those only appear as the deck snapshot `source`.

### reward (one per seat per between-game interval)
`reward`: {series_id, after_game_no, after_game_id, seat, participant, rewards_per_game, status,
actions: [{kind: "type", category, offered}, {kind: "add", selected, index}, {kind: "remove", card},
{kind: "basic", to_type, to_race}, {kind: "finish"}], deck_after: {id: copies}}.

### game (authority report: hot-seat, bot or network host; covers both seats)
- `game`: {game_id, series_id, duel_index, best_of, deck_mode, started_at, ended_at, active_ms, paused_ms, turns,
  first_player, start_hp, base_ap, base_draw, outcome: `completed` | `abandoned`, decisive, winner, loser,
  reason: `lethal` | `concede` | `forfeit` | `disconnect_claim` | `other` | `abandoned`, final_hp: [hp0, hp1],
  draws_supported: false}
- `participants[seat]`: {seat, kind: `human` | `bot`, link: `profile` | `guest` | `remote` | `bot`, participant_id, steam_hash?, steam_link?}
- `decks[seat]` (frozen when the duel starts): {snapshot_id, seat, participant, source: `prebuilt` | `custom` | `draft`
  (`+series_changes` from duel 2 on, or after a resume), base_source, main: {id: copies}, extra: {id: copies},
  basic_units: {id: copies}, main_size, extra_size, size, fingerprint (16 hex), duel_index,
  name (v2: the structure-deck name for `prebuilt`, fixed game content, ≤ 40 chars; `""` otherwise. A custom deck's
  name is the player's own free text and is never sent)}
- v2 timing in `game` (host wall clock, `now_ms` of the collector):
  - `turn_times`: [[turn number, seat, active ms], ...], one entry per completed turn, at most 600 per duel
    (`turn_times_truncated` counts the rest). A turn runs from its `turn` event to the next one (or the end of the
    duel), so the opponent's trap responses inside it count towards it. Disconnect pauses inside a turn are left out.
    The turn still running when a duel is abandoned has no entry.
  - `turn_ms`: [seat 0 total, seat 1 total] of the entries above (including truncated ones).
  - `clock`: `"host_wall"` (what measured the times).
- `counters[seat][card id]`: {draws, hand_entries, draw_opps, draw_opps_played, hand_plays, plays, plays_by_kind{kind: n},
  activations, activations_by_kind{"<kind>:<result>": n}, special_summons}
- `totals[seat]`: {turns_taken, ap_granted, ap_unspent, ap_spent_on_plays, damage_taken, healing, draws, hand_entries,
  plays, activations, special_summons}
- `opportunities`: [token, seat, card id, instance uid, entry reason, entry turn, outcome, exit turn]
  - entry reasons: `draw_turn`, `draw_effect` (both count as draws); `retrieve_spent`, `retrieve_exhaust`, `search_draw`,
    `return_field`, `return_limbo` (not draws). `generated` is reserved: no card currently creates cards mid-duel.
  - outcomes: `played` (a committed hand play), `special` (special-summoned from Hand), `material` (tributed from Hand),
    `exited` (discarded or moved), `in_hand_at_end`, `open` (the duel never finished)
- `events` (bounded to 3000 per duel; `completeness.events_truncated` counts the rest):
  `[seq, turn, "turn", seat]`, `[seq, turn, "hand", seat, card, uid, token, reason]`,
  `[seq, turn, "exit", seat, card, uid, token, outcome]`,
  `[seq, turn, "play", seat, card, uid, kind, from_zone, ap, source_card, materials[[card, uid, from]], action_id]`,
  `[seq, turn, "act", seat, card, uid, kind, effect_id, "manual" | "triggered", result]`, `[seq, turn, "hp", seat, delta]`,
  `[seq, turn, "pause", 1 | 0]`
- `completeness`: {events, events_truncated, events_dropped?, opportunities_closed, measured_seats,
  activation_results: ["resolved", "negated"], unmeasured: ["response_latency", "attacks"], recovered_after_restart?}

Play kinds: `normal_summon`, `cast_spell`, `set_spell`, `set_trap`, `power` (hand plays committed at AP payment),
`special_ritual`, `special_arcane`, `special_fusion`, `special_effect` (placement from Extra Deck, Spent, Draw, Exhaust
or Hand by an effect).
Activation kinds: `ability` (effect `ability:<idx>`), `cast_spell`, `set_spell` (a later activation of a set Spell is not
a second play), `power`, `trap`, `trigger` (effect `on:<event>`). Results: `resolved` or `negated`. A picker cancelled before
commit records nothing.

### gclient (network client corroboration, from its own views only)
`gclient`: {game_id, series_id, duel_index, seat, mode, started_at, ended_at, first_player, best_of, deck_mode,
deck: {main, extra, size, fingerprint}, participant, outcome, winner, turns, final_hp, forfeit}.

### series
`series`: {series_id, best_of, deck_mode, participants, scores, winner, status: `complete` | `forfeit`, forfeit_by,
games: [{game_no, game_id, winner, reason}], first_choices: [{after_game_no, chooser, first}], resumed_from_save,
rewards_per_game}.

## 4. Attribution rules

1. A card's counters belong to the seat that played or activated it. Opportunities belong to the card's owner.
2. Card identity is the definition id of the instance. The engine has no transform-to-another-id effects today. Every
   instance in a duel comes from the frozen starting deck (provenance `starting_deck`); fields for a transformed or
   generated definition are reserved for when such cards exist.
3. Draw conversion counts each draw opportunity once: retaining keeps the token, a redraw or retrieval opens a new one,
   and special summons, revivals and activations never mark a draw opportunity as played.
4. Setting a Spell or Trap is one play. Activating it later is an activation, not another play.
5. Materials are recorded on the special-summon play that consumed them.

## 5. Requirement to event coverage

| Requirement (spec section) | Record and fields | Hook (committed rules events only) |
|---|---|---|
| Profile: pseudonymous id, first seen, build, last seen | profile, session; `received_at` | Telemetry startup |
| Session start (end not inferred) | session | Telemetry startup |
| Draft pick: offer with counts, selection, category, pick n, settings | draft.picks, quota, order | `Series._draft_pick`, `_draft_setup`, `_finish_draft` |
| Abandoned drafts kept | draft.status `abandoned` | detach, series_over, startup recovery |
| Reward offers and picks (separate measure) | reward.actions | `Series._reward_command` |
| Starting decks frozen at duel start (main/Extra multisets, basics, source, size, fingerprint) | game.decks | `Series._start_game` (before setup) |
| Starting HP/AP, starting player, series length, duel index | game.game | `Series._start_game` |
| Deck changes between duels | reward.deck_after; `source` `+series_changes` | rewards |
| Card drawn (turn vs effect; failed draws not counted) | opportunities, counters.draws | `GameCore.draw_cards` (only on success) |
| Retrieval / direct hand entry | opportunities reason | `GameCore.move_to_pile` (dest hand) |
| Card played: kind, source zone, AP, action id | events "play", counters.plays_by_kind | `_op_pay`, `SummonOps._op_place` |
| Special summon subtype and materials | play kind, materials | `_op_place`, `_op_tribute` |
| Activation: source, effect id, manual/triggered, result | events "act", activations_by_kind | `_op_check_negated`, `activate_trap`, `_flush_triggers` |
| Hand-entry opportunity with token and outcome | opportunities | `_remove_from_zone` (hand exit) |
| Completion: ids, participants, times, active duration, turns, winner, reason, final HP | game.game | `GameCore.end_game`, `Series.award_game` / `forfeit`, concede |
| Disconnect pause excluded from duration | game.paused_ms | `NetSession` disconnect and rejoin |
| Abandoned duel kept apart from results | outcome `abandoned` | detach, startup recovery |
| Per-player per-card counters frozen in the report | game.counters, totals | collector |
| Series results | series | `Series` series_over |
| Tutorial / bot / local / test filterable | flags, mode, env | stamping |
| Two reports, agreement or conflict | gclient vs game | `NetSession._s2c_view` (client) |
| Optional summaries (turns, AP, damage/healing, specials) | totals | `change_hp`, turn notes |
| Response latency, attacks | not measured (marked `unmeasured`) | none: avoids invasive timing hooks |
| Game time and turn time per seat and turn number (v2) | game.active_ms, game.turn_times, game.turn_ms | `MatchEngine` `turn` note, `GameCore.end_game`, `NetSession` pause |
| Structure deck played (v2, for by-deck metrics) | decks[seat].name | `Series` deck_locked |

## 6. Metrics derived from v2 (firebase/tools/lib/metrics.js `timing`)

- `game_length`: summary {n, mean, median, p10, p90, min, max} of canonical `active_ms`, a 2-minute histogram
  (to 60 min, then open-ended), and summaries by mode, by deck key and by number of turns.
- `turn_time.all | human | bot`: summary, a 10-second histogram (to 5 min, then open-ended), by turn number (30+
  grouped) and by order (first / second player). `by_mode`, `by_deck` (human turns) and `by_seat`.
- Deck key (`reconcile.deckKey`): `prebuilt:<structure deck name>` (v2), else `custom`, `draft`, `prebuilt` (v1) or
  `unknown`. The `deck` filter keeps duels where either seat used it, and only that seat's turns.
