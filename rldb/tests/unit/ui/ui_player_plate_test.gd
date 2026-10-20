extends GdUnitTestSuite
## H1 WP-3 (design review #17-#21, D4 / D6): the player plate with the Vial of Life and the topaz AP
## gems. The F2 frame's rim per state (idle bronze, active gold, low-HP ember), the one-sound-per-AP-
## change rule, the HP hold the effects use (Divine Serpents, the killing blow) and the "+N AP" anchor.

var _rm: bool
var _fast: bool
var _played: Array = []


func before_test() -> void:
	_rm = UIStyle.reduce_motion
	_fast = UIStyle.fast_anim
	UIStyle.reduce_motion = false
	UIStyle.fast_anim = false
	_played = []


func after_test() -> void:
	UIStyle.reduce_motion = _rm
	UIStyle.fast_anim = _fast


func _pv(hp: int, ap: int = 2, start: int = 2, peak: int = 2) -> Dictionary:
	return {"name": "Ana", "hp": hp, "ap": ap, "ap_start": start, "ap_peak": peak}


func _plate() -> PlayerPlate:
	var pl: PlayerPlate = auto_free(PlayerPlate.new())
	pl.play_sfx = func(n: String, _db: float) -> void: _played.append(n)
	add_child(pl)
	pl.begin_game("s:1")
	pl.update_from(_pv(60), false, true, "", "")
	return pl


func test_plate_uses_the_vial_and_the_topaz_gems() -> void:
	var pl := _plate()
	assert_object(pl.hp_bar).is_instanceof(HpVial)
	assert_object(pl.ap_gems).is_instanceof(ApGemRow)
	assert_object(pl.hp_bar.shake_target).is_same(pl)
	assert_object(pl.get_theme_stylebox("panel")).is_instanceof(FrameBox)


func test_vial_knows_the_local_player_and_their_turn() -> void:
	var pl := _plate()
	pl.update_from(_pv(60), true, true, "", "")
	assert_bool(pl.hp_bar.is_local).is_true()
	assert_bool(pl.hp_bar.my_turn).is_true()
	pl.update_from(_pv(60), false, true, "", "")
	assert_bool(pl.hp_bar.my_turn).is_false()
	pl.update_from(_pv(60), true, false, "", "")
	assert_bool(pl.hp_bar.is_local).is_false()
	assert_bool(pl.hp_bar.my_turn).is_false()


func test_rim_is_bronze_when_idle_and_gold_when_active() -> void:
	var pl := _plate()
	assert_that(pl.frame.rim).is_equal(PlayerPlate.RIM_IDLE)
	assert_float(pl.frame.glow.a).is_equal(0.0)
	pl.update_from(_pv(60), true, true, "", "")
	assert_that(pl.frame.rim).is_not_equal(PlayerPlate.RIM_IDLE)
	assert_float(pl.frame.glow.a).is_greater(0.0)
	assert_bool(pl.turn_mark.on).is_true()


func test_low_hp_turns_the_rim_ember_and_back() -> void:
	var pl := _plate()
	pl.update_from(_pv(15), false, true, "", "")
	assert_that(pl.frame.rim).is_equal(HpVial.LOW_PLATE_BORDER)
	pl.update_from(_pv(40), false, true, "", "")
	assert_that(pl.frame.rim).is_equal(PlayerPlate.RIM_IDLE)


func test_reduce_motion_active_plate_is_lit_and_still() -> void:
	UIStyle.reduce_motion = true
	var pl := _plate()
	pl.update_from(_pv(60), true, true, "", "")
	assert_bool(pl.is_processing()).is_false()
	assert_float(pl.frame.sweep).is_less(0.0)
	assert_float(pl.frame.glow.a).is_greater(0.0)


func test_an_unannounced_ap_change_plays_exactly_one_gem_sound() -> void:
	var pl := _plate()
	pl.update_from(_pv(60, 0, 2, 2), false, true, "", "")   # a 2-AP card paid: two gems spent
	assert_array(_played).is_equal(["ap_loss"])


func test_an_ap_change_announced_by_an_effect_is_silent_on_the_gems() -> void:
	var pl := _plate()
	pl.claim_ap_sound()
	pl.update_from(_pv(60, 3, 2, 3), false, true, "", "")   # FxPlayer plays ap_gain for it
	assert_array(_played).is_empty()
	pl.update_from(_pv(60, 2, 2, 3), false, true, "", "")   # the next, unannounced change is voiced
	assert_array(_played).is_equal(["ap_loss"])


