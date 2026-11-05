extends GdUnitTestSuite
## L11 (design/owner-feedback-2026-11-05.md): Shapeshifter Loak (19) and Mimic (95) take on the ARTWORK
## of the unit whose stats they copy, for as long as they stay on the Field. Name, frame, text and
## category stay their own; the art resets when the card leaves the Field. The override lives on the
## card instance (art_o) and reaches every seat's view as `art_id`, so it works online and for spectators.

const LOAK := 19
const MIMIC := 95
const AURIC := 23
const LARVA := 156
const MAGE := TB.FILLER


## Player 0's `id` arrives in front-row column 1 (On Summon) and copies player 1's unit there.
func _copy(m: MatchEngine, id: int, target_id: int) -> Array:
	var target := TB.unit(m, 1, target_id, 0)
	var me := TB.special(m, 0, id, 0)
	assert_str(TB.choose_uids(m, [target])).is_equal("")
	return [me, target]


func test_loak_shows_the_copied_units_art_but_keeps_its_own_identity() -> void:
	var m := TB.make()
	var u := _copy(m, LOAK, AURIC)
	var loak: int = u[0]
	assert_int(m.art_id(loak)).is_equal(AURIC)
	for viewer in [0, 1]:
		var v := MatchView.card_view(m, loak, viewer)
		assert_int(int(v["art_id"])).is_equal(AURIC)
		assert_int(int(v["id"])).is_equal(LOAK)
		assert_str(String(v["name"])).is_equal("Shapeshifter Loak")
		assert_str(String(v["category"])).is_equal("unit")
	var spec: Dictionary = MatchView.build_spectator(m, 0)["players"][0]["units"][0]
	assert_int(int(spec["art_id"])).is_equal(AURIC)
	assert_int(CardArt.art_id_of(MatchView.card_view(m, loak, 1))).is_equal(AURIC)


func test_copy_logs_a_public_copy_form_fx() -> void:
	var m := TB.make()
	_copy(m, LOAK, AURIC)
	var found := {}
	for row in MatchView.log_for(m, 1):
		for e in row["fx"]:
			if String(e.get("k", "")) == "copy_form":
				found = e
	assert_int(int(found.get("art", -1))).is_equal(AURIC)
	assert_int(int(found.get("id", -1))).is_equal(LOAK)
	assert_dict(found["at"]).is_equal({"p": 0, "zone": "unit", "slot": 0})


func test_art_resets_when_the_copier_leaves_the_field() -> void:
	var m := TB.make()
	var loak: int = _copy(m, LOAK, AURIC)[0]
	m.move_to_pile(loak, "spent")
	assert_that(m.cards[loak]["art_o"]).is_null()
	assert_int(m.art_id(loak)).is_equal(LOAK)
	assert_bool(MatchView.card_view(m, loak, 0).has("art_id")).is_false()
	var again: Dictionary = m.cards[loak]
	again["zone"] = "limbo"
	m.players[0]["spent"].erase(loak)
	m.place_unit(loak, 0, 2, "atk")                         # back on the Field later: its own art
	assert_bool(MatchView.card_view(m, loak, 0).has("art_id")).is_false()


func test_mimic_shows_the_copied_units_art() -> void:
	var m := TB.make()
	var mimic: int = _copy(m, MIMIC, AURIC)[0]
	assert_int(int(MatchView.card_view(m, mimic, 1)["art_id"])).is_equal(AURIC)
	assert_str(String(MatchView.card_view(m, mimic, 1)["name"])).is_equal("Mimic")


func test_copying_an_evolved_unit_shows_its_evolved_art() -> void:
	var m := TB.make()
	var loak: int = _copy(m, LOAK, LARVA)[0]
	assert_int(m.art_id(loak)).is_equal(LARVA)


func test_a_copy_of_a_copy_shows_the_art_the_copied_unit_shows() -> void:
	var m := TB.make()
	var first := TB.unit(m, 1, LOAK, 0)
	m.cards[first]["art_o"] = AURIC                         # an opposing Loak showing Auric's art
	var loak := TB.special(m, 0, LOAK, 0)
	TB.choose_uids(m, [first])
	assert_int(m.art_id(loak)).is_equal(AURIC)


func test_other_units_carry_no_art_override() -> void:
	var m := TB.make()
	var mage := TB.unit(m, 0, MAGE, 0)
	assert_bool(MatchView.card_view(m, mage, 0).has("art_id")).is_false()
	assert_bool(MatchView.card_view(m, mage, 1).has("art_id")).is_false()
