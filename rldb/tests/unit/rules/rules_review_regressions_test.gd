extends GdUnitTestSuite
## Regression tests for defects found by the independent specialist reviews
## (combat/timing, hidden information). Each was confirmed failing before its fix.


func test_no_gain_unit_does_not_block_buff_to_other_targets() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 51, 0)                                # Rushed Recklessly: +8 DEF column
	TB.unit(m, 0, 38, 0)                                    # Lone Warrior (no gains) in front
	var ally := TB.unit(m, 0, TB.WATER, 3, "atk", 8, 8)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 1)
	TB.attack(m, a, m.players[0]["units"][0])
	TB.choose(m, ["Activate Rushed Recklessly"])
	assert_int(m.def_of(ally)).is_equal(16)


func test_fusion_on_full_board_with_hand_materials_consumes_nothing() -> void:
	var m := TB.make()
	TB.power(m, 0, 137)                                     # Unstable Fusions: Hand materials
	for s in 6:
		TB.unit(m, 0, TB.FIRE, s)
	var beast := TB.card(m, 0, 4)
	var dragon := TB.card(m, 0, 2)
	var wyrm := TB.card(m, 0, 93, "extra")
	TB.cast(m, 0, 82)
	if m.pending.get("kind", "") == "select":
		TB.choose_uids(m, [wyrm])
	assert_str(m.cards[beast]["zone"]).is_equal("hand")
	assert_str(m.cards[dragon]["zone"]).is_equal("hand")
	assert_str(m.cards[wyrm]["zone"]).is_equal("extra")


func test_equal_atk_battle_immunity_reads_opponent_before_it_left_field() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	var steadfast := TB.unit(m, 1, 39, 0, "atk", 30)        # immune to 30+ ATK battles
	var foe := TB.unit(m, 0, TB.WATER, 0, "atk", 24)
	m.cards[foe]["mods"].append({"atk": 6, "def": 0, "until": "field", "src": "buff"})
	TB.attack(m, steadfast, foe)
	assert_str(m.cards[foe]["zone"]).is_equal("spent")
	assert_str(m.cards[steadfast]["zone"]).is_equal("unit")


func test_attack_does_not_resolve_if_target_became_protected() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 52, 0)                                # Defcon 2 (summon) is not an attack trap
	var back := TB.unit(m, 0, TB.WATER, 3, "atk", 1)
	var a := TB.unit(m, 1, TB.WATER, 1, "atk", 30)
	m.submit(1, {"t": "attack", "uid": a})
	TB.choose_uids(m, [back])
	# Simulate a response that fills the front zone before the battle step.
	assert_bool(m.pending.is_empty()).is_true()
	var m2 := TB.make()
	TB.to_turn2(m2)
	TB.to_battle(m2)
	var back2 := TB.unit(m2, 0, TB.WATER, 3, "atk", 1)
	var a2 := TB.unit(m2, 1, TB.WATER, 1, "atk", 30)
	var f := m2.make_frame(a2, 1, [{"op": "battle"}], "attack")
	f["vars"]["target"] = back2
	TB.unit(m2, 0, TB.WATER, 0)                             # front zone now occupied
	m2.push_frame(f)
	m2.run()
	assert_str(m2.cards[back2]["zone"]).is_equal("unit")


func test_debilitated_flying_sandworm_goes_to_spent_not_exhaust() -> void:
	var m := TB.make()
	var fs := TB.unit(m, 0, 171, 0)
	m.apply_status(fs, "debilitate", 1)
	TB.kill(m, fs)
	assert_str(m.cards[fs]["zone"]).is_equal("spent")


func test_magic_cylinder_uses_attacker_last_known_atk_after_mirror_force() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 46, 1)                                # Mirror Force
	TB.set_card(m, 0, 45, 0)                                # Magic Cylinder (column 1)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 14)
	m.cards[a]["mods"].append({"atk": 16, "def": 0, "until": "field", "src": "buff"})
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "def")
	var d := TB.unit(m, 0, TB.WATER, 0)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Mirror Force"])
	TB.choose(m, ["Activate Magic Cylinder"])
	assert_int(m.players[1]["hp"]).is_equal(30)


func test_retain_does_not_follow_a_card_out_of_hand() -> void:
	var m := TB.make()
	var c: int = m.players[0]["hand"][0]
	m.apply_status(c, "retain", 1)
	m.move_to_pile(c, "spent")
	assert_int(m.status_count(c, "retain")).is_equal(0)


func test_stance_can_change_more_than_once_in_main_phase_one() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "stance", "uid": u})
	assert_str(m.validate(0, {"t": "stance", "uid": u})).is_empty()


func test_moving_card_out_of_spent_is_not_named_publicly() -> void:
	var m := TB.make()
	var top := TB.card(m, 0, 21, "spent")
	TB.summon(m, 0, 150, 0)                                 # Mumen's Bounty: Spent -> top of Draw
	TB.choose_uids(m, [top])
	assert_bool(JSON.stringify(MatchView.log_for(m, 1)).contains("Shen")).is_false()
	assert_bool(JSON.stringify(MatchView.log_for(m, 0)).contains("Shen")).is_true()


func test_status_on_hand_card_is_not_named_publicly() -> void:
	var m := TB.make()
	var c := TB.card(m, 0, 21)
	m.apply_status(c, "retain", 1)
	assert_bool(JSON.stringify(MatchView.log_for(m, 1)).contains("Shen")).is_false()
	assert_bool(JSON.stringify(MatchView.log_for(m, 0)).contains("Shen")).is_true()


func test_choice_from_draw_is_not_presented_in_draw_order() -> void:
	var m := TB.make(7, 0)
	var ids := []
	for i in 6:
		ids.append(TB.card(m, 0, 122, "draw"))
	TB.summon(m, 0, 73, 0)                                  # Mans Best Friend: Warrior from Draw
	var shown: Array = m.pending["options"].map(func(o): return o["v"])
	var sorted := shown.duplicate()
	sorted.sort()
	assert_array(shown).is_equal(sorted)


func test_no_legal_choice_message_is_private() -> void:
	var m := TB.make()
	TB.summon(m, 0, 73, 0)                                  # no Warrior in Draw
	var pub := JSON.stringify(MatchView.log_for(m, 1))
	assert_bool(pub.contains("no legal choice")).is_false()
