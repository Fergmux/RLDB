# Agent / model ledger — production-quality pass

Model routing per rules/09 §3. The lead session runs on Opus 5.5 (architecture, rules timing,
multiplayer privacy, integration). Delegated tasks pass an explicit `model` override; no global
model override is set.

| Task | Role (agent) | Model | Result |
| --- | --- | --- | --- |
| Decision reconciliation (P-xx/S-xx/C-xx) in rules engine | lead | Opus 5.5 | Done; 17 decision tests (15 failed on old engine) |
| Series save/resume, custom decks, 60 s claim | lead | Opus 5.5 | Done; series + net tests pass |
| Art bible + board UX spec | art-director | Sonnet | `design/art/art-bible.md`, `design/ux/match-board.md` |
| Board/cards/hover actions/animations (I-01..I-03) | ui-programmer | Sonnet | Done (resumed once); 293 tests pass; screenshots reviewed by lead — mid-attack shot missing |
| Deck builder + main menu | ui-programmer | Sonnet | Done (resumed once after turn limit); 4 tests; screenshots reviewed by lead |
| Untimed mandatory card text audit (P-30) | general-purpose | Haiku | None found besides 90/183 (already corrected); reviewed by lead |
| Privacy/security review of new fx, saves, custom decks, claim | security-engineer | Opus | 1 leak (accepted P-27 trade-off, documented), 1 exploit + 3 risks fixed with tests |
| UX review of ui-v2 screens (I-01..I-03) | ux-designer | Sonnet | I-01 MEETS, I-02/I-03 PARTIAL; 5 blocking + 7 other defects → fix pass |
| Adversarial two-client QA (16 scenarios) | qa-lead | Opus (resumed once) | 12/16 passed first run; 2 product defects (malformed commands, stale prompts) fixed by lead; 16/16 pass |
| Performance probe (windowed, animations) | lead | Opus | avg 5.1 ms, p95 12.8 ms, p99 20.9 ms (over 16.7 ms target) → fix pass |
| UX defect fix pass (D1–D12, keyboard, perf, fx null) | ui-programmer | Sonnet (resumed twice) | All 12 defects fixed with v3 evidence; p99 20.9 → 16.5–17.3 ms; lead added full-history log link |

Earlier pass (rules/08) reviews, for reference: gameplay-programmer, security-engineer,
network-programmer, systems-designer, qa-lead — all inherited Opus.

## Playtest feedback 02 (F02-01..F02-15, 2026-10-15)

| Task | Role | Model | Result |
| --- | --- | --- | --- |
| Rules side: stance summons, battle preview, AP start/peak, short labels, no-target toast; game_screen interaction integration; live driver | lead | Opus 5.5 | Done; 18 rules + 7 UI integration tests; live driver 65/65 |
| Card rendering: 2:3 cards, rotated cards, ATK diamond, type icons, ready/selected/preview/order states | technical-artist | Sonnet (resumed twice) | Done; 11 geometry tests; galleries; UX D1/D2/D3/D4/D6/D9/D15-17 fixed |
| Procedural SFX + Sfx module (rate limit, volume/mute) | godot-gdscript-specialist (audio brief by lead) | Sonnet | 20 WAVs, 7 tests; programmatic WAV analysis only |
| Structured details pane + AP slots | ui-programmer | Sonnet (resumed twice) | Done; 17 tests; gallery |
| Repeat live runs + evidence index | qa-tester | Haiku | Found flaky sound check + a script error → lead fixed stale hand-key bug (regression test seen failing) |
| UX review of F02 screenshots | ux-designer | Sonnet | 8 MEETS / 7 PARTIAL, 18 defects; high + medium fixed |
| Adversarial QA (privacy, rules, locks, two-client) | qa-lead | Opus (resumed twice) | 3 defects with failing tests (stale multi-pick, guard preview, stance probe) → fixed; 392/392 pass |
