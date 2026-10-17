extends GdUnitTestSuite
## G02 (playtest feedback 08): a deck tile opens and closes its full card list in place, so the
## deck-select list is never rebuilt (the rebuild reset the rim, glow and scroll: a flash).


func _tile(open: bool = false) -> DeckTile:
	var main := [Series.card_summary(112), Series.card_summary(112), Series.card_summary(36)]
	var t: DeckTile = auto_free(DeckTile.new({"title": "Deck", "theme": "", "main": main, "extra": [], "btn_text": "Choose deck", "open": open}))
	add_child(t)
	return t


func _toggle_text(t: DeckTile) -> String:
	var b: Array = t.find_children("*", "Button", true, false).filter(func(x): return x.text.ends_with("full list"))
	return b[0].text if b.size() == 1 else ""


func _sections(t: DeckTile) -> int:
	return t.find_children("*", "Label", true, false).filter(func(l): return l.text.begins_with("MAIN DECK") or l.text.begins_with("EXTRA DECK")).size()


func test_set_open_adds_and_removes_the_list_in_place() -> void:
	var t := _tile()
	assert_int(_sections(t)).is_equal(0)
	assert_str(_toggle_text(t)).is_equal("View full list")
	t.set_open(true)
	assert_bool(t.selected).is_true()
	assert_int(_sections(t)).is_equal(2)
	assert_str(_toggle_text(t)).is_equal("Hide full list")
	t.set_open(true)                       # idempotent: no second copy of the list
	assert_int(_sections(t)).is_equal(2)
	t.set_open(false)
	assert_bool(t.selected).is_false()
	assert_int(_sections(t)).is_equal(0)
	assert_str(_toggle_text(t)).is_equal("View full list")


func test_list_sits_above_the_buttons() -> void:
	var t := _tile()
	t.set_open(true)
	var root: Node = t.get_child(0)
	var last: Node = root.get_child(root.get_child_count() - 1)
	assert_bool(last is HBoxContainer).is_true()
	assert_int(last.find_children("*", "Button", true, false).size()).is_equal(2)


func test_tile_built_open_starts_with_its_gold_rim() -> void:
	var t := _tile(true)
	assert_int(_sections(t)).is_equal(2)
	var sb := t.get_theme_stylebox("panel") as StyleBoxFlat
	assert_bool(sb.border_color.is_equal_approx(UIStyle.GOLD_HI)).is_true()
