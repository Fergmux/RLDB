extends GdUnitTestSuite
## The duel HUD clock (C2): game and turn time counting up with an injected clock, turn changes,
## network pauses, the frozen final time, hot-seat seat switches sharing one clock, and the
## plaque's texts.

var now: Array = [10_000]


func before_test() -> void:
	DuelClock.clocks.clear()
	now[0] = 10_000


func after_test() -> void:
	DuelClock.clocks.clear()


func _clock() -> Callable:
	return func() -> int: return now[0]


func _view(turn: int, game_no: int = 1, paused: bool = false, winner: int = -1) -> Dictionary:
	var v := {"stage": "game", "save_id": "series_x", "game_no": game_no,
		"match": {"turn": turn, "active": turn % 2, "winner": winner}}
	if paused:
		v["net"] = {"paused": true}
	return v


func _at(v: Dictionary) -> DuelClock:
	var c := DuelClock.for_view(v, _clock())
	c.observe(v)
	return c


func test_game_and_turn_time_count_up() -> void:
	var c := _at(_view(1))
	now[0] += 83_000
	assert_int(c.game_ms()).is_equal(83_000)
	assert_int(c.turn_ms()).is_equal(83_000)


func test_a_new_turn_restarts_only_the_turn_clock() -> void:
	var c := _at(_view(1))
	now[0] += 40_000
	_at(_view(2))
	now[0] += 5_000
	assert_int(c.game_ms()).is_equal(45_000)
	assert_int(c.turn_ms()).is_equal(5_000)
	# Repeated views of the same turn change nothing.
	_at(_view(2))
	now[0] += 1_000
	assert_int(c.turn_ms()).is_equal(6_000)


func test_a_network_pause_stops_both_clocks() -> void:
	var c := _at(_view(3))
	now[0] += 10_000
	_at(_view(3, 1, true))
	now[0] += 120_000
	assert_bool(c.stopped()).is_true()
	assert_int(c.game_ms()).is_equal(10_000)
	_at(_view(3))
	now[0] += 2_000
	assert_int(c.game_ms()).is_equal(12_000)
	assert_int(c.turn_ms()).is_equal(12_000)


func test_a_pause_across_a_turn_change_is_banked_for_the_game() -> void:
	var c := _at(_view(3))
	now[0] += 10_000
	_at(_view(3, 1, true))
	now[0] += 30_000
	_at(_view(4, 1, true))
	now[0] += 30_000
	_at(_view(4))
	now[0] += 4_000
	assert_int(c.game_ms()).is_equal(14_000)
	assert_int(c.turn_ms()).is_equal(4_000)


func test_the_clock_freezes_when_the_game_is_won() -> void:
	var c := _at(_view(5))
	now[0] += 300_000
	_at(_view(5, 1, false, 0))
	now[0] += 60_000
	assert_int(c.game_ms()).is_equal(300_000)
	assert_bool(c.stopped()).is_true()


func test_hot_seat_screens_share_the_clock_and_a_new_game_starts_at_zero() -> void:
	var a := _at(_view(1))
	now[0] += 20_000
	var b := _at(_view(1))
	assert_object(b).is_same(a)
	var next := _at(_view(1, 2))
	assert_object(next).is_not_same(a)
	assert_int(next.game_ms()).is_equal(0)


func test_no_clock_outside_a_game() -> void:
	assert_object(DuelClock.for_view({"stage": "rewards", "match": {"turn": 3}})).is_null()
	assert_object(DuelClock.for_view({"stage": "game", "match": {}})).is_null()


func test_plaque_shows_game_and_turn_time() -> void:
	var c := _at(_view(1))
	now[0] += 754_000
	_at(_view(2))
	now[0] += 42_000
	var v: DuelClockView = auto_free(DuelClockView.new())
	v.set_clock(c)
	assert_array(v.texts()).is_equal(["13:16", "0:42"])
	assert_bool(v.visible).is_true()
	v.set_clock(null)
	assert_bool(v.visible).is_false()


func test_plaque_redraws_on_sand_steps_not_every_frame() -> void:
	# H7 (21 Oct): the plaque redrew on every frame; the sand moves ~10 px a minute, so it only
	# needs a redraw per SAND_STEP_MS (and per second for the numbers).
	# Arrange: a running clock that does not advance between frames.
	var c := _at(_view(1))
	var view: DuelClockView = auto_free(DuelClockView.new())
	add_child(view)
	view.set_clock(c)
	for i in 3:
		await get_tree().process_frame
	var n := [0]
	view.draw.connect(func(): n[0] += 1)
	# Act: idle frames, then one sand step.
	for i in 6:
		await get_tree().process_frame
	var idle: int = n[0]
	now[0] += DuelClockView.SAND_STEP_MS
	for i in 3:
		await get_tree().process_frame
	# Assert
	assert_int(idle).is_equal(0)
	assert_int(n[0]).is_equal(1)
