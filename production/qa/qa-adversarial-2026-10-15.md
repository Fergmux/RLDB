# Adversarial Network QA — 2026-10-15

**Scope:** two-client (real ENet localhost) play of RLDB on the host authority, Godot 4.6.1, branch `build/rldb-game` (HEAD 504116d plus the uncommitted working tree).
**Suites (new):** `rldb/tests/integration/qa/` (`qa_net_base.gd` harness plus 5 suites, 16 tests). Saves go to `user://test_saves`.
**Command:** `Godot_v4.6.1-stable_win64_console.exe --headless --path rldb -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/integration/qa --ignoreHeadlessMode -c`
**Result (final run):** 16 tests, **12 passed, 4 failed**. All 4 failures come from **2 product defects**. No test bug remains. gdUnit also counted 10 "errors": these are the host's GDScript runtime errors from defect D1.

## Scenario results

| # | Scenario | Test | Result |
|---|---|---|---|
| 1 | Plan B over the network. The host selects targets in a chosen order (Fire, then Earth). Shared Fate becomes eligible after the first destruction. Checks depth-first order, healing last (+20), that the client's merged log equals `log_for(m,1)`, and that the unselected face-down Magic Cylinder is never named or uid'd in client payloads | trap_chain › plan_b… | PASS |
| 7 | C-03/P-23: Magic Cylinder and Damage Conversion are silent on a direct attack (no prompt, -10 HP, traps stay face-down) | trap_chain › column_traps… | PASS |
| — | P-22 over the network: Shen's On Summon (Eternal) has resolved before the host's Alexander's Arrow prompt | trap_chain › on_summon… | PASS |
| 2 | Ordered trigger prompts on both sides (4 × Soul Devourer). The client answers out of order. Rejected as expected: stale id, out-of-range, -1, duplicate, too many, empty, string indices, `values`, and answers from the wrong seat. The P-24 window lets Energy Dispel negate the client's chosen trigger | choices › trigger_order… | PASS |
| 8 | Malformed client commands (wrong types) | choices › malformed… / each_malformed… | **FAIL — D1** |
| 3 | Into the Void reveals the host's Spent to the client while it chooses; nothing persists afterwards. The host's Arcane material choice (own Spent) and Kaya hand choice never reach client payloads | hidden › 2 tests | PASS |
| 4 | Reconnect during an optional start-of-turn trigger (Ritual Sanct), during the Arcane material multi-select (Tyde), and during the host's Plan B select (the host is blocked while paused). Each completes exactly once; replayed seq and stale id are ignored | reconnect › 3 tests | PASS |
| 5 | Save at the rewards checkpoint, tear down, resume from `SeriesStore` with a new host. An impostor token is refused. The same client token rebinds, and score, decks and rewards continue into game 2. A winner's `first_player` is refused | series › resumes… | PASS |
| 6 | Host claim: refused while the opponent is connected; refused before 60 s; after the wait it awards the current game only. The client returns and the series continues to game 2 | series › host_claim… | **FAIL — D2** (the rest of the flow passes) |
| 7 | C-04 fatigue ends a networked game (4 missed draws × 2 = 8 HP). The client sees the winner and the rewards stage | series › fatigue… | PASS |
| 8 | Concede during the opponent's pending trap prompt | series › concede… | **FAIL — D2** |
| 8 | Commands sent across stage transitions (game/deck/first-player commands during rewards, rewards after done, stale `first_player` after game 2 starts) | series › commands_across… | PASS |

## Product defects

### D1 — Malformed client commands raise host script errors and get no reply (S3, P2)
- **Category / System:** Network / command validation (`series.gd`, `match_engine.gd`). Frequency: Always. Regression: Unknown.
- **Repro:** start a network series and reach the client's turn. From the client, send any of:
  - `{"t": 5}`
  - `{"t":"attack","uid":[<uid>]}`
  - `{"t":"stance","uid":{"x":1}}`
  - `{"t":"choose","id":1,"indices":[{"a":1}]}`
