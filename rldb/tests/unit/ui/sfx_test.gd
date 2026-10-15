extends GdUnitTestSuite
## Sfx event mapping, rate limiter and settings persistence.

var _backup: String = ""
var _had_file: bool = false


func before_test() -> void:
	_had_file = FileAccess.file_exists(Sfx.SETTINGS_PATH)
	_backup = FileAccess.get_file_as_string(Sfx.SETTINGS_PATH) if _had_file else ""
	Sfx._reset_limiter()


func after_test() -> void:
	if _had_file:
		var f := FileAccess.open(Sfx.SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Sfx.SETTINGS_PATH))
	Sfx.load_settings()


func test_for_fx_mapping() -> void:
	assert_str(Sfx.for_fx({"k": "draw", "p": 0, "n": 3}, 0)).is_equal("card_draw")
	assert_str(Sfx.for_fx({"k": "play", "p": 0, "zone": "backrow", "slot": 1}, 0)).is_equal("card_set")
	assert_str(Sfx.for_fx({"k": "play", "p": 0, "zone": "power", "slot": 1}, 0)).is_equal("card_play")
	assert_str(Sfx.for_fx({"k": "play", "p": 0, "zone": "unit", "slot": 1}, 0)).is_equal("card_play")
	assert_str(Sfx.for_fx({"k": "summon", "p": 1, "slot": 0}, 0)).is_equal("summon")
	assert_str(Sfx.for_fx({"k": "attack", "from": {"p": 0, "slot": 0}, "to": {"p": 1, "slot": 0}}, 0)).is_equal("attack")
	assert_str(Sfx.for_fx({"k": "hp", "p": 0, "d": 3}, 0)).is_equal("heal")
	assert_str(Sfx.for_fx({"k": "hp", "p": 0, "d": -3}, 0)).is_equal("damage")
	assert_str(Sfx.for_fx({"k": "destroy", "at": {}, "cause": "x"}, 0)).is_equal("destroy")
	assert_str(Sfx.for_fx({"k": "status", "at": {}, "s": "rune", "n": 1}, 0)).is_equal("buff")
	assert_str(Sfx.for_fx({"k": "status", "at": {}, "s": CardDB.BUFFS[0], "n": 1}, 0)).is_equal("buff")
	assert_str(Sfx.for_fx({"k": "status", "at": {}, "s": CardDB.DEBUFFS[0], "n": 1}, 0)).is_equal("debuff")
	assert_str(Sfx.for_fx({"k": "stat", "at": {}, "atk": 1, "def": 1}, 0)).is_equal("")
	assert_str(Sfx.for_fx({"k": "ap", "p": 0, "d": 1}, 0)).is_equal("")
	assert_str(Sfx.for_fx({"k": "turn", "p": 0, "turn": 2}, 0)).is_equal("turn")
	assert_str(Sfx.for_fx({"k": "phase", "phase": "battle", "turn": 2}, 0)).is_equal("phase")


func test_for_fx_game_over_perspective_and_unknown() -> void:
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 0}, 0)).is_equal("victory")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 1}, 0)).is_equal("defeat")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 1}, 1)).is_equal("victory")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": -1}, 0)).is_equal("defeat")
	assert_str(Sfx.for_fx({"k": "bogus"}, 0)).is_equal("")
	assert_str(Sfx.for_fx({}, 0)).is_equal("")


func test_all_named_sounds_have_assets() -> void:
	for n in Sfx.NAMES:
		assert_bool(ResourceLoader.exists(Sfx.DIR + n + ".wav")).is_true()


func test_limiter_drops_same_name_repeat() -> void:
	assert_bool(Sfx._allow("impact", 1000)).is_true()
	assert_bool(Sfx._allow("impact", 1050)).is_false()
	assert_bool(Sfx._allow("impact", 1000 + Sfx.MIN_INTERVAL_MS)).is_true()


func test_limiter_burst_cap() -> void:
	var names: Array[String] = ["card_draw", "card_play", "summon", "attack", "impact", "damage"]
	var ok: int = 0
	for i in names.size():
		if Sfx._allow(names[i], 5000 + i * 10):
			ok += 1
	assert_int(ok).is_equal(Sfx.BURST_MAX)
	# After the window passes, sounds are allowed again.
	assert_bool(Sfx._allow("heal", 5000 + Sfx.BURST_WINDOW_MS + 60)).is_true()


func test_play_is_safe_noop_for_unknown_and_empty() -> void:
	Sfx.play("")
	Sfx.play("no_such_sound")
	Sfx.set_muted(true)
	Sfx.play("select")
	assert_bool(Sfx.is_muted()).is_true()


func test_settings_round_trip_and_clamp() -> void:
	Sfx.set_volume(1.7)
	assert_float(Sfx.get_volume()).is_equal(1.0)
	Sfx.set_volume(-2.0)
	assert_float(Sfx.get_volume()).is_equal(0.0)
	Sfx.set_volume(0.35)
	Sfx.set_muted(true)
	Sfx._volume = 0.9
	Sfx._muted = false
	Sfx.load_settings()
	assert_float(Sfx.get_volume()).is_equal_approx(0.35, 0.001)
	assert_bool(Sfx.is_muted()).is_true()
	Sfx.set_muted(false)
	Sfx.load_settings()
	assert_bool(Sfx.is_muted()).is_false()
