extends GdUnitTestSuite
## Summoning, sacrifice, tribute and Fusion/Ritual/Arcane special summons.


func test_normal_summon_pays_current_cost_and_places_in_chosen_zone() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.FIRE)
	assert_str(m.submit(0, {"t": "summon", "uid": u})).is_empty()
	assert_str(TB.choose(m, ["Back row, column 3"])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()          # B3: no stance prompt on your own turn
	assert_int(m.cards[u]["slot"]).is_equal(5)
	assert_str(m.cards[u]["stance"]).is_equal("atk")
	assert_int(m.players[0]["ap"]).is_equal(1)


func test_cancelling_summon_before_commit_refunds_nothing_and_keeps_card() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.FIRE)
	m.submit(0, {"t": "summon", "uid": u})
	assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
	assert_str(m.cards[u]["zone"]).is_equal("hand")
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_sacrifice_refunds_one_ap() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "sacrifice", "uid": u})
	assert_int(m.players[0]["ap"]).is_equal(3)
	assert_str(m.cards[u]["zone"]).is_equal("spent")


func test_sacrificing_cliff_gives_three_ap() -> void:
	var m := TB.make()
	var cliff := TB.unit(m, 0, 174, 0)
	m.submit(0, {"t": "sacrifice", "uid": cliff})
	assert_int(m.players[0]["ap"]).is_equal(5)


func test_tributing_cliff_from_field_gives_two_ap() -> void:
	var m := TB.make()
	var cliff := TB.unit(m, 0, 174, 0)
	m.apply_status(cliff, "rune", 1)
	var inferno := TB.card(m, 0, 98, "extra")      # Raging Inferno 1R
	assert_str(m.submit(0, {"t": "ritual", "uid": inferno})).is_empty()
	TB.choose_uids(m, [cliff])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.players[0]["ap"]).is_equal(4)
	assert_str(m.cards[inferno]["zone"]).is_equal("unit")


func test_mumens_bounty_gives_two_on_sacrifice() -> void:
	var m := TB.make()
	var mumen := TB.unit(m, 0, 150, 0)
	m.submit(0, {"t": "sacrifice", "uid": mumen})
	assert_int(m.players[0]["ap"]).is_equal(4)


func test_newly_summoned_unit_cannot_be_sacrificed_but_can_be_tributed() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", null, null, true)
	assert_str(m.validate(0, {"t": "sacrifice", "uid": u})).is_equal("A unit summoned this turn cannot be sacrificed.")
	m.apply_status(u, "rune", 1)
	var inferno := TB.card(m, 0, 98, "extra")
	assert_str(m.validate(0, {"t": "ritual", "uid": inferno})).is_empty()


func test_arcane_three_with_spent_costs_two_and_two_is_unavailable_no_overpayment() -> void:
	# F03-04 supersedes the original "overpayment is allowed" rule: totals must be exact.
	var m := TB.make()
	var a := TB.card(m, 0, 28, "spent")               # Guardian of the Forest (cost 2)
	var b := TB.card(m, 0, 32, "spent")               # Frost Wyvern (cost 2)
	var boom := TB.card(m, 0, 175, "extra")           # Boom 3A
	assert_str(m.submit(0, {"t": "arcane", "uid": boom})).contains("exactly")
	assert_str(m.cards[a]["zone"]).is_equal("spent")
	assert_str(m.cards[b]["zone"]).is_equal("spent")
	assert_str(m.cards[boom]["zone"]).is_equal("extra")
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_arcane_materials_below_requirement_are_rejected() -> void:
	var m := TB.make()
	var a := TB.card(m, 0, 28, "spent")
	var b := TB.card(m, 0, TB.WATER, "spent")
	TB.card(m, 0, 175, "extra")
	var boom: int = m.players[0]["extra"][0]
	m.submit(0, {"t": "arcane", "uid": boom})
	assert_str(TB.choose_uids(m, [b])).contains("required")


func test_extra_deck_unit_is_not_arcane_material() -> void:
	var m := TB.make()
	TB.card(m, 0, 93, "spent")                       # Fusion unit in Spent
	TB.card(m, 0, 174, "spent")                      # Arcane unit (2A) in Spent
	var kaya := TB.card(m, 0, 170, "extra")          # 1A
	assert_str(m.validate(0, {"t": "arcane", "uid": kaya})).contains("exactly")


