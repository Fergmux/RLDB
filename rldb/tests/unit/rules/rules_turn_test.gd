extends GdUnitTestSuite
## Turn structure, AP, draws, Retain and recycling (file 05 behavioural checks).


func test_turn_refresh_with_unused_ap_resets_to_exactly_two_and_draws_four() -> void:
	var m := TB.make()
	m.players[0]["ap"] = 1
	var hand_before: int = m.players[1]["hand"].size()
	TB.to_turn2(m)                      # player 0 ends with unspent AP
	assert_int(m.players[1]["ap"]).is_equal(2)
	assert_int(m.players[1]["hand"].size()).is_equal(hand_before + 4)


func test_unspent_ap_does_not_accumulate() -> void:
	var m := TB.make()
	m.players[0]["ap"] = 5
	TB.to_turn2(m)
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_int(m.active).is_equal(0)
	assert_int(m.players[0]["ap"]).is_equal(2)


func test_retain_one_keeps_card_consumes_stack_and_draws_four_more() -> void:
	var m := TB.make()
	var kept: int = m.players[0]["hand"][0]
	m.apply_status(kept, "retain", 1)
	TB.to_turn2(m)
	# End of player 0's turn: kept card stays in hand, Retain removed.
	assert_str(m.cards[kept]["zone"]).is_equal("hand")
	assert_int(m.status_count(kept, "retain")).is_equal(0)
	assert_int(m.players[0]["hand"].size()).is_equal(1)
	# Player 1 ends; player 0 draws four fresh cards in addition to the kept one.
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	assert_int(m.players[0]["hand"].size()).is_equal(5)
	assert_bool(kept in m.players[0]["hand"]).is_true()


func test_retain_two_protects_across_two_discard_steps() -> void:
	var m := TB.make()
	var kept: int = m.players[0]["hand"][0]
	m.apply_status(kept, "retain", 2)
	TB.to_turn2(m)
	assert_int(m.status_count(kept, "retain")).is_equal(1)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	assert_str(m.cards[kept]["zone"]).is_equal("hand")
	assert_int(m.status_count(kept, "retain")).is_equal(0)


func test_first_turn_has_no_battle_phase_but_second_player_can_battle() -> void:
	var m := TB.make()
	m.submit(0, {"t": "next_phase"})
	assert_str(m.phase).is_equal("main2")
	m.submit(0, {"t": "next_phase"})
	assert_int(m.active).is_equal(1)
	m.submit(1, {"t": "next_phase"})
	assert_str(m.phase).is_equal("battle")


func test_extra_deck_card_in_recycled_spent_returns_to_extra_deck() -> void:
	var m := TB.make(3, 0)
	var fusion := TB.card(m, 0, 93, "spent")      # Bastion Wyrm (Fusion)
	var basic := TB.card(m, 0, TB.WATER, "spent")
	m.players[0]["draw"].clear()
	m.draw_cards(0, 1)
	assert_str(m.cards[fusion]["zone"]).is_equal("extra")
	assert_str(m.cards[basic]["zone"]).is_equal("hand")


func test_empty_draw_and_spent_costs_fatigue_per_missed_draw() -> void:
	var m := TB.make(3, 0)
	var hp: int = m.players[0]["hp"]
	var drawn := m.draw_cards(0, 4)
	assert_int(drawn.size()).is_equal(0)
	assert_int(m.players[0]["hp"]).is_equal(hp - 8)      # C-04: 2 HP per missed draw (default)


func test_fatigue_can_be_disabled_by_config() -> void:
	var m := TB.make(3, 0)
	m.config["fatigue_damage"] = 0
	var hp: int = m.players[0]["hp"]
	m.draw_cards(0, 4)
	assert_int(m.players[0]["hp"]).is_equal(hp)


func test_partial_draw_charges_fatigue_only_for_missing_cards() -> void:
	var m := TB.make(3, 0)
	TB.card(m, 0, TB.WATER, "draw")
	var hp: int = m.players[0]["hp"]
	m.draw_cards(0, 4)
	assert_int(m.players[0]["hp"]).is_equal(hp - 6)


func test_partial_draw_completes_as_far_as_cards_allow() -> void:
	var m := TB.make(3, 0)
	TB.card(m, 0, TB.WATER, "draw")
	TB.card(m, 0, TB.WATER, "spent")
	var drawn := m.draw_cards(0, 4)
	assert_int(drawn.size()).is_equal(2)


func test_out_of_turn_command_is_rejected() -> void:
	var m := TB.make()
	assert_str(m.submit(1, {"t": "next_phase"})).is_equal("It is not your turn.")


func test_delayed_ap_modifier_survives_turn_reset() -> void:
	var m := TB.make()
	m.players[1]["ap_next"].append({"n": 1, "src": "test"})
	TB.to_turn2(m)
	assert_int(m.players[1]["ap"]).is_equal(3)
