extends GdUnitTestSuite
## L4 (owner feedback 2026-11-05): "attacking with a unit again quickly after attacking with a unit
## cancels the first animation, we should queue them instead over cancelling/overwriting, this should
## be the case for all animations".
##
## On the real GameScreen bound to a local host: a view that arrives while an earlier one's effects
## still play waits (FxPlayer.views) and is shown, with its effects, once they are done; clicks never
## cut an animation short; the board never runs ahead of what has been animated; a backlog plays a
## little faster; a reattached seat or a new game clears the queue.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var a: int
var o: int
var was_seq: bool
var was_rm: bool


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	was_seq = FxPlayer.sequence_views
	was_rm = UIStyle.reduce_motion
	FxPlayer.sequence_views = true
	UIStyle.reduce_motion = false
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	TB.to_battle(m)
	a = m.active
	o = 1 - a
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	GameScreen._coin_shown[String(host.series.view_for(a).get("save_id", "local"))] = true
	await gs.attach(host.seats[a])
	await await_idle_frame()


func after_test() -> void:
	FxPlayer.sequence_views = was_seq
	UIStyle.reduce_motion = was_rm


## Three attackers facing three sturdy Defense units, shown and settled.
func _board() -> Dictionary:
	var att := [TB.unit(m, a, 1, 0, "atk", 30, 30), TB.unit(m, a, 1, 1, "atk", 30, 30), TB.unit(m, a, 1, 2, "atk", 30, 30)]
	var dfn := [TB.unit(m, o, 1, 0, "def", 5, 35), TB.unit(m, o, 1, 1, "def", 5, 35), TB.unit(m, o, 1, 2, "def", 5, 35)]
	host.broadcast()
	gs.skip_effects()
	return {"att": att, "def": dfn}


func _attack(b: Dictionary, i: int) -> void:
	assert_str(TB.attack(m, b["att"][i], b["def"][i])).is_empty()
	host.broadcast()


func _shown_attacked(slot: int) -> bool:
	return bool(gs.pv(a)["units"][slot].get("attacked", false))


func _widget(slot: int) -> CardWidget:
	return gs.board.slot_item(a, "unit", slot)["widget"]


## Waits (frames) until the effects and the queue are done, at most `secs`.
func _settle(secs: float = 6.0) -> void:
	var t0 := Time.get_ticks_msec()
	while (gs.fx.gating() or not gs.fx.views.is_empty()) and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame


func test_a_second_attack_waits_for_the_first_to_play_out() -> void:
	# Arrange
	var b := _board()
	# Act: the first attack, a few frames into its lunge, then the second one at once.
	_attack(b, 0)
	for i in 4:
		await get_tree().process_frame
	_attack(b, 1)
	await get_tree().process_frame
	# Assert: the first lunge still runs; the second view waits and the board has not run ahead.
	assert_bool(gs.fx.gating()).is_true()
	assert_vector(_widget(0).fx_offset).is_not_equal(Vector2.ZERO)
	assert_int(gs.fx.views.size()).is_equal(1)
	assert_bool(_shown_attacked(0)).is_true()
	assert_bool(_shown_attacked(1)).is_false()
	# ...then it plays in its turn, after the first has settled back.
	await _settle()
	assert_bool(_shown_attacked(1)).is_true()
	assert_bool(gs.fx.last_plan.any(func(s): return String(s["tag"]) == "attack")).is_true()
	await _settle()
	assert_vector(_widget(0).fx_offset).is_equal(Vector2.ZERO)
	assert_vector(_widget(1).fx_offset).is_equal(Vector2.ZERO)


func test_a_click_never_cuts_an_animation_short() -> void:
	# Arrange
	var b := _board()
	_attack(b, 0)
	for i in 3:
		await get_tree().process_frame
	# Act: a left click anywhere, and a click on the next attacker card (selecting it).
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	gs._input(click)
	gs.selection.on_widget_pressed(_widget(1))
	gs.selection.on_widget_right(_widget(2))
	await get_tree().process_frame
	# Assert: the lunge is still in flight.
	assert_bool(gs.fx.gating()).is_true()
	assert_vector(_widget(0).fx_offset).is_not_equal(Vector2.ZERO)


