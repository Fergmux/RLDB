extends GdUnitTestSuite
## WP-3 / D4: the Vial of Life HP display. Value clamping, the low / critical thresholds, segment
## ticks, the damage trail and heal pour timing with an injected clock, the heartbeat schedule, the
## max-HP stretch and the reduce-motion path.

var _rm: bool
var _fast: bool
var _now: float = 10.0


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	_fast = UIStyle.fast_anim
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	_now = 10.0


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	UIStyle.fast_anim = _fast


func _clock() -> float:
	return _now


## A vial in the tree on the fake clock, snapped to `hp` of `p_max`.
func _vial(hp: int, p_max: int = 60) -> HpVial:
	var v: HpVial = auto_free(HpVial.new())
	v.clock = _clock
	add_child(v)
	v.set_value(hp, p_max, true)
	return v


func _at(v: HpVial, t: float) -> void:
	_now = t
	v.step()


func test_clamp_and_fraction_stay_in_range() -> void:
	assert_float(HpVial.clamp_hp(-5.0, 60)).is_equal(0.0)
	assert_float(HpVial.clamp_hp(75.0, 60)).is_equal(60.0)
	assert_float(HpVial.clamp_hp(30.0, 0)).is_equal(1.0)   # a zero max is treated as 1
	assert_float(HpVial.fraction(30.0, 60.0)).is_equal(0.5)
	assert_float(HpVial.fraction(90.0, 60.0)).is_equal(1.0)
	assert_float(HpVial.fraction(-1.0, 60.0)).is_equal(0.0)


func test_set_hp_never_stores_negative_hp() -> void:
	var v := _vial(10)
	v.set_hp(-7)
	assert_int(v.hp).is_equal(0)


func test_low_threshold_is_a_quarter_of_max_inclusive() -> void:
	assert_bool(HpVial.is_low(15, 60)).is_true()
	assert_bool(HpVial.is_low(16, 60)).is_false()
	assert_bool(HpVial.is_low(0, 60)).is_true()
	assert_bool(HpVial.is_low(20, 80)).is_true()
	assert_bool(HpVial.is_low(21, 80)).is_false()


func test_critical_threshold_is_a_tenth_of_max_inclusive() -> void:
	assert_bool(HpVial.is_critical(6, 60)).is_true()
	assert_bool(HpVial.is_critical(7, 60)).is_false()


func test_ticks_every_ten_hp_excluding_the_ends() -> void:
	assert_array(HpVial.tick_values(60)).is_equal([10, 20, 30, 40, 50])
	assert_array(HpVial.tick_values(65)).is_equal([10, 20, 30, 40, 50, 60])
	assert_array(HpVial.tick_values(10)).is_empty()


func test_trail_holds_then_drains_to_the_new_value() -> void:
	var hold := HpVial.DMG_FLASH + HpVial.DMG_HOLD
	assert_float(HpVial.trail_top(0.0, 60.0, 34.0, hold, HpVial.DMG_DRAIN)).is_equal(60.0)
	assert_float(HpVial.trail_top(hold - 0.001, 60.0, 34.0, hold, HpVial.DMG_DRAIN)).is_equal(60.0)
	assert_float(HpVial.trail_top(hold + HpVial.DMG_DRAIN / 2.0, 60.0, 34.0, hold, HpVial.DMG_DRAIN)).is_equal_approx(47.0, 0.001)
	assert_float(HpVial.trail_top(hold + HpVial.DMG_DRAIN, 60.0, 34.0, hold, HpVial.DMG_DRAIN)).is_equal(34.0)


func test_hit_flash_lasts_ninety_ms() -> void:
	assert_float(HpVial.flash_at(0.0, HpVial.DMG_FLASH)).is_equal(1.0)
	assert_float(HpVial.flash_at(0.045, HpVial.DMG_FLASH)).is_equal_approx(0.5, 0.001)
	assert_float(HpVial.flash_at(HpVial.DMG_FLASH, HpVial.DMG_FLASH)).is_equal(0.0)


func test_damage_timeline_on_the_injected_clock() -> void:
	var v := _vial(60)
	var hits: Array[int] = []
	v.damaged.connect(func(a: int) -> void: hits.append(a))
	v.set_hp(34)
	assert_array(hits).is_equal([26])
	_at(v, 10.05)
	assert_float(v.liquid_level()).is_between(34.0, 60.0)          # the liquid drops during the flash
	_at(v, 10.2)
	assert_float(v.liquid_level()).is_equal(34.0)
	assert_float(v.trail_top_at()).is_equal(60.0)                  # amber hold
	_at(v, 10.0 + HpVial.DMG_FLASH + HpVial.DMG_HOLD + HpVial.DMG_DRAIN / 2.0)
	assert_float(v.trail_top_at()).is_equal_approx(47.0, 0.01)    # half-way through the drain
	assert_int(v.particle_count()).is_greater(0)                   # embers leave the edge
	_at(v, 12.0)
	assert_float(v.trail_top_at()).is_equal(34.0)
	assert_bool(v.animating()).is_false()


func test_number_counts_to_the_new_value() -> void:
	var v := _vial(60)
	v.set_hp(40)
	assert_float(v.shown_number()).is_equal(60.0)
	_now = 10.0 + HpVial.COUNT_T
	assert_float(v.shown_number()).is_equal(40.0)


