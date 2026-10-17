# RLDB telemetry schema v1: records and field dictionary

Status: implemented 17 Oct 2026 (production batch, Stage 3). Source of truth for
`rldb/src/telemetry/telemetry_collector.gd` (producer), `firebase/firestore.rules` (envelope
validation) and `firebase/tools/lib/reconcile.js` / `metrics.js` (consumer). Any change to a field
meaning bumps `schema_version`. The rules accept only `schema_version == 1`, so v2 needs a rules
deploy first.

## 1. Document envelope (validated by the security rules)

Path: `users/{uid}/submissions/{docId}`. Created once, never updated or deleted by a client.

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | int | `1` |
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
  basic_units: {id: copies}, main_size, extra_size, size, fingerprint (16 hex), duel_index}
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
