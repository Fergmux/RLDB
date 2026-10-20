extends GdUnitTestSuite
## A2: the spectator's copy of a player's cursor is drawn RENDER_DELAY_MS behind, interpolated
## between samples, and hides when the samples stop.


func test_sample_interpolates_between_samples_at_render_delay() -> void:
	var tr := CursorTrack.new()
	tr.push(Vector2(0.0, 0.0), 1000)
	tr.push(Vector2(1.0, 0.5), 1100)
	var p := tr.sample(1050 + CursorTrack.RENDER_DELAY_MS)
	assert_float(p.x).is_equal_approx(0.5, 0.001)
	assert_float(p.y).is_equal_approx(0.25, 0.001)


func test_sample_holds_last_and_first_outside_range() -> void:
	var tr := CursorTrack.new()
	tr.push(Vector2(0.2, 0.2), 1000)
	tr.push(Vector2(0.8, 0.4), 1060)
	assert_vector(tr.sample(500)).is_equal(Vector2(0.2, 0.2))
	assert_vector(tr.sample(5000)).is_equal(Vector2(0.8, 0.4))


func test_invalid_points_are_ignored() -> void:
	var tr := CursorTrack.new()
	tr.push(Vector2(NAN, 0.1), 10)
	tr.push(Vector2(1.0 + CursorTrack.LIMIT + 0.1, 0.5), 20)
	assert_bool(tr.visible_at(30)).is_false()
	assert_bool(CursorTrack.valid(Vector2(-0.5, 1.4))).is_true()


func test_track_hides_after_silence() -> void:
	var tr := CursorTrack.new()
	tr.push(Vector2(0.5, 0.5), 1000)
	assert_bool(tr.visible_at(1000 + CursorTrack.HIDE_AFTER_MS - 1)).is_true()
	assert_bool(tr.visible_at(1000 + CursorTrack.HIDE_AFTER_MS)).is_false()
	tr.clear()
	assert_bool(tr.visible_at(1001)).is_false()
