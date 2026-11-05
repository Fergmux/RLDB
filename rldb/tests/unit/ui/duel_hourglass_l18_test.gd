extends GdUnitTestSuite
## L18 (owner feedback 2026-11-05): "the turn hourglass timer icon thing should be animated to rotate every
## now and then and the sand should fall/move correctly with its orientation".
##
## DuelClock.Glass is the physical glass: the top drains over a minute of running time, the glass turns
## over when the top runs dry (and at a new turn when the top holds under half), and turning it over puts
## the old bottom on top: sand is never refilled. DuelClockView.settle() draws the sand settled under
## gravity in screen space, so it stays level while the glass tilts.

const Glass := DuelClock.Glass
const DRAIN := DuelClock.Glass.DRAIN_MS
const HOLD := DuelClock.Glass.EMPTY_HOLD_MS


## A glass advanced from 0 to `ms` of running time in `step` ms steps on turn `t` (one frame per step).
func _run(g: DuelClock.Glass, from_ms: int, to_ms: int, step: int = 100, t: int = 1) -> int:
	var flips := 0
	var ms := from_ms
	while ms < to_ms:
		ms = mini(ms + step, to_ms)
		if g.advance(ms, t, float(step) / 1000.0):
			flips += 1
	return flips


func test_the_top_drains_over_a_minute_of_running_time() -> void:
	# Arrange
	var g := Glass.new()
	g.advance(0, 1, 0.0)
	# Act
	_run(g, 0, DRAIN / 2)
	# Assert
	assert_float(g.top).is_equal_approx(0.5, 0.001)
	assert_bool(g.turning()).is_false()


func test_a_stopped_clock_stops_the_sand() -> void:
	var g := Glass.new()
	g.advance(10_000, 1, 0.0)
	# Real frames pass but the running (game) time does not move: paused or won.
	for i in 30:
		g.advance(10_000, 1, 0.1)
	assert_float(g.top).is_equal(1.0)


func test_an_empty_top_turns_the_glass_over_after_a_short_hold() -> void:
	var g := Glass.new()
	g.advance(0, 1, 0.0)
	_run(g, 0, DRAIN)
	assert_float(g.top).is_equal(0.0)
	assert_bool(g.turning()).is_false()          # it holds a moment first
	var flips := _run(g, DRAIN, DRAIN + HOLD + 100)
	assert_int(flips).is_equal(1)
	assert_bool(g.turning()).is_true()


func test_turning_over_puts_the_bottom_sand_on_top_not_a_refill() -> void:
	# Arrange: a turn change with 30 % left on top.
	var g := Glass.new()
	g.advance(0, 1, 0.0)
	_run(g, 0, int(DRAIN * 0.7))
	assert_float(g.top).is_equal_approx(0.3, 0.001)
	# Act: the next turn turns it over; let the flip finish (no sand runs while it turns).
	assert_bool(g.advance(int(DRAIN * 0.7), 2, 0.0)).is_true()
	_run(g, int(DRAIN * 0.7), int(DRAIN * 0.7) + 2000, 100, 2)
	# Assert: the 70 % that had run down is now on top, less the time since the flip ended.
	assert_bool(g.turning()).is_false()
	assert_float(g.top).is_between(0.68, 0.7)


func test_a_new_turn_keeps_a_glass_that_is_still_mostly_full() -> void:
	var g := Glass.new()
	g.advance(0, 1, 0.0)
	_run(g, 0, int(DRAIN * 0.3))
	assert_bool(g.advance(int(DRAIN * 0.3), 2, 0.016)).is_false()
	assert_bool(g.turning()).is_false()


func test_reduced_motion_turns_the_glass_at_once() -> void:
	var g := Glass.new()
	g.advance(0, 1, 0.0)
	_run(g, 0, int(DRAIN * 0.8))
	assert_bool(g.advance(int(DRAIN * 0.8), 2, 0.016, true)).is_true()
	assert_bool(g.turning()).is_false()
	assert_float(g.angle()).is_equal(0.0)
	assert_float(g.top).is_equal_approx(0.8, 0.001)


func test_the_flip_is_an_eased_half_turn() -> void:
	# Starts and ends still (eased), turns exactly half a turn, and overshoots only a little.
	assert_float(Glass.ease_flip(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(Glass.ease_flip(1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Glass.ease_flip(0.5)).is_equal_approx(0.5, 0.0001)
	var lo := 0.0
	var hi := 1.0
	for i in 101:
		var e := Glass.ease_flip(float(i) / 100.0)
		lo = minf(lo, e)
		hi = maxf(hi, e)
	assert_float(lo).is_greater(-0.08)
	assert_float(hi).is_less(1.08)
	assert_float(Glass.ease_flip(0.05)).is_less(0.05)   # slow start, not linear


## The sand settles under gravity: it holds its share of the bulb's area, and with the glass on its side
## its surface is level in screen space (the sand slides inside the tilted bulb, it does not turn with it).
func test_sand_settles_level_in_a_tilted_bulb() -> void:
	for ang in [0.0, PI / 3.0, PI / 2.0, PI * 0.8]:
		# Arrange
		var bulb := Transform2D(ang, Vector2(50, 50)) * DuelClockView.bulb_outline(true)
		# Act
		var parts := DuelClockView.settle(bulb, 0.4)
		# Assert: the area matches...
		var a := 0.0
		for q in parts:
			a += DuelClockView.poly_area(q)
		assert_float(a).is_equal_approx(DuelClockView.poly_area(bulb) * 0.4, DuelClockView.poly_area(bulb) * 0.02)
		# ...and the sand lies at the bottom of the bulb with a flat top.
		var top := INF
		var bottom := -INF
		for q in parts:
			for p in q:
				top = minf(top, p.y)
				bottom = maxf(bottom, p.y)
		var low := -INF
		for p in bulb:
			low = maxf(low, p.y)
		assert_float(bottom).is_equal_approx(low, 0.05)
		var on_surface := 0
		for q in parts:
			for p in q:
				if absf(p.y - top) < 0.01:
					on_surface += 1
		assert_int(on_surface).is_greater_equal(2)


## The regression the owner saw: while the glass turned over, the full bulb was drawn emptying and the
## empty one full. Now the sand that was at the bottom rides up with its bulb and ends on top.
func test_the_full_bottom_bulb_carries_its_sand_up_through_the_flip() -> void:
	# Arrange: a dry top, held long enough to turn over.
	var now := [0]
	var clk := DuelClock.new()
	clk.now_ms = func() -> int: return now[0]
	clk.observe({"match": {"turn": 1}})
	var view: DuelClockView = auto_free(DuelClockView.new())
	add_child(view)
	view.set_clock(clk)
	await get_tree().process_frame
	now[0] = DRAIN + HOLD + 200
	# Act: frames until the glass is a little past half way through its turn.
	var tries := 0
	while not (clk.glass.turning() and clk.glass.flip > 0.6) and tries < 200:
		await get_tree().process_frame
		tries += 1
	# Assert: the bulb that is now uppermost on screen (the old bottom) holds the sand.
	var g := clk.glass
	var xf := Transform2D(g.angle(), Vector2(0, 0))
	var a_y := (xf * Vector2(0, -6)).y   # centre of the glass-frame upper bulb on screen
	var b_y := (xf * Vector2(0, 6)).y
	assert_bool(g.turning()).is_true()
	assert_float(b_y).is_less(a_y)                    # the old bottom bulb is now above
	assert_float(1.0 - g.top).is_greater(0.95)        # and it still holds the sand
