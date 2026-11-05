extends GdUnitTestSuite
## L8 (owner feedback 2026-11-05): the rules emit presentation events for statuses paying out
## ("status_tick": Poison, Burn, Medic) and wearing off ("status_expire"), so the board can show them.

func _fx_since(m: MatchEngine, since: int) -> Array:
	var out := []
	for e in m.log_entries:
		if int(e["seq"]) >= since:   # add_fx may attach to the latest entry
			out.append_array(e["fx"])
	return out


func _kinds(ev: Array) -> Array:
	return ev.map(func(e): return String(e["k"]))


func test_poison_ticks_before_its_damage_then_wears_off_at_one() -> void:
	# Arrange: the active player's unit carries 1 Poison.
	var m := TB.make()
	var p: int = m.active
	var u := TB.unit(m, p, TB.FILLER, 0)
	m.cards[u]["st"]["poison"] = 1
	var since := int(m.log_entries[-1]["seq"])
	# Act: end the turn (Main 1 -> Main 2 -> end).
	m.submit(p, {"t": "next_phase"})
	m.submit(p, {"t": "next_phase"})
	# Assert
	var ev := _fx_since(m, since)
	var k := _kinds(ev)
	var ti := k.find("status_tick")
	assert_int(ti).is_greater_equal(0)
	assert_str(String(ev[ti]["s"])).is_equal("poison")
	assert_int(int(ev[ti]["n"])).is_equal(1)
	assert_int(k.find("hp", ti)).is_greater(ti)
	var xi := k.find("status_expire")
	assert_int(xi).is_greater(k.find("hp", ti))
	assert_str(String(ev[xi]["s"])).is_equal("poison")
	assert_dict(ev[xi]["at"]).is_equal({"p": p, "zone": "unit", "slot": 0})


func test_a_status_still_running_does_not_expire() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.FILLER, 0)
	m.cards[u]["st"]["paralyse"] = 2
	var since := int(m.log_entries[-1]["seq"])
	m.decrement_status(u, "paralyse")
	assert_bool(_kinds(_fx_since(m, since)).has("status_expire")).is_false()
	m.decrement_status(u, "paralyse")
	assert_bool(_kinds(_fx_since(m, since)).has("status_expire")).is_true()


func test_no_expire_event_for_a_card_off_the_field() -> void:
	# Retain on a hand card is private to its owner: no presentation event.
	var m := TB.make()
	var h := TB.card(m, 0, TB.FILLER, "hand")
	m.cards[h]["st"]["retain"] = 1
	var since := int(m.log_entries[-1]["seq"])
	m.decrement_status(h, "retain")
	assert_bool(_kinds(_fx_since(m, since)).has("status_expire")).is_false()


func test_medic_ticks_at_the_start_of_its_controllers_turn() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 0)
	m.cards[u]["st"]["medic"] = 2
	var since := int(m.log_entries[-1]["seq"])
	TB.to_turn2(m)
	var ev := _fx_since(m, since).filter(func(e): return e["k"] == "status_tick")
	assert_int(ev.size()).is_equal(1)
	assert_str(String(ev[0]["s"])).is_equal("medic")
	assert_int(int(ev[0]["n"])).is_equal(2)


func test_burn_ticks_when_its_unit_attacks() -> void:
	var m := TB.make()
	TB.to_battle(m)
	var p: int = m.active
	var a := TB.unit(m, p, TB.FILLER, 0)
	m.cards[a]["st"]["burn"] = 3
	var target := TB.unit(m, 1 - p, TB.FILLER, 0, "atk", 1, 1)   # loses: the burning attacker stays
	var since := int(m.log_entries[-1]["seq"])
	assert_str(TB.attack(m, a, target)).is_empty()
	var ev := _fx_since(m, since).filter(func(e): return e["k"] == "status_tick")
	assert_int(ev.size()).is_equal(1)
	assert_str(String(ev[0]["s"])).is_equal("burn")
	assert_int(int(ev[0]["n"])).is_equal(3)
