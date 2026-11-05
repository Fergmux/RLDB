extends GdUnitTestSuite
## L8 (owner feedback 2026-11-05): every status event plays its own look, sound and name (FxStatus);
## several on one card are staggered, never piled up; a Cleanse / Curse ward plays its own flash.
## Batches come from the real rules engine (MatchView.log_for), as the screen sees them.

const ALL := ["rune", "retain", "eternal", "pierce", "cleanse", "medic", "infiltrate", "nimble",
	"reveal", "burn", "paralyse", "curse", "poison", "blind", "debilitate"]


func _batch(m: MatchEngine, viewer: int, since: int) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer, since):
		for f in row["fx"]:
			out.append(f)
	return out


func _since(m: MatchEngine) -> int:
	return int(m.log_entries[-1]["seq"])


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _tags(plan: Array, prefix: String) -> Array:
	return plan.filter(func(s): return String(s["tag"]).begins_with(prefix))


func after_test() -> void:
	UIStyle.reduce_motion = false


func test_each_status_event_has_its_own_sound() -> void:
	for s in ALL:
		assert_str(FxStatus.sound_for({"k": "status", "s": s, "n": 1})).is_equal("status_" + s)
		assert_bool(s == "rune" or Sfx.NAMES.has("status_" + s)).override_failure_message(s).is_true()
	assert_str(FxStatus.sound_for({"k": "status_blocked", "s": "poison", "by": "cleanse"})).is_equal("status_blocked")
	assert_str(FxStatus.sound_for({"k": "status_tick", "s": "poison", "n": 2})).is_equal("poison_tick")
	assert_str(FxStatus.sound_for({"k": "status_tick", "s": "burn", "n": 2})).is_equal("burn_tick")
	assert_str(FxStatus.sound_for({"k": "status_tick", "s": "medic", "n": 2})).is_equal("status_medic")
	assert_str(FxStatus.sound_for({"k": "status_expire", "s": "paralyse"})).is_equal("status_expire")


func test_three_statuses_on_one_card_are_staggered_with_their_sounds() -> void:
	# Arrange: one effect applies Poison, Burn and Curse to the same unit at once.
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 0)
	var since := _since(m)
	var batch := {}
	for s in ["poison", "burn", "curse"]:
		m.apply_status(u, s, 1, batch)
	var gs := _screen()
	await await_idle_frame()
	# Act
	gs.fx.play(_batch(m, 0, since), {})
	var plan: Array = gs.fx.last_plan
	# Assert: three looks, each STAGGER after the last, each with its own cue at the same moment.
	var looks := _tags(plan, "status:")
	assert_int(looks.size()).is_equal(3)
	for i in range(1, 3):
		var gap := float(looks[i]["t"]) - float(looks[i - 1]["t"])
		assert_float(gap).is_equal_approx(FxStatus.STAGGER * UIStyle.dur(1.0), 0.01)
	for s in ["poison", "burn", "curse"]:
		var cue := _tags(plan, "sfx:status_" + s)
		var look := _tags(plan, "status:" + s)
		assert_int(cue.size()).override_failure_message(s).is_equal(1)
		assert_float(float(cue[0]["t"])).is_equal_approx(float(look[0]["t"]), 0.001)
	assert_array(_tags(plan, "sfx:debuff")).is_empty()
	gs.fx.finish_all()


func test_statuses_on_different_cards_are_not_held_back() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, TB.FILLER, 0)
	var b := TB.unit(m, 1, TB.FILLER, 1)
	var since := _since(m)
	m.apply_status(a, "poison", 1)
	m.apply_status(b, "poison", 1)
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_batch(m, 0, since), {})
	var looks := _tags(gs.fx.last_plan, "status:")
	assert_int(looks.size()).is_equal(2)
	assert_float(float(looks[1]["t"]) - float(looks[0]["t"])).is_less(FxStatus.STAGGER * 0.5)
	gs.fx.finish_all()


func test_a_ward_stopping_a_status_plays_the_blocked_flash_and_cue() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 0)
	m.cards[u]["st"]["cleanse"] = 1
	var since := _since(m)
	m.apply_status(u, "poison", 2)
	var ev := _batch(m, 0, since)
	assert_bool(ev.any(func(e): return e["k"] == "status_blocked" and e["by"] == "cleanse")).is_true()
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(ev, {})
	assert_int(_tags(gs.fx.last_plan, "status_blocked").size()).is_equal(1)
	assert_int(_tags(gs.fx.last_plan, "sfx:status_blocked").size()).is_equal(1)
	assert_array(_tags(gs.fx.last_plan, "status:")).is_empty()
	gs.fx.finish_all()


func test_every_look_draws_in_every_mode() -> void:
	# Every status, every mode, through its timeline: the art draws (no script error stops the suite).
	var host: Control = auto_free(Control.new())
	add_child(host)
	for s in ALL:
		for mode in ["apply", "tick", "blocked", "expire"]:
			for g in [false, true]:
				var art := FxStatusArt.new()
				art.key = s
				art.mode = mode
				art.ward = "curse" if s == "eternal" else "cleanse"
				art.glow = g
				art.size = Vector2(85, 128)
				host.add_child(art)
				for tv in [0.05, 0.3, 0.6, 0.95]:
					art.t = tv
	await await_idle_frame()
	await await_idle_frame()
	assert_int(host.get_child_count()).is_equal(ALL.size() * 8)


func test_reduce_motion_plays_no_travel_or_particles() -> void:
	UIStyle.reduce_motion = true
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 0)
	var since := _since(m)
	m.apply_status(u, "poison", 1)
	m.apply_status(u, "burn", 1)
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_batch(m, 0, since), {})
	var looks := _tags(gs.fx.last_plan, "status:")
	assert_int(looks.size()).is_equal(2)
	# Under reduce motion the stagger is a short beat, not the full STAGGER.
	assert_float(float(looks[1]["t"]) - float(looks[0]["t"])).is_less(FxStatus.STAGGER * UIStyle.dur(1.0))
	await get_tree().create_timer(0.3).timeout
	assert_array(gs.fx_layer.find_children("*", "FxStatusArt", true, false)).is_empty()
	gs.fx.finish_all()
