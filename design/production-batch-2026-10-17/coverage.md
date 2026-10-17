# Production batch 2026-10-17: coverage

Status values: pending, in progress, merged (unverified), verified.

## Workstream 1: card database (A1, with A2 for tests)

- **Card changes:** the per-card ledger is `card-ledger.md` (written by A1). It covers the 101 changed IDs and 319 cells; the 82 unchanged cards are retained.
- **Import:** reads the dated CSV, handles `temp`, uses source-aware summon fields, audited TEXT_CORRECTIONS, and regenerates deterministically. Status: in progress (A1).
- **Per-card tests (F26):** all 183 IDs, with a manifest and runner. Status: in progress (A2).

## Workstream 2: Firebase metrics (A3)

| Requirement | Event or record | Status |
| --- | --- | --- |
| Profile/session | profile and session records | in progress |
| Draft picks (offers and copies, decisions, abandoned drafts); reward offers and picks | draftReport / rewardReport | in progress |
| Starting deck snapshot (Main/Extra multisets, source, HP/AP, starting seat) | gameReport.start | in progress |
| Draw / play / activation / special summon / hand opportunities | event batch plus per-game counters | in progress |
| Game completion (reason, winner, HP, turns, duration; abandoned kept separate) | gameReport.end | in progress |
| Verified / provisional / conflicted | admin reconciliation tool | in progress |
| Metrics: W/L, pick rate, deck inclusion, plays, conversion, card win rate, copy-count win rate | admin aggregation tool plus fixtures | in progress |
| Strict rules, emulator tests, deployed and verified live | `firebase/` | in progress (interim deny-all deployed) |
| Settings toggle, privacy note, kill switch, environment labels | client config | in progress |

## Workstream 3: feedback F01–F26

| Item | Owner | Status | Evidence |
| --- | --- | --- | --- |
| F01 Stable deck-select modal | A5 | in progress | |
| F02 Self-buff animation regression | A6 | in progress | |
| F03 Type-choice icon alignment | A5 | in progress | |
| F04 Actionable Extra Deck viewer | A5 | in progress | |
| F05 Card context in the input prompt | A5 | in progress | |
| F06 No hover during zone selection | A5 | in progress | |
| F07 Stance is the final special-summon step | A1 | in progress | |
| F08 Arcane payment circles | A5 | in progress | |
| F09 Sanctified Blade optional Medic | A1 + A2 | in progress | |
| F10 Click a card to take a reward | A5 | in progress | |
| F11 Bot stance decisions | A7 | merged `3ab50c7` | `bot_stance_test.gd` (6 positions); bot-vs-bot 4/4 completed, summons 29 Attack / 23 Defense; suite 621/621 on branch |
| F12 Winning attack on a unit, cinematic | A6 | in progress | |
| F13 4x AA default | A6 | in progress | |
| F14 Catalogue redesign | A4 | in progress | |
| F15 No count or instruction text | A4 | in progress | |
| F16 Fixed-width tags; 99 / 15 caps | A4 | in progress | |
| F17 Canonical deck order | A4 | in progress | |
| F18 Add/remove only in the preview; quantity under the card | A4 | in progress | |
| F19 Simple ATK/DEF in the builder preview | A4 | in progress | |
| F20 Saved/Starter buttons | A4 | in progress | |
| F21 Escape = Back; inspection first | A4 | in progress | |
| F22 Back sound | A6 | in progress | |
| F23 Delete only for saved decks | A4 | in progress | |
| F24 Animated and audible deck edits | A4 (+ A6 sounds) | in progress | |
| F25 Button click sounds | A6 | in progress | |
| F26 Per-card tests | A2 | in progress | |
| Q8 Remove draft drag | A5 | in progress | |
