extends GdUnitTestSuite
## J11 (owner feedback 2026-10-22): sacrifice starts from the "Sacrifice Unit" button under the
## player plate (command sacrifice_pick): pick one of the units that may be sacrificed, confirm,
## and it is sacrificed for +1 AP. The button is enabled only while a sacrifice is legal; the card
## action row no longer offers Sacrifice.


func _pick_action(m: MatchEngine, p: int) -> Dictionary:
	for a in MatchView.actions_for(m, p):
		if a["t"] == "sacrifice_pick":
			return a
	return {}


func test_button_action_is_offered_while_a_sacrifice_is_legal() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0)
	var a := _pick_action(m, 0)
	assert_bool(a.is_empty()).is_false()
	assert_str(String(a["label"])).is_equal("Sacrifice Unit")
	assert_bool(a.has("uid")).is_false()
	assert_bool(bool(a["ok"])).is_true()


func test_button_action_is_disabled_without_a_unit() -> void:
	var m := TB.make()
	var a := _pick_action(m, 0)
	assert_bool(bool(a["ok"])).is_false()
	assert_str(String(a["reason"])).is_equal("You have no unit on the Field to sacrifice.")


func test_button_action_gives_the_shared_reason_when_no_unit_qualifies() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0, "atk", null, null, true)    # summoned this turn
	var a := _pick_action(m, 0)
	assert_bool(bool(a["ok"])).is_false()
	assert_str(String(a["reason"])).is_equal("A unit summoned this turn cannot be sacrificed.")


func test_button_action_is_disabled_in_the_battle_phase() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	TB.unit(m, 1, TB.WATER, 0)
	var a := _pick_action(m, 1)
	assert_bool(bool(a["ok"])).is_false()
	assert_str(String(a["reason"])).contains("Setup or Recovery Phase")


func test_pick_offers_only_units_that_may_be_sacrificed() -> void:
	var m := TB.make()
	var ok := TB.unit(m, 0, TB.WATER, 0)
	TB.unit(m, 0, TB.WATER, 1, "atk", null, null, true)    # summoned this turn
	var deb := TB.unit(m, 0, TB.WATER, 2)
	m.apply_status(deb, "debilitate", 1)
	TB.unit(m, 1, TB.WATER, 0)                              # the opponent's
	assert_str(m.submit(0, {"t": "sacrifice_pick"})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("select")
	assert_bool(bool(m.pending["cancellable"])).is_true()
	assert_array(m.pending["options"].map(func(o): return int(o["v"]))).is_equal([ok])


func test_pick_then_confirm_sacrifices_the_unit_for_one_ap() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	var ap: int = m.players[0]["ap"]
	m.submit(0, {"t": "sacrifice_pick"})
	assert_str(TB.choose_uids(m, [u])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("confirm")
	assert_str(String(m.pending["prompt"])).contains(m.name_of(u))
	assert_bool(bool(m.pending["cancellable"])).is_true()
	assert_str(TB.choose(m, [MatchEngine.SACRIFICE_YES])).is_empty()
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(String(m.cards[u]["zone"])).is_equal("spent")
	assert_int(m.players[0]["ap"]).is_equal(ap + 1)
	assert_int(TB.log_index(m, "sacrifices")).is_not_equal(-1)


func test_confirmation_offers_sacrifice_and_cancel_only() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "sacrifice_pick"})
	assert_str(String(m.pending["prompt"])).is_equal(MatchEngine.SACRIFICE_PICK_PROMPT)
	TB.choose_uids(m, [u])
	assert_array(m.pending["options"].map(func(o): return String(o["label"]))).is_equal([MatchEngine.SACRIFICE_YES])
	assert_bool(bool(m.pending["cancellable"])).is_true()


func test_cancel_at_the_pick_or_the_confirmation_changes_nothing() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "sacrifice_pick"})
	assert_str(m.submit(0, {"t": "cancel", "id": int(m.pending["id"])})).is_empty()
	assert_bool(m.pending.is_empty() and m.stack.is_empty()).is_true()
	m.submit(0, {"t": "sacrifice_pick"})
	TB.choose_uids(m, [u])
	assert_str(m.submit(0, {"t": "cancel", "id": int(m.pending["id"])})).is_empty()
	assert_bool(m.pending.is_empty() and m.stack.is_empty()).is_true()
	assert_str(String(m.cards[u]["zone"])).is_equal("unit")


func test_the_opponent_sees_only_a_choice_being_made() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0)
	m.submit(0, {"t": "sacrifice_pick"})
	var w: Dictionary = MatchView.build(m, 1)["pending"]
	assert_bool(bool(w["mine"])).is_false()
	assert_bool(w.has("options")).is_false()


func test_sacrifice_pick_is_refused_off_turn() -> void:
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0)
	assert_str(m.submit(1, {"t": "sacrifice_pick"})).is_equal("It is not your turn.")


func test_the_bot_never_sends_the_button_command() -> void:
	var m := TB.make()
	TB.unit(m, 0, TB.WATER, 0)
	var brain := BotBrain.new()
	brain.me = 0
	var ts: Array = brain.candidates(m).map(func(c): return String(c["t"]))
	assert_bool(ts.has("sacrifice_pick")).is_false()
	assert_bool(ts.has("sacrifice")).is_true()               # it still sacrifices a chosen unit
