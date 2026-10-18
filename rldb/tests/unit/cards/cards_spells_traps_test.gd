extends GdUnitTestSuite
## Per-card behaviour checks for Spells and Traps.


# ---------------------------------------------------------------- Spells

func test_c080_wings_of_aurenthor_gives_every_unit_nimble() -> void:
	var m := TB.make()
	var a := TB.unit(m, 0, TB.WATER, 0)
	var b := TB.unit(m, 1, TB.WATER, 0)
	TB.cast(m, 0, 80)
	assert_int(m.status_count(a, "nimble")).is_equal(1)
	assert_int(m.status_count(b, "nimble")).is_equal(1)


func test_c081_fog_of_war_blinds_every_unit() -> void:
	var m := TB.make()
	var a := TB.unit(m, 0, TB.WATER, 0)
	var b := TB.unit(m, 1, TB.WATER, 0)
	TB.cast(m, 0, 81)
	assert_int(m.status_count(a, "blind")).is_equal(1)
	assert_int(m.status_count(b, "blind")).is_equal(1)


func test_c041_delayed_gratification_retains_card_and_adds_ap_next_turn() -> void:
	var m := TB.make()
	var keep: int = m.players[0]["hand"][0]
	TB.cast(m, 0, 41)
	TB.choose_uids(m, [keep])
	assert_int(m.status_count(keep, "retain")).is_equal(1)
	TB.to_turn2(m)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	assert_int(m.players[0]["ap"]).is_equal(3)
	assert_bool(keep in m.players[0]["hand"]).is_true()


func test_c042_ambush_summons_basic_units_from_hand_and_draw() -> void:
	var m := TB.make()
	TB.cast(m, 0, 42)
	assert_int(m.field_units(0).size()).is_equal(6)
	for u in m.field_units(0):
		assert_str(m.category(u)).is_equal("basic_unit")


func test_c043_freaky_funday_switches_atk_and_def_until_end_of_turn() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 20)
	TB.cast(m, 0, 43)
	assert_int(m.atk_of(u)).is_equal(20)
	assert_int(m.def_of(u)).is_equal(10)
	TB.to_turn2(m)
	assert_int(m.atk_of(u)).is_equal(10)


func test_c043_freaky_funday_also_switches_atk_and_def_in_card_effects() -> void:
	# Ruling 2026-10-16: while it lasts, "+ATK" from a card effect gives DEF and vice versa.
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 20)
	TB.cast(m, 0, 43)
	TB.cast(m, 0, 182)                                      # Shimmer Serum: +20 ATK this turn
	TB.choose_uids(m, [u])
	assert_int(m.atk_of(u)).is_equal(20)
	assert_int(m.def_of(u)).is_equal(30)
	var late := TB.unit(m, 0, TB.WATER, 1, "atk", 10, 20)   # arrives after Funday: not switched
	TB.cast(m, 0, 182)
	TB.choose_uids(m, [late])
	assert_int(m.atk_of(late)).is_equal(10)
	assert_int(m.def_of(late)).is_equal(40)
	TB.to_turn2(m)
	assert_int(m.atk_of(u)).is_equal(10)
	assert_int(m.def_of(u)).is_equal(20)


func test_c043_two_freaky_fundays_cancel_out() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10, 20)
	TB.cast(m, 0, 43)
	TB.cast(m, 0, 43)
	assert_int(m.atk_of(u)).is_equal(10)
	assert_int(m.def_of(u)).is_equal(20)
	TB.cast(m, 0, 182)
	TB.choose_uids(m, [u])
	assert_int(m.atk_of(u)).is_equal(30)                    # effects are back to normal too
	assert_int(m.def_of(u)).is_equal(20)


func test_c043_unit_that_leaves_and_returns_is_a_new_card() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, 162, 0)                          # Diggie 6/0 (2026-10-17)
	TB.cast(m, 0, 43)
	assert_int(m.atk_of(u)).is_equal(0)
	m._leave_field(u, "spent", "test")
	m.players[0]["spent"].erase(u)
	m.place_unit(u, 0, 0, "atk")
	assert_int(m.atk_of(u)).is_equal(6)
	assert_int(m.def_of(u)).is_equal(0)


