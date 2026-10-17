# Firebase game and player statistics — implementation request

Date: 17 October 2026
Status: requested; implement collection only, without player-facing statistics or dashboards.

## Outcome and scope

Add reliable background telemetry to the existing RLDB Godot game so future in-game statistics and private analytics dashboards can compute the measures below globally and for each player. Implement collection, authenticated ingestion, durable retry, canonical completed-game records, and repeatable aggregation. Do not build a statistics screen or dashboard in this pass. Continue the existing project at `rldb/project.godot`; preserve gameplay, rules, networking and hidden-information protections.

Read repository instructions, the latest rules, `design/decision-register-answers.md`, playtest feedback, and the card database update documents before implementation. Use stable card definition IDs and instance IDs, never display names or CSV row positions. Inspect current match authority, saves, deck builder, draft/reward flow and Steam networking before choosing hooks.

## Provided Firebase configuration

- Project ID: `rldb-b5593`.
- Firebase Web API key: `AIzaSyAAP2b-X1agiZYWFY_dlyMptFrAFzox_Mg`.
- Anonymous sign-in is enabled.
- Existing database rules are reportedly in test/allow mode. Do not rely on that for implementation or release.
- Proposed database: Cloud Firestore. Verify it exists and confirm the intended database/location before infrastructure creation. Do not assume Realtime Database and Firestore rules are interchangeable.

The Web API key identifies the Firebase app; it does not grant database authorization. Use Firebase Authentication ID tokens for authenticated requests. Never put service-account private keys, Admin SDK credentials or refresh tokens in checked-in files or logs. Store anonymous credentials in an appropriate local credential store and redact diagnostics. Ask only for genuinely missing configuration, deployment access or a required project decision; do not request the already supplied values again. Do not change existing Firebase resources blindly.

## Player experience and privacy

No gameplay-facing telemetry UI, statistics, notifications, login prompts, upload indicators, errors, debug hints or dialogs. Network/auth/service failures must not block a turn, response window, match completion, rewards or startup. Record bounded, redacted developer diagnostics separately; “silent” means silent to players, not impossible to debug. Run asynchronously with explicit timeouts.

This is background gameplay measurement, not device surveillance: collect only the pseudonymous identifiers and gameplay fields needed here. Do not collect chat, email, Steam persona names, raw Steam IDs, contacts, device fingerprints or unrelated personal data. Do not expose opponent hidden cards through telemetry endpoints or the multiplayer game log. Do not add a dashboard/public read endpoint now.

Before public distribution, document the data practices and appropriate disclosure/consent controls for the release context; this request to omit gameplay UI does not authorize concealing collection from privacy documentation. Provide a developer configuration/kill switch and a documented data-deletion process. Propose raw-data retention and aggregate-retention settings for the owner to approve; make retention configurable rather than keeping identifiable raw events forever by accident.

## Identity and analytical boundaries

Persist one Firebase anonymous UID per local profile. Reuse it across sessions and renew tokens; do not create a new account each launch. Anonymous identities are installation/profile scoped, not automatically the same human across reinstalls or devices. Do not claim cross-device individual statistics without a future account-linking design. For local play, distinguish both local player profiles; never attribute both seats to one UID. Use a separate local participant identifier or mark guest seats unlinked. Bots have an explicit identity kind, never an ordinary human UID.

Track distinct identifiers for: event, application session, series, game/duel, draft, deck snapshot, action, card definition and card instance. Save game/series IDs with existing reconnect and between-game series saves. Use a new game ID for each duel, not each reconnect. A duel is one game; series results are separate.

Every record needs schema version, game build, rules/content version (including a card-data hash), environment, mode, tutorial/bot/local/network flags, event sequence and timestamps. Keep immutable historical deck/card versions; renamed or rebalanced cards must not silently rewrite history. Production, development and automated test data must be separable.

## Required event and record model

Define validated typed schemas and a field dictionary in repository documentation. Prefer compact event batches and a per-game snapshot over a Firestore write for every cosmetic action. Do not capture animation frames, pointer movement or continuously poll card state.

### Profile/session

Record pseudonymous player ID, profile creation/server first-seen, session start/end if known, build and last-seen. Do not infer a completed session from a clean shutdown requirement. Keep auth identity separate from gameplay participant identity and validate the mapping server-side.

### Draft choices

