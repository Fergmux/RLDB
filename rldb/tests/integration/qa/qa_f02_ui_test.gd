extends GdUnitTestSuite
## Adversarial QA of playtest-feedback-02 interaction locks on the real GameScreen bound to a
## LocalHost seat: ordered multi-selection (Plan B), keyboard on the opponent's prompt,
## Enter with a focused button, stale action clicks.
## Report: production/qa/qa-f02-adversarial-2026-10-15.md

const PLAN_B := 163

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var first: int


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	first = m.active


func _attach(seat: int) -> void:
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[seat])
	gs.skip_effects()
	await await_idle_frame()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _opt(pd: Dictionary, text: String) -> int:
	for o in pd["options"]:
		if String(o["label"]).contains(text):
			return int(o["i"])
	return -1


func _opt_slot(pd: Dictionary, p: int, slot: int) -> int:
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == p and o["ref"]["zone"] == "unit" and o["ref"]["slot"] == slot:
			return int(o["i"])
	return -1


## Turn 2 Battle Phase for the second player; the first player (defender) holds two Plan B
## and three units; the attacker has declared an attack. Returns [attacker, defender units].
func _plan_b_board() -> Array:
	var d := first
	var a := 1 - first
	host.handle(d, {"t": "next_phase"})
	host.handle(d, {"t": "next_phase"})
	host.handle(a, {"t": "next_phase"})
	assert_str(m.phase).is_equal("battle")
	var us := [TB.unit(m, d, TB.WATER, 0), TB.unit(m, d, TB.FIRE, 1), TB.unit(m, d, TB.EARTH, 2),
		TB.unit(m, d, TB.WATER, 3), TB.unit(m, d, TB.WATER, 4)]
	m.players[d]["backrow"] = [-1, -1, -1]
	TB.set_card(m, d, PLAN_B, 0)
	TB.set_card(m, d, PLAN_B, 1)
	var att := TB.unit(m, a, TB.WATER, 0, "atk", 50)
	host.broadcast()
	return [att, us]


func test_plan_b_second_multi_prompt_starts_with_no_stale_selection() -> void:
	# Arrange: defender's screen; attacker declares an attack on the defender's slot 0 unit
	var board := _plan_b_board()
	var d := first
	await _attach(d)
	host.handle(1 - d, {"t": "attack", "uid": board[0]})
	var pd: Dictionary = MatchView.build(m, 1 - d)["pending"]
	host.handle(1 - d, {"t": "choose", "id": pd["id"], "indices": [_opt_slot(pd, d, 0)]})
	gs.skip_effects()
	await await_idle_frame()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	# Act 1: first Plan B, ordered picks slot 2 then slot 1, confirmed
	gs._pick_option(_opt(gs.pending(), "Plan B"))
	gs.skip_effects()
	await await_idle_frame()
	assert_int(int(gs.pending()["max"])).is_greater(1)
	gs._pick_option(_opt_slot(gs.pending(), d, 2))
	gs._pick_option(_opt_slot(gs.pending(), d, 1))
	gs._confirm_multi()
	gs.skip_effects()
	await await_idle_frame()
	# Assert 1: destruction followed the clicked order
	var i_earth := TB.log_index(m, "Basic Mage (Earth) is destroyed")
	var i_fire := TB.log_index(m, "Basic Mage (Fire) is destroyed")
	assert_int(i_earth).is_not_equal(-1)
	assert_int(i_fire).is_greater(i_earth)
	# Act 2: the window re-opens; activate the second Plan B
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var second := _opt(gs.pending(), "Plan B")
	assert_int(second).is_not_equal(-1)
	gs._pick_option(second)
	gs.skip_effects()
	await await_idle_frame()
	assert_int(int(gs.pending().get("max", 1))).is_greater(1)
	# Assert 2: the new prompt has nothing pre-selected from the first Plan B
	assert_array(gs.multi).is_empty()