func test_c083_sacred_offerings_adds_a_rune() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	TB.cast(m, 0, 83)
	TB.choose_uids(m, [u])                                  # sole legal target is still chosen by the player
	assert_int(m.status_count(u, "rune")).is_equal(1)


func test_c084_assassinate_destroys_unit_with_30_def_or_less_only() -> void:
	var m := TB.make()
	var weak := TB.unit(m, 1, TB.WATER, 0, "atk", 8, 30)
	var tough := TB.unit(m, 1, TB.WATER, 1, "atk", 8, 31)
	TB.cast(m, 0, 84)
	TB.choose_uids(m, [weak])               # only the 30-DEF unit is legal, but it is still chosen
	assert_str(m.cards[weak]["zone"]).is_equal("spent")
	assert_str(m.cards[tough]["zone"]).is_equal("unit")


func test_c101_into_the_void_exhausts_opponent_spent_card_and_itself() -> void:
	var m := TB.make()
	var target := TB.card(m, 1, 21, "spent")
	var spell := TB.cast(m, 0, 101)
	TB.choose_uids(m, [target])
	assert_str(m.cards[target]["zone"]).is_equal("exhaust")
	assert_str(m.cards[spell]["zone"]).is_equal("exhaust")


func test_c104_earthquake_flips_unprotected_opposing_units_only() -> void:
	var m := TB.make()
	var front := TB.unit(m, 1, TB.WATER, 0, "atk")
	var back := TB.unit(m, 1, TB.WATER, 3, "atk")
	TB.cast(m, 0, 104)
	assert_str(m.cards[front]["stance"]).is_equal("def")
	assert_str(m.cards[back]["stance"]).is_equal("atk")


func test_c136_equaliser_destroys_units_with_20_atk_and_exhausts_itself() -> void:
	var m := TB.make()
	var big := TB.unit(m, 1, TB.WATER, 0, "atk", 20)
	var small := TB.unit(m, 0, TB.WATER, 0, "atk", 19)
	var spell := TB.cast(m, 0, 136)
	assert_str(m.cards[big]["zone"]).is_equal("spent")
	assert_str(m.cards[small]["zone"]).is_equal("unit")
	assert_str(m.cards[spell]["zone"]).is_equal("exhaust")


func test_c138_no_hubris_destroys_a_buffed_unit() -> void:
	var m := TB.make()
	var buffed := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(buffed, "pierce", 1)
	TB.unit(m, 1, TB.WATER, 1)
	TB.cast(m, 0, 138)
	TB.choose_uids(m, [buffed])
	assert_str(m.cards[buffed]["zone"]).is_equal("spent")


func test_c138_no_hubris_cannot_be_cast_without_buffed_target() -> void:
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0)
	var spell := TB.card(m, 0, 138)
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).is_equal("No legal target.")


func test_c182_shimmer_serum_raises_its_targets_cost_not_its_own() -> void:
	var m := TB.make()
	var own := TB.unit(m, 0, TB.WATER, 0)
	var s := TB.cast(m, 0, 182)
	TB.choose_uids(m, [own])
	assert_int(m.current_cost(s)).is_equal(0)
	assert_int(m.current_cost(own)).is_equal(2)


func test_c152_ruler_no_more_destroys_a_power() -> void:
	var m := TB.make()
	var pw := TB.power(m, 1, 88)
	TB.cast(m, 0, 152)
	TB.choose_uids(m, [pw])
	assert_str(m.cards[pw]["zone"]).is_equal("spent")


# ---------------------------------------------------------------- Traps (player 0 owns, player 1 active)

func _p1_turn() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	return m


func test_c085_energy_capture_answers_spell_with_a_rune() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 85, 0)
	var mine := TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 1, TB.WATER, 0)
	TB.cast(m, 1, 81)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Activate Energy Capture"])
	TB.choose_uids(m, [mine])
	assert_int(m.status_count(mine, "rune")).is_equal(1)


