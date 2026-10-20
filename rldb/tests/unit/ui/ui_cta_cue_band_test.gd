extends GdUnitTestSuite
## CtaCue's sheen band: every polygon it draws must triangulate (the tutorial logged "Invalid polygon
## data, triangulation failed" from a sliver at the button edge), and dropping slivers must not lose
## any visible band.

const SIZES := [Vector2(150, 40), Vector2(168, 44), Vector2(212, 52), Vector2(96, 34)]


func _raw_area(sz: Vector2, x: float, sk: float) -> float:
	var inner := PackedVector2Array([Vector2(3, 2), Vector2(sz.x - 3, 2), Vector2(sz.x - 3, sz.y - 2), Vector2(3, sz.y - 2)])
	var total := 0.0
	for q in 2:
		var b0 := x - CtaCue.BAND_PX * 0.5 + CtaCue.BAND_PX * 0.5 * q
		var b1 := b0 + CtaCue.BAND_PX * 0.5
		var half := PackedVector2Array([Vector2(b0 + sk, 2), Vector2(b1 + sk, 2), Vector2(b1 - sk, sz.y - 2), Vector2(b0 - sk, sz.y - 2)])
		for part in Geometry2D.intersect_polygons(half, inner):
			total += absf(CtaCue._area(part))
	return total


func test_band_parts_every_sweep_position_triangulates() -> void:
	for sz in SIZES:
		var sk: float = sz.y * 0.5
		var x := -CtaCue.BAND_PX
		while x <= sz.x + CtaCue.BAND_PX:
			for part in CtaCue.band_parts(sz, x, sk):
				assert_bool(Geometry2D.triangulate_polygon(part).is_empty()) \
						.override_failure_message("size %s x %.2f: %s" % [sz, x, part]).is_false()
			x += 0.25


func test_band_parts_keeps_all_visible_band() -> void:
	for sz in SIZES:
		var sk: float = sz.y * 0.5
		var x := -CtaCue.BAND_PX
		while x <= sz.x + CtaCue.BAND_PX:
			var kept := 0.0
			for part in CtaCue.band_parts(sz, x, sk):
				kept += absf(CtaCue._area(part))
			assert_float(_raw_area(sz, x, sk) - kept).is_less_equal(2.0)
			x += 0.25


## Corner slivers found by a seeded randomised sweep (~1 in 16,000 positions): the raw clip yields a
## ~0.0001 px^2 triangle the renderer cannot triangulate. The sweep is seeded, so it is deterministic.
func test_band_parts_drops_corner_slivers_that_fail_to_triangulate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var raw_bad := 0
	var kept_bad := 0
	for i in 60000:
		var sz := Vector2(rng.randf_range(20, 320), rng.randf_range(20, 64))
		var sk: float = sz.y * 0.5
		var x := rng.randf_range(-CtaCue.BAND_PX, sz.x + CtaCue.BAND_PX)
		raw_bad += _raw_failures(sz, x, sk)
		for part in CtaCue.band_parts(sz, x, sk):
			if Geometry2D.triangulate_polygon(part).is_empty():
				kept_bad += 1
	assert_int(raw_bad).override_failure_message("the sweep no longer finds a raw sliver").is_greater(0)
	assert_int(kept_bad).is_equal(0)


func _raw_failures(sz: Vector2, x: float, sk: float) -> int:
	var inner := PackedVector2Array([Vector2(3, 2), Vector2(sz.x - 3, 2), Vector2(sz.x - 3, sz.y - 2), Vector2(3, sz.y - 2)])
	var n := 0
	for q in 2:
		var b0 := x - CtaCue.BAND_PX * 0.5 + CtaCue.BAND_PX * 0.5 * q
		var b1 := b0 + CtaCue.BAND_PX * 0.5
		var half := PackedVector2Array([Vector2(b0 + sk, 2), Vector2(b1 + sk, 2), Vector2(b1 - sk, sz.y - 2), Vector2(b0 - sk, sz.y - 2)])
		for part in Geometry2D.intersect_polygons(half, inner):
			if Geometry2D.triangulate_polygon(part).is_empty():
				n += 1
	return n
