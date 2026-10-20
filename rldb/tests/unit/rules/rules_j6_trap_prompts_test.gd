extends GdUnitTestSuite
## J6 (owner feedback 2026-10-22): each seat's Trap response prompts. "eligible" (the engine default:
## P-27, asked only when a Trap can respond), "always" (the player's toggle on: asked whenever they
## hold a face-down card set before this turn, so the prompt never shows whether a Trap can respond)
## and "off" (never asked). The setting is the seat's own: never logged, never in the opponent's view.

const DAMAGE_CONVERSION := 47      # Trap: an attack on one of your units in this column
const FACE_DOWN_SPELL := 83        # a Spell: set face-down it can never respond
const ATTACKER := 1
const DEFENDER := 0


## Player 1's Battle Phase: an attacker, and player 0's sturdy Defense unit in column 1 with
## `set_id` set face-down (on an earlier turn) in that column, or nothing when set_id is -1.
func _board(set_id: int, mode: String = "") -> Dictionary:
	var m := TB.make()
	TB.p1_battle(m)
	var a := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	var card := TB.set_card(m, DEFENDER, set_id, 0) if set_id != -1 else -1
	if mode != "":
		assert_str(m.submit(DEFENDER, {"t": "trap_prompts", "mode": mode})).is_empty()
	return {"m": m, "a": a, "wall": wall, "card": card}


## The attacker's view of the pending choice (what the opponent of the responder sees).
func _opp_wait(m: MatchEngine) -> Dictionary:
	return MatchView.build(m, ATTACKER).get("pending", {})


func test_default_mode_asks_only_with_an_eligible_trap() -> void:
	var b := _board(FACE_DOWN_SPELL)
	var m: MatchEngine = b["m"]
	assert_str(m.trap_prompt_mode(DEFENDER)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)
	TB.attack(m, b["a"], b["wall"])
	assert_bool(m.pending.is_empty()).is_true()            # P-27 unchanged for bots and tests


func test_prompts_on_ask_with_a_face_down_card_that_cannot_respond() -> void:
	var b := _board(FACE_DOWN_SPELL, EffectEngine.TRAP_PROMPT_ALWAYS)
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a"], b["wall"])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var labels: Array = m.pending["options"].map(func(o): return String(o["label"]))
	assert_array(labels).is_equal([EffectEngine.TRAP_SKIP_NONE, EffectEngine.TRAP_PASS_TURN])
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()


func test_the_opponent_sees_the_same_wait_with_or_without_a_usable_trap() -> void:
	var dummy := _board(FACE_DOWN_SPELL, EffectEngine.TRAP_PROMPT_ALWAYS)
	var real := _board(DAMAGE_CONVERSION, EffectEngine.TRAP_PROMPT_ALWAYS)
	TB.attack(dummy["m"], dummy["a"], dummy["wall"])
	TB.attack(real["m"], real["a"], real["wall"])
	var w1 := _opp_wait(dummy["m"])
	var w2 := _opp_wait(real["m"])
	assert_bool(w1.is_empty()).is_false()
	assert_array(w1.keys()).contains_exactly_in_any_order(w2.keys())
	for k in w1:
		if k != "id":
			assert_str(str(w1[k])).override_failure_message("pending view key %s differs" % k).is_equal(str(w2[k]))


func test_prompts_on_never_ask_without_a_face_down_card() -> void:
	var b := _board(-1, EffectEngine.TRAP_PROMPT_ALWAYS)
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a"], b["wall"])
	assert_bool(m.pending.is_empty()).is_true()            # the empty back row is public anyway


func test_prompts_on_ignore_a_card_set_this_turn() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var a := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	var c := TB.set_card(m, DEFENDER, FACE_DOWN_SPELL, 0)
	m.cards[c]["set_turn"] = m.turn                        # set this turn: no Trap could respond yet
	m.submit(DEFENDER, {"t": "trap_prompts", "mode": EffectEngine.TRAP_PROMPT_ALWAYS})
	TB.attack(m, a, wall)
	assert_bool(m.pending.is_empty()).is_true()


