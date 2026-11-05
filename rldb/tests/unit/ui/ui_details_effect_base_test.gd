extends GdUnitTestSuite
## L batch follow-up (5 Nov): the match card details pane's "Base" showed the printed stat even when
## an effect set the unit's base (Shapeshifter Loak / Mimic copying a unit (L11), Roma, ...). The
## per-seat view now carries the effect-set base (`base_atk` / `base_def`, only when an effect set
## it), and the stat tile reads "Base: printed → set base", with the up / down marker measured from
## the set base. Hidden cards still give nothing away.
## Story: design/owner-feedback-2026-11-05.md L11 (follow-up).

const LOAK := 19        # Shapeshifter Loak: copies the opposing unit in its column
const SOLOMON := 37     # Solomon, the Captain 20/14 Warrior (2026-11-03)


func _loak_copying_solomon() -> Dictionary:
	var m := TB.make()
	var foe := TB.unit(m, 1, SOLOMON, 0)
	var loak := TB.summon(m, 0, LOAK, 0)
	TB.choose_uids(m, [foe])
	return {"m": m, "loak": loak, "foe": foe}


func _num_label(p: Node, text: String) -> Label:
	for n in p.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text == text and l.get_theme_font_size("font_size") >= 20:
			return l
	return null


func test_view_carries_the_effect_set_base_of_a_copying_unit() -> void:
	# Arrange
	var s := _loak_copying_solomon()
	var m: MatchEngine = s["m"]
	# Act
	var v := MatchView.card_view(m, s["loak"], 1)
	# Assert: printed stays the card's own, base is what Loak copied.
	var df := CardDB.get_def(LOAK)
	assert_that(v["printed_atk"]).is_equal(df["atk"])
	assert_int(int(v["base_atk"])).is_equal(20)
	assert_int(int(v["base_def"])).is_equal(14)
	assert_int(int(v["atk"])).is_equal(20)


func test_view_has_no_set_base_for_an_unchanged_unit() -> void:
	# Arrange
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 1)
	# Act
	var v := MatchView.card_view(m, u, 0)
	# Assert
	assert_bool(v.has("base_atk")).is_false()
	assert_bool(v.has("base_def")).is_false()


func test_hidden_card_view_never_carries_a_base() -> void:
	# Arrange: a card in player 0's Hand with an effect-set base, seen by player 1.
	var m := TB.make()
	var h := TB.card(m, 0, TB.WATER, "hand")
	m.cards[h]["base_atk"] = 30
	m.cards[h]["base_def"] = 30
	# Act
	var v := MatchView.card_view(m, h, 1)
	# Assert
	assert_bool(v.get("hidden", false)).is_true()
	assert_bool(v.has("base_atk")).is_false()
	assert_bool(v.has("atk")).is_false()


func test_details_tile_shows_the_copied_base_of_a_varies_unit() -> void:
	# Arrange: Loak's printed ATK/DEF vary ("?"); it copied Solomon's 20/14.
	var s := _loak_copying_solomon()
	var v := MatchView.card_view(s["m"], s["loak"], 0)
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.size = Vector2(320, 700)
	add_child(p)
	# Act
	p.show_card(v)
	# Assert: the base is the copied stat (not "?"), and the current value equals it, so it is
	# drawn in the plain text colour (no buff / debuff colour).
	assert_int(p.count_text("Base:\n20")).is_equal(1)
	assert_int(p.count_text("Base:\n14")).is_equal(1)
	assert_int(p.count_text("Base: ?")).is_equal(0)
	var num := _num_label(p, "20")
	assert_object(num).is_not_null()
	assert_that(num.get_theme_color("font_color")).is_equal(UIStyle.TEXT)


func test_details_tile_shows_printed_arrow_set_base_for_a_printed_unit() -> void:
	# Arrange: a printed 8/8 unit whose base an effect set to 30/24 (as Mirrorflesh, Roma, set_base).
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 1)
	m.cards[u]["base_atk"] = 30
	m.cards[u]["base_def"] = 24
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.size = Vector2(320, 700)
	add_child(p)
	# Act
	p.show_card(MatchView.card_view(m, u, 1))
	# Assert
	assert_int(p.count_text("Base: 8 →\n30")).is_equal(1)
	assert_int(p.count_text("Base: 8 →\n24")).is_equal(1)
	var num := _num_label(p, "30")
	assert_object(num).is_not_null()
	assert_that(num.get_theme_color("font_color")).is_equal(UIStyle.TEXT)


func test_details_tile_measures_a_buff_from_the_set_base() -> void:
	# Arrange: Loak's copied 20 ATK, +6 from an effect.
	var s := _loak_copying_solomon()
	var m: MatchEngine = s["m"]
	m.cards[s["loak"]]["mods"].append({"atk": 6, "def": 0, "until": "perm", "src": "Test"})
	var v := MatchView.card_view(m, s["loak"], 0)
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.size = Vector2(320, 700)
	add_child(p)
	# Act
	p.show_card(v)
	# Assert
	var num := _num_label(p, "26")
	assert_object(num).is_not_null()
	assert_that(num.get_theme_color("font_color")).is_equal(UIStyle.GOOD)


func test_details_tile_keeps_plain_base_when_nothing_set_it() -> void:
	# Arrange
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 1)
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.size = Vector2(320, 700)
	add_child(p)
	# Act
	p.show_card(MatchView.card_view(m, u, 0))
	# Assert
	assert_int(p.count_text("Base: 8")).is_equal(2)
	assert_int(p.count_text("→")).is_equal(0)
