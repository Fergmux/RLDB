class_name Ornate
extends RefCounted
## Decorative drawing helpers shared by the series screens and the input prompt: corner
## flourishes, ornamental dividers, vertical gradients, and the scroll-bar theme. Everything is
## drawn from vectors onto a CanvasItem, so it scales with the window and needs no art files.


## Fills `rect` with a vertical gradient from `top` to `bottom`.
static func vgradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Fills `rect` with a horizontal gradient from `left` to `right`.
static func hgradient(ci: CanvasItem, rect: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


## Points of a rounded rectangle, clockwise from the left end of the top-left arc: radius `rt` on
## the two top corners and `rb` on the two bottom ones (0 keeps a corner square). The outline is
## convex, so it can be filled in one `draw_polygon` call.
static func rounded_points(rect: Rect2, rt: float, rb: float, seg: int = 6) -> PackedVector2Array:
	var half := minf(rect.size.x, rect.size.y) / 2.0
	rt = clampf(rt, 0.0, half)
	rb = clampf(rb, 0.0, half)
	var arcs := [
		[Vector2(rect.position.x + rt, rect.position.y + rt), rt, PI],
		[Vector2(rect.end.x - rt, rect.position.y + rt), rt, PI * 1.5],
		[Vector2(rect.end.x - rb, rect.end.y - rb), rb, 0.0],
		[Vector2(rect.position.x + rb, rect.end.y - rb), rb, PI * 0.5],
	]
	var pts := PackedVector2Array()
	for a in arcs:
		var c: Vector2 = a[0]
		var r: float = a[1]
		if r <= 0.0:
			pts.append(c)
			continue
		for i in seg + 1:
			var ang: float = a[2] + PI * 0.5 * float(i) / float(seg)
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts


## Fills a rounded rectangle (see `rounded_points`) with a gradient from `from` to `to`: top to
## bottom, or left to right when `horizontal`. The colour is set per outline point, so the
## gradient stays exact across the rounded corners.
static func rounded_gradient(ci: CanvasItem, rect: Rect2, rt: float, rb: float, from: Color, to: Color, horizontal: bool = false) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var pts := rounded_points(rect, rt, rb)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var k := (pts[i].x - rect.position.x) / rect.size.x if horizontal else (pts[i].y - rect.position.y) / rect.size.y
		cols[i] = from.lerp(to, clampf(k, 0.0, 1.0))
	ci.draw_polygon(pts, cols)


## A small diamond centred on `c` (half-diagonal `r`).
static func diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


## Four double-line corner brackets with a diamond and end dots, `inset` px inside `rect`.
static func corners(ci: CanvasItem, rect: Rect2, col: Color, arm: float = 22.0, inset: float = 5.0, w: float = 2.0) -> void:
	var inner := Color(col, col.a * 0.55)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := Vector2(rect.position.x + inset if sx < 0 else rect.end.x - inset, rect.position.y + inset if sy < 0 else rect.end.y - inset)
			var ax := Vector2(-sx, 0.0)   # unit vectors pointing into the rect
			var ay := Vector2(0.0, -sy)
			ci.draw_polyline(PackedVector2Array([p + ay * arm, p, p + ax * arm]), col, w, true)
			var q := p + ax * 5.0 + ay * 5.0
			ci.draw_polyline(PackedVector2Array([q + ay * arm * 0.55, q, q + ax * arm * 0.55]), inner, maxf(1.0, w * 0.5), true)
			diamond(ci, p + ax * 2.5 + ay * 2.5, 3.2, col)
			ci.draw_circle(p + ay * arm, 1.7, col, true, -1.0, true)
			ci.draw_circle(p + ax * arm, 1.7, col, true, -1.0, true)


## Horizontal rule that fades out at both ends, with a centre diamond (and two small side ones).
static func divider(ci: CanvasItem, y: float, x0: float, x1: float, col: Color, gem: bool = true) -> void:
	var mid := (x0 + x1) / 2.0
	var clear := Color(col, 0.0)
	var gap := 12.0 if gem else 0.0
	hgradient(ci, Rect2(x0, y - 0.75, mid - gap - x0, 1.5), clear, col)
	hgradient(ci, Rect2(mid + gap, y - 0.75, x1 - mid - gap, 1.5), col, clear)
	if gem:
		diamond(ci, Vector2(mid, y), 5.0, col)
		diamond(ci, Vector2(mid, y), 2.4, Color(0.08, 0.06, 0.04, 0.9))
		diamond(ci, Vector2(mid - 17, y), 2.4, Color(col, col.a * 0.8))
		diamond(ci, Vector2(mid + 17, y), 2.4, Color(col, col.a * 0.8))


## Control that draws `divider` across its width (a layout-friendly ornamental rule).
class Rule extends Control:
	var col: Color = Color(UIStyle.GOLD, 0.7)
	var gem: bool = true

	func _init(c: Color = Color(UIStyle.GOLD, 0.7), with_gem: bool = true, h: float = 14.0) -> void:
		col = c
		gem = with_gem
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Ornate.divider(self, size.y / 2.0, 0.0, size.x, col, gem)


## The house scroll bar set (UIStyle.apply_scrollbar_theme: an 8 px engraved ink track, a 6 px gold
## thumb that brightens on hover and press, 12 px between the content and the track). Assign to a
## ScrollContainer's `theme`.
static func scroll_theme() -> Theme:
	return UIStyle.apply_scrollbar_theme(Theme.new())
