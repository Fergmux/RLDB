extends GdUnitTestSuite
## Perf (2026-11-05, design/perf-2026-11-05.md): every new view set every board and hand card up
## again and re-applied its marks, and each call repainted the whole face (0.3-2.5 ms a card). A
## command's frame repainted ~25 unchanged faces, 10-15 ms of a 35 ms p95 frame. A face now repaints
## only when something it is drawn from changed (CardWidget.request_face / face_key).

const UNIT := {"uid": 7, "id": 1, "name": "Test Knight", "category": "basic_unit", "cost": 2, "atk": 3, "def": 2,
	"printed_atk": 3, "printed_def": 2, "zone": "hand", "statuses": {}}


func _card(v: Dictionary, kind: String = "hand") -> CardWidget:
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(v.duplicate(true), kind)
	add_child(w)
	return w


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func test_setup_with_an_unchanged_view_does_not_repaint_the_face() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act: the board sets the same card up again (a new view where this card did not change)
	w.setup(UNIT.duplicate(true), "hand")
	w.set_marks(false, false)
	w.set_ready(false)
	w.request_face()
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before)


func test_marks_repaint_the_overlay_not_the_face() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	var overlay: Control = w.get_child(1, true)   # [face, overlay]
	var od := [0]
	overlay.draw.connect(func(): od[0] += 1)
	# Act: selected and soft-dimmed (overlay brackets, self_modulate)
	w.set_marks(false, true, false, true)
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before)
	assert_int(od[0]).is_greater_equal(1)


func test_a_changed_view_repaints_the_face() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	var v := UNIT.duplicate(true)
	v["atk"] = 5
	# Act
	w.setup(v, "hand")
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before + 1)


func test_a_view_changed_in_place_repaints_the_face() -> void:
	# Arrange: the caller keeps the same dictionary and edits it
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act
	w.view["statuses"] = {"burn": 2}
	w.setup(w.view, "hand")
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before + 1)


func test_hover_change_repaints_the_face() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act: hovered changes the face's drop shadow
	w.hovered = true
	await _settle()
	w.hovered = true   # unchanged: no second paint
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before + 1)


func test_empty_zone_dim_repaints_its_face() -> void:
	# Arrange: an empty zone's recess mesh is keyed on its dim (ZoneMesh)
	var w: CardWidget = auto_free(CardWidget.new())
	w.setup(null, "board")
	add_child(w)
	await _settle()
	var before := w.face_draws
	# Act
	w.set_marks(false, false, true)
	await _settle()
	w.set_marks(false, false, true)
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before + 1)


func test_face_epoch_bump_repaints_on_the_next_request() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act
	CardWidget.face_epoch += 1
	w.setup(UNIT.duplicate(true), "hand")
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before + 1)


func test_a_scale_wobble_that_returns_to_rest_repaints_nothing() -> void:
	# Arrange: the camera shake scales the board by about 1.6 % and back, frame by frame
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act
	for sc in [1.016, 1.008, 1.012, 1.004, 1.0]:
		w.scale = Vector2(sc, sc)
		await get_tree().process_frame
	await _settle()
	# Assert
	assert_int(w.face_draws).is_equal(before)


func test_a_small_scale_change_repaints_once_it_holds_still() -> void:
	# Arrange
	var w := _card(UNIT)
	await _settle()
	var before := w.face_draws
	# Act: a slow drift to 1.1, then it rests there
	for sc in [1.02, 1.04, 1.06, 1.08, 1.1]:
		w.scale = Vector2(sc, sc)
		await get_tree().process_frame
	var while_moving := w.face_draws - before
	await _settle()
	# Assert: no repaint while it moved, one at the scale it settled on
	assert_int(while_moving).is_equal(0)
	assert_int(w.face_draws).is_equal(before + 1)
	var k := roundf(1.1 * CardWidget.TEXT_OS_STEPS) / CardWidget.TEXT_OS_STEPS
	assert_float(w.last_draw_scale()[1]).is_equal_approx(w.get_viewport().get_oversampling() * k, 0.0001)
