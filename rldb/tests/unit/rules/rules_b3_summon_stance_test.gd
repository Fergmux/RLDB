extends GdUnitTestSuite
## Owner feedback 2026-10-20 B3: no Attack/Defense choice when summoning, except on the opponent's
## turn or in the Battle Phase. Otherwise the unit enters in Attack stance and its controller may
## change its stance afterwards (a unit summoned in the Recovery Phase may still change it there).

const TAG_TEAM_X := 12             # ability: lose 2 AP, summon a unit from Spent in this column
const HYDRA := 27                  # On Destroy: may summon a 1-cost Dragon from Spent to its zone
const BASIC_DRAGON := 2
const CREEPING_NULL := 65          # Ritual unit, 3 Runes
const BASIC_BEAST := 4


func _summon_from_hand(m: MatchEngine, p: int, slot: int) -> int:
	var u := TB.card(m, p, TB.WATER)
	m.players[p]["ap"] = 5
	assert_str(m.submit(p, {"t": "summon", "uid": u})).is_empty()
	assert_str(TB.choose(m, [TB.slot_label(slot)])).is_empty()
	return u


func test_setup_phase_summon_enters_attack_without_a_stance_prompt() -> void:
	var m := TB.make()
	var u := _summon_from_hand(m, 0, 0)
	assert_str(TB.pend_kind(m)).is_empty()
	assert_str(m.cards[u]["zone"]).is_equal("unit")
	assert_str(m.cards[u]["stance"]).is_equal("atk")


func test_recovery_phase_summon_enters_attack_without_a_stance_prompt() -> void:
	var m := TB.make()
	m.submit(0, {"t": "next_phase"})                    # turn 1: straight to Recovery
	assert_str(m.phase).is_equal(MatchEngine.PHASE_MAIN2)
	var u := _summon_from_hand(m, 0, 1)
	assert_str(TB.pend_kind(m)).is_empty()
	assert_str(m.cards[u]["stance"]).is_equal("atk")


func test_summon_command_asking_for_defense_is_refused() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	assert_str(m.submit(0, {"t": "summon", "uid": u, "stance": "def"})).is_equal(MatchEngine.SUMMON_ATTACK_ONLY)
	assert_str(m.cards[u]["zone"]).is_equal("hand")


func test_unit_summoned_in_setup_phase_can_change_to_defense_that_turn() -> void:
	var m := TB.make()
	var u := _summon_from_hand(m, 0, 0)
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_empty()
	assert_str(m.cards[u]["stance"]).is_equal("def")


func test_unit_summoned_in_recovery_phase_can_change_stance_there() -> void:
	var m := TB.make()
	m.submit(0, {"t": "next_phase"})
	var u := _summon_from_hand(m, 0, 1)
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_empty()
	assert_str(m.cards[u]["stance"]).is_equal("def")
	assert_str(m.submit(0, {"t": "stance", "uid": u})).is_empty()   # and back, like the Setup Phase
	assert_str(m.cards[u]["stance"]).is_equal("atk")


func test_unit_summoned_before_the_recovery_phase_still_cannot_change_stance_there() -> void:
	var m := TB.make()
	TB.to_turn2(m)                                       # player 1, Setup Phase
	var old := TB.unit(m, 1, TB.WATER, 2)
	var fresh := _summon_from_hand(m, 1, 0)              # summoned in the Setup Phase
	m.submit(1, {"t": "next_phase"})                     # Battle
	m.submit(1, {"t": "next_phase"})                     # Recovery
	assert_str(m.submit(1, {"t": "stance", "uid": old})).is_equal(MatchEngine.STANCE_PHASE_ONLY)
	assert_str(m.submit(1, {"t": "stance", "uid": fresh})).is_equal(MatchEngine.STANCE_PHASE_ONLY)


func test_summon_actions_offer_one_summon_button_without_a_stance() -> void:
	var m := TB.make()
	var u := TB.card(m, 0, TB.WATER)
	var acts := MatchView.actions_for(m, 0).filter(func(a): return a["t"] == "summon" and int(a["uid"]) == u)
	assert_int(acts.size()).is_equal(1)
	assert_str(String(acts[0]["label"])).is_equal("Summon")
	assert_bool(acts[0].has("stance")).is_false()


func test_ritual_summon_enters_attack_without_a_stance_prompt() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var mat := TB.unit(m, 1, BASIC_BEAST, 0)
	m.apply_status(mat, "rune", 3)
	var r := TB.card(m, 1, CREEPING_NULL, "extra")
	assert_str(m.submit(1, {"t": "ritual", "uid": r})).is_empty()
	assert_str(TB.choose_uids(m, [mat])).is_empty()
	assert_str(TB.choose(m, [TB.slot_label(0)])).is_empty()
	assert_str(TB.pend_kind(m)).is_not_equal("stance")
	assert_str(m.cards[r]["zone"]).is_equal("unit")
	assert_str(m.cards[r]["stance"]).is_equal("atk")


func test_effect_summon_in_setup_phase_enters_attack_without_a_prompt() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var tt := TB.unit(m, 1, TAG_TEAM_X, 3)               # back row, column 1
	var spent := TB.card(m, 1, TB.WATER, "spent")
	assert_str(TB.ability(m, tt, 0)).is_empty()
	assert_str(TB.choose_uids(m, [spent])).is_empty()
	if TB.pend_kind(m) == "slot":
		assert_str(TB.choose(m, [TB.slot_label(0)])).is_empty()
	assert_str(TB.pend_kind(m)).is_not_equal("stance")
	assert_str(m.cards[spent]["zone"]).is_equal("unit")
	assert_str(m.cards[spent]["stance"]).is_equal("atk")


func test_effect_summon_in_battle_phase_asks_for_a_stance() -> void:
	var m := TB.make()
	TB.p1_battle(m)
	var tt := TB.unit(m, 1, TAG_TEAM_X, 3)
	var spent := TB.card(m, 1, TB.WATER, "spent")
	assert_str(TB.ability(m, tt, 0)).is_empty()
	assert_str(TB.choose_uids(m, [spent])).is_empty()
	if TB.pend_kind(m) == "slot":
		assert_str(TB.choose(m, [TB.slot_label(0)])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("stance")
	assert_str(TB.choose(m, ["Defense"])).is_empty()
	assert_str(m.cards[spent]["stance"]).is_equal("def")


func test_effect_summon_on_the_opponents_turn_asks_for_a_stance() -> void:
	var m := TB.make()
	TB.to_turn2(m)                                       # player 1's turn; player 0's Hydra dies
	var hy := TB.unit(m, 0, HYDRA, 0)
	var drake := TB.card(m, 0, BASIC_DRAGON, "spent")
	TB.kill(m, hy, 1)
	# The optional "Summon a Dragon?" choice, then its zone (the zone Hydra left), then the stance.
	for i in 4:
		if TB.pend_kind(m) == "stance" or TB.pend_kind(m) == "":
			break
		if TB.pend_kind(m) == "slot":
			assert_str(TB.choose(m, [TB.slot_label(0)])).is_empty()
		else:
			assert_str(TB.choose_uids(m, [drake])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("stance")
	assert_int(int(m.pending["player"])).is_equal(0)
	assert_str(TB.choose(m, ["Defense"])).is_empty()
	assert_str(m.cards[drake]["stance"]).is_equal("def")
