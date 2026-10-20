extends GdUnitTestSuite
## J25 (owner feedback 2026-10-22): Paralyse also stops a manual stance change, as well as attacks
## and zone moves. A stance change forced by another card's effect still happens.

const EARTHQUAKE := 104      # Spell: change the stance of the opponent's unprotected units


func _stance_action(m: MatchEngine, p: int, uid: int) -> Dictionary:
	for a in MatchView.actions_for(m, p):
		if a["t"] == "stance" and int(a.get("uid", -1)) == uid:
			return a
	return {}


func test_paralysed_unit_manual_stance_change_is_refused() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "paralyse", 1)
	assert_str(m.validate(0, {"t": "stance", "uid": u})).is_equal(MatchEngine.PARALYSED_STANCE)
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_equal(MatchEngine.PARALYSED_STANCE)
	assert_str(String(m.cards[u]["stance"])).is_equal("atk")


func test_paralysed_unit_stance_action_is_not_offered() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.apply_status(u, "paralyse", 1)
	var a := _stance_action(m, 0, u)
	assert_bool(a.is_empty()).is_false()
	assert_bool(bool(a["ok"])).is_false()
	assert_str(String(a["reason"])).is_equal(MatchEngine.PARALYSED_STANCE)


func test_unparalysed_unit_may_still_change_stance() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_empty()
	assert_str(String(m.cards[u]["stance"])).is_equal("def")


func test_paralyse_wearing_off_allows_stance_change_again() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var u := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(u, "paralyse", 1)
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})
	m.submit(1, {"t": "next_phase"})      # end of player 1's turn: Paralyse -1
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})
	m.submit(0, {"t": "next_phase"})      # player 1's next Setup Phase
	assert_int(m.status_count(u, "paralyse")).is_equal(0)
	assert_int(m.active).is_equal(1)
	assert_str(m.validate(1, {"t": "stance", "uid": u})).is_empty()


func test_forced_stance_change_from_a_card_still_flips_a_paralysed_unit() -> void:
	var m := TB.make()
	var enemy := TB.unit(m, 1, TB.WATER, 0)
	m.apply_status(enemy, "paralyse", 2)
	var quake := TB.card(m, 0, EARTHQUAKE)
	m.players[0]["ap"] = 5
	assert_str(m.submit(0, {"t": "cast", "uid": quake})).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(String(m.cards[enemy]["stance"])).is_equal("def")
	assert_int(m.status_count(enemy, "paralyse")).is_equal(2)


func test_paralyse_help_text_names_stance_changes() -> void:
	var t := String(CardDB.STATUS_HELP["paralyse"])
	assert_str(t).contains("attack")
	assert_str(t).contains("move zones")
	assert_str(t).contains("change stance")
