extends GdUnitTestSuite
## L20 (design/owner-feedback-2026-11-05.md): when one effect applies several Debuffs to a unit at the
## same time, 1 Cleanse stack prevents all of them and then decrements once; the same for Curse
## against Buffs. Separate units, and separate effects, are independent. Each prevention emits a
## "status_blocked" presentation event.

const FROST_WYVERN := 32        # once per turn: 1 Paralyse and 4 Burn to a unit in this column
const GEOLOCK := 57             # second ability: 1 Infiltrate and 1 Nimble to a unit
const NECRO := 188              # doubles its Debuffs, then applies them to an opponent's unit


## Resolves one effect of player 0 made of `ops`.
func _resolve(m: MatchEngine, ops: Array) -> void:
	m.push_frame(m.make_frame(-1, 0, ops, "test"))
	m.run()


func _st(target, s: String, n: int = 1) -> Dictionary:
	return {"op": "status", "target": target, "s": s, "n": n}


## The status_blocked events attached to the log so far, in order.
func _blocked_fx(m: MatchEngine) -> Array:
	var out := []
	for e in m.log_entries:
		for fx in e["fx"]:
			if String(fx["k"]) == "status_blocked":
				out.append(fx)
	return out


func test_one_cleanse_prevents_every_debuff_of_one_effect_then_decrements_once() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "paralyse"), _st(u, "burn", 4)])
	assert_int(m.status_count(u, "paralyse")).is_equal(0)
	assert_int(m.status_count(u, "burn")).is_equal(0)
	assert_int(m.status_count(u, "cleanse")).is_equal(0)


func test_one_curse_prevents_every_buff_of_one_effect_then_decrements_once() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "curse", 1)
	_resolve(m, [_st(u, "infiltrate"), _st(u, "nimble"), _st(u, "cleanse")])
	assert_int(m.status_count(u, "infiltrate")).is_equal(0)
	assert_int(m.status_count(u, "nimble")).is_equal(0)
	assert_int(m.status_count(u, "cleanse")).is_equal(0)
	assert_int(m.status_count(u, "curse")).is_equal(0)


func test_cleanse_also_prevents_a_curse_applied_with_other_debuffs() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "curse"), _st(u, "poison", 3)])
	assert_int(m.status_count(u, "curse")).is_equal(0)
	assert_int(m.status_count(u, "poison")).is_equal(0)
	assert_int(m.status_count(u, "cleanse")).is_equal(0)


func test_a_second_cleanse_stack_survives_one_batch() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 2)
	_resolve(m, [_st(u, "blind"), _st(u, "burn", 2)])
	assert_int(m.status_count(u, "cleanse")).is_equal(1)
	assert_int(m.status_count(u, "blind")).is_equal(0)


func test_separate_effects_are_prevented_separately() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "paralyse")])
	_resolve(m, [_st(u, "burn", 4)])
	assert_int(m.status_count(u, "paralyse")).is_equal(0)
	assert_int(m.status_count(u, "burn")).is_equal(4)


func test_each_unit_is_handled_independently() -> void:
	var m := TB.make()
	var a := TB.unit(m, 1, TB.WATER, 0)
	var b := TB.unit(m, 1, TB.WATER, 1)
	var c := TB.unit(m, 1, TB.WATER, 2)
	m.apply_status(a, "cleanse", 1)
	m.apply_status(b, "cleanse", 1)
	_resolve(m, [{"op": "all", "sel": {"kind": "unit", "side": "opp"}, "as": "all"}, _st("$all", "burn", 6), _st("$all", "blind")])
	for u in [a, b]:
		assert_int(m.status_count(u, "cleanse")).is_equal(0)
		assert_int(m.status_count(u, "burn")).is_equal(0)
		assert_int(m.status_count(u, "blind")).is_equal(0)
	assert_int(m.status_count(c, "burn")).is_equal(6)
	assert_int(m.status_count(c, "blind")).is_equal(1)


func test_buffs_of_the_same_effect_are_not_stopped_by_cleanse() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "burn", 2), _st(u, "pierce")])
	assert_int(m.status_count(u, "pierce")).is_equal(1)
	assert_int(m.status_count(u, "burn")).is_equal(0)


func test_frost_wyvern_paralyse_and_burn_are_both_prevented_by_one_cleanse() -> void:
	var m := TB.make()
	var wyvern := TB.unit(m, 0, FROST_WYVERN, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(foe, "cleanse", 1)
	assert_str(TB.ability(m, wyvern)).is_empty()
	assert_str(TB.choose_uids(m, [foe])).is_empty()
	assert_int(m.status_count(foe, "paralyse")).is_equal(0)
	assert_int(m.status_count(foe, "burn")).is_equal(0)
	assert_int(m.status_count(foe, "cleanse")).is_equal(0)


func test_geolock_infiltrate_and_nimble_are_both_prevented_by_one_curse() -> void:
	var m := TB.make()
	var geo := TB.unit(m, 0, GEOLOCK, 0)
	var own := TB.unit(m, 0, TB.WATER, 1)
	m.apply_status(own, "curse", 1)
	assert_str(TB.ability(m, geo, 1)).is_empty()
	assert_str(TB.choose_uids(m, [own])).is_empty()
	assert_int(m.status_count(own, "infiltrate")).is_equal(0)
	assert_int(m.status_count(own, "nimble")).is_equal(0)
	assert_int(m.status_count(own, "curse")).is_equal(0)


func test_necro_spread_debuffs_are_all_prevented_by_one_cleanse() -> void:
	var m := TB.make()
	var necro := TB.unit(m, 0, NECRO, 0)
	m.cards[necro]["st"] = {"burn": 2, "poison": 3}
	var foe := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(foe, "cleanse", 1)
	assert_str(TB.ability(m, necro)).is_empty()
	assert_str(TB.choose_uids(m, [foe])).is_empty()
	assert_int(m.status_count(foe, "burn")).is_equal(0)
	assert_int(m.status_count(foe, "poison")).is_equal(0)
	assert_int(m.status_count(foe, "cleanse")).is_equal(0)


func test_each_prevention_emits_a_status_blocked_event() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 4)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "paralyse"), _st(u, "burn", 4)])
	var ev := _blocked_fx(m)
	assert_int(ev.size()).is_equal(2)
	assert_dict(ev[0]["at"]).is_equal({"p": 1, "zone": "unit", "slot": 4})
	assert_str(String(ev[0]["by"])).is_equal("cleanse")
	assert_str(String(ev[0]["s"])).is_equal("paralyse")
	assert_bool(ev[0]["used"]).is_true()
	assert_str(String(ev[1]["s"])).is_equal("burn")
	assert_int(int(ev[1]["n"])).is_equal(4)
	assert_bool(ev[1]["used"]).is_false()


func test_curse_prevention_event_names_curse() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 2)
	m.apply_status(u, "curse", 1)
	_resolve(m, [_st(u, "eternal")])
	var ev := _blocked_fx(m)
	assert_int(ev.size()).is_equal(1)
	assert_str(String(ev[0]["by"])).is_equal("curse")
	assert_str(String(ev[0]["s"])).is_equal("eternal")


func test_the_event_reaches_both_seats_views_of_the_log() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "cleanse", 1)
	_resolve(m, [_st(u, "blind")])
	for viewer in [0, 1]:
		var seen := false
		for row in MatchView.build(m, viewer)["log"]:
			for fx in row.get("fx", []):
				seen = seen or String(fx["k"]) == "status_blocked"
		assert_bool(seen).is_true()
