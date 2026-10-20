extends GdUnitTestSuite
## Owner feedback 2026-10-18: draft categories are tabs drafted in any order; a tab shows its picks
## left and is disabled once its picks are all made.

const View := preload("res://src/ui/game/deck_select_view.gd")


func _tabs(left: Dictionary, current: String) -> FolderTabs:
	var v: DeckSelectView = View.new(null)
	var dr := {"categories": ["unit", "spell", "trap"], "labels": {"unit": "Unit", "spell": "Spell", "trap": "Trap"},
		"left": left, "category": current}
	var ft: FolderTabs = auto_free(v.category_tabs(dr))
	add_child(ft)
	return ft


func test_a_tab_with_picks_left_is_enabled_and_says_how_many() -> void:
	var ft := _tabs({"unit": 1, "spell": 3, "trap": 0}, "unit")
	var b := ft.tab("spell")
	assert_bool(b.disabled).is_false()
	assert_str(b.tooltip_text).is_equal("Draft Spell cards: 3 picks left.")


func test_a_finished_category_tab_is_disabled() -> void:
	var ft := _tabs({"unit": 1, "spell": 3, "trap": 0}, "unit")
	var b := ft.tab("trap")
	assert_bool(b.disabled).is_true()
	assert_str(b.tooltip_text).contains("all picks made")


func test_the_current_category_is_the_open_tab() -> void:
	var ft := _tabs({"unit": 1, "spell": 3, "trap": 0}, "spell")
	assert_str(ft.selected).is_equal("spell")
