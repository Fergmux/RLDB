extends GdUnitTestSuite
## Owner feedback 23 Oct, K2: once the draft is complete the pane drops the "Basic unit x3" caption
## above Change basic unit, and a finished category tab shows a round enamelled tick medallion in the
## category's colour instead of a flat text tick in a pill.
## Story: design/owner-feedback-2026-10-23.md K2.

const View := preload("res://src/ui/game/deck_select_view.gd")


func _dr(complete: bool) -> Dictionary:
	return {"categories": ["unit", "spell"], "labels": {"unit": "Unit", "spell": "Spell"},
		"left": {"unit": 0, "spell": 0} if complete else {"unit": 0, "spell": 2},
		"category": "" if complete else "spell", "complete": complete, "total": 4, "basic_copies": 3,
		"basic": Series.card_summary(Series.basic_for("Water", "Mage")), "picked": []}


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)


func test_k2_complete_pane_has_no_basic_copies_caption() -> void:
	var v: DeckSelectView = View.new(null)
	var pane: Control = auto_free(v.confirm_pane(_dr(true)))
	add_child(pane)
	assert_object(pane.find_child("ChangeBasicComplete", true, false)).is_not_null()
	for t in _labels(pane):
		assert_str(String(t)).not_contains("Basic unit ×")


func test_k2_finished_tab_shows_a_tick_medallion_in_its_colour() -> void:
	var v: DeckSelectView = View.new(null)
	var ft: FolderTabs = auto_free(v.category_tabs(_dr(false)))
	add_child(ft)
	var done := ft.tab("unit").find_child("DoneTick", true, false)
	assert_object(done).is_instanceof(TickMedallion)
	assert_bool((done as TickMedallion).tint.is_equal_approx(UIStyle.CATEGORY_COLORS["unit"])).is_true()
	for t in _labels(ft.tab("unit")):
		assert_str(String(t)).not_contains("✓")


func test_k2_open_tab_keeps_its_picks_left_count() -> void:
	var v: DeckSelectView = View.new(null)
	var ft: FolderTabs = auto_free(v.category_tabs(_dr(false)))
	add_child(ft)
	assert_object(ft.tab("spell").find_child("DoneTick", true, false)).is_null()
	assert_array(_labels(ft.tab("spell"))).contains(["2"])


func test_k2_medallion_is_round_and_click_through() -> void:
	var m: TickMedallion = auto_free(TickMedallion.new(Color.RED, 24.0))
	assert_float(m.custom_minimum_size.x).is_equal(26.0)
	assert_int(m.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_float(TickMedallion.rim_width(24.0)).is_greater(2.0)


func test_k2_enamel_shades_stay_deep_enough_for_the_ivory_tick() -> void:
	# A pale tint is deepened so the ivory tick reads on the enamel.
	var sh := TickMedallion.enamel(Color(0.95, 0.92, 0.85))
	assert_float((sh[1] as Color).v).is_less_equal(0.78)
	assert_float((sh[2] as Color).v).is_less((sh[1] as Color).v)