func test_c086_get_well_soon_heals_after_opponent_destroys_your_unit() -> void:
	var m := _p1_turn()
	TB.to_battle(m)
	TB.set_card(m, 0, 86, 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var victim := TB.unit(m, 0, TB.WATER, 0)
	var survivor := TB.unit(m, 0, TB.WATER, 2)
	TB.attack(m, a, victim)
	TB.choose(m, ["Activate Get Well Soon"])
	TB.choose_uids(m, [survivor])
	assert_int(m.status_count(survivor, "medic")).is_equal(4)


func test_c087_shared_fate_retaliates_when_unit_destroyed_by_effect() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 87, 0)
	var mine := TB.unit(m, 0, TB.WATER, 0)
	var foe := TB.unit(m, 1, TB.WATER, 0, "atk", 8, 40)
	TB.cast(m, 1, 84)                                       # Assassinate
	TB.choose_uids(m, [mine])                               # target first (the only 30-DEF-or-less unit), then cost, then the trap window
	TB.choose(m, ["Activate Shared Fate"])
	TB.choose_uids(m, [foe])                                # Shared Fate's own target, chosen by the trap owner
	assert_str(m.cards[foe]["zone"]).is_equal("spent")


func test_c047_damage_conversion_heals_by_attacker_atk() -> void:
	var m := _p1_turn()
	TB.to_battle(m)
	var dc := TB.set_card(m, 0, 47, 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	var d := TB.unit(m, 0, TB.WATER, 1, "def", 0, 40)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Damage Conversion"])
	assert_int(m.players[0]["hp"]).is_equal(72)
	assert_int(m.current_cost(dc)).is_equal(1)


func test_c048_overextend_weakens_the_chosen_unit_after_third_unit() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 48, 0)
	var big := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	TB.unit(m, 1, TB.WATER, 1, "atk", 10)
	TB.summon(m, 1, TB.FIRE, 2)
	TB.choose(m, ["Activate Overextend"])
	TB.choose_uids(m, [big])                                # sole highest-ATK unit: still chosen by the player
	assert_int(m.atk_of(big)).is_equal(10)


func test_c049_trap_hole_paralyses_two_cost_summon() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 49, 0)
	var u := TB.summon(m, 1, 28, 0)                         # Guardian of the Forest, cost 2
	TB.choose(m, ["Activate Trap Hole"])
	assert_int(m.status_count(u, "paralyse")).is_equal(3)


func test_c049_trap_hole_answers_a_one_cost_summon_too() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 49, 0)
	TB.summon(m, 1, TB.FIRE, 0)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")     # the 2-cost minimum is gone (2026-10-18)


func test_c050_wabuku_gives_eternal_to_unit_in_its_column() -> void:
	var m := _p1_turn()
	TB.to_battle(m)
	TB.set_card(m, 0, 50, 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var d := TB.unit(m, 0, TB.WATER, 1)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Wabuku"])
	assert_str(m.cards[d]["zone"]).is_equal("unit")


func test_c103_alexanders_arrow_drains_summoned_unit() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 103, 0)
	TB.unit(m, 0, TB.WATER, 0, "atk", 6)
	TB.unit(m, 0, TB.WATER, 1, "atk", 9)
	var u := TB.summon(m, 1, 37, 0)                         # Solomon 26 ATK
	TB.choose(m, ["Activate Alexander's Arrow"])
	assert_int(m.atk_of(u)).is_equal(20)


func test_c140_energy_dispel_destroys_the_spell_without_negating_and_raises_its_own_cost() -> void:
	var m := _p1_turn()
	var dispel := TB.set_card(m, 0, 140, 0)
	var u := TB.unit(m, 1, TB.WATER, 0)
	var spell := TB.cast(m, 1, 83)
	TB.choose_uids(m, [u])                                  # target first, then cost, then the trap window
	TB.choose(m, ["Activate Energy Dispel"])
	assert_int(m.status_count(u, "rune")).is_equal(1)       # 2026-10-18: no negation
	assert_str(m.cards[spell]["zone"]).is_equal("spent")
	assert_str(m.cards[dispel]["zone"]).is_equal("spent")
	assert_int(m.current_cost(dispel)).is_equal(2)


