extends GdUnitTestSuite
## Status behaviour from file 02, including corrected Cleanse/Retain rules.


func test_cleanse_one_on_multiple_debuffs_removes_all_and_is_consumed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "poison", 2)
	m.apply_status(u, "burn", 3)
	m.apply_status(u, "rune", 2)
	m.apply_status(u, "cleanse", 1)
	assert_int(m.status_count(u, "poison")).is_equal(0)
	assert_int(m.status_count(u, "burn")).is_equal(0)
	assert_int(m.status_count(u, "cleanse")).is_equal(0)
	assert_int(m.status_count(u, "rune")).is_equal(2)


func test_cleanse_three_on_debuffed_unit_leaves_two_for_prevention() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "poison", 2)
	m.apply_status(u, "cleanse", 3)
	assert_int(m.status_count(u, "cleanse")).is_equal(2)
	m.apply_status(u, "paralyse", 1)
	assert_int(m.status_count(u, "paralyse")).is_equal(0)
	assert_int(m.status_count(u, "cleanse")).is_equal(1)


func test_curse_does_not_affect_runes() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "rune", 3)
	m.apply_status(u, "eternal", 1)
	m.apply_status(u, "curse", 1)
	assert_int(m.status_count(u, "rune")).is_equal(3)
	assert_int(m.status_count(u, "eternal")).is_equal(0)
	assert_int(m.status_count(u, "curse")).is_equal(0)


func test_poison_three_loses_three_hp_then_becomes_two() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "poison", 3)
	TB.to_turn2(m)
	assert_int(m.players[0]["hp"]).is_equal(57)
	assert_int(m.status_count(u, "poison")).is_equal(2)


func test_medic_heals_at_start_of_controllers_turn_then_decrements() -> void:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "medic", 3)
	TB.to_turn2(m)
	assert_int(m.players[1]["hp"]).is_equal(63)
	assert_int(m.status_count(u, "medic")).is_equal(2)


func test_paralyse_blocks_attack_and_decrements_at_end_of_controllers_turn() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "paralyse", 1)
	TB.to_battle(m)
	assert_str(m.validate(1, {"t": "attack", "uid": u})).is_equal("Paralysed.")
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_int(m.status_count(u, "paralyse")).is_equal(0)


func test_debilitate_suppresses_aura_but_keeps_earlier_instant_grant() -> void:
	var m := TB.make()
	var cave := TB.unit(m, 0, 34, 0)          # Dragon of the Cave: adjacent +6 DEF
	var friend := TB.unit(m, 0, TB.WATER, 1)
	m.cards[friend]["mods"].append({"atk": 4, "def": 0, "until": "field", "src": "earlier instant"})
	assert_int(m.def_of(friend)).is_equal(14)
	m.apply_status(cave, "debilitate", 1)
	assert_int(m.def_of(friend)).is_equal(8)
	assert_int(m.atk_of(friend)).is_equal(12)


func test_debilitated_unit_cannot_be_sacrificed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "debilitate", 1)
	assert_str(m.validate(0, {"t": "sacrifice", "uid": u})).is_equal("Debilitated units cannot be sacrificed.")


func test_unit_leaving_field_resets_stats_but_keeps_persistent_cost() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, 21, 0)        # Shen the World Dragon (cost 4)
	m.apply_status(u, "eternal", 1)
	m.cards[u]["mods"].append({"atk": 5, "def": 5, "until": "field", "src": "x"})
	m.cards[u]["cost_p"] = 1
	m.move_to_pile(u, "spent")
	assert_bool(m.cards[u]["st"].is_empty()).is_true()
	assert_bool(m.cards[u]["mods"].is_empty()).is_true()
	assert_int(m.current_cost(u)).is_equal(5)


func test_nimble_moves_to_adjacent_empty_zone_once_per_turn() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "nimble", 2)
	assert_str(m.submit(0, {"t": "move", "uid": u})).is_empty()
	assert_str(TB.choose(m, ["Back row, column 2"])).is_empty()
	assert_int(m.cards[u]["slot"]).is_equal(4)
	assert_int(m.status_count(u, "nimble")).is_equal(1)
	assert_str(m.validate(0, {"t": "move", "uid": u})).is_equal("Nimble: already moved this turn.")


func test_burn_costs_controller_hp_when_unit_attacks() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	var u := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	m.apply_status(u, "burn", 4)
	TB.attack(m, u, -1)
	assert_int(m.players[1]["hp"]).is_equal(56)
	assert_int(m.status_count(u, "burn")).is_equal(0)
	assert_int(m.players[0]["hp"]).is_equal(55)


func test_curse_prevents_an_incoming_buff_and_is_consumed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "curse", 1)
	m.apply_status(u, "eternal", 1)
	assert_int(m.status_count(u, "eternal")).is_equal(0)
	assert_int(m.status_count(u, "curse")).is_equal(0)
