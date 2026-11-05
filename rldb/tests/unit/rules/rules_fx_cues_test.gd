extends GdUnitTestSuite
## L batch final QA (design/qa-final-2026-11-05.md): the two cues the audio pass could not wire
## (L1) now have public presentation events.
##   - "to_hand": a card is added to a Hand by an effect. Public: who and from where; the card's
##     identity only for the seats that could see it (its owner; everyone when it came from a public
##     zone). Sfx.for_fx plays "card_return".
##   - "miss": a declared attack does not resolve (its attacker or target is gone, or the target is
##     now Protected). Sfx.for_fx plays "miss".

const MANS_BEST_FRIEND := 73       # On Summon: Add a Warrior Unit from Draw to Hand.
const WARRIOR := 37                # Solomon, the Captain (Warrior)
const HIDDEN_TRAP := 50            # Wabuku: any face-down card opens a hidden response window


func _events(m: MatchEngine, viewer: int, kind: String) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer):
		for e in row["fx"]:
			if String(e.get("k", "")) == kind:
				out.append(e)
	return out


func test_card_added_from_draw_emits_to_hand_with_identity_for_its_owner_only() -> void:
	# Arrange
	var m := TB.make()
	var w := TB.card(m, 0, WARRIOR, "draw")
	# Act
	TB.special(m, 0, MANS_BEST_FRIEND, 1)
	if TB.pend_kind(m) != "":
		TB.choose_uids(m, [w])
	# Assert
	assert_str(String(m.cards[w]["zone"])).is_equal("hand")
	var mine := _events(m, 0, "to_hand")
	assert_int(mine.size()).is_equal(1)
	if mine.size() != 1:
		return
	assert_int(int(mine[0]["p"])).is_equal(0)
	assert_str(String(mine[0]["from"])).is_equal("draw")
	assert_int(int(mine[0].get("id", -1))).is_equal(WARRIOR)
	for viewer in [1, -1]:
		var theirs := _events(m, viewer, "to_hand")
		assert_int(theirs.size()).is_equal(1)
		assert_bool(theirs[0].has("id")).override_failure_message("identity leaked to %d" % viewer).is_false()
		assert_bool(theirs[0].has("seen_by")).is_false()


func test_to_hand_and_miss_map_to_their_sounds() -> void:
	assert_str(Sfx.for_fx({"k": "to_hand", "p": 0, "from": "draw"}, 1)).is_equal("card_return")
	assert_str(Sfx.for_fx({"k": "miss", "p": 1, "at": {}}, 0)).is_equal("miss")


func test_attack_whose_target_left_the_field_emits_a_public_miss() -> void:
	# Arrange: player 1 attacks; a hidden response window lets the target leave before the battle.
	var m := TB.make(7, 20, true)
	var target := TB.unit(m, 0, TB.FILLER, 0, "def")
	TB.set_card(m, 0, HIDDEN_TRAP, 0)
	var attacker := TB.unit(m, 1, TB.FIRE, 0)
	TB.p1_battle(m)
	assert_str(m.submit(1, {"t": "attack", "uid": attacker})).is_equal("")
	if TB.pend_kind(m) == "attack_target":
		TB.choose_uids(m, [target])
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	m.move_to_pile(target, "spent")   # it leaves the Field while the defender decides
	# Act
	TB.choose(m, ["Skip"])
	# Assert
	assert_str(TB.log_text(m)).contains("The attack does not resolve (target left the Field).")
	for viewer in [0, 1, -1]:
		var miss := _events(m, viewer, "miss")
		assert_int(miss.size()).is_equal(1)
		if miss.size() != 1:
			return
		assert_int(int(miss[0]["p"])).is_equal(1)
		assert_dict(miss[0]["at"]).is_equal({"p": 1, "zone": "unit", "slot": 0})
	assert_int(_events(m, 0, "battle").size()).is_equal(0)


func test_attack_that_resolves_emits_no_miss() -> void:
	var m := TB.make()
	var target := TB.unit(m, 0, TB.FILLER, 0, "def")
	var attacker := TB.unit(m, 1, TB.FIRE, 0)
	TB.p1_battle(m)
	TB.attack(m, attacker, target)
	assert_int(_events(m, 0, "miss").size()).is_equal(0)
	assert_int(_events(m, 0, "battle").size()).is_equal(1)
