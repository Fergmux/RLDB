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
	# L1: stat changes now sound (a net gain is a buff, a loss a debuff, no change is silent).
	assert_str(Sfx.for_fx({"k": "stat", "at": {}, "atk": 1, "def": 1}, 0)).is_equal("buff")
	assert_str(Sfx.for_fx({"k": "stat", "at": {}, "atk": -2, "def": 0}, 0)).is_equal("debuff")
	assert_str(Sfx.for_fx({"k": "stat", "at": {}, "atk": 1, "def": -1}, 0)).is_equal("")
	# D6 (2026-10-20): AP changes now have their own sounds (they were silent).
	assert_str(Sfx.for_fx({"k": "ap", "p": 0, "d": 1}, 0)).is_equal("ap_gain")
	assert_str(Sfx.for_fx({"k": "ap", "p": 0, "d": -1}, 0)).is_equal("ap_loss")
	assert_str(Sfx.for_fx({"k": "turn", "p": 0, "turn": 2}, 0)).is_equal("turn")
	assert_str(Sfx.for_fx({"k": "phase", "phase": "battle", "turn": 2}, 0)).is_equal("phase")


func test_for_fx_discard_and_stance_have_their_own_cues() -> void:
	# L1: the discard to Spent and a stance change were silent.
	assert_str(Sfx.for_fx({"k": "discard", "p": 0, "n": 2}, 0)).is_equal("card_discard")
	assert_str(Sfx.for_fx({"k": "stance", "at": {}, "to": "def"}, 0)).is_equal("stance_defense")
	assert_str(Sfx.for_fx({"k": "stance", "at": {}, "to": "atk"}, 0)).is_equal("stance_attack")


func test_hit_for_defense_stance_is_block_else_impact() -> void:
	# L1: an attack into a Defense-stance unit clangs on a shield.
	assert_str(Sfx.hit_for({"stance": "def"})).is_equal("block")
	assert_str(Sfx.hit_for({"stance": "atk"})).is_equal("impact")
	assert_str(Sfx.hit_for(null)).is_equal("impact")
	assert_str(Sfx.hit_for({"hidden": true})).is_equal("impact")


func test_defender_view_reads_the_attacked_slot_of_the_previous_view() -> void:
	# Arrange: player 1 has a Defense-stance unit in slot 2 of the view before the batch.
	var units := [null, null, {"id": 7, "stance": "def"}]
	var prev := {"players": [{"units": []}, {"units": units}]}
	var hit := {"k": "attack", "from": {"p": 0, "slot": 0}, "to": {"p": 1, "slot": 2}}
	var direct := {"k": "attack", "from": {"p": 0, "slot": 0}, "to": {"p": 1, "direct": true}}
	# Act / Assert: the attack into it clangs; a direct attack or no previous view stays an impact
	assert_str(Sfx.hit_for(FxPlayer._defender_view(hit, prev))).is_equal("block")
	assert_object(FxPlayer._defender_view(direct, prev)).is_null()
	assert_object(FxPlayer._defender_view(hit, {})).is_null()
	assert_object(FxPlayer._defender_view({"k": "attack", "to": {"p": 1, "slot": 5}}, prev)).is_null()


func test_every_named_sound_is_registered_once() -> void:
	# The cue names are the contract with the asset set (design/audio/sfx-cues.json): no duplicates.
	var seen := {}
	for n in Sfx.NAMES:
		assert_bool(seen.has(n)).override_failure_message("%s twice" % n).is_false()
		seen[n] = true


func test_for_fx_game_over_perspective_and_unknown() -> void:
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 0}, 0)).is_equal("victory")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 1}, 0)).is_equal("defeat")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": 1}, 1)).is_equal("victory")
	assert_str(Sfx.for_fx({"k": "game_over", "winner": -1}, 0)).is_equal("defeat")
	assert_str(Sfx.for_fx({"k": "bogus"}, 0)).is_equal("")
	assert_str(Sfx.for_fx({}, 0)).is_equal("")


func test_all_named_sounds_have_assets() -> void:
	# L1: a cue may ship as .wav or .ogg (Sfx.asset_path tries both).
	for n in Sfx.NAMES:
		assert_bool(Sfx.has_asset(n)).override_failure_message("%s has no .wav / .ogg" % n).is_true()


func test_asset_path_prefers_wav_and_is_empty_when_missing() -> void:
	# Arrange: summon ships as a .wav; a made-up name has no file.
	# Act / Assert
	assert_str(Sfx.asset_path("summon")).is_equal(Sfx.DIR + "summon.wav")
	assert_str(Sfx.asset_path("no_such_cue_l1")).is_equal("")
	assert_bool(Sfx.has_asset("no_such_cue_l1")).is_false()


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
