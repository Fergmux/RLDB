extends GdUnitTestSuite
## K1 (owner feedback 2026-10-23): "playing a trap/spell fullscreen should have a sound effect".
## The Spell/Trap spotlight plays one cue per presentation as the card lands (an arcane cast for a
## Spell, a snap for a Trap), through Sfx (so mute and volume apply), and nothing else in its batch
## sounds for the same moment.

const SPELL_ID := 41   # any card id with a summary works for the big card
const TRAP_ID := 46


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


## Swaps the spotlight's sound player for a recorder; returns the list it fills with [name, dB].
func _record(gs: GameScreen) -> Array:
	var calls := []
	gs.fx._spotlight.play_sfx = func(n: String, db: float) -> void: calls.append([n, db])
	return calls


func _spot(how: String, id: int) -> Dictionary:
	return {"k": "spotlight", "p": 0, "id": id, "how": how}


func after() -> void:
	UIStyle.reduce_motion = false


func test_trap_spotlight_snaps_and_spell_spotlights_cast() -> void:
	assert_str(FxSpotlight.sound_for(_spot("trap", TRAP_ID))).is_equal("trap_spring")
	assert_str(FxSpotlight.sound_for(_spot("cast", SPELL_ID))).is_equal("spell_cast")
	assert_str(FxSpotlight.sound_for(_spot("activate", SPELL_ID))).is_equal("spell_cast")
	assert_str(FxSpotlight.sound_for({"k": "spotlight", "id": SPELL_ID})).is_equal("spell_cast")


func test_each_spotlight_plays_its_cue_once_as_the_card_lands() -> void:
	# Arrange
	var gs := _screen()
	await await_idle_frame()
	var calls := _record(gs)
	# Act: a Spell, then the Trap answering it, queued in one batch
	gs.fx.play([_spot("cast", SPELL_ID), _spot("trap", TRAP_ID)], {})
	await await_millis(150)
	# Assert: nothing before the first card has landed, then one cue per presentation, in order
	assert_array(calls).is_empty()
	await await_millis(int((FxSpotlight.HOLD * 2.0 * UIStyle.dur(1.0)) * 1000.0) + 300)
	assert_array(calls).is_equal([["spell_cast", 0.0], ["trap_spring", 0.0]])
	gs.fx.finish_all()


func test_skipped_spotlight_plays_no_late_cue() -> void:
	var gs := _screen()
	await await_idle_frame()
	var calls := _record(gs)
	gs.fx.play([_spot("trap", TRAP_ID)], {})
	gs.fx.finish_all()   # a click skips it before the card lands
	await await_millis(int(FxSpotlight.HOLD * 1000.0) + 200)
	assert_array(calls).is_empty()


func test_reduced_motion_plays_the_calm_cue_once() -> void:
	var gs := _screen()
	await await_idle_frame()
	UIStyle.reduce_motion = true
	var calls := _record(gs)
	gs.fx.play([_spot("trap", TRAP_ID)], {})
	await await_millis(1500)
	assert_array(calls).is_equal([["trap_spring", FxSpotlight.CALM_DB]])
	gs.fx.finish_all()


## The fx events seat `viewer` receives after log seq `since` (as GameScreen collects them).
func _batch(m: MatchEngine, viewer: int, since: int) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer, since):
		out.append_array(row["fx"])
	return out


## Plays `events` on `gs`; returns [the spotlight's start, the other sounds as [t, tag]].
func _plan_sounds(gs: GameScreen, events: Array) -> Array:
	gs.fx.play(events, {})
	var spot := -1.0
	var sounds := []
	for s in gs.fx.last_plan:
		var tag := String(s["tag"])
		if tag == "spotlight":
			assert_float(spot).override_failure_message("two spotlights in one batch").is_equal(-1.0)
			spot = float(s["t"])
		elif tag.begins_with("sfx:"):
			sounds.append([float(s["t"]), tag])
	gs.fx.finish_all()
	return [spot, sounds]


## Nothing else in the batch sounds while the card is on screen: its cue is the one sound of the moment.
func _assert_alone(spot: float, sounds: Array) -> void:
	assert_float(spot).is_greater_equal(0.0)
	var on_screen := FxSpotlight.HOLD * UIStyle.dur(1.0)
	for snd in sounds:
		var t: float = snd[0]
		assert_bool(t > spot and t < spot + on_screen).override_failure_message(
			"%s at %.2f s sounds over the spotlight (%.2f s to %.2f s)" % [snd[1], t, spot, spot + on_screen]).is_false()


func test_cast_spell_cue_is_the_only_sound_while_the_card_is_shown() -> void:
	# Arrange: a real cast from the hand, read from the engine as each seat sees it
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	var keep := TB.card(m, 0, TB.FILLER)   # the card in the Hand the Spell gives Retain to
	var since := int(m.log_entries[-1]["seq"])
	# Act: cast it and choose its target (the Spell is shown once the cast is committed)
	TB.cast(m, 0, SPELL_ID)
	assert_str(TB.choose_uids(m, [keep])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	# Assert
	for viewer in [0, 1]:
		var r := _plan_sounds(gs, _batch(m, viewer, since))
		_assert_alone(r[0], r[1])


func test_sprung_trap_cue_is_the_only_sound_while_the_card_is_shown() -> void:
	# Arrange: an attack into a set Mirror Force, the attacking side controlling four cards
	var gs := _screen()
	await await_idle_frame()
	var m := TB.make()
	TB.p1_battle(m)
	var att := TB.unit(m, 1, TB.WATER, 0, "atk", 10, 10)
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "atk", 10, 10)
	var wall := TB.unit(m, 0, TB.WATER, 0, "def", 5, 40)
	TB.set_card(m, 0, TRAP_ID, 1)
	assert_str(TB.attack(m, att, wall)).is_empty()
	var since := int(m.log_entries[-1]["seq"])
	# Act: the defender springs the Trap
	assert_str(TB.choose(m, ["Activate"])).is_empty()
	while TB.pend_kind(m) == "trap_response":
		TB.choose(m, ["Skip"])
	# Assert: its destructions (and their sounds) wait until the card has gone
	for viewer in [0, 1]:
		var r := _plan_sounds(gs, _batch(m, viewer, since))
		_assert_alone(r[0], r[1])
		assert_bool((r[1] as Array).any(func(s): return s[1] == "sfx:destroy")).is_true()


func test_spotlight_cues_are_registered_and_imported() -> void:
	for n in [FxSpotlight.SOUND_SPELL, FxSpotlight.SOUND_TRAP]:
		assert_bool(Sfx.NAMES.has(n)).is_true()
		assert_bool(ResourceLoader.exists(Sfx.DIR + n + ".wav")).is_true()


func test_muted_spotlight_cue_is_silent() -> void:
	# Arrange: muted through the in-memory flag only (never the player's settings file)
	if not Sfx._loaded:
		Sfx.load_settings()
	var was: bool = Sfx._muted
	Sfx._muted = true
	var before := Sfx.debug_played.size()
	# Act
	Sfx.play(FxSpotlight.SOUND_TRAP, 0.0, 0.0)
	Sfx.play(FxSpotlight.SOUND_SPELL, 0.0, 0.0)
	# Assert
	assert_int(Sfx.debug_played.size()).is_equal(before)
	Sfx._muted = was
