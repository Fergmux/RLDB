extends GdUnitTestSuite
## WP-3 / D4: the topaz AP gem row. The F02-06 slot policy (F02-06, the plate's former ApGems), the
## idle sockets before the first turn, the pop curve and the gain / spend signals on an injected clock.

var _rm: bool
var _fast: bool
var _now: float = 5.0


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	_fast = UIStyle.fast_anim
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	_now = 5.0


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	UIStyle.fast_anim = _fast


func _clock() -> float:
	return _now


func _row(ap: int, start: int, peak: int) -> ApGemRow:
	var g: ApGemRow = auto_free(ApGemRow.new())
	g.clock = _clock
	add_child(g)
	g.set_values(ap, start, peak, true)
	return g


func test_policy_matches_the_f02_06_slot_rule() -> void:
	# [ap, start, peak] -> [capacity, filled, spent] (F02-06, formerly PlayerPlate.ApGems).
	var cases := [[[2, 2, 2], [2, 2, 0]], [[1, 2, 2], [2, 1, 1]], [[0, 2, 2], [2, 0, 2]], [[3, 2, 4], [4, 3, 1]],
		[[5, 2, 5], [5, 5, 0]], [[14, 2, 14], [14, 14, 0]], [[0, 0, 0], [0, 0, 0]], [[-1, 0, 0], [0, 0, 0]]]
	for c in cases:
		var a: int = c[0][0]
		var s: int = c[0][1]
		var p: int = c[0][2]
		assert_int(ApGemRow.capacity_for(a, s, p)).is_equal(int(c[1][0]))
		assert_int(ApGemRow.filled_for(a, s, p)).is_equal(int(c[1][1]))
		assert_int(ApGemRow.spent_for(a, s, p)).is_equal(int(c[1][2]))


func test_before_the_first_turn_shows_two_idle_sockets() -> void:
	var g := _row(0, 0, 0)
	assert_int(g.slots()).is_equal(ApGemRow.IDLE_SLOTS)
	assert_int(g.capacity()).is_equal(0)
	assert_str(g.ap_text()).is_equal("AP 0/2")


func test_text_shows_current_over_capacity() -> void:
	var g := _row(1, 2, 2)
	assert_str(g.ap_text()).is_equal("AP 1/2")
	assert_int(g.slots()).is_equal(2)


func test_row_shrinks_only_above_the_budget() -> void:
	assert_float(ApGemRow.row_scale(2)).is_equal(1.0)
	assert_float(ApGemRow.row_scale(7)).is_equal(1.0)
	assert_float(ApGemRow.row_scale(12)).is_less(1.0)
	assert_float(ApGemRow.row_scale(200)).is_equal(ApGemRow.MIN_SCALE)


func test_pop_overshoots_then_settles() -> void:
	assert_float(ApGemRow.pop_scale(0.0)).is_equal(0.0)
	assert_float(ApGemRow.pop_scale(ApGemRow.GAIN_T * 0.55)).is_equal_approx(ApGemRow.POP_PEAK, 0.001)
	assert_float(ApGemRow.pop_scale(ApGemRow.GAIN_T)).is_equal(1.0)
	var peak := 0.0
	for i in 50:
		peak = maxf(peak, ApGemRow.pop_scale(ApGemRow.GAIN_T * float(i) / 50.0))
	assert_float(peak).is_less_equal(ApGemRow.POP_PEAK + 0.0001)


func test_gained_gems_signal_with_stagger() -> void:
	var g := _row(0, 2, 2)
	var got: Array[int] = []
	g.gem_gained.connect(func(i: int) -> void: got.append(i))
	g.set_values(2, 2, 2)
	assert_array(got).is_equal([0])
	_now += ApGemRow.STAGGER
	g.step()
	assert_array(got).is_equal([0, 1])
	_now += ApGemRow.GAIN_T + 0.01
	g.step()
	assert_bool(g.animating()).is_false()


func test_spent_gem_signals_and_finishes() -> void:
	var g := _row(2, 2, 2)
	var got: Array[int] = []
	g.gem_spent.connect(func(i: int) -> void: got.append(i))
	g.set_values(1, 2, 2)
	assert_array(got).is_equal([1])
	assert_bool(g.animating()).is_true()
	_now += ApGemRow.PUFF_T + 0.01
	g.step()
	assert_bool(g.animating()).is_false()


func test_reduce_motion_snaps_but_keeps_the_sound_signals() -> void:
	UIStyle.reduce_motion = true
	var g := _row(2, 2, 2)
	var got := [0]
	g.gem_spent.connect(func(_i: int) -> void: got[0] += 1)
	g.set_values(0, 2, 2)
	assert_int(got[0]).is_equal(2)
	assert_bool(g.animating()).is_false()


func test_snap_update_is_silent() -> void:
	var g := _row(2, 2, 2)
	var got := [0]
	g.gem_spent.connect(func(_i: int) -> void: got[0] += 1)
	g.set_values(0, 2, 2, true)
	assert_int(got[0]).is_equal(0)
