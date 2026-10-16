extends GdUnitTestSuite
## F03-14: the HP bar's reference capacity resets when a fresh game starts.

func _pv(hp: int) -> Dictionary:
	return {"name": "Ana", "hp": hp, "ap": 2, "ap_start": 2, "ap_peak": 2}


func test_heal_raises_capacity_and_new_game_resets_to_60() -> void:
	var pl: PlayerPlate = auto_free(PlayerPlate.new())
	add_child(pl)
	pl.begin_game("s:1")
	pl.update_from(_pv(60), false, true, "", "")
	assert_int(pl.hp_capacity()).is_equal(60)
	pl.update_from(_pv(95), false, true, "", "")
	assert_int(pl.hp_capacity()).is_equal(95)     # healing above 60 stays legal
	pl.begin_game("s:1")                            # same game: unchanged
	assert_int(pl.hp_capacity()).is_equal(95)
	pl.begin_game("s:2")                            # next game of the series
	pl.update_from(_pv(60), false, true, "", "")
	assert_int(pl.hp_capacity()).is_equal(60)
	assert_int(pl.hp_bar.max_hp).is_equal(60)
	assert_float(pl.hp_bar.shown).is_equal(60.0)  # snapped, no drain from the old value


func test_new_series_with_same_game_number_also_resets() -> void:
	var pl: PlayerPlate = auto_free(PlayerPlate.new())
	add_child(pl)
	pl.begin_game("a:1")
	pl.update_from(_pv(110), false, true, "", "")
	pl.begin_game("b:1")
	pl.update_from(_pv(60), false, true, "", "")
	assert_int(pl.hp_capacity()).is_equal(60)
