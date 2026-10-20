extends GdUnitTestSuite
## D8 / B5 / D6 (owner feedback 2026-10-20): the set pieces keep the FX queue in step with the log.
## A Fusion / Ritual / Arcane summon plays one set piece that holds the rest of its batch for its full
## length (never compressed), the Divine Serpents' strike owns its damage and destructions, a sacrifice
## plays before the AP it gives, and every HP / AP change has exactly one sound, for both seats.
## Batches come from the real rules engine (MatchView.log_for), as the screen and the network see them.

const SOUL := 160


func _batch(m: MatchEngine, viewer: int, since: int) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer, since):
		for f in row["fx"]:
			out.append(f)
	return out


func _since(m: MatchEngine) -> int:
	return int(m.log_entries[-1]["seq"])


func _answer_all(m: MatchEngine) -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		var pd := m.pending
		var n: int = pd["options"].size()
		var want: int = n if int(pd.get("min_total", 0)) > 0 else maxi(int(pd["min"]), 1)
		m.submit(pd["player"], {"t": "choose", "id": pd["id"], "indices": range(mini(want, n))})


## A special summon of `kind` through the real command flow; returns [engine, batch since the command].
func _special(kind: String) -> Array:
	var m := TB.make()
	TB.to_turn2(m)
	var a: int = m.active
	m.players[a]["ap"] = 6
	var since := 0
	match kind:
		"fusion":
			var mag := TB.unit(m, a, 69, 0)
			TB.unit(m, a, 34, 1)
			TB.card(m, a, 142, "extra")
			since = _since(m)
			assert_str(m.submit(a, {"t": "ability", "uid": mag, "idx": 0})).is_empty()
		"ritual":
			var u := TB.unit(m, a, 1, 0)
			m.apply_status(u, "rune", 1)
			var r := TB.card(m, a, 98, "extra")
			since = _since(m)
			assert_str(m.submit(a, {"t": "ritual", "uid": r})).is_empty()
		"arcane":
			TB.card(m, a, 1, "spent")
			TB.card(m, a, 110, "spent")
			var ar := TB.card(m, a, 172, "extra")
			since = _since(m)
			assert_str(m.submit(a, {"t": "arcane", "uid": ar})).is_empty()
	_answer_all(m)
	return [m, since]


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _tags(plan: Array, prefix: String) -> Array:
	return plan.filter(func(s): return String(s["tag"]).begins_with(prefix))


# ---------------------------------------------------------------- B5: the Serpent strike

func _serpent_events() -> Array:
	var m := TB.make()
	TB.unit(m, 0, 158, 0)
	TB.unit(m, 0, 159, 1)
	var since := _since(m)
	TB.summon(m, 0, SOUL, 4)
	return _batch(m, 0, since)


func test_serpent_batch_is_detected_as_the_serpent_strike() -> void:
	var info := FxSerpent.detect(_serpent_events())
	assert_bool(info.is_empty()).is_false()
	assert_int(int(info["p"])).is_equal(0)
	assert_int(int(info["opp"])).is_equal(1)
	assert_int(int(info["d"])).is_equal(30)
	assert_int((info["destroys"] as Array).size()).is_equal(3)


func test_other_damage_and_destruction_is_not_the_serpent_strike() -> void:
	var ev := [{"k": "hp", "p": 1, "d": -30},
		{"k": "destroy", "at": {"p": 0, "zone": "unit", "slot": 0}, "id": 1, "dest": "spent"},
		{"k": "destroy", "at": {"p": 0, "zone": "unit", "slot": 1}, "id": 1, "dest": "spent"}]
	assert_dict(FxSerpent.detect(ev, func(_id: int) -> String: return "Basic Mage")).is_empty()
	# one Serpent alone is not the strike, nor are destructions without a public identity
	var one := [ev[0], {"k": "destroy", "at": {"p": 0, "zone": "unit", "slot": 0}, "id": SOUL}]
	assert_dict(FxSerpent.detect(one)).is_empty()
	var anon := [ev[0], {"k": "destroy", "at": {"p": 0, "zone": "unit", "slot": 0}}, {"k": "destroy", "at": {"p": 0, "zone": "unit", "slot": 1}}]
	assert_dict(FxSerpent.detect(anon, func(_id: int) -> String: return "Divine Serpent - Head")).is_empty()


