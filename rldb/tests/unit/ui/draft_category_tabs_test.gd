extends GdUnitTestSuite
## Owner feedback 2026-10-18: draft categories are tabs drafted in any order; a tab shows its picks
## left and is disabled once its picks are all made.

const View := preload("res://src/ui/game/deck_select_view.gd")


func _tab(cat: String, n_left: int, on: bool) -> Button:
	var v: DeckSelectView = View.new(null)
	var b: Button = auto_free(v._category_tab(cat, cat.capitalize(), n_left, on))
	add_child(b)
	return b


func test_a_tab_with_picks_left_is_enabled_and_says_how_many() -> void:
	var b := _tab("spell", 3, false)
	assert_bool(b.disabled).is_false()
	assert_str(b.tooltip_text).is_equal("Draft Spell cards: 3 picks left.")


func test_a_finished_category_tab_is_disabled() -> void:
	var b := _tab("trap", 0, false)
	assert_bool(b.disabled).is_true()
	assert_str(b.tooltip_text).contains("all picks made")
