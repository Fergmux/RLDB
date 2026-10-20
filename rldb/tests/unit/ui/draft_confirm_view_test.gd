extends GdUnitTestSuite
## Owner feedback 22 Oct, J30: once every card is drafted the draft screen shows Confirm
## selections (the deck locks in only then). The tab strip drops its basic-unit chip, which the
## complete pane shows with its own Change button, and the picks are summed per category.
## Story: design/owner-feedback-2026-10-22.md J30.

const View := preload("res://src/ui/game/deck_select_view.gd")


func _dr(complete: bool) -> Dictionary:
	return {"categories": ["unit", "spell", "extra"], "labels": {"unit": "Unit", "spell": "Spell", "extra": "Extra Deck"},
		"left": {"unit": 0, "spell": 0, "extra": 0} if complete else {"unit": 1, "spell": 0, "extra": 0},
		"category": "" if complete else "unit", "complete": complete, "basic_copies": 3,
		"basic": {"id": 1, "name": "Basic Mage", "type": "Water", "race": "Mage"}}


func test_j30_strip_keeps_the_basic_chip_while_drafting() -> void:
	var v: DeckSelectView = View.new(null)
	var ft: FolderTabs = auto_free(v.category_tabs(_dr(false)))
	add_child(ft)
	assert_object(ft.find_child("BasicChip", true, false)).is_not_null()


func test_j30_strip_drops_the_basic_chip_once_complete() -> void:
	var v: DeckSelectView = View.new(null)
	var ft: FolderTabs = auto_free(v.category_tabs(_dr(true)))
	add_child(ft)
	assert_object(ft.find_child("BasicChip", true, false)).is_null()
	assert_str(ft.selected).is_empty()


func test_j30_drafted_counts_group_the_extra_deck_kinds() -> void:
	var picked := [{"category": "unit"}, {"category": "unit"}, {"category": "fusion"}, {"category": "ritual"},
		{"category": "arcane"}, {"category": "spell"}]
	assert_dict(View.drafted_counts(picked)).is_equal({"unit": 2, "extra": 3, "spell": 1})