func test_serpent_strike_owns_its_damage_and_destructions_once() -> void:
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_serpent_events(), {})
	var plan: Array = gs.fx.last_plan
	assert_int(_tags(plan, "serpent").size()).is_equal(1)
	assert_array(_tags(plan, "hp:")).is_empty()           # no plain HP floater: the strike shows it
	assert_array(_tags(plan, "destroy")).is_empty()       # no plain destructions: the strike consumes them
	assert_array(_tags(plan, "sfx:damage")).is_empty()    # its impact plays the damage sound itself
	assert_array(_tags(plan, "sfx:destroy")).is_empty()
	gs.fx.finish_all()


func test_lethal_serpent_strike_replaces_the_final_blow_flourish() -> void:
	# the 30 damage ends the game: the strike plays and starts the victory look itself
	var ev := _serpent_events()
	ev.append({"k": "game_over", "winner": 0})
	var gs := _screen()
	await await_idle_frame()
	gs.fx.expect_game_end(ev)
	gs.fx.play(ev, {})
	var plan: Array = gs.fx.last_plan
	assert_int(_tags(plan, "serpent").size()).is_equal(1)
	assert_array(_tags(plan, "flourish")).is_empty()
	assert_array(_tags(plan, "game_end")).is_empty()
	assert_bool(gs.fx.game_end_hold).is_true()
	gs.fx.finish_all()
	assert_bool(gs.fx.game_end_hold).is_false()


func test_serpent_strike_restores_the_hp_bar_when_skipped() -> void:
	var gs := _screen()
	await await_idle_frame()
	var pl: PlayerPlate = gs.plate_of(1)
	pl.hp_bar.set_hp(30, true)          # the final state the board shows
	gs.fx.play(_serpent_events(), {})
	await await_millis(int(_wait_ms()))
	assert_int(pl.hp_bar.hp).is_equal(30)
	gs.fx.finish_all()
	assert_int(pl.hp_bar.hp).is_equal(30)
	assert_float(pl.hp_bar.shown).is_equal(30.0)


## Real milliseconds into the strike (past the Soul arrival, before the impact).
func _wait_ms() -> float:
	return (FxPlayer.TRANSIENT_HOLD + 0.3) * 1000.0 * UIStyle.dur(1.0)


# ---------------------------------------------------------------- D8: special-summon set pieces

func test_each_special_summon_plays_one_set_piece_that_holds_its_batch() -> void:
	for kind in ["fusion", "ritual", "arcane"]:
		var r := _special(kind)
		var m: MatchEngine = r[0]
		var ev := _batch(m, m.active, int(r[1]))
		assert_int(ev.filter(func(e): return e["k"] == "material").size()).is_greater(0)
		var gs := _screen()
		await await_idle_frame()
		gs.fx.play(ev, {})
		var plan: Array = gs.fx.last_plan
		var sp := _tags(plan, "set_piece:" + kind)
		assert_int(sp.size()).is_equal(1)
		assert_array(_tags(plan, "material")).is_empty()   # materials are drawn in by the set piece
		# everything scheduled after the set piece starts once it has played in full
		var start := float(sp[0]["t"])
		var idx := plan.find(sp[0])
		for i in range(idx + 1, plan.size()):
			assert_float(float(plan[i]["t"])).is_greater_equal(start + FxSummon.length_for(kind) * UIStyle.dur(1.0) - 0.001)
		gs.fx.finish_all()
		gs.queue_free()


func test_set_pieces_are_distinct_and_have_their_own_sounds() -> void:
	var seen := {}
	for kind in ["fusion", "ritual", "arcane"]:
		for snd in [FxSummon.SOUND_CHARGE[kind], FxSummon.SOUND_CLIMAX[kind]]:
			assert_bool(Sfx.NAMES.has(snd)).is_true()
			assert_bool(ResourceLoader.exists(Sfx.DIR + String(snd) + ".wav")).is_true()
			assert_bool(seen.has(snd)).is_false()
			seen[snd] = true
		assert_float(FxSummon.length_for(kind)).is_between(1.2, 2.0)
		assert_float(FxSummon.land_time(kind)).is_less(FxSummon.length_for(kind))
	assert_bool(Sfx.NAMES.has(FxSummon.SOUND_SLAM)).is_true()


