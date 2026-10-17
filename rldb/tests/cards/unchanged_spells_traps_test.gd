extends GdUnitTestSuite
## F26 -- Spells and Traps whose card data is unchanged in the 2026-10-17 CSV. Complements
## tests/unit/cards/cards_spells_traps_test.gd with optional, illegal-target, trigger-scope
## and duration cases. Trap tests: player 1 acts on turn 2, player 0 owns the set Trap.


# ---------------------------------------------------------------- 82 Polymerization

func test_c082_polymerization_fusion_summons_from_field_materials() -> void:
	var m := CF.make()
	var beast := TB.unit(m, 0, 4, 0)
	var dragon := TB.unit(m, 0, 2, 1)
	var wyrm := TB.card(m, 0, 93, "extra")
	var poly := TB.cast(m, 0, 82)
	assert_str(CF.finish_fusion(m, wyrm, [beast, dragon], "Front row, column 3")).is_empty()
	assert_str(CF.zone(m, wyrm)).is_equal("unit")
	assert_str(CF.zone(m, beast)).is_equal("spent")
	assert_str(CF.zone(m, dragon)).is_equal("spent")
	assert_str(CF.zone(m, poly)).is_equal("spent")
	assert_int(m.status_count(wyrm, "eternal")).is_equal(1)    # Bastion Wyrm's own On Summon


func test_c082_polymerization_cannot_be_cast_without_legal_materials() -> void:
	var m := CF.make()
	TB.unit(m, 0, 4, 0)                                          # a Beast but no Dragon
	TB.card(m, 0, 93, "extra")
	var poly := TB.card(m, 0, 82)
	m.players[0]["ap"] = 5
	assert_str(m.submit(0, {"t": "cast", "uid": poly})).is_not_empty()
	assert_str(CF.zone(m, poly)).is_equal("hand")
	assert_int(CF.ap(m, 0)).is_equal(5)


# ---------------------------------------------------------------- 41 Delayed Gratification

func test_c041_delayed_gratification_never_retains_itself() -> void:
	var m := CF.make()
	var keep := TB.card(m, 0, 4)
	var dg := TB.cast(m, 0, 41)
	var offered := CF.offered(m)
	assert_bool(dg in offered).is_false()
	assert_bool(keep in offered).is_true()


# ---------------------------------------------------------------- 154 Sneaky Snunday

func test_c154_sneaky_snunday_reverses_loss_this_turn_only() -> void:
	var m := CF.make()
	var brew := TB.power(m, 0, 167)
	TB.cast(m, 0, 154)
	TB.ability(m, brew)
	TB.choose(m, ["Opponent loses 4 HP"])
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP + 4)
	CF.end_turn(m)                                               # player 1's turn: reversal over
	m.change_hp(1, -4, "test")
	assert_int(CF.hp(m, 1)).is_equal(GameCore.START_HP)


# ---------------------------------------------------------------- 83 Sacred Offerings

func test_c083_sacred_offerings_can_target_an_opponent_unit() -> void:
	var m := CF.make()
	var foe := TB.unit(m, 1, TB.WATER, 0)
	var own := TB.unit(m, 0, TB.WATER, 0)
	TB.cast(m, 0, 83)
	assert_array(CF.offered(m)).contains([foe, own])
	TB.choose_uids(m, [foe])
	assert_int(m.status_count(foe, "rune")).is_equal(1)
	assert_int(m.status_count(own, "rune")).is_equal(0)


# ---------------------------------------------------------------- 84 Assassinate

func test_c084_assassinate_def_boundary_is_inclusive_at_30() -> void:
	var m := CF.make()
	var at30 := TB.unit(m, 1, TB.WATER, 0, "atk", null, 30)
	var at31 := TB.unit(m, 1, TB.WATER, 1, "atk", null, 31)
	TB.cast(m, 0, 84)
	assert_bool(at30 in CF.offered(m)).is_true()
	assert_bool(at31 in CF.offered(m)).is_false()
	TB.choose_uids(m, [at30])
	assert_str(CF.zone(m, at30)).is_equal("spent")


# ---------------------------------------------------------------- 138 No Hubris

