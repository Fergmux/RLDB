extends GdUnitTestSuite
## Owner feedback 2026-10-20 D13: a Trap response window offers Activate, Skip (this window only)
## and "Skip for the rest of this turn", after which the engine offers that player no Trap window
## until the turn ends.

const DAMAGE_CONVERSION := 47      # Trap: an opponent's unit in this column declares an attack (2026-11-03)
const ATTACKER := 1
const DEFENDER := 0


## Player 1's Battle Phase: two attackers, and player 0's sturdy Defense unit with Damage
## Conversion set in its column (it survives both attacks). Since 2026-11-03 the Trap answers an
## attacker in its own column, so both attackers stand in column 1 (front and back row).
func _board() -> Dictionary:
	var m := TB.make()
	TB.p1_battle(m)
	var a1 := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	var a2 := TB.unit(m, ATTACKER, TB.WATER, 3, "atk", 10, 10)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	var trap := TB.set_card(m, DEFENDER, DAMAGE_CONVERSION, 0)
	return {"m": m, "a1": a1, "a2": a2, "wall": wall, "trap": trap}


func _labels(m: MatchEngine) -> Array:
	return m.pending["options"].map(func(o): return String(o["label"]))


func test_window_offers_skip_pass_for_the_turn_and_activate() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	assert_str(TB.attack(m, b["a1"], b["wall"])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_array(_labels(m)).is_equal(["Skip", "Skip for the rest of this turn", "Activate Damage Conversion"])
	assert_int(int(m.pending["options"][0]["v"])).is_equal(EffectEngine.TRAP_V_SKIP)


func test_skip_declines_only_this_window() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(TB.attack(m, b["a2"], b["wall"])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")       # asked again for the next attack


func test_pass_for_the_turn_stops_every_later_window_this_turn() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	assert_str(TB.choose(m, ["Skip for the rest of this turn"])).is_empty()
	assert_bool(m.passing_traps(DEFENDER)).is_true()
	assert_str(TB.attack(m, b["a2"], b["wall"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()                    # no window: the attack resolved
	assert_int(int(m.cards[b["a2"]]["attacked_turn"])).is_equal(m.turn)
	assert_str(m.cards[b["trap"]]["zone"]).is_equal("backrow")    # the Trap was never used


func test_pass_for_the_turn_ends_with_the_turn() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	TB.choose(m, ["Skip for the rest of this turn"])
	m.submit(ATTACKER, {"t": "next_phase"})                       # Recovery
	m.submit(ATTACKER, {"t": "next_phase"})                       # end of turn 2
	assert_int(m.turn).is_equal(3)
	assert_bool(m.passing_traps(DEFENDER)).is_false()
	assert_int(int(m.players[DEFENDER]["trap_pass_turn"])).is_equal(-1)
	m.submit(DEFENDER, {"t": "next_phase"})
	m.submit(DEFENDER, {"t": "next_phase"})
	m.submit(DEFENDER, {"t": "next_phase"})                       # turn 4: player 1 again
	TB.to_battle(m)
	assert_str(TB.attack(m, b["a1"], b["wall"])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")       # offered again on a later turn


func test_the_flag_is_in_the_passing_players_view_only_and_logged_privately() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	TB.choose(m, ["Skip for the rest of this turn"])
	var own: Dictionary = MatchView.build(m, DEFENDER)["players"][DEFENDER]
	var theirs: Dictionary = MatchView.build(m, ATTACKER)["players"][DEFENDER]
	assert_bool(bool(own.get("trap_pass", false))).is_true()
	assert_bool(theirs.has("trap_pass")).is_false()
	assert_str(TB.log_text(m)).not_contains("rest of this turn")   # no public line
	var priv := m.log_entries.filter(func(e): return String(e["priv"].get(DEFENDER, "")).contains("rest of this turn"))
	assert_int(priv.size()).is_equal(1)


func test_hidden_window_variant_is_named_skip() -> void:
	var m := TB.make(7, 20, true)                                 # hidden response windows
	TB.p1_battle(m)
	var a1 := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	TB.unit(m, DEFENDER, TB.WATER, 2, "def", 5, 40)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	TB.set_card(m, DEFENDER, DAMAGE_CONVERSION, 2)                  # face down, wrong column
	TB.attack(m, a1, wall)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_array(_labels(m)).is_equal(["Skip (no Trap can respond)", "Skip for the rest of this turn"])


func test_remote_answer_by_index_passes_the_sanitiser() -> void:
	assert_str(NetSession.sanitize_command({"t": "choose", "id": 4, "indices": [1]})).is_empty()


func test_bot_never_passes_for_the_rest_of_the_turn() -> void:
	for sd in 8:
		var b := _board()
		var m: MatchEngine = b["m"]
		TB.attack(m, b["a1"], b["wall"])
		var cmd := BotBrain.new(DEFENDER, sd).decide(m)
		var v: int = int(m.pending["options"][int(cmd["indices"][0])]["v"])
		assert_int(v).override_failure_message("seed %d" % sd).is_not_equal(EffectEngine.TRAP_V_PASS_TURN)
