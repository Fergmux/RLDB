# Production batch 2026-10-17: decisions

## Questions put to the owner (Stage 0), with recommendations

| # | Question | Recommendation | Owner answer |
| --- | --- | --- | --- |
| Q1 | Is the 99-card deck cap combined (Main + Extra) or per deck? | Combined. Saved decks are one list, and the deck builder shows one total | (pending) |
| Q2 | Ingestion architecture: Cloud Functions (needs the Blaze plan) or direct client writes on Spark? | Blaze plus an HTTPS Cloud Function, with deny-all Firestore rules. It costs about £0 at playtest volume; set a budget alert | (pending) |
| Q3 | Deployment authorisation and access: may I deploy rules, functions and indexes to `rldb-b5593`? The owner would run `firebase login` | Yes. Deploy deny-all rules first, because the database is currently open to anyone | (pending) |
| Q4 | Online result finalisation | Two matching reports make a game verified; one report makes it provisional (included by default, flagged); disagreeing reports make it conflicted (excluded) | (pending) |
| Q5 | Retention | Raw event batches 180 days; game, draft and reward reports 2 years; aggregates kept; deletion by UID with an admin script | (pending) |
| Q6 | Disclosure and consent | One Settings checkbox, "Share anonymous gameplay statistics" (on by default), plus a privacy note document | (pending) |
| Q7 | Environment label for current builds | `playtest` for current builds; `production` reserved for a release; `dev` and `test` for editor and automated runs | (pending) |
| Q8 | Draft-order drag-and-drop versus F07's "no-drag-and-drop input model" | Remove the drag; keep the arrow buttons | (pending) |
| Q9 | Lone Warrior / Revealed third Extra Deck card (`#REF!` in the sheet) | Owner to name it; otherwise the deck keeps 2 | (pending) |

## Autonomous decisions (recorded as made)

- **`temp` in `condition`:** treated as editorial metadata. It is stripped at import and never shown or compiled. The raw value is kept in the provenance field.
- **Illusionist (177) On Destruction:** you may move one card from YOUR Exhaust to YOUR Draw whose current ordinary AP cost is at most 1. Special-cost (Extra Deck) cards are not eligible. It uses the same Draw-placement semantics as the existing "move to Draw" effects. It is optional. Necrovast's exception is unchanged.
- **Stormcaller (25):** "Destroy all Unprotected Basic Units" hits both players' unprotected basic units and is mandatory. The same reading as Dante's "all Units".
- **Dante (36):** the manual once-per-turn effect is "Apply 1 Cleanse or 10 Burn to a Unit": any unit, with the player choosing which. The ATK bonus is +1 per Burn on Dante, continuous.
- **Tag Team names:** follow the new CSV by ID. This resolves the F06-03 sheet mismatch: 7 = Tag Team - B, 11 = Tag Team - J.
