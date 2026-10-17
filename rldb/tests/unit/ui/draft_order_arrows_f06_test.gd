extends GdUnitTestSuite
## F06-05 / owner answer 2026-10-17 §8: the draft order is reordered with each row's up / down
## arrows only; the rows take no drag-and-drop.

const View := preload("res://src/ui/game/deck_select_view.gd")


func _row() -> Control:
	var r: Control = auto_free(View.OrderRow.new("unit", 1, "Unit", 9))
	add_child(r)
	r.size = Vector2(800, 44)
	return r


func test_rows_offer_no_drag_and_drop() -> void:
	var r := _row()
	assert_bool(r.has_method("_get_drag_data")).is_false()
	assert_bool(r.has_method("_can_drop_data")).is_false()
	assert_bool(r.has_method("_drop_data")).is_false()
	assert_int(r.mouse_default_cursor_shape).is_not_equal(Control.CURSOR_MOVE)
	assert_str(r.tooltip_text).not_contains("Drag")


func test_arrow_moves_keep_every_category_once() -> void:
	var v: DeckSelectView = View.new(null)
	v._order = ["unit", "spell", "extra", "trap", "power"]
	for i in 4:
		v._move("power", -1)
	assert_array(v._order).is_equal(["power", "unit", "spell", "extra", "trap"])
	assert_array(v._focus_after).is_equal(["power", "up"])
	v._move("power", -1)            # already first: nothing moves
	assert_array(v._order).is_equal(["power", "unit", "spell", "extra", "trap"])
	v._move("unit", 1)
	assert_array(v._order).is_equal(["power", "spell", "unit", "extra", "trap"])
	assert_array(v._focus_after).is_equal(["unit", "down"])
	v._move("trap", 1)              # already last
	assert_array(v._order).is_equal(["power", "spell", "unit", "extra", "trap"])
