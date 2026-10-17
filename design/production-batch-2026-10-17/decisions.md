# Production batch 2026-10-17: decisions

## Questions and owner answers (source: `design/production-batch-owner-answers-2026-10-17.md`, which overrides the recommendations)

| # | Question | Recommendation | Owner answer |
| --- | --- | --- | --- |
| Q1 | Is the 99-card deck cap combined (Main + Extra) or per deck? | Combined. Saved decks are one list, and the deck builder shows one total | **99 combined (Main + Extra), and Extra at most 15 within that.** No visible limit labels; oversized saves are preserved safely |
| Q2 | Ingestion architecture: Cloud Functions (needs the Blaze plan) or direct client writes on Spark? | Blaze plus an HTTPS Cloud Function, with deny-all Firestore rules. It costs about £0 at playtest volume; set a budget alert | **Spark only.** No Blaze, no billing, no Cloud Functions. Direct client writes under strict rules; integrity limits documented; aggregation by an authorised local/admin tool, never freely writable totals |
| Q3 | Deployment authorisation and access: may I deploy rules, functions and indexes to `rldb-b5593`? The owner would run `firebase login` | Yes. Deploy deny-all rules first, because the database is currently open to anyone | Authorised: the Firebase CLI and Java installed, and security rules deployed to rldb-b5593. Done 17 Oct: CLI 15.34, Temurin JRE 21, owner logged in. Interim deny-all deployed and verified (403 for unauthenticated). Nothing unrelated or paid |
| Q4 | Online result finalisation | Two matching reports make a game verified; one report makes it provisional (included by default, flagged); disagreeing reports make it conflicted (excluded) | **As recommended.** Agreeing reports: verified. One report: provisional (included, flagged). Disagreeing: conflicted (excluded). Later agreement upgrades without double counting; a later conflict removes the provisional contribution on rebuild. Classification is done by trusted reconciliation (the admin tool), never declared by a client |
| Q5 | Retention | Raw event batches 180 days; game, draft and reward reports 2 years; aggregates kept; deletion by UID with an admin script | **Keep all gameplay data indefinitely**; no age-based deletion. Documented admin deletion process, kill switch, monitor Spark quota. The local outbox is still bounded |
| Q6 | Disclosure and consent | One Settings checkbox, "Share anonymous gameplay statistics" (on by default), plus a privacy note document | **Settings checkbox "Share anonymous gameplay statistics"**, on by default, with a privacy note; turning it off stops future collection and upload (queued-data treatment documented). Owner wants a **stable Steam-linked ID** without the persona name; it must be securely linked, not a trusted client-supplied Steam ID. The pseudonymous data may still be personal data (owner intent recorded, not a legal finding) |
| Q7 | Environment label for current builds | `playtest` for current builds; `production` reserved for a release; `dev` and `test` for editor and automated runs | As recommended: playtest / production / dev / test, set by build configuration and stamped on every record and aggregate key; production aggregates exclude the others by default. Labels are not a security boundary |
| Q8 | Draft-order drag-and-drop versus F07's "no-drag-and-drop input model" | Remove the drag; keep the arrow buttons | **Remove draft-order dragging**; keep the up/down arrows, focus behaviour and order |
| Q9 | Lone Warrior / Revealed third Extra Deck card (`#REF!` in the sheet) | Owner to name it; otherwise the deck keeps 2 | Unknown: leave Lone Warrior / Revealed with its 2 valid Extra Deck cards; the owner will update it later |

## Genuine blocker reported to the owner

- **Verified Steam-linked identity is not possible on Spark.** It needs a trusted server to check a Steam auth ticket with a publisher Web API key, plus the owner's own App ID; the game is still on Spacewar 480. Chosen fallback: a stable anonymous Firebase UID per install (refresh token in a local credential file) plus a salted one-way hash of the Steam ID, explicitly flagged `unverified`. It is used for grouping, never treated as proof of identity. A verified link can be added later (own App ID plus a trusted server) without changing collected data.
- **No trusted aggregation in the cloud on Spark.** Totals are computed by an owner-run admin tool (`firebase/tools/`), which also does the verified / provisional / conflicted classification.

## Autonomous decisions (proposed by the agent; NOT owner-confirmed, reported at the end)

