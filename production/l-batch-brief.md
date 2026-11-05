# L batch, 5 Nov 2026: brief for every agent

Read this whole file before you start. Your items come from `design/owner-feedback-2026-11-05.md`. Read your rows there
word for word, plus the "Clarifications" section, whose owner answers are confirmed rules. The owner wants a
**production-quality** fantasy card game: polished, beautiful, smooth, nothing strange, plain or placeholder. "Spare no
expense": take the time to do each item properly, and check the result in screenshots as an art director would. If you
see something near your work that could be better, fix it too and list it under "Extra improvements" in your report.

You work **unsupervised**: never stop to ask. Take the best decision and list it under "Decisions" in your final
report (the integrator copies them to the owner).

## Project facts
- Godot 4.6.1, GDScript, static typing. The Godot root is `rldb/`, in your worktree too. Doc comments (`##`) on public
  functions.
- Godot exe: `/c/Users/fergm/Downloads/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe` (call it
  `$G`).
- **First command in a fresh worktree:** `cd rldb && $G --headless --path . --import`. It builds the `.godot` cache and
  registers new `class_name`s; rerun it after adding one.
- Tests: gdUnit4 under `rldb/tests/`. Full suite (from `rldb/`):
  `$G --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`.
  Never use `-d` (the debugger hangs on script errors). For one suite, use `-a res://tests/unit/rules/xyz_test.gd`.
  **Check the process exit code, not only the summary line.**
- **Baseline:** about 50 older tests fail on HEAD because they pin pre-3-Nov card values. The list is in the MAIN tree at
  `C:/Users/fergm/Documents/code/RLDB/production/l-batch-baseline-failures.txt` (absolute path; it appears a few
  minutes after you start, so read it before your final suite run), and a dedicated tests agent is fixing them. Do not "fix" those yourself
  unless your item changes the same behaviour. Your rule: **add no new failures**. A failing test outside the baseline
  list is yours to explain or fix.
- Naming: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`, arrange/act/assert.
- **Every bug fix needs a regression test that you watched fail first**: revert the fix temporarily, see red, restore,
  see green.
- **Never use `git stash`.** The stash stack is shared by every worktree and agent.
- Two agents running net tests at once clash on ENet port 24721. If a net test flakes, rerun it alone.
- Card behaviour is scripted per card ID in `rldb/src/core/card_scripts.gd`. Card text comes from
  `rldb/data/cards.json`, which `tools/import_cards.py` generates from the pinned CSV. Never hand-edit `cards.json`:
  change the importer (`TEXT_CORRECTIONS` etc.), rerun it, and run the importer's tests:
  `python -I -X utf8 -m unittest discover -s tools/tests -p "test_import_cards.py"`.
- The engine is deterministic and host-authoritative. `MatchEngine`, `GameCore` and `EffectEngine` live in `src/core`.
  The UI reads only `match_view.gd` (a per-seat redacted view) and sends commands. Hidden information must never leak
  into a seat's view, the log, a sound, telemetry or the network.
- Online play: `src/net/net_session.gd`. Commands from a remote client are sanitised (`_STR_FIELDS` / `_INT_FIELDS`), so
  a new command field must be added there.
- UI style: `src/ui/ui_style.gd` (UIStyle: colours, fonts, `button`, `label`, panels) and
  `src/ui/widgets/ui_surface.gd` (baked materials). Reuse them. Use HousePanel / OrnatePanel for frames, JuicyButton for
  buttons, and `Sfx.play(name)` for sounds. Respect `UIStyle.reduce_motion`. Fonts: Cinzel for titles, Alegreya Sans for
  body.
- **Sounds:** every cue name the batch needs is already registered in `Sfx.NAMES` (`src/ui/audio/sfx.gd`, block "L
  batch"), and the audio agent is generating the files. Call `Sfx.play("<name>")` at your events using those names. A
  name with no file yet is silent, which is fine. If you need a cue that is not in the list, use the closest one and
  report it under "Sounds wanted". Do not edit the `NAMES` list yourself (it would conflict).
  `tests/unit/ui/sfx_test.gd::test_all_named_sounds_have_assets` is red until the audio merge.
- Windowed screenshot drivers live in `rldb/src/dev/`. They open a real window, so run them without `--headless`. For
  example: `$G --path . -- --f04-series-shots=<outdir> --no-steam`, `$G --path . -- --f02-shots=<outdir>`,
  `-- --bot-shots=<outdir>`, `-s res://src/dev/card_redesign_shots.gd -- <outdir> 1600x1000`. Extend one, or write your
  own driver for your screens. Hover checks can flake when the real mouse is over the window; rerun them.
- **UI and visual work needs retained screenshots** (before and after) in
  `production/qa/evidence/2026-11-05-l-batch/<your-area>/`. Save them as JPG at quality 88, at most 1600 px wide (PNG
  made `.git` balloon once). Look at them yourself with the Read tool and judge them critically. Iterate until they
  look excellent.
- Use your own scratch subfolder (e.g. `<scratchpad>/<your-area>/`) so agents never clash on file names.
- File edits: keep each file's existing line endings (CRLF vs LF). In Python use
  `open(p, encoding='utf-8', newline='')`. Long scripts go in a temp file, not in a bash heredoc that contains quotes.
- Automated runs must use the TEST paths for user files (DeckStore, PlayerStats, SeriesStore, settings). The owner's
  decks were once wiped by a test.
- In UI motion, use one-shot `process_frame.connect(..., CONNECT_ONE_SHOT)` or tweens, not a suspended
  `await process_frame` on nodes that can be freed (that once crashed the suite at exit).

## Hard rules
- **Never push. Never export a build** (the integrator exports). Never run or kill the owner's RLDB.exe.
- Commit on your branch, one commit per feedback item (or tight group), in Conventional Commits: `feat(ui): ...`,
  `fix(rules): ...`. The body references `Story: design/owner-feedback-2026-11-05.md L<n>`. End every commit message
  with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit only your own files
  (`git add <paths>`), never `git add -A`. **Commit as you finish each item**; do not pile up uncommitted work.
- Stay inside your file-ownership list. If you must touch a file another agent owns, keep the hunk small and
  self-contained, and list it in your report under "Shared files touched".
- Do not edit `design/owner-feedback-2026-11-05.md` (the integrator maintains it).
- Firebase: Spark plan only. Never enable billing. Never put service-account keys, Admin SDK credentials, refresh
  tokens or API keys in checked-in files or logs.
- Privacy: never collect or store chat text, Steam persona names, raw Steam IDs or device fingerprints.
- Before finishing: run the **full suite** on your branch. No failures outside the baseline list (minus those you
  fixed). Also run the importer tests if you touched the importer.

## Final report (your last message)
1. Commits (hash + subject).
2. What you built, with the files.
3. Tests added (and which ones you watched fail first).
4. Screenshot paths you looked at.
5. Decisions you took (for owner review), and Deviations (where you beat the owner's suggestion).
6. Extra improvements, Shared files touched, Sounds wanted.
7. Anything blocked or worked around, and anything left over.
