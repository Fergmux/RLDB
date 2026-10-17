extends GdUnitTestSuite
## F02: FX displacement (CardWidget.fx_offset) is composed on top of the resting position and the hover
## lift. Regression: a self-buff's trigger shake used to write `position.x` on a lifted (hovered) card,
## which the lift took for a new resting place every frame, so the card crept upward with its label.

const VIEW := {"uid": 5, "id": 1, "name": "Basic Mage", "cat": "basic_unit", "atk": 8, "def": 8, "zone": "unit", "statuses": {}}

var holder: Control
var w: CardWidget


func before_test() -> void:
	holder = Control.new()
	add_child(holder)
	w = CardWidget.new().setup(VIEW.duplicate(true), "board")
	holder.add_child(w)


func after_test() -> void:
	remove_child(holder)
	holder.free()


func _lifted_rest() -> Vector2:
	var rest := w.custom_minimum_size
	return -(rest * w.lift_k - rest) / 2.0 + w.lift_offset


func test_shake_on_a_lifted_card_never_moves_its_anchor() -> void:
	w.lift_k = GameHoverController.FIELD_SCALE
	var lifted := w.position
	assert_vector(lifted).is_equal_approx(_lifted_rest(), Vector2(0.01, 0.01))
	var fx := FxCardEffects.new(null)
	# Three overlapping self-buff shakes, interleaved frame by frame (as three tweens would run).
	for step in 40:
		for track in 3:
			var k := clampf((step - track * 6) / 15.0, 0.0, 1.0)
			fx._shake_x(k, w, 5.0)
			assert_float(w.position.y).is_equal_approx(lifted.y, 0.001)
			assert_float(w.position.x - w.fx_offset.x).is_equal_approx(lifted.x, 0.001)
	assert_vector(w.position).is_equal_approx(lifted, Vector2(0.001, 0.001))
	assert_vector(w.size).is_equal_approx(w.custom_minimum_size * GameHoverController.FIELD_SCALE, Vector2(0.01, 0.01))
	w.lift_k = 1.0
	assert_vector(w.position).is_equal(Vector2.ZERO)
	assert_vector(w.size).is_equal(w.custom_minimum_size)


func test_old_position_write_drift_is_what_fx_offset_replaces() -> void:
	# Documents the root cause: an external `position.x` write while lifted re-anchors the lift.
	w.lift_k = GameHoverController.FIELD_SCALE
	var lifted_y := w.position.y
	w.position.x = 3.0
	assert_float(w.position.y).is_less(lifted_y - 1.0)


func test_interrupted_shake_is_cleaned_up_by_reset_widget() -> void:
	w.lift_k = GameHoverController.FIELD_SCALE
	var lifted := w.position
	var fx := FxCardEffects.new(null)
	fx._shake_x(0.3, w, 5.0)
	var player: FxPlayer = FxPlayer.new()
	player.reset_widget(w, holder)   # finish_all() path mid-animation
	assert_vector(w.fx_offset).is_equal(Vector2.ZERO)
	assert_vector(w.position).is_equal_approx(lifted, Vector2(0.001, 0.001))
	# Unhover during the shake, then the cleanup: the card is back at its slot anchor at rest size.
	fx._shake_x(0.5, w, 5.0)
	w.lift_k = 1.0
	player.reset_widget(w, holder)
	assert_vector(w.position).is_equal(Vector2.ZERO)
	assert_vector(w.size).is_equal(w.custom_minimum_size)
	assert_bool(w.get_rect().is_equal_approx(Rect2(Vector2.ZERO, w.custom_minimum_size))).is_true()
	player.free()


func test_fx_offset_on_a_resting_card_is_relative_to_its_slot() -> void:
	w.fx_offset = Vector2(12, -7)
	assert_vector(w.position).is_equal(Vector2(12, -7))
	assert_vector(w.rest_position()).is_equal(Vector2.ZERO)
	w.lift_k = 1.1   # lift starts mid-effect: the rest excludes the effect
	assert_vector(w.rest_position()).is_equal(Vector2.ZERO)
	w.fx_offset = Vector2.ZERO
	w.lift_k = 1.0
	assert_vector(w.position).is_equal(Vector2.ZERO)
