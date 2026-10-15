extends GdUnitTestSuite
## Combat table, type advantage, Eternal, Pierce, direct attacks, Blind/Infiltrate.


func _battle_match() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	return m


func test_water_8_attacking_fire_10_destroys_fire_and_deals_4() -> void:
	var m := _battle_match()
	var water := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var fire := TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	assert_str(TB.attack(m, water, fire)).is_empty()
	assert_str(m.cards[fire]["zone"]).is_equal("spent")
	assert_str(m.cards[water]["zone"]).is_equal("unit")
	assert_int(m.players[0]["hp"]).is_equal(56)
	assert_bool(TB.log_text(m).contains("14 vs")).is_true()


func test_fire_10_attacking_water_8_in_attack_stance_loses_to_defender_advantage() -> void:
	var m := _battle_match()
	var fire := TB.unit(m, 1, TB.FIRE, 0, "atk", 10)
	var water := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, fire, water)
	assert_str(m.cards[fire]["zone"]).is_equal("spent")
	assert_str(m.cards[water]["zone"]).is_equal("unit")
	assert_int(m.players[1]["hp"]).is_equal(56)


func test_equal_atk_against_attack_stance_destroys_both_without_damage() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	var b := TB.unit(m, 0, TB.WATER, 0, "atk", 12)
	TB.attack(m, a, b)
	assert_str(m.cards[a]["zone"]).is_equal("spent")
	assert_str(m.cards[b]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(60)
	assert_int(m.players[1]["hp"]).is_equal(60)


func test_atk_8_against_def_10_destroys_neither_and_attacker_loses_2() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var b := TB.unit(m, 0, TB.WATER, 0, "def", 0, 10)
	TB.attack(m, a, b)
	assert_str(m.cards[a]["zone"]).is_equal("unit")
	assert_str(m.cards[b]["zone"]).is_equal("unit")
	assert_int(m.players[1]["hp"]).is_equal(58)


func test_attacker_beating_defense_stance_deals_no_damage_without_pierce() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	var b := TB.unit(m, 0, TB.WATER, 0, "def", 0, 10)
	TB.attack(m, a, b)
	assert_str(m.cards[b]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(60)


func test_pierce_deals_excess_and_is_consumed() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	m.apply_status(a, "pierce", 1)
	var b := TB.unit(m, 0, TB.WATER, 0, "def", 0, 10)
	TB.attack(m, a, b)
	assert_int(m.players[0]["hp"]).is_equal(50)
	assert_int(m.status_count(a, "pierce")).is_equal(0)


func test_eternal_saves_losing_attack_stance_defender_but_hp_loss_applies() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	var b := TB.unit(m, 0, TB.WATER, 0, "atk", 12)
	m.apply_status(b, "eternal", 1)
	TB.attack(m, a, b)
	assert_str(m.cards[b]["zone"]).is_equal("unit")
	assert_int(m.status_count(b, "eternal")).is_equal(0)
	assert_int(m.players[0]["hp"]).is_equal(52)


func test_diggie_can_attack_directly_past_units_but_normal_unit_cannot() -> void:
	var m := _battle_match()
	var diggie := TB.unit(m, 1, 162, 0)
	var normal := TB.unit(m, 1, TB.WATER, 1)
	TB.unit(m, 0, TB.WATER, 0)
	assert_bool(-1 in m.attack_targets(diggie)).is_true()
	assert_bool(-1 in m.attack_targets(normal)).is_false()


func test_back_row_unit_is_protected_only_while_front_zone_occupied() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0)
	var front := TB.unit(m, 0, TB.WATER, 1)
	var back := TB.unit(m, 0, TB.WATER, 4)
	assert_bool(back in m.attack_targets(a)).is_false()
	m.move_to_pile(front, "spent")
	assert_bool(back in m.attack_targets(a)).is_true()


func test_infiltrate_allows_attacking_protected_unit_and_is_consumed() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	m.apply_status(a, "infiltrate", 1)
	TB.unit(m, 0, TB.WATER, 1)
	var back := TB.unit(m, 0, TB.WATER, 4)
	assert_bool(back in m.attack_targets(a)).is_true()
	TB.attack(m, a, back)
	assert_int(m.status_count(a, "infiltrate")).is_equal(0)
	assert_str(m.cards[back]["zone"]).is_equal("spent")


func test_blind_picks_random_target_only_among_legal_targets() -> void:
	for s in range(1, 12):
		var m := TB.make(s)
		TB.to_turn2(m)
		TB.to_battle(m)
		var a := TB.unit(m, 1, TB.WATER, 0, "atk", 1)
		m.apply_status(a, "blind", 1)
		var front := TB.unit(m, 0, TB.WATER, 2, "def", 0, 50)
		var back := TB.unit(m, 0, TB.WATER, 5, "def", 0, 50)
		assert_str(m.submit(1, {"t": "attack", "uid": a})).is_empty()
		assert_bool(m.pending.is_empty()).is_true()  # no target prompt under Blind
		assert_bool(TB.log_text(m).contains("attacks Basic Mage (Water)")).is_true()
		assert_int(m.status_count(a, "blind")).is_equal(0)
		assert_bool(TB.log_index(m, "Battle: Basic Mage (Water) 1 vs Basic Mage (Water) DEF 50") >= 0).is_true()
		assert_str(m.cards[back]["zone"]).is_equal("unit")


func test_unit_can_attack_only_once_per_turn() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	TB.attack(m, a, -1)
	assert_str(m.validate(1, {"t": "attack", "uid": a})).is_equal("This unit already attacked this turn.")


func test_defense_stance_unit_cannot_attack() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "def")
	assert_str(m.validate(1, {"t": "attack", "uid": a})).is_equal("Only Attack-stance units can attack.")


func test_battle_phase_forbids_summon_set_and_stance_but_allows_spells() -> void:
	var m := _battle_match()
	var u := TB.card(m, 1, TB.WATER)
	var trap := TB.card(m, 1, 45)
	var spell := TB.card(m, 1, 83)       # Sacred Offerings
	var onfield := TB.unit(m, 1, TB.WATER, 0)
	assert_str(m.validate(1, {"t": "summon", "uid": u})).is_not_empty()
	assert_str(m.validate(1, {"t": "set", "uid": trap})).is_not_empty()
	assert_str(m.validate(1, {"t": "stance", "uid": onfield})).is_not_empty()
	assert_str(m.validate(1, {"t": "cast", "uid": spell})).is_empty()


func test_stance_change_only_in_main_phase_one() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var u := TB.unit(m, 1, TB.WATER, 0)
	assert_str(m.validate(1, {"t": "stance", "uid": u})).is_empty()
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_str(m.phase).is_equal("main2")
	assert_str(m.validate(1, {"t": "stance", "uid": u})).is_not_empty()


func test_elemental_mastery_raises_type_bonus_to_twelve() -> void:
	var m := _battle_match()
	TB.power(m, 1, 88)
	var water := TB.unit(m, 1, TB.WATER, 0, "atk", 8)
	var fire := TB.unit(m, 0, TB.FIRE, 0, "atk", 10)
	TB.attack(m, water, fire)
	assert_int(m.players[0]["hp"]).is_equal(50)


func test_direct_attack_damage_equals_attacker_atk() -> void:
	var m := _battle_match()
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 17)
	TB.attack(m, a, -1)
	assert_int(m.players[0]["hp"]).is_equal(43)