func test_extra_deck_unit_does_not_match_ordinary_cost_two() -> void:
	var m := TB.make()
	var arc := TB.card(m, 0, 174, "spent")
	assert_int(m.current_cost(arc)).is_equal(-1)
	var f := m.make_frame(-1, 0, [], "")
	assert_bool(arc in m.select(f, {"kind": "spent", "side": "self", "cost_max": 2})).is_false()


func test_roma_with_three_rune_material_becomes_36() -> void:
	var m := TB.make()
	var mat := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(mat, "rune", 3)
	var roma := TB.card(m, 0, 96, "extra")
	m.submit(0, {"t": "ritual", "uid": roma})
	TB.choose_uids(m, [mat])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.atk_of(roma)).is_equal(36)
	assert_int(m.def_of(roma)).is_equal(36)


func test_roma_summoned_without_a_ritual_is_0_0() -> void:
	# Ruling: revived from Spent (or summoned any non-Ritual way) no Runes were used, so 0/0.
	var m := TB.make()
	var roma := TB.special(m, 0, 96, 0)
	assert_int(m.atk_of(roma)).is_equal(0)
	assert_int(m.def_of(roma)).is_equal(0)


func test_roma_with_zero_rune_material_is_illegal() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0)
	var roma := TB.card(m, 0, 96, "extra")
	assert_str(m.validate(0, {"t": "ritual", "uid": roma})).is_equal("No unit with enough Runes.")


func test_polymerization_fuses_field_materials_into_bastion_wyrm() -> void:
	var m := TB.make()
	var beast := TB.unit(m, 0, 4, 0)       # Basic Beast (Water)
	var dragon := TB.unit(m, 0, 2, 1)      # Basic Dragon (Water)
	var wyrm := TB.card(m, 0, 93, "extra")
	var poly := TB.card(m, 0, 82)
	assert_str(m.submit(0, {"t": "cast", "uid": poly})).is_empty()
	# F04-22 / F07: the Fusion unit and each material are picked, then zone; the stance commits.
	TB.choose_uids(m, [wyrm])
	TB.choose_uids(m, [beast])
	TB.choose_uids(m, [dragon])
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_str(m.cards[wyrm]["zone"]).is_equal("unit")
	assert_str(m.cards[beast]["zone"]).is_equal("spent")
	assert_str(m.cards[dragon]["zone"]).is_equal("spent")
	assert_int(m.status_count(wyrm, "eternal")).is_equal(1)


func test_fusion_material_cannot_count_twice() -> void:
	var m := TB.make()
	TB.unit(m, 0, 2, 0)                     # one Dragon only
	TB.card(m, 0, 151, "extra")             # Ultimate Dragon needs three Dragons
	assert_int(m.fusion_candidates(0, ["field"]).size()).is_equal(0)


func test_set_spell_pays_once_and_can_be_activated_same_turn() -> void:
	var m := TB.make()
	var target := TB.unit(m, 0, TB.WATER, 0)
	var spell := TB.card(m, 0, 83)          # Sacred Offerings (cost 1)
	m.submit(0, {"t": "set", "uid": spell})
	TB.choose(m, ["column 1"])
	assert_int(m.players[0]["ap"]).is_equal(1)
	assert_str(m.submit(0, {"t": "activate_set", "uid": spell})).is_empty()
	TB.choose_uids(m, [target])             # target first (cancellable), then the cost is paid
	assert_int(m.players[0]["ap"]).is_equal(1)
	assert_int(m.status_count(target, "rune")).is_equal(1)
	assert_str(m.cards[spell]["zone"]).is_equal("spent")


func test_tributing_mumens_bounty_from_field_gives_one_ap() -> void:
	var m := TB.make()
	var mumen := TB.unit(m, 0, 150, 0)
	m.apply_status(mumen, "rune", 1)
	var inferno := TB.card(m, 0, 98, "extra")
	m.submit(0, {"t": "ritual", "uid": inferno})
	TB.choose_uids(m, [mumen])
	TB.choose(m, ["Front row, column 2"])
	TB.choose(m, ["Attack"])
	assert_int(m.players[0]["ap"]).is_equal(3)


func test_newly_summoned_unit_can_attack_the_same_turn() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var u := TB.summon(m, 1, TB.FIRE, 0)
	m.submit(1, {"t": "next_phase"})
	assert_str(m.validate(1, {"t": "attack", "uid": u})).is_empty()
