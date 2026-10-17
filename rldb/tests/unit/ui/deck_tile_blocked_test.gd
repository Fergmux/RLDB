extends GdUnitTestSuite
## Review finding: a deck that breaks the deck caps (an old oversized save) has a disabled choose
## button with the reason as its tooltip.


func test_blocked_tile_cannot_be_chosen() -> void:
	var t: DeckTile = auto_free(DeckTile.new({"title": "Big", "theme": "", "main": [], "extra": [], "btn_text": "Use this deck", "blocked": "Too many cards."}))
	add_child(t)
	var btns := t.find_children("*", "Button", true, false).filter(func(b): return b.text == "Use this deck")
	assert_int(btns.size()).is_equal(1)
	assert_bool(btns[0].disabled).is_true()
	assert_str(btns[0].tooltip_text).is_equal("Too many cards.")


func test_usable_tile_is_enabled() -> void:
	var t: DeckTile = auto_free(DeckTile.new({"title": "Ok", "theme": "", "main": [], "extra": [], "btn_text": "Use this deck"}))
	add_child(t)
	var btns := t.find_children("*", "Button", true, false).filter(func(b): return b.text == "Use this deck")
	assert_bool(btns[0].disabled).is_false()
