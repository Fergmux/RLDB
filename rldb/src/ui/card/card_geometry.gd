class_name CardGeometry
extends RefCounted
## Pure polygon helpers for the procedurally drawn card (no drawing, no state): regular polygons,
## the DEF shield and ATK diamond outlines, outward offsets and closed polylines.


## Regular `n`-gon of radius `r` around `c`, first vertex at angle `rot`.
static func poly(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + float(i) * TAU / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Seven-point heater shield filling `rect` (flat top with clipped corners, pointed bottom).
static func shield_pts(rect: Rect2) -> PackedVector2Array:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		Vector2(x + 0.08 * w, y), Vector2(x + 0.92 * w, y), Vector2(x + w, y + 0.12 * h), Vector2(x + w, y + 0.56 * h),
		Vector2(x + 0.5 * w, y + h), Vector2(x, y + 0.56 * h), Vector2(x, y + 0.12 * h)])


## Rhombus touching the middle of each edge of `rect`: top, right, bottom, left.
static func diamond_pts(rect: Rect2) -> PackedVector2Array:
	var c := rect.get_center()
	return PackedVector2Array([Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y), Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)])


## Pushes every point away from `c` by `amount` (negative = inward).
static func grow_pts(pts: PackedVector2Array, c: Vector2, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * amount)
	return out


## Copy of `pts` with the first point appended, for drawing a closed outline with draw_polyline.
static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	return o
