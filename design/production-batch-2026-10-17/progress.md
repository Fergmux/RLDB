# Production batch 2026-10-17: progress

**Resume here after compaction or restart.** First reread, in order:
1. `design/implement-production-batch-2026-10-17.md` (the master instructions)
2. this file
3. `decisions.md`, `coverage.md` and `agents.md` in this folder
4. the three specifications:
   - card data: `design/implement-card-database-update-2026-10-17.md` and `design/card-database-diff-2026-10-17.md`
   - metrics: `design/firebase-game-statistics-request-2026-10-17.md`
   - feedback F01–F26: `design/playtest-feedback-07-production-2026-10-17.md`

Then inspect the actual working tree (`git log`, `git status`, worktrees under `.claude/worktrees/`) before continuing.

## Current phase

**Stages 2–4 running unattended**, under the owner's instruction of 17 Oct: "don't pause or ask questions until everything is complete".

- Firebase CLI and Java are installed, and the owner is logged in.
- Interim deny-all rules are deployed and verified.
- Wave A agents A1–A7 are running (see `agents.md`). A7 is merged.
- Toss-up decisions go in `decisions.md` for the final report.

## Stage 0 findings

### Repository and tooling
- Godot 4.6.1 (Forward+, D3D12). Branch `build/rldb-game`.
- Tests: 614 GdUnit cases passing (as of `6b01b15`).
- Node v24 is installed. Firebase CLI, gcloud and Java are not; the Firestore emulator needs Java.

### Card source
- `rules/sources/RLDB Master - Card Database (2026-10-17).csv`: SHA-256 `8ac4a39a…6d693da3` matches the spec.
- 183 rows. The headers match the baseline.

### Importer
- `tools/import_cards.py` reads the baseline CSV by a hard-coded filename (line 74).
- `CONDITION_TO_SUMMON = {"63","97"}` is a hazard: the new 63 condition is `temp`.
- `TEXT_CORRECTIONS` (line 32) needs an audit per ID.

### Firebase
- The Firestore `(default)` database exists.
- An unauthenticated REST read returned 404 NOT_FOUND, not PERMISSION_DENIED. **The database is open to anyone** (test rules).

### Art
- There are no card art assets in the repo; `rldb/assets/art` holds only backgrounds.
- `card_img` values are references to the owner's art set, so there is nothing local to remap. They are kept as data.

### Decks
- Saved custom decks are a single combined list of card ids (`DeckStore`); Main and Extra are split by category at game start.

### Existing behaviour that conflicts with F07's cross-cutting "no drag-and-drop input model"
- The draft-order drag-and-drop added in F06-05.

### Card questions settled by the new CSV
- The Tag Team name question from F06-03 is resolved: the new CSV names 7 = "Tag Team - B" and 11 = "Tag Team - J", matching the owner's deck sheet.

## Next actions once the owner answers
1. Record the answers in `decisions.md`.
2. Write `coverage.md` (card ledger skeleton, metrics table, F01–F26) and `agents.md`.
3. Stage 2: importer audit and the card migration (lead plus a gameplay agent), and the per-card test framework.
4. Stage 3: Firebase.
5. Stage 4: F01–F26.
6. Stage 5: verification and reviews.
