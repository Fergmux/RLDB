# Adversarial QA — playtest feedback 02 (commit ace0329)

Date: 2026-10-15 · Reporter: qa-lead (agent) · Build: `build/rldb-game` @ ace0329 plus the uncommitted working tree at run time (including the coordinator's `game_screen.gd` patch)
Scope: F02-01..15 changes in `rldb/src/core/*`, `rldb/src/ui/game_screen.gd`, `rldb/src/net/net_session.gd`. Confirmed rules (`design/decision-register-answers.md`) are the oracle.

## New test files (tests/ only; no src/ edits)

- `rldb/tests/integration/qa/qa_f02_test.gd`: rules and engine (14 tests)
- `rldb/tests/integration/qa/qa_f02_ui_test.gd`: headless GameScreen + LocalHost (5 tests)
- `rldb/tests/integration/qa/qa_net_f02_test.gd`: two NetSessions over real ENet (4 tests)

Full suite (`-a res://tests`): **392 test cases, 0 errors, 6 failures, 0 orphans.** Every failure is a defect-exposing test listed below. No existing test regressed.

## Findings

### QA-F02-01 — S2: a stale ordered multi-selection carries into the next multi-select prompt (Plan B)

- **Test (fails now):** `qa_f02_ui_test.gd::test_plan_b_second_multi_prompt_starts_with_no_stale_selection` gives `gs.multi` = `[2, 1]` where `[]` was expected.
- **Repro:** The defender has 5 units and two set Plan B. The opponent attacks. The defender activates Plan B #1, clicks unit col 3 then col 2 and confirms. The destructions resolve in the clicked order, which is correct. The response window reopens. The defender activates Plan B #2. The new prompt opens with options 2 and 1 already selected, with order badges, and the Confirm button already enabled. One Enter destroys two units the player never chose in this prompt.
- **Root cause:** `GameScreen._on_view` only clears `multi` when `pending` is empty. `_confirm_multi` never clears it. Pending never becomes empty between the two prompts (multi-select, then trap_response, then multi-select), so the stale indices are reapplied to a different option list.
- **Fix direction:** clear `multi` when `pending.id` changes, or after `_confirm_multi` sends.

### QA-F02-02 — S3: the battle preview promises Mans Best Friend protection that fails when the Warrior cannot receive Eternal

- **Tests (fail now):**
  - `qa_f02_test.gd::test_preview_guarded_lone_warrior_matches_real_battle`: the preview says `t_dies=false`, but in the battle the target is destroyed.
  - `qa_f02_test.gd::test_preview_guarded_cursed_warrior_matches_real_battle`: same mismatch.
- **Repro 1:** P0 has The Lone Warrior (38, `no_buffs`) in Defense at slot 0 and Mans Best Friend (73) at slot 3. P1 attacks it with a 40-ATK unit. The preview shows "protected by Mans Best Friend" and a non-favourable verdict. In the real battle `_guardian_replacement` destroys MBF, `apply_status(eternal)` is refused because of `no_buffs`, and the Lone Warrior is destroyed too.
- **Repro 2:** Steadfast Soldier (39) with 1 Curse, guarded by MBF, attacked by a 20-ATK unit. The Curse absorbs the Eternal and both cards die.
- **Root cause:** `MatchEngine._battle_survives` treats a guard in the column as protection without checking whether Eternal can actually land (`no_buffs` flag, Curse > 0). This breaks the F02-12 requirement not to call an outcome by a simple label when an effect changes it. The preview here is also more optimistic than the battle: it under-reports the loss of two cards.

### QA-F02-03 — S3: a stance-summon validation oracle reveals hidden cards' identity

- **Tests (fail now):**
  - `qa_f02_test.gd::test_stance_probe_on_opponents_hidden_card_returns_generic_hand_error`
  - `qa_net_f02_test.gd::test_client_cannot_probe_host_hidden_hand_with_stance_summons`. Over ENet the client receives "This unit cannot be in Defense stance." for the host's hidden Mumen's Bounty and "Card is not in your Hand." for an ordinary hidden card.
- **Repro:** On your own turn, send `{"t":"summon","uid":<any opponent hand/draw/extra uid>,"stance":"def"}`. A modified client is needed (the UI never sends this). The two different replies tell the client whether that hidden uid is card 150.
- **Root cause:** `MatchEngine.validate` checks `stance` and `has_flag_raw(uid, "no_defense")` before the ownership and zone checks in the `summon`/`ritual`/`arcane` branches. Uids are random (1000..999999) but already enumerable through the existing "Unknown card." reply, so this adds a real identity leak.
- **Fix direction:** run the stance checks after each branch's owner and zone checks.

### Observations (not filed as defects)

- **Working tree briefly failed to compile during the run:** `src/ui/board/card_details.gd:318` called `PackedStringArray.filter`, and `card_widget.gd:328` referenced a missing `_draw_landscape`. These were concurrent uncommitted edits by another agent. Both were resolved by the time the full suite ran. Re-run the suite before committing those files.
- **Untested, worth a design check:** Plan B uses `n:"any"` (min 0), so Enter or Confirm with nothing selected commits the Trap with zero targets.

## Attacks that held (tests pass)

**Hidden information**
- The attack-target `preview` reaches only the chooser. It does not identify opponent hand cards or set Traps (engine view and raw ENet payloads checked for hidden uids).
- The no-target toast from a hidden-source effect is private to its controller. The opponent's log has no entry and no timing fx.
- Building the views never adds log entries or toasts.

**Rules integrity**
- `stance` is rejected on set/stance/sacrifice commands and for bad values (`1`, `"DEF"`, `""`, `null`, an array, an over-long string), both locally and through `sanitize_command`. A remote unknown field is rejected. No state changed.
- Stance summons still enforce AP and the Bahatia type lock (both stances).
- Ritual Defense still requires Runes, places the unit in Defense with no stance prompt and tributes the material.
- Arcane Defense exhausts its materials. Cancelling at material choice changes nothing.
- `battle_preview` leaves the full engine state byte-identical (cards, players, log, pending, stack, rng, queues). This was checked across 3 attackers × 5 targets, including Burn, Pierce, Eternal, Curse, MBF, a face-down card and Elemental Mastery.
- The preview matches the real battle (HP to each side, both destructions) in 12 cases:
  - type advantage, either side
  - stacked Elemental Mastery
  - Mastery on the defender's side
  - Pierce vs Defense
  - a no-battle-damage attacker
  - Burn on a losing attacker
  - an equal-ATK trade with an Eternal attacker
  - 30+ ATK immunity
  - a Defense stalemate
  - a guarded plain Warrior
  - a direct attack with Burn
- AP bookkeeping:
  - `ap_peak` follows gains, including the sacrifice refund.
  - Spending never lowers `ap_peak`.
  - Both fields reset to the real allowance on the next own turn.

**UI locks and sync**
- Plan B's ordered multi-pick through GameScreen destroys cards in the clicked order.
- Digits, Enter, Space and Tab on the opponent's prompt send nothing.
- Enter with the banner's Confirm focused sends exactly one command, with no error.
- A stale Summon click after the card left the Hand sends nothing.
- A stale Attack click while the opponent's trap prompt is pending sends nothing, and the action row is empty.
- Over ENet, a client Summon Defense pays once. The authority, the client's view and the host's view all agree on stance and AP.
