extends GdUnitTestSuite
## Performance regression guard (H7, 21 Oct: "I'm only getting like 80 fps, before I was getting 240").
## Godot turns processing on at NOTIFICATION_READY for any script that defines _process, so a
## set_process(false) in _init() is silently undone. These widgets then redrew every frame forever:
## 40 buttons and 8 piles on the deck choice cost ~10 ms a frame. Each test puts an idle widget in
## the tree and checks that it neither processes nor redraws on its own.

const FRAMES := 6


func _idle_draws(c: CanvasItem) -> int:
	var n := [0]
	c.draw.connect(func(): n[0] += 1)
	for i in FRAMES:
		await get_tree().process_frame
	return n[0]


func _settle(c: Control) -> void:
	if c.anchor_right == 0.0:   # full-rect overlays (CtaCue) take their parent's size
		c.size = Vector2(120, 80)
	add_child(c)
	for i in 3:
		await get_tree().process_frame


func test_idle_juicy_button_does_not_process_or_redraw() -> void:
	# Arrange
	var b: JuicyButton = auto_free(JuicyButton.new())
	b.text = "Idle"
	await _settle(b)
	# Act
	var draws: int = await _idle_draws(b)
	# Assert
	assert_bool(b.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_idle_pile_stack_does_not_process_or_redraw() -> void:
	var p: PileStack = auto_free(PileStack.new())
	await _settle(p)
	var draws: int = await _idle_draws(p)
	assert_bool(p.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_ready_pile_stack_still_animates() -> void:
	var p: PileStack = auto_free(PileStack.new())
	await _settle(p)
	p.set_pile(30, true, true)
	var draws: int = await _idle_draws(p)
	assert_bool(p.is_processing()).is_equal(not UIStyle.reduce_motion)
	if not UIStyle.reduce_motion:
		assert_int(draws).is_greater_equal(FRAMES - 1)


func test_hidden_zone_ring_does_not_process() -> void:
	var z: ZoneRing = auto_free(ZoneRing.new())
	await _settle(z)
	assert_bool(z.is_processing()).is_false()


func test_off_cta_cue_does_not_process_or_redraw() -> void:
	var c: CtaCue = auto_free(CtaCue.new())
	await _settle(c)
	var draws: int = await _idle_draws(c)
	assert_bool(c.is_processing()).is_false()
	assert_int(draws).is_equal(0)


func test_idle_card_widget_does_not_process() -> void:
	var w: CardWidget = auto_free(CardWidget.new())
	await _settle(w)
	assert_bool(w.is_processing()).is_false()
