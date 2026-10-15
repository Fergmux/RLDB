extends GdUnitTestSuite
## Hidden-information redaction in views, logs and choice payloads.


func test_opponent_view_has_hand_count_but_no_hand_contents() -> void:
	var m := TB.make()
	var v := MatchView.build(m, 1)
	assert_int(v["players"][0]["counts"]["hand"]).is_equal(4)
	assert_bool(v["players"][0].has("hand")).is_false()
	assert_bool(v["players"][0].has("draw_inspect")).is_false()


func test_set_card_is_anonymous_to_opponent_in_view_and_log() -> void:
	var m := TB.make()
	var trap := TB.card(m, 0, 45)
	m.submit(0, {"t": "set", "uid": trap})
	TB.choose(m, ["column 2"])
	var v := MatchView.build(m, 1)
	var shown: Dictionary = v["players"][0]["backrow"][1]
	assert_bool(shown["hidden"]).is_true()
	assert_bool(shown.has("uid")).is_false()
	assert_bool(shown.has("name")).is_false()
	var text := JSON.stringify(v)
	assert_bool(text.contains("Magic Cylinder")).is_false()
	assert_bool(text.contains(str(trap))).is_false()
	var own := MatchView.build(m, 0)
	assert_str(own["players"][0]["backrow"][1]["name"]).is_equal("Magic Cylinder")


func test_opponent_log_hides_drawn_card_identities() -> void:
	var m := TB.make()
	var secret := TB.card(m, 1, 21, "draw")
	m.players[1]["draw"].erase(secret)
	m.players[1]["draw"].append(secret)        # top of Draw
	TB.to_turn2(m)
	var opp_log := JSON.stringify(MatchView.log_for(m, 0))
	var own_log := JSON.stringify(MatchView.log_for(m, 1))
	assert_bool(opp_log.contains("Shen")).is_false()
	assert_bool(opp_log.contains("draws 4 cards")).is_true()
	assert_bool(own_log.contains("Shen")).is_true()


func test_own_draw_inspection_shows_contents_without_changing_order() -> void:
	var m := TB.make()
	var before: Array = m.players[0]["draw"].duplicate()
	var v := MatchView.build(m, 0)
	var shown: Array = v["players"][0]["draw_inspect"].map(func(c): return c["uid"])
	var a := shown.duplicate()
	var b := before.duplicate()
	a.sort()
	b.sort()
	assert_array(a).is_equal(b)
	assert_array(m.players[0]["draw"]).is_equal(before)


func test_pending_choice_options_are_hidden_from_non_chooser() -> void:
	var m := TB.make()
	TB.card(m, 1, 21, "spent")
	var into_void := TB.card(m, 0, 101)
	m.submit(0, {"t": "cast", "uid": into_void})
	var chooser: Dictionary = MatchView.build(m, 0)["pending"]
	var other: Dictionary = MatchView.build(m, 1)["pending"]
	assert_bool(chooser["mine"]).is_true()
	assert_str(chooser["options"][0]["card"]["name"]).is_equal("Shen the World Dragon")
	assert_bool(other["mine"]).is_false()
	assert_bool(other.has("options")).is_false()


func test_choice_payload_uses_indices_not_hidden_uids() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var fd := TB.set_card(m, 0, 45, 0)
	TB.power(m, 1, 55)                          # Spy: reveal a face-down card
	m.submit(1, {"t": "ability", "uid": m.players[1]["powers"][0], "idx": 0})
	var v := MatchView.build(m, 1)
	assert_bool(JSON.stringify(v).contains(str(fd))).is_false()


func test_hidden_window_prompts_holder_of_face_down_card_even_without_eligible_trap() -> void:
	var m := TB.make(7, 20, true)
	TB.to_turn2(m)
	TB.to_battle(m)
	TB.set_card(m, 0, 83, 2)                    # a face-down Spell: cannot respond
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.attack(m, a, -1)
	assert_str(m.pending["kind"]).is_equal("trap_response")
	assert_int(m.pending["options"].size()).is_equal(1)
	assert_str(MatchView.build(m, 1)["pending"]["prompt"]).contains("deciding whether to respond")
	TB.choose(m, ["Pass"])
	assert_int(m.players[0]["hp"]).is_equal(50)


func test_hidden_window_looks_identical_to_opponent_with_or_without_eligible_trap() -> void:
	var with_trap := TB.make(7, 20, true)
	var without := TB.make(7, 20, true)
	for m in [with_trap, without]:
		TB.to_turn2(m)
		TB.to_battle(m)
	TB.set_card(with_trap, 0, 45, 0)
	TB.set_card(without, 0, 83, 0)
	for m in [with_trap, without]:
		TB.attack(m, TB.unit(m, 1, TB.WATER, 0, "atk", 10), -1)
	var v1: Dictionary = MatchView.build(with_trap, 1)["pending"]
	var v2: Dictionary = MatchView.build(without, 1)["pending"]
	assert_str(v1["prompt"]).is_equal(v2["prompt"])
	assert_array(v1.keys()).contains_exactly_in_any_order(v2.keys())


func test_no_window_when_opponent_has_no_face_down_cards() -> void:
	var m := TB.make(7, 20, true)
	TB.to_turn2(m)
	TB.to_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	TB.attack(m, a, -1)
	assert_bool(m.pending.is_empty()).is_true()


func test_opponent_spent_exhaust_and_extra_contents_are_redacted() -> void:
	var m := TB.make()
	var s := TB.card(m, 0, 21, "spent")
	var e := TB.card(m, 0, 22, "exhaust")
	var x := TB.card(m, 0, 93, "extra")
	var v := MatchView.build(m, 1)
	var blob := JSON.stringify(v)
	for name in ["Shen the World Dragon", "Zorath, Deity of the End", "Bastion Wyrm"]:
		assert_bool(blob.contains(name)).is_false()
	for uid in [s, e, x]:
		assert_bool(blob.contains("\"uid\":%d" % uid)).is_false()
	var counts: Dictionary = v["players"][0]["counts"]
	assert_int(counts["spent"]).is_equal(1)
	assert_int(counts["exhaust"]).is_equal(1)
	assert_int(counts["extra"]).is_equal(1)