func test_a_second_hit_continues_the_visible_trail() -> void:
	var v := _vial(60)
	v.set_hp(50)
	_at(v, 10.2)
	v.set_hp(40)
	assert_float(v.trail_top_at()).is_equal(60.0)   # still from the first hit's top


func test_big_hit_signal_only_for_ten_or_more() -> void:
	var v := _vial(60)
	var big: Array[int] = []
	v.big_hit.connect(func(a: int) -> void: big.append(a))
	v.set_hp(51)
	v.set_hp(41)
	assert_array(big).is_equal([10])


func test_heal_pours_with_quart_out() -> void:
	var v := _vial(20)
	var heals: Array[int] = []
	v.healed.connect(func(a: int) -> void: heals.append(a))
	v.set_hp(44)
	assert_array(heals).is_equal([24])
	_at(v, 10.0 + HpVial.HEAL_POUR / 2.0)
	assert_float(v.liquid_level()).is_equal_approx(lerpf(20.0, 44.0, HpVial.quart_out(0.5, 1.0)), 0.01)
	_at(v, 11.5)
	assert_float(v.liquid_level()).is_equal(44.0)


func test_same_value_is_a_no_op() -> void:
	var v := _vial(30)
	v.set_hp(30)
	assert_bool(v.animating()).is_false()


func test_low_state_beats_on_entry_then_every_period_on_my_turn() -> void:
	var v := _vial(30)
	v.is_local = true
	v.my_turn = true
	var beats: Array[float] = []
	var lows: Array[bool] = []
	v.heartbeat.connect(func() -> void: beats.append(_now))
	v.low_hp_changed.connect(func(l: bool) -> void: lows.append(l))
	v.set_hp(15)
	assert_array(lows).is_equal([true])
	assert_int(beats.size()).is_equal(1)
	_at(v, 10.0 + HpVial.HEARTBEAT_PERIOD - 0.01)
	assert_int(beats.size()).is_equal(1)
	_at(v, 10.0 + HpVial.HEARTBEAT_PERIOD)
	assert_int(beats.size()).is_equal(2)
	v.my_turn = false
	_at(v, 10.0 + HpVial.HEARTBEAT_PERIOD * 2.0 + 0.01)
	assert_int(beats.size()).is_equal(2)
	v.set_hp(40)
	assert_array(lows).is_equal([true, false])


func test_opponent_vial_never_beats() -> void:
	var v := _vial(30)
	v.is_local = false
	v.my_turn = true
	var beats := [0]
	v.heartbeat.connect(func() -> void: beats[0] += 1)
	v.set_hp(10)
	_at(v, 15.0)
	assert_int(beats[0]).is_equal(0)
	assert_bool(v.low()).is_true()


func test_max_increase_stretches_over_three_hundred_ms() -> void:
	var v := _vial(60)
	v.max_hp = 80
	assert_float(v.shown_max()).is_equal(60.0)
	_now = 10.0 + HpVial.MAX_STRETCH_T / 2.0
	assert_float(v.shown_max()).is_between(60.0, 80.0)
	_now = 10.0 + HpVial.MAX_STRETCH_T
	assert_float(v.shown_max()).is_equal(80.0)


func test_snap_skips_every_animation() -> void:
	var v := _vial(60)
	v.set_hp(20, true)
	assert_float(v.liquid_level()).is_equal(20.0)
	assert_float(v.trail_top_at()).is_equal(20.0)
	assert_bool(v.animating()).is_false()


func test_reduce_motion_fades_the_trail_without_travel_or_particles() -> void:
	UIStyle.reduce_motion = true
	var v := _vial(60)
	v.set_hp(30)
	assert_float(v.liquid_level()).is_equal(30.0)
	assert_float(v.trail_top_at()).is_equal(30.0)   # no drain timeline
	assert_int(v.particle_count()).is_equal(0)
	assert_bool(v.animating()).is_true()             # the 120 ms fade
	_at(v, 10.0 + HpVial.REDUCED_FADE + 0.001)
	assert_bool(v.animating()).is_false()


func test_shatter_drains_to_zero_and_drops_shards() -> void:
	var v := _vial(8)
	v.shatter()
	assert_int(v.hp).is_equal(0)
	assert_int(v.particle_count()).is_between(8, 12)
	_at(v, 10.0 + HpVial.SHATTER_CRACK / 2.0)
	assert_float(v.liquid_level()).is_equal(8.0)    # the glass cracks first
	_at(v, 10.0 + HpVial.SHATTER_CRACK + HpVial.SHATTER_DRAIN)
	assert_float(v.liquid_level()).is_equal(0.0)


func test_ember_and_sparkle_counts_stay_in_spec() -> void:
	assert_int(HpVial.ember_count(1)).is_equal(3)
	assert_int(HpVial.ember_count(60)).is_equal(6)
	assert_int(HpVial.sparkle_count(1)).is_equal(5)
	assert_int(HpVial.sparkle_count(60)).is_equal(8)


func test_plate_contract_flash_and_max_hp_fields() -> void:
	var v := _vial(60)
	v.flash = 0.6
	assert_float(v.flash).is_equal(0.6)
	v.max_hp = 0
	assert_int(v.max_hp).is_equal(1)
	assert_that(v.custom_minimum_size).is_equal(HpVial.VIAL_SIZE)
