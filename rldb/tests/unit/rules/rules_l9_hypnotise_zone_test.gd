extends GdUnitTestSuite
## L9 (design/owner-feedback-2026-11-05.md): "when playing hypnotise it doesn't let you decide where to
## place the unit on your side of the field, it should give you the choice". The caster picks the empty
## zone, as when placing a summon (after the target, before the cost, cancellable). At end of turn it
## goes back to its own zone (or to its owner's Spent when that zone was filled), as before.

const HYPNOTISE := 180


## Casts Hypnotise for player 0 and answers the target; the zone prompt is left open.
func _cast_at(m: MatchEngine, victim: int) -> int:
	var spell := TB.card(m, 0, HYPNOTISE)
	m.players[0]["ap"] = 10
	assert_str(m.submit(0, {"t": "cast", "uid": spell})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()
	return spell


func _control_fx(m: MatchEngine) -> Array:
	var out := []
	for e in m.log_entries:
		for fx in e["fx"]:
			if String(fx["k"]) == "control":
				out.append(fx)
	return out


func test_hypnotise_asks_for_a_zone_on_the_casters_side() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0)
	var victim := TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	_cast_at(m, victim)
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_int(int(m.pending["player"])).is_equal(0)
	assert_int(int(m.pending["placing"])).is_equal(victim)
	assert_bool(m.pending["cancellable"]).is_true()
	var slots := []
	for o in m.pending["options"]:
		slots.append(int(o["slot"]))
	assert_array(slots).is_equal([1, 2, 3, 4, 5])            # every empty zone of player 0 (0 is taken)


func test_hypnotised_unit_goes_to_the_chosen_zone() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	var spell := _cast_at(m, victim)
	assert_str(TB.choose(m, ["Back row, column 3"])).is_empty()
	assert_int(int(m.cards[victim]["ctl"])).is_equal(0)
	assert_int(int(m.cards[victim]["slot"])).is_equal(5)
	assert_int(m.players[0]["units"][5]).is_equal(victim)
	assert_int(m.players[1]["units"][1]).is_equal(-1)
	assert_str(CF.zone(m, spell)).is_equal("spent")
	assert_str(TB.log_text(m)).contains("back row, column 3")


func test_zone_choice_can_be_cancelled_before_anything_is_paid() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	var spell := _cast_at(m, victim)
	var ap := int(m.players[0]["ap"])
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_str(CF.zone(m, spell)).is_equal("hand")
	assert_int(int(m.players[0]["ap"])).is_equal(ap)
	assert_int(int(m.cards[victim]["ctl"])).is_equal(1)
	assert_int(int(m.cards[victim]["slot"])).is_equal(1)


func test_a_zone_filled_meanwhile_falls_back_to_the_first_free_zone() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	TB.unit(m, 0, TB.WATER, 0)
	var f := m.make_frame(-1, 0, [{"op": "take_control", "target": victim, "slot": "$cslot"}], "test")
	f["vars"]["cslot"] = 0                                    # chosen, then filled before it resolved
	m.push_frame(f)
	m.run()
	assert_int(int(m.cards[victim]["ctl"])).is_equal(0)
	assert_int(int(m.cards[victim]["slot"])).is_equal(1)


func test_it_returns_to_its_own_zone_at_end_of_turn() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 4, "atk", 10)
	_cast_at(m, victim)
	TB.choose(m, ["Front row, column 2"])
	TB.to_turn2(m)
	assert_int(int(m.cards[victim]["ctl"])).is_equal(1)
	assert_int(int(m.cards[victim]["slot"])).is_equal(4)
	assert_int(m.players[0]["units"][1]).is_equal(-1)


func test_control_changes_emit_presentation_events_with_their_sounds() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 4, "atk", 10)
	_cast_at(m, victim)
	TB.choose(m, ["Front row, column 2"])
	TB.to_turn2(m)
	var ev := _control_fx(m)
	assert_int(ev.size()).is_equal(2)
	assert_dict(ev[0]["from"]).is_equal({"p": 1, "zone": "unit", "slot": 4})
	assert_dict(ev[0]["to"]).is_equal({"p": 0, "zone": "unit", "slot": 1})
	assert_bool(ev[0]["back"]).is_false()
	assert_str(Sfx.for_fx(ev[0], 0)).is_equal("control_steal")
	assert_dict(ev[1]["from"]).is_equal({"p": 0, "zone": "unit", "slot": 1})
	assert_dict(ev[1]["to"]).is_equal({"p": 1, "zone": "unit", "slot": 4})
	assert_bool(ev[1]["back"]).is_true()
	assert_str(Sfx.for_fx(ev[1], 1)).is_equal("control_return")


func test_return_to_a_filled_zone_sends_it_to_spent_with_an_event() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	_cast_at(m, victim)
	TB.choose(m, ["Front row, column 3"])
	TB.unit(m, 1, TB.WATER, 0)
	TB.to_turn2(m)
	assert_str(CF.zone(m, victim)).is_equal("spent")
	var ev := _control_fx(m)
	assert_str(String(ev[-1]["dest"])).is_equal("spent")
	assert_dict(ev[-1]["to"]).is_empty()


func test_the_casters_view_shows_the_zone_choice_and_the_unit_it_places() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 2, "atk", 10)
	_cast_at(m, victim)
	var pv: Dictionary = MatchView.build(m, 0)["pending"]
	assert_str(String(pv["kind"])).is_equal("slot")
	assert_dict(pv["placing"]).is_equal({"p": 1, "zone": "unit", "slot": 2})
	assert_str(String(pv["options"][0]["zone"])).is_equal("unit")
	var wait: Dictionary = MatchView.build(m, 1)["pending"]
	assert_bool(wait["mine"]).is_false()
	assert_str(String(wait["prompt"])).contains("choosing a zone")


func test_the_bot_answers_the_zone_choice() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 2, "atk", 10)
	_cast_at(m, victim)
	var brain := BotBrain.new(0, 3)
	var cmd := brain.choose(m, 0)
	assert_str(m.submit(0, cmd)).is_empty()
	assert_int(int(m.cards[victim]["ctl"])).is_equal(0)


func test_hypnotise_still_needs_a_free_zone_and_a_legal_target() -> void:
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	for s in 6:
		TB.unit(m, 0, TB.WATER, s)
	var spell := TB.card(m, 0, HYPNOTISE)
	m.players[0]["ap"] = 10
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).contains("free zone")