func test_c138_no_hubris_offers_only_buffed_units() -> void:
	var m := CF.make()
	var buffed := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(buffed, "pierce", 1)   # Rune is neither a Buff nor a Debuff
	var debuffed := TB.unit(m, 1, TB.WATER, 1)
	m.apply_status(debuffed, "poison", 1)
	TB.cast(m, 0, 138)
	assert_bool(buffed in CF.offered(m)).is_true()
	assert_bool(debuffed in CF.offered(m)).is_false()


# ---------------------------------------------------------------- 182 Shimmer Serum

func test_c182_shimmer_serum_atk_lasts_until_end_of_turn_and_blinds() -> void:
	var m := CF.make()
	var own := TB.unit(m, 0, TB.WATER, 0)
	TB.cast(m, 0, 182)
	TB.choose_uids(m, [own])
	assert_int(m.atk_of(own)).is_equal(24)
	assert_int(m.status_count(own, "blind")).is_equal(1)
	CF.end_turn(m)
	assert_int(m.atk_of(own)).is_equal(8)


func test_c182_shimmer_serum_cost_keeps_rising_and_persists_in_spent() -> void:
	var m := CF.make()
	var own := TB.unit(m, 0, TB.WATER, 0)
	var s := TB.cast(m, 0, 182)
	TB.choose_uids(m, [own])
	assert_str(CF.zone(m, s)).is_equal("spent")
	m.move_to_pile(s, "hand")
	m.submit(0, {"t": "cast", "uid": s})
	TB.choose_uids(m, [own])
	assert_int(m.current_cost(s)).is_equal(2)


# ---------------------------------------------------------------- 152 Ruler No More

func test_c152_ruler_no_more_needs_a_power_on_the_field() -> void:
	var m := CF.make()
	var s := TB.card(m, 0, 152)
	m.players[0]["ap"] = 5
	assert_str(m.submit(0, {"t": "cast", "uid": s})).is_not_empty()
	assert_str(CF.zone(m, s)).is_equal("hand")


func test_c152_ruler_no_more_can_destroy_own_power() -> void:
	var m := CF.make()
	var mine := TB.power(m, 0, 88)
	TB.cast(m, 0, 152)
	assert_bool(mine in CF.offered(m)).is_true()
	TB.choose_uids(m, [mine])
	assert_str(CF.zone(m, mine)).is_equal("spent")


# ---------------------------------------------------------------- 85 Energy Capture

func test_c085_energy_capture_does_not_answer_own_effects() -> void:
	var m := CF.make()
	var trap := TB.set_card(m, 0, 85, 0)
	var u := TB.unit(m, 0, TB.WATER, 0)
	TB.cast(m, 0, 83)
	assert_str(TB.pend_kind(m)).is_equal("select")              # the Spell's own target, no window
	TB.choose_uids(m, [u])
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")
	assert_str(CF.zone(m, trap)).is_equal("backrow")


# ---------------------------------------------------------------- 49 Trap hole

func test_c049_trap_hole_pass_keeps_trap_set_and_unit_untouched() -> void:
	var m := CF.p1_main()
	var trap := TB.set_card(m, 0, 49, 0)
	var u := TB.summon(m, 1, 28, 0)
	assert_str(CF.decline(m)).is_empty()
	assert_int(m.status_count(u, "paralyse")).is_equal(0)
	assert_str(CF.zone(m, trap)).is_equal("backrow")


func test_c049_trap_hole_goes_to_spent_after_activation() -> void:
	var m := CF.p1_main()
	var trap := TB.set_card(m, 0, 49, 0)
	TB.summon(m, 1, 28, 0)
	TB.choose(m, ["Activate Trap hole"])
	assert_str(CF.zone(m, trap)).is_equal("spent")


# ---------------------------------------------------------------- 50 Wabuku

func test_c050_wabuku_offers_only_own_units_in_its_column() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 50, 1)
	var a := TB.unit(m, 1, TB.WATER, 1, "atk", 30)
	var front := TB.unit(m, 0, TB.WATER, 1)
	var back := TB.unit(m, 0, TB.WATER, 4)
	var other := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, front)
	TB.choose(m, ["Activate Wabuku"])
	var offered := CF.offered(m)
	assert_bool(front in offered).is_true()
	assert_bool(back in offered).is_true()
	assert_bool(other in offered).is_false()
	assert_bool(a in offered).is_false()


