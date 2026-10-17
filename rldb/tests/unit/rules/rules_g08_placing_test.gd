extends GdUnitTestSuite
## G08 (design/playtest-feedback-08.md): every zone choice names the card it places
## (`pending.placing`, exposed as `placing_uid` / `placing` in the chooser's view), so the
## placement arrow starts at the card being summoned or moved, never at the effect's card.


func _main() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)                     # player 1 active, Main Phase 1
	m.players[1]["ap"] = 10
	return m


func test_normal_summon_places_the_hand_card() -> void:
	var m := _main()
	var h := TB.card(m, 1, TB.WATER)
	assert_str(m.submit(1, {"t": "summon", "uid": h, "stance": "atk"})).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("slot")
	var pd := MatchView._pending_view(m, 1)
	assert_int(int(pd["placing_uid"])).is_equal(h)
	assert_str(String(pd["placing_zone"])).is_equal("hand")
	assert_bool(pd.has("placing")).is_false()          # not on the Field: no board position


func test_summon_from_spent_by_an_ability_places_the_chosen_unit_not_the_ability_card() -> void:
	var m := _main()
	var sac := TB.unit(m, 1, TB.WATER, 1)
	var ab := TB.unit(m, 1, 12, 4)                       # Pay 2 AP: summon from Spent in this column
	assert_str(m.submit(1, {"t": "sacrifice", "uid": sac})).is_empty()
	assert_str(TB.ability(m, ab)).is_empty()
	TB.choose_uids(m, [sac])
	assert_str(TB.pend_kind(m)).is_equal("slot")
	var pd := MatchView._pending_view(m, 1)
	assert_int(int(pd["source_uid"])).is_equal(ab)
	assert_int(int(pd["placing_uid"])).is_equal(sac)
	assert_str(String(pd["placing_zone"])).is_equal("spent")


func test_fusion_by_ability_places_the_fusion_unit() -> void:
	var m := _main()
	var hydra := TB.unit(m, 1, 27, 0)
	var guard := TB.unit(m, 1, 28, 2)
	var al := TB.unit(m, 1, 40, 1)
	var wyrm := TB.card(m, 1, 93, "extra")
	assert_str(TB.ability(m, al)).is_empty()
	for _i in 4:
		if TB.pend_kind(m) == "slot":
			break
		for o in m.pending["options"]:
			if int(o.get("v", -1)) in [wyrm, hydra, guard]:
				TB.choose_uids(m, [int(o["v"])])
				break
	assert_str(TB.pend_kind(m)).is_equal("slot")
	var pd := MatchView._pending_view(m, 1)
	assert_int(int(pd["placing_uid"])).is_equal(wyrm)
	assert_str(String(pd["placing_zone"])).is_equal("extra")


func test_power_and_set_place_their_own_card() -> void:
	var m := _main()
	var trap := TB.card(m, 1, 45)                        # Magic Cylinder
	assert_str(m.submit(1, {"t": "set", "uid": trap})).is_empty()
	if TB.pend_kind(m) == "slot":
		assert_int(int(MatchView._pending_view(m, 1)["placing_uid"])).is_equal(trap)


func test_the_opponent_never_sees_which_hand_card_is_placed() -> void:
	var m := _main()
	var h := TB.card(m, 1, TB.WATER)
	assert_str(m.submit(1, {"t": "summon", "uid": h, "stance": "atk"})).is_empty()
	var other := MatchView._pending_view(m, 0)
	assert_bool(other.has("placing_uid")).is_false()
	assert_bool(other.has("placing_zone")).is_false()
