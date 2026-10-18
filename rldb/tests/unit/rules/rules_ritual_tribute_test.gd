extends GdUnitTestSuite
## Owner feedback 2026-10-18: a unit with enough Runes for a Ritual unit it could summon offers
## "Ritual Tribute"; it runs that Ritual summon with this unit as the tributed material.

const CREEPING_NULL := 65          # Ritual unit, 3 Runes
const BASIC_BEAST := 4


func _tribute_actions(m: MatchEngine, p: int, uid: int) -> Array:
	return MatchView.actions_for(m, p).filter(func(a): return a["t"] == "ritual_tribute" and int(a["uid"]) == uid)


func test_a_unit_with_enough_runes_offers_ritual_tribute() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	var short := TB.unit(m, 0, BASIC_BEAST, 1)
	m.apply_status(mat, "rune", 3)
	m.apply_status(short, "rune", 2)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	var acts := _tribute_actions(m, 0, mat)
	assert_int(acts.size()).is_equal(1)
	assert_str(String(acts[0]["label"])).is_equal("Ritual Tribute")
	assert_int(int(acts[0]["target"])).is_equal(null_u)
	assert_bool(acts[0]["ok"]).is_true()
	assert_array(_tribute_actions(m, 0, short)).is_empty()


func test_ritual_tribute_summons_the_ritual_unit_with_that_material() -> void:
	var m := TB.make()
	var other := TB.unit(m, 0, BASIC_BEAST, 1)
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(other, "rune", 3)
	m.apply_status(mat, "rune", 3)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	assert_str(m.submit(0, {"t": "ritual_tribute", "uid": mat, "target": null_u})).is_empty()
	# No material choice: straight to the zone, then the stance.
	assert_str(TB.pend_kind(m)).is_equal("slot")
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	while not m.pending.is_empty():
		CF.decline(m)                                           # The Creeping Null's own prompts
	assert_str(m.cards[null_u]["zone"]).is_equal("unit")
	assert_str(m.cards[mat]["zone"]).is_not_equal("unit")
	assert_str(m.cards[other]["zone"]).is_equal("unit")


func test_ritual_tribute_rejects_a_unit_without_enough_runes() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 2)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	assert_str(m.validate(0, {"t": "ritual_tribute", "uid": mat, "target": null_u})).is_not_empty()


func test_ritual_tribute_target_from_a_remote_client_is_accepted() -> void:
	assert_str(NetSession.sanitize_command({"t": "ritual_tribute", "uid": 3, "target": 9.0})).is_empty()
	assert_str(NetSession.sanitize_command({"t": "ritual_tribute", "uid": 3, "target": "x"})).is_not_empty()
