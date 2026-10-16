extends GdUnitTestSuite
## F04-05 / F04-16: the hover lift is a real size change (crisp text), and the inspector shows
## no close hint while keeping its Close button.

const _VIEW := {"uid": 1, "id": 1, "name": "Test Spell", "category": "spell", "cost_kind": "ap", "cost": 1,
	"printed_cost": 1, "zone": "hand", "face_up": true, "statuses": {}, "runes": 0, "text": "Do a thing."}


func _widget() -> CardWidget:
	var w: CardWidget = auto_free(CardWidget.new())
	w.auto_hover = false
	w.setup(_VIEW, "hand")
	w.position = Vector2(40, 60)
	return w


func test_lift_grows_size_about_centre_without_scale() -> void:
	var w := _widget()
	w.lift_k = 1.25
	assert_vector(w.size).is_equal(Vector2(150, 225))
	assert_vector(w.scale).is_equal(Vector2.ONE)
	assert_vector(w.position + w.size / 2.0).is_equal_approx(Vector2(100, 150), Vector2(1, 1))


func test_lift_offset_moves_the_card_and_rest_restores_position() -> void:
	var w := _widget()
	w.lift_offset = Vector2(0, -48)
	w.lift_k = 1.25
	assert_vector(w.position + w.size / 2.0).is_equal_approx(Vector2(100, 102), Vector2(1, 1))
	w.lift_k = 1.0
	w.lift_offset = Vector2.ZERO
	assert_vector(w.size).is_equal(Vector2(120, 180))
	assert_vector(w.position).is_equal(Vector2(40, 60))


func test_inspector_has_no_close_hint_but_keeps_close_button() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var ins := CardInspector.open(host, _VIEW)
	assert_object(ins).is_not_null()
	var texts := PackedStringArray()
	var stack: Array = [ins]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			texts.append((n as Label).text)
		if n is Button:
			texts.append((n as Button).text)
		stack.append_array(n.get_children())
	assert_bool("Esc or click outside to close" in texts).is_false()
	assert_bool("Close" in texts).is_true()
	ins.close()