For each draft pick: draft ID, player, category, pick number, offered card IDs with offered copy counts, selected card ID/count, reroll/skip/cancel status and relevant composition settings. Distinguish draft from reward selections, prebuilt decks and free deck-builder edits. Log each actual offer and decision once. Persist abandoned drafts too so selection statistics do not require a completed game. Track reward offers/picks separately as a useful additional measure.

### Starting deck snapshots

When a duel actually starts, freeze both players' exact main and Extra Deck multisets (card ID -> quantity), basic-unit choice, source (prebuilt/custom/draft), deck size and optional stable deck fingerprint. Include cards regardless of initial zone. Store configured starting HP/AP and starting player. Keep this snapshot independent of mid-game additions, transforms, generated copies and removals.

“Picked to be in a deck at duel start” means inclusion in this snapshot, not every deck-builder click. Also distinguish draft selections later removed before the duel. Capture subsequent deck changes/rewards separately so series progression can be reconstructed. Track configured series length and duel index.

### Gameplay events

Hook committed rules-engine actions, not UI clicks or animations:

- Card drawn: player, card/instance IDs, draw source, turn/action sequence; distinguish ordinary draw from retrieval, generation and direct hand insertion. Retaining is not drawing again. Failed empty-pile draws do not count as successful draws.
- Card played: card/instance ID, acting player, source zone, play kind (normal summon, special summon subtype, immediate spell, set spell/trap/power), actual AP spent and unique action ID. Emit only for committed legal actions. A canceled picker or rejected click is not a play.
- Activation/resolution: effect owner/source card, effect ID, manual/triggered, result (resolved, negated, no legal target, canceled). Count repeated power/unit abilities separately from playing the card. Setting a spell/trap is one play; later activation is a distinct activation, not a second play.
- Track each hand-entry opportunity with a unique token, entry reason and whether it was played before exiting hand. Keep its originating successful-draw token if applicable. A retained card keeps the same opportunity. A later redraw creates a new draw opportunity. This supports meaningful draw-to-play conversion without special summons inflating it.
- Special summons from Extra Deck/Spent are plays in the broad play total, with their source/kind retained, but are not automatically conversions of a draw. Capture material IDs and summon subtype if used for extra-deck usage analysis.
- Useful optional compact summaries: turns elapsed, AP earned/spent/unspent, damage/healing by source, attacks, special summons, statuses applied and response latency. Prefer counters derived from existing authoritative events; do not implement invasive timing instrumentation or unrelated analytics SDK collection.

Maintain original card definition, current transformed definition if applicable, creator/source, and generated-vs-starting-deck provenance so tokens/copies/transforms are not misattributed. Document attribution rules rather than guessing them in a dashboard.

### Game completion

Record stable game ID, series ID, participants, starting snapshots, start/end time, active duration (excluding disconnect pauses where measurable), turns, starting seat, winner/loser or explicit draw, completion reason and final HP. Include normal lethal, concession, host-declared disconnect win and other actual supported outcomes distinctly. A disconnect pause is not a loss. Abandoned/incomplete games stay a separate state and are excluded from ordinary completed-game win rates. Saving between games must not manufacture an unfinished game's outcome.

Freeze per-player/per-card draw/play/activation counters and draw-opportunity outcomes into the completed-game report. Retain event-batch provenance and completeness flags. Mark unknown or incomplete measurements explicitly; do not fill missing observations with zero. Tutorial, bot, same-device/local and test games must be filterable and excluded from human competitive statistics by default.

## Exact metrics and denominators

Support every measure globally and filtered by player, time range, mode and content version. Report sample size alongside percentages; sparse cards should not look conclusively strongest/weakest. Return no percentage when denominator is zero.

| Measure | Required calculation |
| --- | --- |
| Player win/loss | W and L among eligible finalized duels; win rate W/(W+L). Keep draws/abandonments separately and document alternative denominator if draws become supported. Series W/L is separate. |
| Most/least drafted | Selected copies and selection count per card; offer-normalized pick rate = picks / pick opportunities where offered. Count a card once per offer opportunity for this denominator, even if duplicated in an offer; retain offered copy counts separately. Cards never offered have undefined pick rate. |
| Starting-deck popularity | Deck inclusions / eligible player-game deck snapshots, total starting copies, and average copies per included deck; main and Extra Deck distinguished. Include zero-use cards from the versioned catalog so “least” can include zero. |
| Most/least played | Total committed plays by card, unique games played in, plays/game, plus activation counts separately. Filter normal/special/source as appropriate. |
| Played as percent drawn | Primary conversion = successful draw opportunities whose card was played from that corresponding hand opportunity / successful draw opportunities. Distinct opportunity IDs prevent repeated activations, redraws, revival and generated cards inflating this beyond 100%. Mark still-open opportunities incomplete for unfinished games. Also expose raw hand-plays/draw-count as a separately named ratio if useful; it is not the primary percentage. |
| Win rate with card | Wins / decisive eligible player-games whose starting deck included >=1 copy. One observation per player-game, not per card copy or play. |
| Win rate by copy count | For each card and exact starting quantity n, wins / decisive eligible player-games with exactly n copies. Support n=0 comparison and variable deck sizes. Never pool one-copy and two-copy observations. |