func test_prompts_off_never_ask_and_the_trap_stays_down() -> void:
	var b := _board(DAMAGE_CONVERSION, EffectEngine.TRAP_PROMPT_OFF)
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a"], b["wall"])
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(String(m.cards[b["card"]]["zone"])).is_equal("backrow")
	assert_bool(m.is_face_up(b["card"])).is_false()


func test_turning_prompts_off_answers_an_open_prompt_with_skip() -> void:
	var b := _board(DAMAGE_CONVERSION, EffectEngine.TRAP_PROMPT_ALWAYS)
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a"], b["wall"])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_str(m.submit(DEFENDER, {"t": "trap_prompts", "mode": EffectEngine.TRAP_PROMPT_OFF})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()            # the host never waits on it
	assert_int(int(m.cards[b["a"]]["attacked_turn"])).is_equal(m.turn)
	assert_bool(m.passing_traps(DEFENDER)).is_false()


func test_either_seat_may_change_its_setting_at_any_time() -> void:
	var b := _board(DAMAGE_CONVERSION)
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a"], b["wall"])                        # the defender's prompt is open
	assert_str(m.submit(ATTACKER, {"t": "trap_prompts", "mode": EffectEngine.TRAP_PROMPT_OFF})).is_empty()
	assert_str(m.trap_prompt_mode(ATTACKER)).is_equal(EffectEngine.TRAP_PROMPT_OFF)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")  # someone else's setting changes nothing here


func test_setting_is_own_seat_only_and_never_logged() -> void:
	var b := _board(-1)
	var m: MatchEngine = b["m"]
	var log_n := m.log_entries.size()
	m.submit(DEFENDER, {"t": "trap_prompts", "mode": EffectEngine.TRAP_PROMPT_OFF})
	assert_int(m.log_entries.size()).is_equal(log_n)
	assert_str(String(MatchView.build(m, DEFENDER)["players"][DEFENDER].get("trap_prompts", ""))).is_equal(EffectEngine.TRAP_PROMPT_OFF)
	assert_bool(MatchView.build(m, ATTACKER)["players"][DEFENDER].has("trap_prompts")).is_false()


func test_an_unknown_setting_is_refused() -> void:
	var m := TB.make()
	assert_str(m.submit(0, {"t": "trap_prompts", "mode": "sometimes"})).is_not_empty()
	assert_str(m.trap_prompt_mode(0)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)


func test_remote_clients_may_send_the_setting() -> void:
	assert_str(NetSession.sanitize_command({"t": "trap_prompts", "mode": "off"})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "trap_prompts", "mode": 3})).is_not_empty()


func test_pool_plausibility_uses_the_event_only() -> void:
	var m := TB.make()
	# No Trap answers the destruction of the opponent's own unit.
	assert_bool(m.trap_window_plausible(0, {"name": "destroyed", "ctl": 1, "cause": "battle"}, [0])).is_false()
	# Some Trap answers an attack on a unit, in any column.
	assert_bool(m.trap_window_plausible(0, {"name": "attack", "player": 1, "target": 5, "column": 2}, [0])).is_true()
	# Nothing answers your own attack.
	assert_bool(m.trap_window_plausible(0, {"name": "attack", "player": 0, "target": 5, "column": 0}, [0])).is_false()


func test_series_keeps_the_seat_setting_for_every_new_game() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 3})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	assert_str(s.submit(1, {"t": "trap_prompts", "mode": EffectEngine.TRAP_PROMPT_ALWAYS})).is_empty()
	assert_str(s.game.trap_prompt_mode(1)).is_equal(EffectEngine.TRAP_PROMPT_ALWAYS)
	s._start_game()                                        # the next duel of the series
	assert_str(s.game.trap_prompt_mode(1)).is_equal(EffectEngine.TRAP_PROMPT_ALWAYS)
	assert_str(s.game.trap_prompt_mode(0)).is_equal(EffectEngine.TRAP_PROMPT_ELIGIBLE)
