# Production batch 2026-10-17: coverage

Status values: pending, in progress, merged (unverified), verified.

## Workstream 1: card database (A1, with A2 for tests)

- **Card changes:** the per-card ledger is `card-ledger.md` (written by A1). It covers the 101 changed IDs and 319 cells; the 82 unchanged cards are retained.
- **Import:** reads the dated CSV, handles `temp`, uses source-aware summon fields, audited TEXT_CORRECTIONS, and regenerates deterministically. Status: merged `16dea57`. 101 changed cards and 319 cells reconciled (34 behaviour, 26 balance, 169 wording, 61 reference, 29 already correct, 0 pending); suite 658/658 and f02 75/75 on the branch.
- **Per-card tests (F26):** all 183 IDs, with a manifest and runner. Merged (`207bd63`, `d788db5`): **183/183 covered, 0 pending**; suite 812/812 on the A2 branch after merging bb600f7.

## Workstream 2: Firebase metrics (A3)

| Requirement | Event or record | Status |
| --- | --- | --- |
| Profile/session | profile and session records | merged `89e5871` |
| Draft picks (offers and copies, decisions, abandoned drafts); reward offers and picks | draftReport / rewardReport | merged `89e5871` |
| Starting deck snapshot (Main/Extra multisets, source, HP/AP, starting seat) | gameReport.start | merged `89e5871` |
| Draw / play / activation / special summon / hand opportunities | event batch plus per-game counters | merged `89e5871` |
| Game completion (reason, winner, HP, turns, duration; abandoned kept separate) | gameReport.end | merged `89e5871` |
| Verified / provisional / conflicted | admin reconciliation tool | merged `89e5871` |
| Metrics: W/L, pick rate, deck inclusion, plays, conversion, card win rate, copy-count win rate | admin aggregation tool plus fixtures | merged `89e5871` |
| Strict rules, emulator tests, deployed and verified live | `firebase/` | in progress (interim deny-all deployed) |
| Settings toggle, privacy note, kill switch, environment labels | client config | merged `89e5871` |

## Workstream 3: feedback F01–F26

| Item | Owner | Status | Evidence |
| --- | --- | --- | --- |
| F01 Stable deck-select modal | A5 | merged `9120580` | |
| F02 Self-buff animation regression | A6 | merged `bb600f7` | |
| F03 Type-choice icon alignment | A5 | merged `9120580` | |
| F04 Actionable Extra Deck viewer | A5 | merged `9120580` | |
| F05 Card context in the input prompt | A5 | merged `9120580` | |
| F06 No hover during zone selection | A5 | merged `9120580` | |
| F07 Stance is the final special-summon step | A1 | merged `16dea57` | |
| F08 Arcane payment circles | A5 | merged `9120580` | |
| F09 Sanctified Blade optional Medic | A1 + A2 | merged `16dea57` | |
| F10 Click a card to take a reward | A5 | merged `9120580` | |
| F11 Bot stance decisions | A7 | merged `3ab50c7` | `bot_stance_test.gd` (6 positions); bot-vs-bot 4/4 completed, summons 29 Attack / 23 Defense; suite 621/621 on branch |
| F12 Winning attack on a unit, cinematic | A6 | merged `bb600f7` | |
| F13 4x AA default | A6 | merged `bb600f7` | |
| F14 Catalogue redesign | A4 | merged `cb4b9e4` | |
| F15 No count or instruction text | A4 | merged `cb4b9e4` | |
| F16 Fixed-width tags; 99 / 15 caps | A4 | merged `cb4b9e4` | |
| F17 Canonical deck order | A4 | merged `cb4b9e4` | |
| F18 Add/remove only in the preview; quantity under the card | A4 | merged `cb4b9e4` | |
| F19 Simple ATK/DEF in the builder preview | A4 | merged `cb4b9e4` | |
| F20 Saved/Starter buttons | A4 | merged `cb4b9e4` | |
| F21 Escape = Back; inspection first | A4 | merged `cb4b9e4` | |
| F22 Back sound | A6 | merged `bb600f7` | |
| F23 Delete only for saved decks | A4 | merged `cb4b9e4` | |
| F24 Animated and audible deck edits | A4 (+ A6 sounds) | merged `cb4b9e4` | |
| F25 Button click sounds | A6 | merged `bb600f7` | |
| F26 Per-card tests | A2 | merged `d788db5`: 183/183 covered, 0 pending | |
| Q8 Remove draft drag | A5 | merged `9120580` | |