A game with two players contributes one game but two player-game observations, potentially with both decks including the same card. Label card win-rate denominator accordingly. Preserve player/opponent/game linkage for later adjustment and avoid pretending the two observations are independent. These are associations, not evidence that the card caused the win: deck strength, pilot, mode, starting seat and patch can confound results.

Recommended additional metrics, using the same captured data:

- First-player win rate; duel length by turns and duration; completion/concession/disconnect rates.
- Drawn-but-never-played frequency and unspent AP, useful for dead cards and pacing.
- Extra Deck inclusion versus actual summon rate by subtype.
- Draft pick position, offer-to-pick rate, and reward pick rate separately.
- Deck size and copy-count distributions; win rate by deck archetype/fingerprint when samples permit.
- Active player/session counts using pseudonymous profiles, clearly labeled as profiles rather than unique humans.
- Ingestion health: queued reports, accepted/duplicate/rejected/conflicted reports and missing participant reports, visible only to authorized developers.

Do not expand this into speculative tracking of unrelated user behaviour. Keep extra metrics low cost and derived where possible.

## Firebase architecture, authority and security

Preferred architecture: Godot uploads batches/reports through a small authenticated ingestion service (for example an HTTPS Cloud Function), which validates Firebase ID tokens, schemas, payload bounds, participant membership, versions, sequence and idempotency keys, then writes Firestore using restricted backend IAM. Firebase Anonymous Auth permits frictionless identity but is not proof that submitted game outcomes are honest.

Suggested private collections: playerProfiles, gameReports (per reporter), games (canonical), playerGames, draftReports, eventBatches, aggregateJobs/checkpoints, cardMetrics and playerCardMetrics. Finalize actual paths/schema before coding; partition aggregates by environment, mode/content version and period as needed. Use subcollections or bounded batch documents rather than an unbounded document per player. Respect Firestore limits and estimate write/storage/function costs for expected game volume before deploying. Do not assume a dashboard can cheaply scan all raw events at query time; create rebuildable, versioned aggregates on trusted backend code. Larger analytical exports may be a later phase.

Online host may submit the game summary, but do not trust an arbitrary client claim to write another player's profile or final totals. Use authenticated participant registration and/or independently submitted participant reports, compare their game identity and outcomes, and keep reports with insufficient corroboration/conflicts explicitly provisional or unverified. A P2P host is still an untrusted client. Do not market these as cheat-proof competitive statistics without an authoritative backend. Define distinct treatment for local tests and an opponent who never uploads. Questions about finalization policy may be asked without blocking event instrumentation.

Idempotency is mandatory at ingestion AND aggregation: stable event/action IDs, stable report IDs, canonical game once, no double increments from two reports, retried functions or duplicate completion signals. Use transactions/checkpoints or another demonstrated exactly-once aggregation effect; transport itself may be at-least-once. Store raw immutable submissions plus provenance so aggregates can be rebuilt after schema changes. Prevent clients from choosing a different authenticated owner UID in a request body.

### Security rules deliverable

Output an exact, deployable `firestore.rules` file matched to the chosen architecture and explain it in the final handoff. For the preferred backend-only design, the complete starting policy is:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

All client SDK/REST database reads/writes are denied, including anonymous clients. The authenticated ingestion service writes through the Admin SDK/server credentials, which bypass Firestore rules, so endpoint validation and backend IAM are essential. Firebase anonymous sign-in remains available independently. No client receives other users' reports, decks, raw events or aggregate data. Future in-game stats require separately designed owner-scoped read access or a validated service endpoint; do not prematurely open collections now.

If choosing direct client writes instead, justify the tradeoff and provide different tested owner-only create/schema/size rules with immutable submissions and server-only canonical records/aggregates. The deny-all example cannot coexist with direct client upload requirements. Never use `allow read, write: if true`, broad authenticated access or a client-supplied admin flag. Produce emulator tests proving unauthorized/cross-user reads and writes fail. Review endpoint abuse protection/rate limits and App Check support for the actual native Godot integration; do not assume a Web SDK attestation solution works on desktop.

