extends GdUnitTestSuite
## K4 (owner feedback 2026-10-23): "When a unit declares an attack and is waiting for trap activation, it
## shouldn't play the attack animation until the trap has resolved."
##
## The declaration and the Trap prompt arrive in one view; the battle (or the Trap that stops it) arrives
## in the view after the prompt is answered. The strike (lunge, its sounds) must play with the battle, in
## whichever batch the battle resolves, and never when the Trap stopped the attack. Every case is read
## from the real rules engine, for both seats (each one's redacted log, as online).

const DAMAGE_CONVERSION := 47   # Trap: an attack on one of your units in this column; the attack goes on
const MIRROR_FORCE := 46        # Trap: destroys every opposing ATK-stance unit (opponent controls 4+ cards)
const RUSHED_RECKLESSLY := 51             # Trap: any attack (also a direct one); +8 DEF to your units in this column
const ATTACKER := 1
const DEFENDER := 0
const STRIKES := ["attack", "direct", "lethal"]


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _since(m: MatchEngine) -> int:
	return int(m.log_entries[-1]["seq"])


## The fx events seat `viewer` receives after log seq `since`, tagged the way GameScreen tags them.
func _batch(m: MatchEngine, viewer: int, since: int) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer, since):
		var via := FxStrike.hp_cause(String(row["text"]))
		for f in row["fx"]:
			var g: Dictionary = (f as Dictionary).duplicate()
			if via != "" and String(g["k"]) == "hp":
				g["via"] = via
			out.append(g)
	return out


## The tags FxPlayer schedules for `events` (empty for an empty batch).
func _tags(gs: GameScreen, events: Array) -> Array:
	if events.is_empty():
		return []
	gs.fx.play(events, {})
	var tags: Array = gs.fx.last_plan.map(func(s): return String(s["tag"]))
	gs.fx.finish_all()
	return tags


func _strikes(tags: Array) -> int:
	return tags.filter(func(t): return t in STRIKES).size()


func _sounds(tags: Array, name: String) -> int:
	return tags.filter(func(t): return t == "sfx:" + name).size()


## Player 1's Battle Phase: an attacker and player 0's sturdy Defense unit with `trap` set in its column.
func _board(trap: int = DAMAGE_CONVERSION) -> Dictionary:
	var m := TB.make()
	TB.p1_battle(m)
	var a1 := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	var a2 := TB.unit(m, ATTACKER, TB.WATER, 1, "atk", 10, 10)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	var t := TB.set_card(m, DEFENDER, trap, 0)
	return {"m": m, "a1": a1, "a2": a2, "wall": wall, "trap": t}


