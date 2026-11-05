extends GdUnitTestSuite
## F03-13 / F03-16 / F03-17 presentation routing and privacy: destroy and Exhaust events are different,
## a hidden card's identity never reaches the seat that may not see it, and the game-end hold only
## exists for a view that carries a game_over event (so a resynced, already-over view plays nothing).


func _fx_of(m: MatchEngine, viewer: int, kind: String) -> Array:
	var out := []
	for e in MatchView.log_for(m, viewer):
		for f in e["fx"]:
			if f["k"] == kind:
				out.append(f)
	return out


func test_destroy_and_exhaust_are_different_events_and_sounds() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var victim := TB.unit(m, 0, TB.WATER, 0)
	m.destroy(victim, "effect", -1, 1)
	var d := _fx_of(m, 0, "destroy")
	assert_int(d.size()).is_equal(1)
	assert_str(String(d[0]["dest"])).is_equal("spent")
	assert_array(_fx_of(m, 0, "exhaust")).is_empty()
	assert_str(Sfx.for_fx(d[0], 0)).is_equal("destroy")
	assert_str(Sfx.for_fx({"k": "destroy", "dest": "exhaust"}, 0)).is_equal("exhaust")
	assert_str(Sfx.for_fx({"k": "exhaust", "p": 0, "from": "spent"}, 0)).is_equal("exhaust")


func test_exhaust_event_identifies_card_to_owner_and_caster() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var caster: int = m.active
	var owner := 1 - caster
	TB.card(m, owner, 36, "spent")
	TB.cast(m, caster, 101)
	assert_str(TB.choose(m, ["Dante"])).is_empty()
	var mine := _fx_of(m, caster, "exhaust")
	var theirs := _fx_of(m, owner, "exhaust")
	assert_int(mine.size()).is_equal(1)
	assert_int(int(mine[0]["id"])).is_equal(36)
	assert_int(int(theirs[0]["id"])).is_equal(36)
	assert_bool(mine[0].has("seen_by")).is_false()


func test_redact_fx_hides_identity_from_unauthorised_seat() -> void:
	var ev := [{"k": "material", "p": 0, "from": "spent", "id": 172, "seen_by": [0]}, {"k": "turn", "p": 0}]
	var own := MatchView.redact_fx(ev, 0)
	var other := MatchView.redact_fx(ev, 1)
	assert_int(int(own[0]["id"])).is_equal(172)
	assert_bool(other[0].has("id")).is_false()
	assert_bool(other[0].has("seen_by")).is_false()
	assert_int(int(ev[0]["id"])).is_equal(172)   # the authority-side event is untouched
	assert_array(MatchView.redact_fx([{"k": "turn"}], 1)).has_size(1)


func test_arcane_materials_from_spent_are_anonymous_to_the_opponent() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var p: int = m.active
	TB.card(m, p, TB.WATER, "spent")
	TB.card(m, p, TB.FIRE, "spent")
	var ar := TB.card(m, p, 171, "extra")                    # Flying Sandworm 2A (Tyde is 3A since 2026-11-03)
	m.players[p]["ap"] = 5
	assert_str(m.submit(p, {"t": "arcane", "uid": ar})).is_empty()
	var pd := m.pending
	m.submit(p, {"t": "choose", "id": pd["id"], "indices": range(pd["options"].size())})
	var guard := 0
	while not m.pending.is_empty() and guard < 6:
		guard += 1
		var q := m.pending
		m.submit(q["player"], {"t": "choose", "id": q["id"], "indices": [0]})
	var seen := _fx_of(m, p, "material")
	var hidden := _fx_of(m, 1 - p, "material")
	assert_int(seen.size()).is_equal(2)
	assert_str(String(seen[0]["kind"])).is_equal("arcane")
	assert_str(String(seen[0]["to"])).is_equal("exhaust")
	assert_bool(seen[0].has("id")).is_true()
	assert_int(hidden.size()).is_equal(2)
	for h in hidden:
		assert_bool(h.has("id")).is_false()


func test_game_end_hold_only_for_a_view_with_game_over() -> void:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await await_idle_frame()
	var p := gs.fx
	p.expect_game_end([{"k": "turn", "p": 0, "turn": 3}])
	assert_bool(p.game_end_hold).is_false()   # a resynced, already-over view has no game_over event
	p.expect_game_end([{"k": "hp", "p": 0, "d": -3}, {"k": "game_over", "winner": 1}])
	assert_bool(p.game_end_hold).is_true()
	p.release_game_end_hold()
	assert_bool(p.game_end_hold).is_false()
	p.release_game_end_hold()   # idempotent
	assert_bool(p.game_end_hold).is_false()


func test_game_end_lengths_distinguish_series_from_game() -> void:
	assert_float(FxGameEnd.length_for(true, true)).is_greater(FxGameEnd.length_for(true, false))
	assert_float(FxGameEnd.length_for(false, true)).is_greater(FxGameEnd.length_for(false, false))
