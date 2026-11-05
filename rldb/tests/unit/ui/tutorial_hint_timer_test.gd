extends GdUnitTestSuite
## QA 2026-11-05 leftover (design/qa-final-2026-11-05.md): the tutorial's off-script hint timer
## called a lambda that captured the hint plate; a rebuild could free the plate first and Godot logged
## "Lambda capture at index 1 was freed". The timer now calls a method of the overlay with only the
## hint's generation bound.


## The overlay without its lesson host (only the hint is exercised).
class BareOverlay extends TutorialOverlay:
	func _ready() -> void:
		ring = TutorialHighlight.new()
		add_child(ring)


func _overlay() -> TutorialOverlay:
	var o: TutorialOverlay = auto_free(BareOverlay.new())
	o.size = Vector2(800, 600)
	add_child(o)
	return o


func test_hint_timer_holds_no_reference_to_the_plate() -> void:
	# Arrange
	var o := _overlay()
	# Act
	o.show_hint("Follow the highlighted step")
	# Assert: every timeout connection is a method of the overlay with no node bound to it
	var conns: Array = o._hint_timer.timeout.get_connections()
	assert_int(conns.size()).is_equal(1)
	var cb: Callable = conns[0]["callable"]
	assert_object(cb.get_object()).is_same(o)
	assert_str(String(cb.get_method())).is_equal("_expire_hint")
	for a in cb.get_bound_arguments():
		assert_bool(a is Object).is_false()


func test_expiry_after_a_rebuild_freed_the_plate_is_harmless() -> void:
	# Arrange: a hint, then a rebuild hides (frees) it before its time is up
	var o := _overlay()
	o.show_hint("First")
	var gen := o._hint_gen
	o._hide_hint()
	await get_tree().process_frame
	# Act
	o._expire_hint(gen)
	# Assert
	assert_object(o.hint_plate).is_null()


func test_an_old_timer_does_not_dismiss_a_newer_hint() -> void:
	# Arrange
	var o := _overlay()
	o.show_hint("First")
	var old := o._hint_gen
	o.show_hint("Second")
	var second := o.hint_plate
	# Act
	o._expire_hint(old)
	# Assert: the newer hint stays until its own timer
	assert_object(o.hint_plate).is_same(second)
	o._expire_hint(o._hint_gen)
	assert_object(o.hint_plate).is_null()
