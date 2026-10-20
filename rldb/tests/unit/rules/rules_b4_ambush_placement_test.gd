extends GdUnitTestSuite
## Owner feedback 2026-10-20 B4: Ambush ("Summon as many Basic Units as possible from your Hand
## and Draw.") asks a zone for each Basic Unit it summons, with the ordinary zone prompt, one unit
## at a time. B3 applies to each: Attack stance in the caster's Setup or Recovery Phase, a stance
## prompt in the Battle Phase.

const AMBUSH := 42
const BASIC_BEAST := 4


func test_ambush_asks_a_zone_for_each_unit_and_places_it_there() -> void:
	var m := TB.make(7, 4)                               # small Draw: 4 filler Basic Mages (all drawn)
	for u in m.players[0]["hand"].duplicate():
		m.move_to_pile(u, "spent")
	var a := TB.card(m, 0, TB.WATER)
	var b := TB.card(m, 0, BASIC_BEAST)
	TB.cast(m, 0, AMBUSH)
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_int(int(m.pending["placing"])).is_equal(a)
	assert_int(m.pending["options"].size()).is_equal(6)
	assert_str(TB.choose(m, [TB.slot_label(4)])).is_empty()
	assert_str(m.cards[a]["zone"]).is_equal("unit")
	assert_int(int(m.cards[a]["slot"])).is_equal(4)
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_int(int(m.pending["placing"])).is_equal(b)
	assert_int(m.pending["options"].size()).is_equal(5)   # the zone just used is gone
	assert_str(TB.choose(m, [TB.slot_label(2)])).is_empty()
	assert_int(int(m.cards[b]["slot"])).is_equal(2)
	assert_str(TB.pend_kind(m)).is_empty()                # no Basic Units left
	assert_str(m.cards[a]["stance"]).is_equal("atk")
	assert_str(m.cards[b]["stance"]).is_equal("atk")


func test_ambush_stops_when_the_zones_are_full() -> void:
	var m := TB.make()
	TB.cast(m, 0, AMBUSH)
	var asked := 0
	while TB.pend_kind(m) == "slot" and asked < 10:
		asked += 1
		var pd := m.pending
		assert_str(m.submit(0, {"t": "choose", "id": pd["id"], "indices": [pd["options"].size() - 1]})).is_empty()
	assert_int(asked).is_equal(6)
	assert_int(m.field_units(0).size()).is_equal(6)


func test_set_ambush_activated_in_the_battle_phase_asks_each_stance() -> void:
	var m := TB.make(7, 4)
	TB.p1_battle(m)
	for u in m.players[1]["hand"].duplicate():
		m.move_to_pile(u, "spent")
	m.players[1]["draw"].clear()
	var a := TB.card(m, 1, TB.WATER)
	var sc := TB.set_card(m, 1, AMBUSH, 0)
	assert_str(m.submit(1, {"t": "activate_set", "uid": sc})).is_empty()
	assert_str(TB.choose(m, [TB.slot_label(0)])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("stance")
	assert_str(TB.choose(m, ["Defense"])).is_empty()
	assert_str(m.cards[a]["stance"]).is_equal("def")


func test_bot_answers_each_ambush_zone_prompt() -> void:
	var m := TB.make()
	var bot := BotBrain.new(0, 4)
	TB.cast(m, 0, AMBUSH)
	var zone_answers := 0
	var steps := 0
	while not m.pending.is_empty() and steps < 20:
		steps += 1
		if TB.pend_kind(m) == "slot":
			zone_answers += 1
		var cmd := bot.decide(m)
		assert_str(m.submit(0, cmd)).is_empty()
	assert_int(zone_answers).is_equal(6)
	assert_int(m.field_units(0).size()).is_equal(6)