- **Expected:** the host rejects the command with an error message to the client and records no runtime error.
- **Actual:** the host logs `SCRIPT ERROR` and the handler aborts mid-function. The client gets **no error reply**, so its UI waits with no feedback.
  - `series.gd:87`: `var t: String = cmd.get("t","")` with an int `t` gives "Trying to assign value of type 'int' to a variable of type 'String'".
  - `match_engine.gd:240` (`validate`) and `:380` (`_execute`): `int(cmd.get("uid"))` with an Array or Dictionary `uid` gives "Nonexistent 'int' constructor".
  - `match_engine.gd:225` (`_int_array`) has the same issue for non-numeric `indices` elements.
- **Mitigating:** game state was unchanged, `last_seq` advanced, and a following valid command still applied. A non-Dictionary `cmd` is dropped safely by Godot's RPC type check.
- **Suspected fix (programmer):** at `NetSession._c2s_command` / `Series.submit`, check the type of `t` (String), `uid`, `idx`, `id` (int/float) and every `indices` element (int/float) before dispatch, and return "Malformed command."
- **Tests:** `qa_net_choices_test.gd::test_malformed_client_commands_are_rejected_and_host_keeps_working` and `::test_each_malformed_command_gets_an_error_reply`.

### D2 — A game ended outside the resolution loop keeps its pending choice and effect stack (S3, P2)
- **Category / System:** Gameplay/Network. The defect is in game end (`game_core.gd` `end_game`, line ~549); `net_session.gd` claim and `match_engine.gd` concede are also involved. Frequency: Always.
- **Repro A (concede):** the client attacks into a host Magic Cylinder, so the host's `trap_response` prompt is pending. The client sends `{"t":"concede"}`.
- **Repro B (claim):** the client has its own `attack_target` prompt pending and disconnects. The host waits out `claim_wait_seconds` and sends `claim_game`. The client then reconnects.
- **Expected:** once `winner` is set, `pending` is empty, `stack` is empty, and neither view shows a prompt.
- **Actual:**
  - A: `m.pending` (`trap_response`) and 1 stack frame survive, and the host view still shows the prompt.
  - B: `m.pending` (`attack_target`) survives. On reconnect, the client view at stage `rewards` still carries `match.pending` with `mine: true`.
  - Answering is refused ("The game is over."), so no rules damage was found. The risk is a dead, live-looking prompt in the finished-game or rewards UI. The UI effect has not been observed (needs a screenshot pass).
- **Root cause:** `end_game` sets `winner` but only `run()` clears `pending`/`stack`/queues. `submit("concede")` and `Series.award_game` call `end_game` without `run()`.
- **Suggested fix:** clear `pending`, `stack`, `trigger_queue` and `window_queue` in `end_game`.
- **Tests:** `qa_net_series_test.gd::test_concede_during_opponent_trap_prompt_ends_game_without_stale_prompt` and `::test_host_claim_awards_current_game_only_then_client_returns_and_series_continues`.

## Test bugs found and fixed during this pass (not product defects)
1. The Plan B leak check matched "Magic Cylinder" in the **public starter-deck catalogue** sent during deck selection. Fixed by recording payloads only after setup.
2. The Kaya hand-choice test picked a Magic Cylinder that was already in the host's starter hand (Tide & Storm contains id 45). Fixed by using a hand card that is not in that deck (Into the Void).
3. The claim test expected "paused" for a second claim. `claim_game` correctly skips the pause gate and returns "There is no game in progress." Fixed the expectation.

## Risks observed but not proven (no failing test)
- **LAN resume token is keyed to the exact `host:port` string** (`NetSession._session_key`). A resumed LAN series always hosts on 24680 (`main.gd:526`). A client that types a different address string (e.g. `localhost` instead of `127.0.0.1`), or whose original series used another port, gets a new token and is refused for that saved series. The other player cannot recover. Needs a design decision.
- **A refused peer is never disconnected** (`_c2s_hello` returns without `disconnect_peer`). The ENet server allows 2 peers, so a lingering refused peer can occupy the slot the rightful client needs to reconnect. Not exercised under load.
- `SESSION_FILE` is a `const` in `user://`, so network tests write real client tokens. It is keyed by test port, so live saves are not affected.

## Coverage notes
- Bug files were not written to `production/qa/bugs/` because this run is limited to this report and `tests/integration/qa/`. Run `/bug-report` for D1 and D2 to file them.
- Release-checklist items (cert tier unset, stage Technical Setup) were out of scope for this pass. NOT ASSESSED.