func test_attack_waiting_on_a_trap_prompt_plays_no_strike_on_either_screen() -> void:
	# Arrange
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	var since := _since(m)
	# Act: the declaration opens the defender's Trap window
	assert_str(TB.attack(m, b["a1"], b["wall"])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	# Assert: neither seat sees the lunge or hears the attack yet; the attacker is marked as declaring
	for viewer in [ATTACKER, DEFENDER]:
		var tags := _tags(gs, _batch(m, viewer, since))
		assert_int(_strikes(tags)).override_failure_message("seat %d: strike before the Trap prompt %s" % [viewer, tags]).is_equal(0)
		assert_int(_sounds(tags, "attack")).is_equal(0)
		assert_int(_sounds(tags, "impact")).is_equal(0)
		assert_bool(tags.has("declare")).is_true()


func test_skipped_trap_plays_the_strike_once_after_the_prompt_closes() -> void:
	# Arrange
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	var since := _since(m)
	# Act: the defender skips
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	# Assert: the strike and its sounds play now, once, on both screens
	for viewer in [ATTACKER, DEFENDER]:
		var tags := _tags(gs, _batch(m, viewer, since))
		assert_int(_strikes(tags)).override_failure_message("seat %d: %s" % [viewer, tags]).is_equal(1)
		assert_int(_sounds(tags, "attack")).is_equal(1)
		assert_int(_sounds(tags, "impact")).is_equal(1)


func test_trap_that_destroys_the_attacker_cancels_the_strike() -> void:
	# Arrange: the attacker's side controls four cards, so Mirror Force can respond
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	TB.p1_battle(m)
	var att := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	for s in [1, 2, 3]:
		TB.unit(m, ATTACKER, TB.WATER, s, "atk", 10, 10)
	var wall := TB.unit(m, DEFENDER, TB.WATER, 0, "def", 5, 40)
	TB.set_card(m, DEFENDER, MIRROR_FORCE, 1)
	var since0 := _since(m)
	assert_str(TB.attack(m, att, wall)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var declared := {}
	for viewer in [ATTACKER, DEFENDER]:
		declared[viewer] = _batch(m, viewer, since0)
	var since := _since(m)
	# Act: the defender activates the Trap; every attacking-side unit is destroyed
	assert_str(TB.choose(m, ["Activate"])).is_empty()
	while TB.pend_kind(m) == "trap_response":
		TB.choose(m, ["Skip"])
	assert_str(String(m.cards[att]["zone"])).is_not_equal("unit")
	assert_str(TB.log_text(m)).contains("does not resolve")
	# Assert: no seat ever sees a strike, in either batch; the destructions do play
	for viewer in [ATTACKER, DEFENDER]:
		var first := _tags(gs, declared[viewer])
		var after := _tags(gs, _batch(m, viewer, since))
		assert_int(_strikes(first) + _strikes(after)).override_failure_message("seat %d: %s / %s" % [viewer, first, after]).is_equal(0)
		assert_int(_sounds(after, "attack")).is_equal(0)
		assert_bool(after.any(func(t): return String(t).begins_with("destroy:1:"))).is_true()


func test_skip_for_the_rest_of_the_turn_strikes_the_next_attack_at_once() -> void:
	# Arrange: the first attack's window is passed for the turn
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	var since1 := _since(m)
	assert_str(TB.choose(m, ["Skip for the rest of this turn"])).is_empty()
	var first := _tags(gs, _batch(m, ATTACKER, since1))
	var since := _since(m)
	# Act: the second attack opens no window and resolves in the same view
	assert_str(TB.attack(m, b["a2"], b["wall"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	# Assert: the first attack struck when its window closed; the second strikes at once, no declaring cue
	assert_int(_strikes(first)).is_equal(1)
	for viewer in [ATTACKER, DEFENDER]:
		var tags := _tags(gs, _batch(m, viewer, since))
		assert_int(_strikes(tags)).is_equal(1)
		assert_int(_sounds(tags, "attack")).is_equal(1)
		assert_bool(tags.has("declare")).is_false()


func test_bot_defender_answer_plays_the_strike_after_its_choice() -> void:
	# Arrange: the bot defends
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	var bot := BotBrain.new(DEFENDER, 3)
	var since0 := _since(m)
	TB.attack(m, b["a1"], b["wall"])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var first := _tags(gs, _batch(m, ATTACKER, since0))
	var since := _since(m)
	# Act: the bot answers its prompt (Damage Conversion lets the attack go on either way)
	var cmd := bot.decide(m)
	assert_dict(cmd).is_not_empty()
	assert_str(m.submit(DEFENDER, cmd)).is_empty()
	while TB.pend_kind(m) == "trap_response":
		m.submit(int(m.pending["player"]), bot.choose(m, 0) if int(m.pending["player"]) == DEFENDER else {"t": "choose", "id": m.pending["id"], "values": [EffectEngine.TRAP_V_SKIP]})
	# Assert: nothing struck before the bot chose; the strike plays once after
	assert_int(_strikes(first)).is_equal(0)
	assert_int(_strikes(_tags(gs, _batch(m, ATTACKER, since)))).is_equal(1)


func test_direct_attack_waits_for_the_trap_prompt_too() -> void:
	# Arrange: the defender has no unit and a Trap that answers any attack
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	TB.p1_battle(m)
	var att := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 10, 10)
	TB.set_card(m, DEFENDER, RUSHED_RECKLESSLY, 0)
	var since0 := _since(m)
	assert_str(TB.attack(m, att, -1)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var first := _tags(gs, _batch(m, DEFENDER, since0))
	var since := _since(m)
	# Act
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	# Assert: the direct strike (and its damage) plays only after the prompt
	assert_int(_strikes(first)).is_equal(0)
	var tags := _tags(gs, _batch(m, DEFENDER, since))
	assert_bool(tags.has("direct")).override_failure_message(str(tags)).is_true()
	assert_int(_sounds(tags, "attack")).is_equal(1)


func test_killing_blow_after_a_trap_prompt_plays_once_after_it() -> void:
	# Arrange: a direct attack for more than the defender's HP, into a Trap window
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	TB.p1_battle(m)
	var att := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 30, 10)
	TB.set_card(m, DEFENDER, RUSHED_RECKLESSLY, 0)
	m.players[DEFENDER]["hp"] = 12
	var since0 := _since(m)
	assert_str(TB.attack(m, att, -1)).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var declared := {}
	for viewer in [ATTACKER, DEFENDER]:
		declared[viewer] = _batch(m, viewer, since0)
	var since := _since(m)
	# Act
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	# Assert: the game ends with this attack; the slow-motion killing blow plays after the prompt only
	assert_int(m.winner).is_equal(ATTACKER)
	for viewer in [ATTACKER, DEFENDER]:
		var first := _tags(gs, declared[viewer])
		var after := _tags(gs, _batch(m, viewer, since))
		assert_int(_strikes(first)).override_failure_message("seat %d: %s" % [viewer, first]).is_equal(0)
		assert_int(after.count("lethal")).override_failure_message("seat %d: %s" % [viewer, after]).is_equal(1)
		assert_int(_strikes(after)).is_equal(1)


func test_zero_damage_direct_attack_still_strikes_when_it_resolves() -> void:
	# Arrange: a 0 ATK attacker deals no damage, so the battle writes no log line of its own
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	TB.p1_battle(m)
	var att := TB.unit(m, ATTACKER, TB.WATER, 0, "atk", 0, 10)
	TB.set_card(m, DEFENDER, RUSHED_RECKLESSLY, 0)
	assert_str(TB.attack(m, att, -1)).is_empty()
	var since := _since(m)
	var hp: int = m.players[DEFENDER]["hp"]
	# Act
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	# Assert: the strike still plays, on both screens, and nothing else changed
	assert_int(m.players[DEFENDER]["hp"]).is_equal(hp)
	for viewer in [ATTACKER, DEFENDER]:
		var tags := _tags(gs, _batch(m, viewer, since))
		assert_bool(tags.has("direct")).override_failure_message("seat %d: %s" % [viewer, tags]).is_true()


func test_hot_seat_hand_over_waits_for_the_strike_after_a_trap_prompt() -> void:
	# Arrange: hot-seat play hands the screen back to the attacker as soon as the defender has answered;
	# the hand-over (SessionLauncher._check_hotseat) waits for GameScreen.fx_hold_until
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	TB.attack(m, b["a1"], b["wall"])
	var since := _since(m)
	assert_str(TB.choose(m, ["Skip"])).is_empty()
	gs.fx_hold_until = 0
	var now := Time.get_ticks_msec()
	# Act: the defender's screen plays the batch with the strike
	gs.fx.play(_batch(m, DEFENDER, since), {})
	var strike_at := -1.0
	for s in gs.fx.last_plan:
		if String(s["tag"]) in STRIKES:
			strike_at = float(s["t"])
	gs.fx.finish_all()
	# Assert: the screen is held until the strike has landed and settled
	assert_float(strike_at).is_greater_equal(0.0)
	assert_int(gs.fx_hold_until - now).is_greater_equal(int((strike_at + FxPlayer.HANDOVER_TAIL * UIStyle.dur(1.0)) * 1000.0))


func test_batch_without_a_strike_or_spotlight_does_not_hold_the_hand_over() -> void:
	# Arrange: the declaration only (the attacker's screen hands over to the defender's prompt at once)
	var gs := _screen()
	await await_idle_frame()
	var b := _board()
	var m: MatchEngine = b["m"]
	var since := _since(m)
	TB.attack(m, b["a1"], b["wall"])
	gs.fx_hold_until = 0
	# Act
	gs.fx.play(_batch(m, ATTACKER, since), {})
	gs.fx.finish_all()
	# Assert
	assert_int(gs.fx_hold_until).is_equal(0)


func test_hot_seat_hand_over_waits_for_a_trap_spotlight() -> void:
	# Arrange
	var gs := _screen()
	await await_idle_frame()
	gs.fx_hold_until = 0
	var now := Time.get_ticks_msec()
	# Act
	gs.fx.play([{"k": "spotlight", "p": DEFENDER, "id": MIRROR_FORCE, "how": "trap"}], {})
	gs.fx.finish_all()
	# Assert: the Trap is shown in full (and its cue heard) before the screen changes hands
	assert_int(gs.fx_hold_until - now).is_greater_equal(int(FxSpotlight.HOLD * UIStyle.dur(1.0) * 1000.0))