## Owner feedback 2026-10-18: Hot Stove answers a Power's effect being activated, not the Power
## being played.
func test_c153_hot_stove_destroys_power_and_burns_owner_when_its_effect_is_activated() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 153, 0)
	var pw := TB.power(m, 1, 92, 0)                         # Preservation Jar: Retain a card in Hand
	var h := TB.card(m, 1, TB.WATER)
	assert_str(TB.ability(m, pw)).is_empty()
	TB.choose_uids(m, [h])
	TB.choose(m, ["Activate Hot Stove"])
	assert_str(m.cards[pw]["zone"]).is_equal("spent")
	assert_int(m.players[1]["hp"]).is_equal(56)


func test_c153_hot_stove_ignores_a_power_being_played() -> void:
	var m := _p1_turn()
	var stove := TB.set_card(m, 0, 153, 0)
	var pw := TB.card(m, 1, 88)
	m.players[1]["ap"] = 5
	m.submit(1, {"t": "power", "uid": pw})
	TB.choose(m, ["Power zone 1"])
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")
	assert_str(m.cards[pw]["zone"]).is_equal("power")
	assert_str(m.cards[stove]["zone"]).is_equal("backrow")


func test_c163_plan_b_trades_own_cards_for_hp() -> void:
	var m := _p1_turn()
	TB.to_battle(m)
	TB.set_card(m, 0, 163, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 5)
	var d1 := TB.unit(m, 0, TB.WATER, 0)
	var d2 := TB.unit(m, 0, TB.WATER, 1)
	TB.attack(m, a, d1)
	TB.choose(m, ["Activate Plan B"])
	TB.choose_uids(m, [d1, d2])
	assert_int(m.players[0]["hp"]).is_equal(80)
	assert_str(m.cards[d2]["zone"]).is_equal("spent")


func test_c164_no_loyalty_curses_target_and_absorbs_adjacent_unit() -> void:
	var m := _p1_turn()
	TB.to_battle(m)
	TB.set_card(m, 0, 164, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8, 8)
	m.apply_status(d, "pierce", 1)
	var adj := TB.unit(m, 0, TB.WATER, 1, "atk", 10, 6)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate No Loyalty"])
	assert_str(m.cards[adj]["zone"]).is_equal("spent")
	assert_int(m.status_count(d, "pierce")).is_equal(0)
	assert_int(m.players[1]["hp"]).is_equal(60)
	assert_str(m.cards[d]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(48)


func test_c052_saviour_defcon_2_revives_small_unit_in_column() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 52, 1)
	var ally := TB.card(m, 0, 28, "spent")
	TB.summon(m, 1, 28, 0)
	TB.choose(m, ["Activate Saviour Appears: Defcon 2"])
	TB.choose_uids(m, [ally])
	TB.choose(m, ["Front row, column 2"])
	assert_int(m.cards[ally]["slot"]).is_equal(1)
	assert_str(m.cards[ally]["stance"]).is_equal("atk")


func test_c165_saviour_defcon_1_answers_big_summon() -> void:
	var m := _p1_turn()
	TB.set_card(m, 0, 165, 0)
	var ally := TB.card(m, 0, 37, "spent")                  # 26 ATK: not eligible
	var ok := TB.card(m, 0, 28, "spent")                    # 14 ATK
	TB.summon(m, 1, 79, 2)                                  # Akakaiju 34 ATK
	TB.choose(m, ["Activate Saviour Appears: Defcon 1"])
	var opts: Array = m.pending["options"].map(func(o): return o["v"])
	assert_bool(ally in opts).is_false()
	TB.choose_uids(m, [ok])
	TB.choose(m, ["Front row, column 1"])
	assert_str(m.cards[ok]["zone"]).is_equal("unit")
	assert_str(m.cards[ally]["zone"]).is_equal("spent")
