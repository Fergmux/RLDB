extends GdUnitTestSuite
## J2 (owner, 22 Oct: "the background image on the main menu moves ever so slightly up down left
## right occasionally"). Root cause: the 40 s "Ken Burns" scale tween on the backdrop (1.000 ->
## 1.006 about its centre). With gui/common/snap_controls_to_pixels on (the default), Godot rounds
## a Control's canvas translation to whole pixels, and a scale about the centre moves that
## translation by -pivot * (scale - 1): about 5 px in x and 3 px in y over half a cycle at 1600x900.
## The smooth zoom was invisible; the rounding showed as single-pixel jumps of the whole painting,
## now left or up, now right or down, every few seconds. The backdrop no longer animates its
## transform, so its rendered rect is identical on every frame.

const HOST := Vector2(1600, 900)
## Tween time stepped by hand: more than a full cycle of the old drift (40 s).
const STEP := 0.25
const STEPS := 200


## The rect the canvas draws `c` at: its global rect with the translation rounded the way Godot
## rounds it while snapping controls to pixels.
static func rendered_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var o := xf.origin
	if c.get_viewport().gui_snap_controls_to_pixels:
		o = (o + Vector2(0.5, 0.5)).floor()
	return Rect2(o, c.size * xf.get_scale())


func _menu() -> MainMenu:
	var host := Control.new()
	host.size = HOST
	add_child(host)
	auto_free(host)
	var mm := MainMenu.new(SessionOptions.new())
	host.add_child(mm)
	return mm


func test_backdrop_rendered_rect_is_constant_over_a_full_tween_cycle() -> void:
	# Arrange
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	var mm := _menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var art: Control = mm.backdrop.get_child(0)
	var first := rendered_rect(art)
	var seen := {str(first): true}
	# Act: run every live tween (the menu's own, the logo sweep, any backdrop drift) for 50 s.
	var tweens := get_tree().get_processed_tweens()
	for i in STEPS:
		for tw in tweens:
			if tw.is_valid():
				tw.custom_step(STEP)
		seen[str(rendered_rect(art))] = true
	UIStyle.reduce_motion = was
	# Assert
	assert_int(seen.size()).is_equal(1)
	assert_vector(mm.backdrop.scale).is_equal(Vector2.ONE)
	assert_vector(first.position).is_equal(Vector2.ZERO)
	assert_vector(first.size).is_equal(HOST)


func test_backdrop_rendered_rect_is_constant_frame_to_frame() -> void:
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	var mm := _menu()
	await get_tree().process_frame
	var art: Control = mm.backdrop.get_child(0)
	var first := rendered_rect(art)
	var moved := 0
	for i in 30:
		await get_tree().process_frame
		if rendered_rect(art) != first:
			moved += 1
	UIStyle.reduce_motion = was
	assert_int(moved).is_equal(0)