Provide Firebase setup/deployment instructions and exact rules at the end. Apply cloud changes only within established deployment authorization; if deployment is unavailable, finish and validate the code/configuration and state precisely what the owner must deploy. Do not claim collection is live before a real test record is accepted under the final rules. Flag the current test-allow rules for replacement before distribution.

## Offline queue and silent failure

Use a durable local outbox (including drafts and completed games), atomically written before upload, with a bounded disk budget and documented retention. Do not assume automatic Firestore offline persistence exists in a Godot REST integration. Preserve original IDs/timestamps across restart, auth refresh and reconnect; retry with exponential backoff plus jitter and opportunistically after connectivity returns/startup. Never busy-loop or delay gameplay. Mark delivered only after server acknowledgement. Handle a lost acknowledgement as a duplicate-safe retry.

Classify errors: offline/timeouts/429/transient 5xx retry; refresh expired tokens appropriately; malformed/permanently forbidden submissions need a bounded redacted diagnostic/quarantine rather than infinite retries. Avoid retry storms. Preserve high-value completed-game summaries when trimming low-priority events, mark missing detail, and document expiry/drop policy. Provide a developer-only way to inspect/flush/test the queue. Reconnect must not reset counters or resend a second canonical game. Backend downtime must never prevent saving a series.

## Implementation workflow and questions

Use applicable installed studio skills and specialist subagents: an architecture/data owner, a gameplay instrumentation owner, and an independent security/QA reviewer where useful. Delegate straightforward schema inventories and coverage audits to lightweight models; use a suitable stronger model for identity, backend validation, idempotency and security reasoning. Give agents clear file ownership and integrate through a shared schema. Verify actual available skills/models rather than inventing commands. Avoid overlapping edits or spawning agents without a useful independent task.

Inspect first, then provide a concise implementation plan and a requirement-to-event coverage table. Ask focused questions when an unresolved product choice materially changes correctness (e.g. cross-device identity or provisional online result policy). Continue independent work while waiting. Do not ask the owner to restate already defined metrics or turn UI into a telemetry setup flow.

Deliver functioning instrumentation and backend components, not merely this design. Maintain a checklist of requested metrics and evidence that each can be calculated from actual test records. Preserve the game rules; analytics cannot alter action resolution order or reveal cards.

## Acceptance and verification

1. Deterministic fixtures demonstrate global and per-player W/L, offer-adjusted draft picks, starting-deck counts, play totals/conversion and win rates at 0/1/2 copies, including explicit expected numerators/denominators.
2. Repeat activations, retained cards, redraws, generated cards, revival and special summons are attributed correctly and cannot inflate draw conversion.
3. Normal completed game, concession, paused disconnect, host timeout victory, abandon, next duel and resumed series are correctly distinguished. Test both clients reporting, duplicates, out-of-order events, function retries and conflicting outcomes.
4. Offline play followed by reconnect uploads once; forced app restart retains queued reports; lost acknowledgements and expired auth tokens recover silently. Permanent validation errors do not loop forever.
5. No telemetry errors, prompts or performance stalls in gameplay; no hidden-data leaks through logs, multiplayer payloads beyond existing needs, or public endpoints.
6. Security emulator tests verify database denial and authenticated endpoint validation, spoofed UID rejection, bounded payloads and server-only aggregation. Test privileged backend operations separately because Admin access bypasses rules.
7. Actual Godot match smoke test plus automated schema/aggregation regressions pass. Separate test environment/records from real balance statistics.
8. Final handoff includes changed files, tests/evidence, unresolved decisions, exact Firebase rules and deployment steps, queue/retention defaults, estimated costs and privacy/identity limits. Clearly state which infrastructure is deployed and which remains to configure. No statistics UI or dashboard is included in this pass.

## Official references for the implementation agent

- API keys and authorization: https://firebase.google.com/docs/projects/api-keys
- Security checklist and anonymous identity limitations: https://firebase.google.com/support/guides/security-checklist
- Firestore REST authentication: https://firebase.google.com/docs/firestore/use-rest-api
- Firestore rules: https://firebase.google.com/docs/firestore/security/get-started
- Offline support (verify SDK/platform availability): https://firebase.google.com/docs/firestore/manage-data/enable-offline

Check current official documentation for the actual chosen SDK/backend before implementation. This document requests implementation; it does not assert Firebase has already been configured beyond the owner's statements above.
