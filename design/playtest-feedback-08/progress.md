# Playtest feedback 08: progress

Read this first after a context compaction. The items are in `design/playtest-feedback-08.md`.

## Plan
- Three worktree agents, split so no two edit the same files:
  - **A (ui-programmer):** G01, G02, G05, G06: series overlay, game menu, deck select.
  - **B (ui-programmer):** G03, G04, G09: prompt banner, choice modal, toast.
  - **C (gameplay-programmer):** G07, G08, G10: Diggie attack options, summon arrow source, menu background.
- **Lead:** merge each branch with `git merge --no-ff` (remove untracked `.uid` files that would be overwritten first), run the full suite and every live driver, run an independent UI and gameplay review, then do the final report.

## Status
| Agent | Branch | State |
| --- | --- | --- |
| A | worktree-agent-a6c6e0c5d8d213de7 | merged `0b852a0` (G01, G02, G05, G06); 28 new tests; net driver 19/19, series 56/56 |
| B | worktree-agent-aa49c6aff3876b883 | merged (G03, G04, G09); 14 new tests |
| C | worktree-agent-a648d539ea7e1571a | merged `5822a8a` (G07, G08; G10 not reproduced, lead added a texture cache `e9ee9b7`) |

## Decisions
(added as made)
- Records were first written over the existing `playtest-feedback-04.md` and `-05.md` by mistake; both were restored from git unchanged, and this round uses `08`.
- Integrated suite after A + C: 976/976.
- Independent code review of the merged A + C changes: running.
- The independent code review found no authority or hidden-information holes. The lead fixed `5d1cc36`:
  - old hot-seat saves deadlocking at Start;
  - online Save and quit after the other player started the next duel;
  - leave touching a freed screen;
  - network tests for suspend, start_duel and attack mode.
- Dialog dim raised to 0.7 so a series window underneath recedes.

## Final verification (17 Oct)
- Suite 994/994. f02 76/76. Series 56/56. Tutorial 207/207. Network series 19/19 (client wins) and 19/19 (client loses). Bot 4/4. fb08 shots 4/4. G10 driver 8/8.
- Both exes rebuilt (`RLDB.exe` playtest, `RLDB-dev.exe` dev); the exe launch shows no script errors; no Godot processes left.
- Evidence: `production/qa/evidence/2026-10-17-fb08/` (`agent-a`, `agent-b`, `agent-c`, `final`).

