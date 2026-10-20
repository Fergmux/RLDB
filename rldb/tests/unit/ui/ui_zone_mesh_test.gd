extends GdUnitTestSuite
## J31 follow-up regression guard: an empty board zone draws its static layers (recess, inner shadow,
## rim, lip, engraved mark) as ONE recorded triangle list (ZoneMesh), not ~92 draw calls, shared by
## every zone of its kind and size, and it does not redraw while idle. If a change to
## CardLayouts.draw_empty_base / draw_empty_mark adds something MeshPen cannot reproduce exactly (text,
## a texture, a StyleBox shadow), the zones silently fall back to the slow live path: these tests catch it.
## The pixel-exactness itself is checked windowed by src/dev/zone_mesh_diff.gd.

const KINDS := ["board", "trap", "power"]
const SIZES := [Vector2(128, 128), Vector2(128, 85), Vector2(85, 128)]
const IDLE_FRAMES := 6


func before_test() -> void:
	ZoneMesh.enabled = true
	ZoneMesh.clear()


func _zone(kind: String, sz: Vector2) -> CardWidget:
	var w: CardWidget = auto_free(CardWidget.new())
	w.auto_hover = false
	w.show_tooltip = false
	w.setup(null, kind)
	w.size = sz
	add_child(w)
	return w


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_every_zone_kind_records_exactly_at_board_and_scaled_sizes() -> void:
	# Arrange: the board's three kinds at their own size, at scaled window sizes (oversampling) and dims.
	for i in KINDS.size():
		for os in [1.0, 0.8, 0.768, 1.08]:
			for mod in [Color.WHITE, Color(0.55, 0.55, 0.55, 1.0), Color(0.8, 0.8, 0.8, 1.0)]:
				for mark in [true, false]:
					# Act
					var pen := ZoneMesh.for_zone(KINDS[i], SIZES[i], os, mark, mod)
					# Assert: recorded (not the live fallback), and a real mesh
					assert_object(pen).override_failure_message("%s os=%s mod=%s mark=%s fell back to live drawing" % [
						KINDS[i], os, mod, mark]).is_not_null()
					assert_bool(pen.unsupported).is_false()
					assert_int(pen.indices.size() % 3).is_equal(0)
					assert_int(pen.indices.size()).is_greater(300)


func test_idle_empty_zones_share_one_mesh_and_do_not_redraw() -> void:
	# Arrange: three unit zones of the same size, as on the board.
	var zones: Array[CardWidget] = [_zone("board", SIZES[0]), _zone("board", SIZES[0]), _zone("board", SIZES[0])]
	await _frames(3)
	var draws_before: Array[int] = []
	for w in zones:
		draws_before.append(w.face_draws)
	# Act
	await _frames(IDLE_FRAMES)
	# Assert: merged, one mesh between them, no redraw while idle
	for i in zones.size():
		assert_bool(zones[i].is_zone_merged()).is_true()
		assert_int(zones[i].face_draws).is_equal(draws_before[i])
		assert_bool(zones[i].is_processing()).is_false()
	assert_int(ZoneMesh.builds).is_equal(1)


func test_zone_pick_keeps_the_mark_live_and_bakes_only_the_recess() -> void:
	# Arrange
	var w := _zone("trap", SIZES[1])
	await _frames(2)
	var builds := ZoneMesh.builds
	# Act: a zone pick (the glow animates; the mark is drawn stronger, over it)
	w.set_marks(true, false)
	await _frames(3)
	# Assert: still merged (a second mesh: the recess without the mark), animating unless motion is reduced
	assert_bool(w.is_zone_merged()).is_true()
	assert_int(ZoneMesh.builds).is_equal(builds + 1)
	assert_bool(w.is_processing()).is_equal(not UIStyle.reduce_motion)


func test_dimmed_zone_uses_a_mesh_for_its_own_modulate() -> void:
	# Arrange
	var w := _zone("power", SIZES[2])
	await _frames(2)
	var builds := ZoneMesh.builds
	# Act: the hard dim of a non-target
	w.set_marks(false, false, true)
	await _frames(2)
	# Assert
	assert_bool(w.is_zone_merged()).is_true()
	assert_int(ZoneMesh.builds).is_equal(builds + 1)


func test_zone_with_mesh_off_draws_live() -> void:
	ZoneMesh.enabled = false
	var w := _zone("board", SIZES[0])
	await _frames(2)
	assert_bool(w.is_zone_merged()).is_false()
	ZoneMesh.enabled = true


func test_mesh_pen_truncates_primitive_colours_like_make_half_float() -> void:
	# Boundary values (the exact numbers are the point): make_half_float truncates the mantissa
	# (0.29 -> 0.289794921875, where rounding would give 0.2900390625) and flushes values under 2^-14.
	assert_float(MeshPen._h(0.29)).is_equal(0.289794921875)
	assert_float(MeshPen._h(0.1)).is_equal(0.0999755859375)
	assert_float(MeshPen._h(0.651)).is_equal(0.65087890625)
	assert_float(MeshPen._h(0.00005)).is_equal(0.0)
	assert_float(MeshPen._h(1.0)).is_equal(1.0)
	assert_float(MeshPen._h(0.0)).is_equal(0.0)


func test_mesh_pen_line_folds_the_modulate_into_its_half_colour() -> void:
	# Arrange: a dimmed pen; the GPU multiplies a vertex colour by the modulate afterwards.
	var m := Color(0.55, 0.55, 0.55, 1.0)
	var pen := MeshPen.new(1.0, m)
	var c := Color(0.831, 0.651, 0.29, 0.1)
	# Act
	pen.draw_line(Vector2(0, 0), Vector2(10, 0), c, 1.0, true)
	# Assert: 9 quads (the line and its 8 feather pieces); colour x modulate = half(c x m)
	assert_int(pen.points.size()).is_equal(36)
	assert_int(pen.indices.size()).is_equal(54)
	var got := pen.colors[0] * m
	assert_float(got.r).is_equal_approx(MeshPen._h(c.r * m.r), 1e-6)
	assert_float(got.b).is_equal_approx(MeshPen._h(c.b * m.b), 1e-6)
	assert_float(got.a).is_equal_approx(MeshPen._h(c.a), 1e-6)


func test_mesh_pen_refuses_what_it_cannot_reproduce() -> void:
	var pen := MeshPen.new()
	var sb := StyleBoxFlat.new()
	sb.shadow_size = 4
	pen.draw_style_box(sb, Rect2(0, 0, 10, 10))
	assert_bool(pen.unsupported).is_true()
