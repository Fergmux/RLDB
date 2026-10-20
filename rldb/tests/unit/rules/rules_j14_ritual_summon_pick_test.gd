extends GdUnitTestSuite
## J14 (owner feedback 2026-10-22): a unit that can be tributed for a Ritual summon offers ONE
## "Ritual Summon" button, never the Ritual unit's name, however many Ritual units it could become.
## Pressing it opens the card select tray (a "select" choice over the Extra Deck) to pick the unit;
## with a single candidate the tray still asks, so the flow is always the same.

const CREEPING_NULL := 65          # Ritual unit, 3 Runes
const MIMIC := 95                  # Ritual unit, 2 Runes
const LEGENDARY_SWORDSMAN := 97    # Ritual unit, 4 Runes
const BASIC_BEAST := 4


func _tribute_actions(m: MatchEngine, p: int, uid: int) -> Array:
	return MatchView.actions_for(m, p).filter(func(a): return a["t"] == "ritual_tribute" and int(a["uid"]) == uid)


## A unit with 3 Runes and an Extra Deck holding Creeping Null (3), Mimic (2) and Swordsman (4).
func _board() -> Dictionary:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	var mimic := TB.card(m, 0, MIMIC, "extra")
	var sword := TB.card(m, 0, LEGENDARY_SWORDSMAN, "extra")
	return {"m": m, "mat": mat, "null": null_u, "mimic": mimic, "sword": sword}


func test_several_ritual_targets_give_one_ritual_summon_button() -> void:
	var b := _board()
	var acts := _tribute_actions(b["m"], 0, b["mat"])
	assert_int(acts.size()).is_equal(1)
	assert_str(String(acts[0]["label"])).is_equal("Ritual Summon")
	assert_bool(acts[0].has("target")).is_false()
	assert_bool(bool(acts[0]["ok"])).is_true()


func test_ritual_summon_button_opens_the_card_select_tray_of_valid_targets() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	assert_str(m.submit(0, {"t": "ritual_tribute", "uid": b["mat"]})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_bool(bool(m.pending.get("reveal_pile", false))).is_true()
	assert_bool(bool(m.pending["cancellable"])).is_true()
	var vals: Array = m.pending["options"].map(func(o): return int(o["v"]))
	assert_array(vals).contains_exactly_in_any_order([b["null"], b["mimic"]])   # not the 4-Rune Swordsman


func test_picking_a_target_summons_it_with_the_unit_as_material() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	m.submit(0, {"t": "ritual_tribute", "uid": b["mat"]})
	assert_str(TB.choose_uids(m, [b["mimic"]])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("slot")         # no material choice: the unit is the material
	TB.choose(m, ["Front row, column 1"])
	if TB.pend_kind(m) == "stance":
		TB.choose(m, ["Attack"])
	while not m.pending.is_empty():
		CF.decline(m)
	assert_str(String(m.cards[b["mimic"]]["zone"])).is_equal("unit")
	assert_str(String(m.cards[b["mat"]]["zone"])).is_not_equal("unit")
	assert_str(String(m.cards[b["null"]]["zone"])).is_equal("extra")


func test_a_single_target_still_asks_in_the_tray() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	var null_u := TB.card(m, 0, CREEPING_NULL, "extra")
	var acts := _tribute_actions(m, 0, mat)
	assert_str(String(acts[0]["label"])).is_equal("Ritual Summon")
	m.submit(0, {"t": "ritual_tribute", "uid": mat})
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_int(m.pending["options"].size()).is_equal(1)
	assert_int(int(m.pending["options"][0]["v"])).is_equal(null_u)


func test_cancelling_the_pick_changes_nothing() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	var ap: int = m.players[0]["ap"]
	m.submit(0, {"t": "ritual_tribute", "uid": b["mat"]})
	assert_str(m.submit(0, {"t": "cancel", "id": int(m.pending["id"])})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(m.stack.is_empty()).is_true()
	assert_str(String(m.cards[b["mat"]]["zone"])).is_equal("unit")
	assert_int(m.players[0]["ap"]).is_equal(ap)


func test_ritual_summon_without_target_is_refused_without_enough_runes() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 1)
	TB.card(m, 0, CREEPING_NULL, "extra")
	assert_str(m.validate(0, {"t": "ritual_tribute", "uid": mat})).is_not_empty()
	assert_array(_tribute_actions(m, 0, mat)).is_empty()


func test_ritual_summon_is_refused_in_the_battle_phase() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var mat := TB.unit(m, 1, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	TB.card(m, 1, CREEPING_NULL, "extra")
	TB.to_battle(m)
	assert_str(m.validate(1, {"t": "ritual_tribute", "uid": mat})).is_equal(FusionOps.NO_EXTRA_IN_BATTLE)