func test_set_piece_skips_cleanly_on_click() -> void:
	var r := _special("fusion")
	var m: MatchEngine = r[0]
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_batch(m, m.active, int(r[1])), {})
	await await_millis(300)
	assert_bool(gs.fx.busy()).is_true()
	gs.fx.finish_all()
	assert_bool(gs.fx.busy()).is_false()
	await await_idle_frame()
	for n in gs.fx_layer.get_children():
		assert_bool(n.is_queued_for_deletion() or not (n is FxSummonArt or n is CardWidget)).is_true()


# ---------------------------------------------------------------- D6: sacrifice and resource sounds

func _sacrifice_batch(viewer: int) -> Array:
	var m := TB.make()
	TB.to_turn2(m)
	var a: int = m.active
	var u := TB.unit(m, a, TB.WATER, 2)
	var since := _since(m)
	assert_str(m.submit(a, {"t": "sacrifice", "uid": u})).is_empty()
	_answer_all(m)
	return _batch(m, viewer if viewer >= 0 else a, since)


func test_sacrifice_is_a_presentation_event_before_its_ap() -> void:
	var ev := _sacrifice_batch(-1)
	var ks := ev.map(func(e): return String(e["k"]))
	assert_bool(ks.has("sacrifice")).is_true()
	assert_int(ks.find("sacrifice")).is_less(ks.find("ap"))
	var s: Dictionary = ev[ks.find("sacrifice")]
	assert_int(int(s["id"])).is_equal(TB.WATER)
	assert_int(int(s["at"]["slot"])).is_equal(2)


func test_sacrifice_plays_then_the_ap_gain_lands_with_its_embers_for_both_seats() -> void:
	for viewer in [1, 0]:   # turn 2: seat 1 sacrifices; seat 0 is the opponent watching
		var gs := _screen()
		await await_idle_frame()
		gs.fx.play(_sacrifice_batch(viewer), {})
		var plan: Array = gs.fx.last_plan
		var sac := _tags(plan, "sacrifice:")
		var ap := _tags(plan, "ap:")
		assert_int(sac.size()).is_equal(1)
		assert_int(ap.size()).is_equal(1)
		assert_float(float(ap[0]["t"]) - float(sac[0]["t"])).is_greater_equal(FxPileEffects.SACRIFICE_TO_AP * UIStyle.dur(1.0) * 0.99)   # a short batch: never compressed
		assert_int(_tags(plan, "sfx:sacrifice").size()).is_equal(1)
		assert_int(_tags(plan, "sfx:ap_gain").size()).is_equal(1)
		gs.fx.finish_all()
		gs.queue_free()


func test_every_hp_and_ap_change_has_exactly_one_sound() -> void:
	var ev := [{"k": "hp", "p": 0, "d": -4}, {"k": "hp", "p": 1, "d": 6}, {"k": "ap", "p": 0, "d": 2}, {"k": "ap", "p": 1, "d": -1}]
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(ev, {})
	var plan: Array = gs.fx.last_plan
	assert_int(_tags(plan, "sfx:damage").size()).is_equal(1)
	assert_int(_tags(plan, "sfx:heal").size()).is_equal(1)
	assert_int(_tags(plan, "sfx:ap_gain").size()).is_equal(1)
	assert_int(_tags(plan, "sfx:ap_loss").size()).is_equal(1)
	assert_int(_tags(plan, "hp:").size()).is_equal(2)
	assert_int(_tags(plan, "ap:").size()).is_equal(2)
	assert_int(_tags(plan, "sfx:").size()).is_equal(4)
	gs.fx.finish_all()


func test_resource_sounds_map_and_exist() -> void:
	assert_str(Sfx.for_fx({"k": "ap", "p": 0, "d": 1}, 0)).is_equal("ap_gain")
	assert_str(Sfx.for_fx({"k": "ap", "p": 1, "d": -2}, 0)).is_equal("ap_loss")
	assert_str(Sfx.for_fx({"k": "ap", "p": 1, "d": 0}, 0)).is_equal("")
	assert_str(Sfx.for_fx({"k": "sacrifice", "p": 0}, 1)).is_equal("sacrifice")
	assert_str(Sfx.for_fx({"k": "hp", "p": 1, "d": 3}, 0)).is_equal("heal")
	assert_str(Sfx.for_fx({"k": "hp", "p": 1, "d": -3}, 0)).is_equal("damage")
	for n in ["ap_gain", "ap_loss", "sacrifice", "serpent_coil", "serpent_strike", "heal", "damage"]:
		assert_bool(ResourceLoader.exists(Sfx.DIR + n + ".wav")).is_true()
