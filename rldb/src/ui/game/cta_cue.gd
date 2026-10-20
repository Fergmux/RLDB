class_name CtaCue
extends Control
## "This is what to do next" on the turn bar's main button (design review #41): while the player has
## nothing else left to do, the button's border breathes (the 2.4 s `breathe` loop) and a sheen sweeps
## across it every PERIOD seconds (`sweep`, 0.9 s a pass). Drawn over the button, click-through. Under
## reduce motion: a static gold rim, no sweep.

## Seconds between two sweeps and the sweep pass's length (s), the sheen band's width (px).
const PERIOD := 3.0
const PASS_S := 0.9
const BAND_PX := 46.0

## Whether the cue shows.
var on: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Shows or hides the cue.
func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	set_process(v and not UIStyle.reduce_motion)
	queue_redraw()


func _notification(what: int) -> void:
	# Godot turns processing on at ready because _process exists: animate only while shown (H7).
	if what == NOTIFICATION_READY:
		set_process(on and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


## Position 0..1 of the sheen across the button at clock time `t` (s), or -1 between passes.
static func sweep_at(t: float) -> float:
	var ph := fmod(t, PERIOD)
	return ph / PASS_S if ph < PASS_S else -1.0


func _draw() -> void:
	if not on:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k := UIStyle.breathe(t, 0.5)
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(7)
	rim.border_color = Color(UIStyle.GOLD_HI, clampf(0.55 * k, 0.0, 1.0))
	rim.shadow_color = Color(UIStyle.GOLD_HI, clampf(0.22 * k, 0.0, 1.0))
	rim.shadow_size = 8
	rim.anti_aliasing = true
	draw_style_box(rim, Rect2(Vector2(-1, -1), size + Vector2(2, 2)))
	if UIStyle.reduce_motion:
		return
	var s := sweep_at(t)
	if s < 0.0:
		return
	var x := lerpf(-BAND_PX, size.x + BAND_PX, s)
	var sk := size.y * 0.5   # a 30-degree-ish slant
	var hi := Color(1, 0.97, 0.85, 0.32 * sin(s * PI))
	for part in band_parts(size, x, sk):
		var cols := PackedColorArray()
		for p in part:
			cols.append(_band_col(p, x, sk, hi))
		draw_polygon(part, cols)


## The sheen band at `x` (slant `sk`) on a button of `sz`, in two halves (so a vertex lies on its
## bright centre line), each clipped to the button's inner rect. Slivers at the edge, which have no
## visible area and fail to triangulate, are dropped.
static func band_parts(sz: Vector2, x: float, sk: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var inner := PackedVector2Array([Vector2(3, 2), Vector2(sz.x - 3, 2), Vector2(sz.x - 3, sz.y - 2), Vector2(3, sz.y - 2)])
	for q in 2:
		var b0 := x - BAND_PX * 0.5 + BAND_PX * 0.5 * q
		var b1 := b0 + BAND_PX * 0.5
		var half := PackedVector2Array([Vector2(b0 + sk, 2), Vector2(b1 + sk, 2), Vector2(b1 - sk, sz.y - 2), Vector2(b0 - sk, sz.y - 2)])
		for part in Geometry2D.intersect_polygons(half, inner):
			if absf(_area(part)) < 0.5 or Geometry2D.triangulate_polygon(part).is_empty():
				continue
			out.append(part)
	return out


# The band colour at point `p`: brightest on the band's slanted centre line, clear at its edges.
func _band_col(p: Vector2, x: float, sk: float, hi: Color) -> Color:
	var cx := x + sk - 2.0 * sk * (p.y / maxf(size.y, 1.0))
	var d := absf(p.x - cx) / (BAND_PX * 0.5)
	return Color(hi, hi.a * clampf(1.0 - d, 0.0, 1.0))


# The signed area of polygon `pts` (shoelace).
static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		a += pts[i].cross(pts[(i + 1) % pts.size()])
	return a * 0.5
