extends GdUnitTestSuite
## F04-04 / F04-07: killing-blow detection picks the lethal sequence (and only for lethal hits), the
## full-screen veil rect equals the screen rect, and the game-end hold outlasts the extra sequence time.


func _atk(p: int, direct: bool) -> Dictionary:
	var to := {"p": p, "direct": true} if direct else {"p": p, "slot": 0}
	return {"k": "attack", "from": {"p": 1 - p, "slot": 0}, "to": to}


func test_lethal_direct_attack_is_detected() -> void:
	var ev := [_atk(1, true), {"k": "hp", "p": 1, "d": -26}, {"k": "game_over", "winner": 0}]
	var info := FxStrike.detect(ev)
	assert_str(String(info["mode"])).is_equal("direct")
	assert_int(int(info["winner"])).is_equal(0)
	assert_int(int(info["loser"])).is_equal(1)
	assert_int(int(info["attack"])).is_equal(0)
	assert_int(int(info["d"])).is_equal(26)


func test_non_lethal_direct_attack_is_not_a_killing_blow() -> void:
	var ev := [_atk(1, true), {"k": "hp", "p": 1, "d": -8}]
	assert_dict(FxStrike.detect(ev)).is_empty()
	assert_int(FxStrike.hp_after(ev, 0)).is_equal(1)


func test_game_over_without_damage_is_not_a_killing_blow() -> void:
	assert_dict(FxStrike.detect([{"k": "game_over", "winner": 1}])).is_empty()


func test_lethal_effect_damage_gets_the_flourish_not_the_strike() -> void:
	var ev := [{"k": "hp", "p": 0, "d": -5}, {"k": "game_over", "winner": 1}]
	var info := FxStrike.detect(ev)
	assert_str(String(info["mode"])).is_equal("effect")
	assert_int(int(info["attack"])).is_equal(-1)
	assert_float(FxStrike.hold_extra(info)).is_equal(FxStrike.FLOURISH_LEN)


func test_attack_on_a_card_is_never_the_direct_lethal_attack() -> void:
	var ev := [_atk(1, false), {"k": "hp", "p": 1, "d": -3}, {"k": "game_over", "winner": 0}]
	assert_str(String(FxStrike.detect(ev)["mode"])).is_equal("effect")


func test_hold_outlasts_the_lethal_sequence() -> void:
	var info := FxStrike.detect([_atk(1, true), {"k": "hp", "p": 1, "d": -9}, {"k": "game_over", "winner": 0}])
	assert_float(FxStrike.hold_extra(info)).is_equal(FxStrike.LETHAL_LEN)
	assert_float(FxStrike.hold_extra({})).is_equal(0.0)
	# wind-up + lunge in slow motion + hit-stop + explosion to the end look fits inside the extra time
	var seq := 0.25 / FxStrike.SLOW_WIND + 0.3 / FxStrike.SLOW_LUNGE + FxStrike.HIT_STOP + FxStrike.BLAST_TO_END
	assert_float(seq).is_less_equal(FxStrike.LETHAL_LEN)


func test_slow_motion_uses_tween_speed_not_engine_time() -> void:
	assert_float(FxStrike.SLOW_LUNGE).is_less(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_game_end_veil_is_the_whole_screen_rect() -> void:
	var screen: Control = auto_free(Control.new())
	add_child(screen)
	screen.position = Vector2.ZERO
	screen.size = Vector2(1600, 900)
	assert_object(FxGameEnd.veil_rect(screen)).is_equal(Rect2(Vector2.ZERO, Vector2(1600, 900)))
	remove_child(screen)


func test_boom_and_charge_sounds_exist() -> void:
	for n in ["boom", "charge"]:
		assert_bool(Sfx.NAMES.has(n)).is_true()
		assert_bool(FileAccess.file_exists("res://assets/audio/sfx/%s.wav" % n)).is_true()
