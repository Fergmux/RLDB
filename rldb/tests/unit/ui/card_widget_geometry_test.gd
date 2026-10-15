extends GdUnitTestSuite
## CardWidget geometry contract (F02-03): all card faces are 2:3 (3:2 rotated), preview/ready/order
## state never mutates the redacted view, and the drawn card rect letterboxes inside any widget rect.


func _unit_view() -> Dictionary:
	return {"uid": 1, "id": 1, "name": "Test", "category": "unit", "cost_kind": "ap", "cost": 2, "printed_cost": 2,
		"zone": "unit", "slot": 0, "face_up": true, "statuses": {}, "runes": 0, "text": "x", "support": "full",
		"art": {}, "race": "Mage", "type": "Water", "printed_atk": 8, "printed_def": 8, "atk": 8, "def": 8,
		"stance": "atk", "protected": false, "attacked": false}


func test_all_sizes_are_two_by_three() -> void:
	for k in CardWidget.SIZES:
		var s: Vector2 = CardWidget.SIZES[k]
		# 85x128 is the pixel-grid 2:3 (85.33 x 128): allow under one pixel of error on the long side.
		assert_float(absf(s.x * 3.0 - s.y * 2.0)).override_failure_message("kind %s is not 2:3" % k).is_less(3.0)


func test_required_sizes() -> void:
	assert_vector(CardWidget.SIZES["board"]).is_equal(Vector2(85, 128))
	assert_vector(CardWidget.SIZES["hand"]).is_equal(Vector2(120, 180))
	assert_vector(CardWidget.SIZES["big"]).is_equal(Vector2(224, 336))
	assert_vector(CardWidget.SIZES["trap"]).is_equal(Vector2(85, 128))


func test_setup_sets_size_and_rotation_swaps_it() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(_unit_view(), "board")
	assert_vector(w.size).is_equal(Vector2(85, 128))
	assert_vector(w.custom_minimum_size).is_equal(Vector2(85, 128))
	var r: CardWidget = auto_free(CardWidget.new())
	r.setup(_unit_view(), "board", "", true)
	assert_bool(r.rotated).is_true()
	assert_vector(r.size).is_equal(Vector2(128, 85))
	assert_vector(r.pivot_offset).is_equal(Vector2(64, 42.5))


func test_setup_is_backwards_compatible() -> void:
	var w: CardWidget = auto_free(CardWidget.new().setup({}, "trap", "Trap"))
	assert_str(w.empty_text).is_equal("Trap")
	assert_bool(w.rotated).is_false()


func test_card_rect_is_two_by_three_inside_square() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(_unit_view(), "board")
	w.size = Vector2(128, 128)
	var cr := w.card_rect()
	assert_float(cr.size.x * 3.0).is_equal_approx(cr.size.y * 2.0, 0.001)
	assert_float(cr.size.y).is_equal_approx(128.0, 0.001)
	assert_vector(cr.get_center()).is_equal_approx(Vector2(64, 64), Vector2(0.01, 0.01))


func test_card_rect_rotated_is_three_by_two_inside_square_and_wide_rect() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(_unit_view(), "board", "", true)
	w.size = Vector2(128, 128)
	var cr := w.card_rect()
	assert_float(cr.size.x * 2.0).is_equal_approx(cr.size.y * 3.0, 0.001)
	assert_float(cr.size.x).is_equal_approx(128.0, 0.001)
	var wide: CardWidget = auto_free(CardWidget.new())   # no minimum size, so it can be 300x60
	wide.rotated = true
	wide.size = Vector2(300, 60)
	w = wide
	cr = w.card_rect()
	assert_float(cr.size.x * 2.0).is_equal_approx(cr.size.y * 3.0, 0.001)
	assert_float(cr.size.y).is_equal_approx(60.0, 0.001)
	assert_float(cr.position.x).is_equal_approx((300.0 - cr.size.x) / 2.0, 0.001)


func test_card_rect_fills_exact_size() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(_unit_view(), "hand")
	assert_vector(w.card_rect().size).is_equal(Vector2(120, 180))
	assert_vector(w.card_rect().position).is_equal(Vector2.ZERO)


func test_preview_does_not_mutate_view() -> void:
	var v := _unit_view()
	var before := v.duplicate(true)
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(v, "board")
	w.set_preview("atk", 14, 6)
	assert_bool(w.has_preview()).is_true()
	assert_dict(w.view).is_equal(before)
	w.clear_preview()
	assert_bool(w.has_preview()).is_false()
	assert_dict(w.view).is_equal(before)
	w.set_preview("bogus", 1, 0)
	assert_bool(w.has_preview()).is_false()


func test_ready_and_order_are_independent_of_marks() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(_unit_view(), "board")
	w.set_ready(true)
	w.set_marks(true, true)
	assert_bool(w.is_ready_on()).is_true()
	assert_bool(w.selected).is_true()
	w.order_no = 3
	assert_int(w.order_no).is_equal(3)
	w.set_ready(false)
	assert_bool(w.is_ready_on()).is_false()


func test_type_badge_minimum_size() -> void:
	var b: TypeIcons.TypeBadge = auto_free(TypeIcons.TypeBadge.new("Fire"))
	assert_vector(b.custom_minimum_size).is_equal(Vector2(22, 22))
	assert_str(b.type_name).is_equal("Fire")


func test_split_name_breaks_before_trailing_parenthetical() -> void:
	var parts := CardWidget.split_name("Basic Mage (Water)")
	assert_array(Array(parts)).is_equal(["Basic Mage", "(Water)"])
	assert_int(CardWidget.split_name("Dragon").size()).is_equal(1)