func test_digits_and_enter_on_opponents_prompt_send_nothing() -> void:
	# Arrange: defender's screen while the attacker chooses a target
	var board := _plan_b_board()
	var d := first
	await _attach(d)
	host.handle(1 - d, {"t": "attack", "uid": board[0]})
	gs.skip_effects()
	await await_idle_frame()
	assert_bool(gs.pending()["mine"]).is_false()
	var sent := gs.debug_sent
	var pid: int = m.pending["id"]
	# Act
	for code in [KEY_1, KEY_2, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB]:
		gs._input(_key(code))
		gs._unhandled_input(_key(code))
	# Assert
	assert_int(gs.debug_sent).is_equal(sent)
	assert_int(m.pending["id"]).is_equal(pid)


func test_enter_with_focused_confirm_sends_one_command() -> void:
	# Arrange: defender in Plan B's multi prompt with one pick and the Confirm button focused
	var board := _plan_b_board()
	var d := first
	await _attach(d)
	host.handle(1 - d, {"t": "attack", "uid": board[0]})
	var pd: Dictionary = MatchView.build(m, 1 - d)["pending"]
	host.handle(1 - d, {"t": "choose", "id": pd["id"], "indices": [_opt_slot(pd, d, 0)]})
	gs.skip_effects()
	await await_idle_frame()
	gs._pick_option(_opt(gs.pending(), "Plan B"))
	gs.skip_effects()
	await await_idle_frame()
	gs._pick_option(_opt_slot(gs.pending(), d, 2))
	gs.skip_effects()
	await await_idle_frame()
	var confirm: Button = null
	for b in gs.banner_btns.get_children():
		if (b as Button).text.begins_with("Confirm"):
			confirm = b
	assert_object(confirm).is_not_null()
	confirm.grab_focus()
	var sent := gs.debug_sent
	var errs := []
	host.seats[d].status_changed.connect(func(t): errs.append(t))
	# Act
	get_viewport().push_input(_key(KEY_ENTER))
	gs.skip_effects()
	await await_idle_frame()
	# Assert
	assert_int(gs.debug_sent).is_equal(sent + 1)
	assert_array(errs.filter(func(t): return t != "")).is_empty()


func test_stale_summon_click_after_card_left_hand_sends_nothing() -> void:
	# Arrange: own turn, a hand unit selected with its action row open
	await _attach(first)
	var uid := TB.card(m, first, TB.WATER)
	m.players[first]["ap"] = 5
	host.broadcast()
	gs.skip_effects()
	await await_idle_frame()
	gs._select(uid)
	gs.skip_effects()
	await await_idle_frame()
	var acts: Array = gs._actions_for_card(uid)
	assert_int(acts.size()).is_equal(2)
	# Act: the card leaves the Hand before the click lands
	m.players[first]["hand"].erase(uid)
	m.cards[uid]["zone"] = "spent"
	m.players[first]["spent"].append(uid)
	host.broadcast()
	gs.skip_effects()
	await await_idle_frame()
	var sent := gs.debug_sent
	gs._run_action(uid, acts[0])
	# Assert
	assert_int(gs.debug_sent).is_equal(sent)
	assert_str(m.cards[uid]["zone"]).is_equal("spent")


func test_stale_click_while_opponent_prompt_pending_sends_nothing() -> void:
	# Arrange: attacker's screen selects its unit, then its attack opens the defender's trap prompt
	var board := _plan_b_board()
	var a := 1 - first
	await _attach(a)
	gs._select(board[0])
	gs.skip_effects()
	await await_idle_frame()
	var acts: Array = gs._actions_for_card(board[0])
	var atk: Array = acts.filter(func(x): return x["t"] == "attack")
	assert_int(atk.size()).is_equal(1)
	host.handle(a, {"t": "attack", "uid": board[0]})
	var pd: Dictionary = MatchView.build(m, a)["pending"]
	host.handle(a, {"t": "choose", "id": pd["id"], "indices": [_opt_slot(pd, first, 0)]})
	gs.skip_effects()
	await await_idle_frame()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var sent := gs.debug_sent
	# Act
	gs._run_action(board[0], atk[0])
	# Assert
	assert_int(gs.debug_sent).is_equal(sent)
	assert_array(gs._actions_for_card(board[0])).is_empty()
