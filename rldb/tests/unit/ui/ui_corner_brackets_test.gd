extends GdUnitTestSuite
## J12 (owner, 22 Oct, design/owner-feedback-2026-10-22.md): corner decorations on rounded shapes turn
## their corner on an arc concentric with the shape's rim instead of a square elbow, so they never poke out
## past a rounded corner (the rewards Picks plate, every OrnatePanel / HousePanel / tile, card brackets).

const EPS := 0.01


## Distance of `pt` beyond the rounded rim of `rect` (radius `rad`) shrunk by `inset`: <= 0 inside.
static func _outside(rect: Rect2, rad: float, inset: float, pt: Vector2) -> float:
	var inner := rect.grow(-inset)
	var r := maxf(rad - inset, 0.0)
	var c := Vector2(clampf(pt.x, inner.position.x + r, inner.end.x - r), clampf(pt.y, inner.position.y + r, inner.end.y - r))
	return pt.distance_to(c) - r


func test_bracket_on_a_rounded_corner_follows_the_rim() -> void:
	# Arrange: the rewards Picks plate's top-left corner (OrnatePanel radius 10, flourish inset 3, arm 10)
	var rect := Rect2(0, 0, 200, 52)
	var inset := 3.0
	var p := Vector2(inset, inset)
	# Act
	var pts := Ornate.bracket_points(p, Vector2.RIGHT, Vector2.DOWN, 10.0, 10.0 - inset)
	# Assert: every point sits on or inside the rim's concentric outline; the ends are the two arm tips
	for pt in pts:
		assert_float(_outside(rect, 10.0, inset, pt)).is_less_equal(EPS)
	assert_vector(pts[0]).is_equal(p + Vector2(0, 10))
	assert_vector(pts[pts.size() - 1]).is_equal(p + Vector2(10, 0))
	assert_bool(pts.has(p)).is_false()   # no square elbow


func test_bracket_arc_is_concentric_with_the_corner() -> void:
	# Arrange
	var p := Vector2(6, 6)
	var r := 6.0
	# Act
	var pts := Ornate.bracket_points(p, Vector2.RIGHT, Vector2.DOWN, 22.0, r)
	# Assert: the arc points (all but the two tips) are r from the corner centre
	var c := p + Vector2(r, r)
	for i in range(1, pts.size() - 1):
		assert_float(pts[i].distance_to(c)).is_equal_approx(r, EPS)
	assert_vector(Ornate.bracket_apex(p, Vector2.RIGHT, Vector2.DOWN, r)).is_equal_approx(c - Vector2(r, r) * sqrt(0.5), Vector2(EPS, EPS))


func test_bracket_on_a_square_corner_keeps_its_elbow() -> void:
	# Arrange / Act: radius 0 (a square shape)
	var p := Vector2(5, 5)
	var pts := Ornate.bracket_points(p, Vector2.RIGHT, Vector2.DOWN, 12.0)
	# Assert
	assert_array(Array(pts)).contains_exactly([p + Vector2(0, 12), p, p + Vector2(12, 0)])
	assert_vector(Ornate.bracket_apex(p, Vector2.RIGHT, Vector2.DOWN, 0.0)).is_equal(p)


func test_bottom_right_bracket_mirrors_and_stays_inside() -> void:
	# Arrange: a HousePanel (radius 12, flourish inset 6) bottom-right corner
	var rect := Rect2(0, 0, 300, 160)
	var p := rect.end - Vector2(6, 6)
	# Act
	var pts := Ornate.bracket_points(p, Vector2.LEFT, Vector2.UP, 18.0, 12.0 - 6.0)
	# Assert
	for pt in pts:
		assert_float(_outside(rect, 12.0, 6.0, pt)).is_less_equal(EPS)
	assert_vector(pts[0]).is_equal(p + Vector2(0, -18))