# ---------------------------------------------------------------- 103 Alexander's Arrow

func test_c103_alexanders_arrow_uses_lowest_own_atk() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, 103, 0)
	TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	TB.unit(m, 0, TB.WATER, 1, "atk", 4)
	var u := TB.summon(m, 1, 24, 2)                             # Chidori Monk, 14 ATK
	TB.choose(m, ["Activate Alexander's Arrow"])
	assert_int(m.atk_of(u)).is_equal(10)


# ---------------------------------------------------------------- 140 Energy Dispel

func test_c140_energy_dispel_negates_a_unit_ability() -> void:
	var m := CF.p1_main()
	var dispel := TB.set_card(m, 0, 140, 0)
	var av := TB.unit(m, 1, 14, 0)
	var foe := TB.unit(m, 0, TB.WATER, 0)
	assert_str(TB.ability(m, av)).is_empty()
	if TB.pend_kind(m) == "select":
		TB.choose_uids(m, [foe])
	TB.choose(m, ["Activate Energy Dispel"])
	assert_int(m.status_count(foe, "burn")).is_equal(0)
	assert_str(CF.zone(m, av)).is_equal("spent")
	assert_str(CF.zone(m, dispel)).is_equal("exhaust")


# ---------------------------------------------------------------- 153 Hot Stove

func test_c153_hot_stove_ignores_spells() -> void:
	var m := CF.p1_main()
	var stove := TB.set_card(m, 0, 153, 0)
	var u := TB.unit(m, 1, TB.WATER, 0)
	TB.cast(m, 1, 83)
	TB.choose_uids(m, [u])
	assert_bool(CF.labels(m).has("Activate Hot Stove")).is_false()
	assert_str(CF.zone(m, stove)).is_equal("backrow")


# ---------------------------------------------------------------- 163 Plan B

func test_c163_plan_b_not_offered_without_another_own_card() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 163, 2)
	var a := TB.unit(m, 1, TB.WATER, 0)
	TB.attack(m, a, -1)
	assert_bool(CF.labels(m).has("Activate Plan B")).is_false()


# ---------------------------------------------------------------- 164 No Loyalty

func test_c164_no_loyalty_ignores_direct_attacks() -> void:
	var m := CF.p1_battle()
	TB.set_card(m, 0, 164, 0)
	var a := TB.unit(m, 1, TB.WATER, 0)
	TB.attack(m, a, -1)
	assert_bool(CF.labels(m).has("Activate No Loyalty")).is_false()
	assert_int(CF.hp(m, 0)).is_less(GameCore.START_HP)


# ---------------------------------------------------------------- 52 Saviour Appears: Defcon 2

func test_c052_defcon_2_ignores_one_cost_summons() -> void:
	var m := CF.p1_main()
	var trap := TB.set_card(m, 0, 52, 0)
	TB.card(m, 0, 4, "spent")
	TB.summon(m, 1, 24, 0)                                       # Chidori Monk, cost 1
	assert_bool(CF.labels(m).has("Activate Saviour Appears: Defcon 2")).is_false()
	assert_str(CF.zone(m, trap)).is_equal("backrow")


func test_c052_defcon_2_rejects_spent_units_costing_more_than_two() -> void:
	var m := CF.p1_main()
	TB.set_card(m, 0, 52, 0)
	var small := TB.card(m, 0, 28, "spent")                      # cost 2
	var big := TB.card(m, 0, 31, "spent")                        # cost 3
	TB.summon(m, 1, 28, 0)
	TB.choose(m, ["Activate Saviour Appears: Defcon 2"])
	assert_bool(small in CF.offered(m)).is_true()
	assert_bool(big in CF.offered(m)).is_false()


# ---------------------------------------------------------------- 165 Saviour Appears: Defcon 1

func test_c165_defcon_1_ignores_summons_below_24_atk() -> void:
	var m := CF.p1_main()
	var trap := TB.set_card(m, 0, 165, 0)
	TB.card(m, 0, 28, "spent")
	TB.summon(m, 1, 77, 0)                                       # Radablast, 22 ATK
	assert_bool(CF.labels(m).has("Activate Saviour Appears: Defcon 1")).is_false()
	assert_str(CF.zone(m, trap)).is_equal("backrow")
