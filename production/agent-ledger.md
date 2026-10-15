# Agent / model ledger — production-quality pass

Model routing per rules/09 §3. The lead session runs on Opus 5.5 (architecture, rules timing,
multiplayer privacy, integration). Delegated tasks pass an explicit `model` override; no global
model override is set.

| Task | Role (agent) | Model | Result |
| --- | --- | --- | --- |
| Decision reconciliation (P-xx/S-xx/C-xx) in rules engine | lead | Opus 5.5 | Done; 17 decision tests (15 failed on old engine) |
| Series save/resume, custom decks, 60 s claim | lead | Opus 5.5 | Done; series + net tests pass |
| Art bible + board UX spec | art-director | Sonnet | `design/art/art-bible.md`, `design/ux/match-board.md` |
| Board/cards/hover actions/animations (I-01..I-03) | ui-programmer | Sonnet | In progress |
| Deck builder + main menu | ui-programmer | Sonnet | Done (resumed once after turn limit); 4 tests; screenshots reviewed by lead |
| Untimed mandatory card text audit (P-30) | general-purpose | Haiku | None found besides 90/183 (already corrected); reviewed by lead |
| Privacy/security review of new fx, saves, custom decks, claim | security-engineer | Opus | 1 leak (accepted P-27 trade-off, documented), 1 exploit + 3 risks fixed with tests |

Earlier pass (rules/08) reviews, for reference: gameplay-programmer, security-engineer,
network-programmer, systems-designer, qa-lead — all inherited Opus.