- **`temp` in `condition`:** treated as editorial metadata. It is stripped at import and never shown or compiled. The raw value is kept in the provenance field.
- **Illusionist (177) On Destruction:** you may move one card from YOUR Exhaust to YOUR Draw whose current ordinary AP cost is at most 1. Special-cost (Extra Deck) cards are not eligible. It uses the same Draw-placement semantics as the existing "move to Draw" effects. It is optional. Necrovast's exception is unchanged.
- **Stormcaller (25):** "Destroy all Unprotected Basic Units" hits both players' unprotected basic units and is mandatory. The same reading as Dante's "all Units".
- **Dante (36):** the manual once-per-turn effect is "Apply 1 Cleanse or 10 Burn to a Unit": any unit, with the player choosing which. The ATK bonus is +1 per Burn on Dante, continuous.
- **Tag Team names:** follow the new CSV by ID. This resolves the F06-03 sheet mismatch: 7 = Tag Team - B, 11 = Tag Team - J.
- **F18 (A4):** clicking a card in the deck builder now selects it instead of adding it, because add/remove happens only in the preview. Add is select, then Add (or Enter / +). The hover no longer changes the preview. Rename is hidden along with Delete. A refused save of an oversized old deck names the cap in its error message. A sort control was added to the catalogue only. (Toss-up: restoring click-to-add is a small change.)

## Card migration (package A1) autonomous decisions (NOT owner-confirmed)

Full list with the options considered: `card-ledger.md` (Decisions section). The ones most worth owner review:

- **Chaos Witch (13):** a still-typeless Witch imposes nothing; after its once-per-turn Type change, every Mage on both sides has the Witch's Type while it is on the Field. The literal alternative (a typeless Witch makes all Mages typeless on arrival) was rejected.
- **Tag Team - W (10):** the search is mandatory (no "you can"); 6, 7, 9 and 11 are optional. Tag Team - J (11) with a typeless partner matches nothing.
- **Magentric (69):** only a Field tribute for a Fusion or Ritual summon counts; the 2 Pierce lands on the summoned unit before its own On Summon effects. Arcane exhausting from Spent does not count.
- **Accio (30):** Skip does neither part; the Retain follows only when a Draw unit was sent to Spent, and targets a unit in Hand.
- **Spell or Trap (29, 59, 63):** means a card in a backrow zone; Powers are excluded.
- **Importer:** the exact Arcane requirement text (F03-04) is now an importer correction (it had only been hand-edited into cards.json). Overrides 90 and 183 dropped as obsolete; 45, 47, 48, 169 kept.
- **F07:** the stance choice commits every Fusion method; the separate Confirm is gone everywhere it existed (only Fusion had one).
- **F09:** not reproduced; Sanctified Blade's Medic waits for activation and a target. Recorded in `card-ledger.md`.
- **F13 (A6):** a legacy saved 8x AA (written by the old always-save behaviour) is treated as the old default and becomes 4x. Other saved levels are kept. (Toss-up: it could keep 8x.)
- **F22 (A6):** the back sound is chosen by button label (Back / Exit / Leave / Cancel / Close) unless a button sets an `sfx` meta. Main-menu hover ticks are kept.
- **F12 (A6):** the HP-change cause (direct / battle / pierce) is read from the authoritative log text. A1 should eventually add a structured cause field; a test guards the wording.
- **F09 (A1):** not reproduced. The Medic only activates by deliberate use, with a target choice. The owner probably saw the Medic status healing at turn start.
- **Firebase (A3):** the admin tool authenticates with Google Cloud ADC or a service-account key kept outside the repo, not an allowlisted user account, so the rules stay closed to every client. The owner must run `gcloud auth application-default login` (gcloud is not installed) or provide a key, before using the tool on live data.
- **Firebase (A3):** turning the setting off deletes not-yet-sent queued records (it doesn't hold them). Tutorial games are not collected.
- **Firebase (A3):** the online client sends a small confirming report built from its own view; the host reports both seats. The host report contains the opponent's hidden cards (database only, never shown to the other player).
- **Firebase (A3):** the salt for the Steam hash ships in the client, and Steam IDs are enumerable, so the hash is pseudonymous, not anonymous (documented in `docs/telemetry/privacy.md`).