func test_reduce_motion_still_voices_the_gem_change_once() -> void:
	UIStyle.reduce_motion = true
	var pl := _plate()
	pl.update_from(_pv(60, 0, 2, 2), false, true, "", "")
	assert_array(_played).is_equal(["ap_loss"])


func test_hold_keeps_the_vial_at_the_old_value_until_released() -> void:
	var pl := _plate()
	pl.update_from(_pv(30), false, true, "", "")   # the board renders the result at once
	pl.hold_hp(50)
	assert_bool(pl.hp_held()).is_true()
	assert_int(pl.hp_bar.hp).is_equal(50)
	pl.update_from(_pv(28), false, true, "", "")   # a later view while held only updates the real value
	assert_int(pl.hp_bar.hp).is_equal(50)
	pl.release_hp()
	assert_bool(pl.hp_held()).is_false()
	assert_int(pl.hp_bar.hp).is_equal(28)
	assert_bool(pl.hp_bar.animating()).is_true()   # the damage trail plays from the held value


func test_release_with_shatter_breaks_the_glass_on_a_killing_blow() -> void:
	var pl := _plate()
	pl.update_from(_pv(0), false, true, "", "")
	pl.hold_hp(12)
	pl.release_hp(false, true)
	assert_int(pl.hp_bar.hp).is_equal(0)
	assert_int(pl.hp_bar.particle_count()).is_greater_equal(8)   # the glass shards


func test_skipped_release_snaps_without_shards() -> void:
	var pl := _plate()
	pl.update_from(_pv(0), false, true, "", "")
	pl.hold_hp(12)
	pl.release_hp(true, true)
	assert_int(pl.hp_bar.hp).is_equal(0)
	assert_float(pl.hp_bar.shown).is_equal(0.0)
	assert_int(pl.hp_bar.particle_count()).is_equal(0)


func test_ap_floater_anchor_sits_right_of_the_ap_label() -> void:
	var pl := _plate()
	pl.size = Vector2(PlayerPlate.PLATE_W, pl.get_combined_minimum_size().y)
	await await_idle_frame()
	var r := pl.ap_gems.get_global_rect()
	assert_float(pl.ap_anchor().x - r.position.x).is_greater(pl.ap_gems.label_end_x() + 20.0)
	assert_float(pl.ap_anchor().x).is_less(pl.get_global_rect().end.x)


# ---------------------------------------------------------------- the killing blow (FxPlayer)

func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _lethal_effect_batch() -> Array:
	return [{"k": "hp", "p": 1, "d": -12}, {"k": "game_over", "winner": 0}]


## A killing direct attack: the strike's wind-up runs before the blow lands.
func _lethal_direct_batch() -> Array:
	return [{"k": "attack", "from": {"p": 0, "slot": 0}, "to": {"p": 1, "direct": true}},
		{"k": "hp", "p": 1, "d": -12, "via": "direct"}, {"k": "game_over", "winner": 0}]


func test_killing_blow_holds_the_losers_vial_until_skipped() -> void:
	var gs := _screen()
	await await_idle_frame()
	var pl: PlayerPlate = gs.plate_of(1)
	pl.hp_bar.set_hp(0, true)   # the board already shows the result
	gs.fx.play(_lethal_direct_batch(), {"players": [{"hp": 60}, {"hp": 12}]})
	assert_bool(pl.hp_held()).is_true()
	assert_int(pl.hp_bar.hp).is_equal(12)   # the HP before the blow, from the previous view
	gs.fx.finish_all()
	assert_bool(pl.hp_held()).is_false()
	assert_int(pl.hp_bar.hp).is_equal(0)


func test_killing_blow_shatters_the_vial_when_it_lands() -> void:
	var gs := _screen()
	await await_idle_frame()
	var pl: PlayerPlate = gs.plate_of(1)
	pl.hp_bar.set_hp(0, true)
	gs.fx.play(_lethal_effect_batch(), {"players": [{"hp": 60}, {"hp": 12}]})
	await await_millis(400)   # the final-blow flourish starts with its batch
	assert_bool(pl.hp_held()).is_false()
	assert_int(pl.hp_bar.hp).is_equal(0)
	assert_int(pl.hp_bar.particle_count()).is_greater(0)   # glass shards