func test_queued_views_are_shown_in_order_until_the_board_is_current() -> void:
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	_attack(b, 2)
	assert_int(gs.fx.views.size()).is_equal(2)
	var seen := []
	var t0 := Time.get_ticks_msec()
	while not gs.fx.views.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		var n := [_shown_attacked(0), _shown_attacked(1), _shown_attacked(2)].count(true)
		if seen.is_empty() or seen[-1] != n:
			seen.append(n)
		await get_tree().process_frame
	await _settle()
	seen.append([_shown_attacked(0), _shown_attacked(1), _shown_attacked(2)].count(true))
	assert_array(seen).is_equal([1, 2, 3])
	assert_dict(gs.mv).is_equal(host.series.view_for(a)["match"])


func test_a_backlog_plays_faster_and_the_last_batch_at_normal_speed() -> void:
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	_attack(b, 2)
	assert_float(gs.fx.speed).is_equal(1.0)          # nothing was waiting when the first started
	var speeds := []
	var t0 := Time.get_ticks_msec()
	while not gs.fx.views.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
		if speeds.is_empty() or speeds[-1] != gs.fx.speed:
			speeds.append(gs.fx.speed)
	assert_array(speeds).contains([FxViewQueue.speed_for(1)])
	await _settle()
	assert_float(gs.fx.speed).is_equal(1.0)


func test_reduced_motion_still_queues() -> void:
	UIStyle.reduce_motion = true
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	assert_int(gs.fx.views.size()).is_equal(1)
	assert_bool(_shown_attacked(1)).is_false()
	await _settle()
	assert_bool(_shown_attacked(1)).is_true()


func test_skip_effects_shows_everything_waiting_at_once() -> void:
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	gs.skip_effects()
	assert_bool(gs.fx.views.is_empty()).is_true()
	assert_bool(gs.fx.gating()).is_false()
	assert_bool(_shown_attacked(1)).is_true()


func test_reattaching_a_seat_clears_the_queue() -> void:
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	assert_int(gs.fx.views.size()).is_equal(1)
	await gs.attach(host.seats[a])
	assert_bool(gs.fx.views.is_empty()).is_true()
	assert_bool(_shown_attacked(1)).is_true()


func test_a_view_of_the_next_game_is_shown_at_once_and_clears_the_queue() -> void:
	# Arrange: an attack playing and one waiting, then the series moves on to game 2.
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	var nxt: Dictionary = host.series.view_for(a).duplicate(true)
	nxt["game_no"] = int(nxt.get("game_no", 1)) + 1
	# Act
	gs._on_view(nxt)
	# Assert
	assert_bool(gs.fx.views.is_empty()).is_true()
	assert_int(int(gs.view["game_no"])).is_equal(int(nxt["game_no"]))


func test_hot_seat_hand_over_waits_for_the_queue() -> void:
	var b := _board()
	_attack(b, 0)
	_attack(b, 1)
	await get_tree().process_frame
	assert_int(gs.fx_hold_until).is_greater(Time.get_ticks_msec())


## J9 with the queue: a killing blow that waits behind another attack still locks the board the moment
## it is made, and its kill then plays and holds the result back.
func test_a_queued_killing_blow_locks_the_board_at_once() -> void:
	# Arrange: an attack playing; the opponent at 5 HP with a weak Attack-stance unit.
	var b := _board()
	var weak: int = b["def"][1]
	m.cards[weak]["stance"] = "atk"
	m.cards[weak]["base_atk"] = 5
	m.cards[weak]["base_def"] = 5
	m.players[o]["hp"] = 5
	host.broadcast()
	gs.skip_effects()
	_attack(b, 0)
	# Act: the killing attack arrives while the first lunge plays.
	assert_str(TB.attack(m, b["att"][1], weak)).is_empty()
	host.broadcast()
	# Assert
	assert_int(m.winner).is_equal(a)
	assert_int(gs.fx.views.size()).is_equal(1)
	assert_bool(gs.game_ending()).is_true()
	gs.selection.on_widget_pressed(_widget(2))
	assert_int(gs.selected_uid).is_equal(-1)
	await _settle(8.0)
	assert_bool(gs.fx.views.is_empty()).is_true()
	assert_int(int(gs.mv.get("winner", -1))).is_equal(a)
