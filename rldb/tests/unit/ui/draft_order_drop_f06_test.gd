extends GdUnitTestSuite
## F06-05: dropping a category on the top half of a row inserts it before that row, on the
## bottom half after it (the drag-and-drop logic, independent of the real cursor).

const OrderRow := preload("res://src/ui/game/deck_select_view.gd").OrderRow


func _row(on_drop: Callable) -> Control:
	var r: Control = auto_free(OrderRow.new("unit", 1, "Unit", 9, on_drop))
	add_child(r)
	r.size = Vector2(800, 44)
	return r


func test_top_half_drops_before_and_bottom_half_after() -> void:
	var got := []
	var r := _row(func(from, onto, after): got.append([from, onto, after]))
	var data := {"draft_cat": "power"}
	assert_bool(r._can_drop_data(Vector2(80, 6), data)).is_true()
	assert_int(r._mark).is_equal(-1)
	r._drop_data(Vector2(80, 6), data)
	assert_bool(r._can_drop_data(Vector2(80, 38), data)).is_true()
	assert_int(r._mark).is_equal(1)
	r._drop_data(Vector2(80, 38), data)
	assert_array(got).is_equal([["power", "unit", false], ["power", "unit", true]])


func test_a_row_refuses_itself_and_foreign_data() -> void:
	var r := _row(func(_a, _b, _c): pass)
	assert_bool(r._can_drop_data(Vector2(80, 6), {"draft_cat": "unit"})).is_false()
	assert_bool(r._can_drop_data(Vector2(80, 6), {"card": 3})).is_false()
