class_name ArrowLayer
extends Control
## Targeting arrow from the acting card to the hovered target: a smooth arc with a soft glow,
## a tapering body, chevrons flowing toward the target and a bevelled head. Everything is drawn
## anti-aliased (user feedback: the old straight dashed arrow was stiff and jagged).

## Arrow start (global).
var a: Vector2 = Vector2.ZERO
## Arrow end (global).
var b: Vector2 = Vector2.ZERO
## Whether it is drawn.
var on: bool = false
## Neutral gold, or the combat-preview verdict colour while hovering an attack target.
var col: Color = UIStyle.TARGET
## Combat-preview verdict shown as a shape at the arrowhead ("good" ✓, "bad" ✕, "neutral" =).
var verdict: String = ""

const HEAD := 22.0
const SAMPLES := 48

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = UiLayers.ARROW

## Point on the arc (quadratic Bézier bowing upward on screen) at t in [0, 1].
func _at(t: float, c: Vector2) -> Vector2:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t

func _draw() -> void:
	if not on:
		return
	var d := b - a
	var length := d.length()
	if length < 24.0:
		return
	var n := Vector2(-d.y, d.x) / length
	if n.y > 0.0:
		n = -n                     # bow upward
	var ctrl := (a + b) / 2.0 + n * clampf(length * 0.22, 24.0, 130.0)
	# Sample the curve and its cumulative length.
	var pts := PackedVector2Array()
	var acc := PackedFloat32Array()
	var total := 0.0
	for i in SAMPLES + 1:
		var q := _at(float(i) / SAMPLES, ctrl)
		if i > 0:
			total += q.distance_to(pts[i - 1])
		pts.append(q)
		acc.append(total)
	# Body stops where the head begins.
	var body := PackedVector2Array()
	for i in pts.size():
		if total - acc[i] >= HEAD * 0.75:
			body.append(pts[i])
	if body.size() < 2:
		return
	var tip := pts[pts.size() - 1]
	var dir := (tip - body[body.size() - 1]).normalized()
	# Glow, shadow, tapering core and a bright inner line.
	draw_polyline(body, Color(col, 0.16), 16.0, true)
	draw_polyline(body, Color(0, 0, 0, 0.5), 8.0, true)
	for i in body.size() - 1:
		var w := lerpf(2.5, 6.0, float(i) / float(body.size() - 2))
		draw_line(body[i], body[i + 1], col, w, true)
	draw_polyline(body, Color(1, 1, 1, 0.45), 1.4, true)
	# Chevrons flowing from the source toward the target.
	var spacing := 34.0
	var phase := 0.0 if UIStyle.reduce_motion else fposmod(float(Time.get_ticks_msec()) / 1000.0 * 70.0, spacing)
	var s0 := phase + 14.0
	var j := 0
	while s0 < total - HEAD * 1.6:
		while j < acc.size() - 1 and acc[j + 1] < s0:
			j += 1
		var seg := maxf(acc[j + 1] - acc[j], 0.001)
		var k := (s0 - acc[j]) / seg
		var c := pts[j].lerp(pts[j + 1], k)
		var t := (pts[j + 1] - pts[j]).normalized()
		var nn := Vector2(-t.y, t.x)
		var fade := clampf(minf(s0 / 40.0, (total - HEAD * 1.6 - s0) / 40.0), 0.0, 1.0)
		draw_polyline(PackedVector2Array([c - t * 4.0 + nn * 4.5, c + t * 2.5, c - t * 4.0 - nn * 4.5]), Color(1, 1, 1, 0.85 * fade), 2.2, true)
		s0 += spacing
	# Head: shadow, fill, highlight facet and an anti-aliased rim.
	var nh := Vector2(-dir.y, dir.x)
	var base := tip - dir * HEAD
	var head := PackedVector2Array([tip, base + nh * HEAD * 0.62, base + dir * HEAD * 0.22, base - nh * HEAD * 0.62])
	var sh := PackedVector2Array()
	for q in head:
		sh.append(q + Vector2(0, 3))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
	draw_colored_polygon(head, col)
	draw_colored_polygon(PackedVector2Array([tip, base + nh * HEAD * 0.62, base + dir * HEAD * 0.22]), Color(1, 1, 1, 0.22))
	var rim := PackedVector2Array(head)
	rim.append(head[0])
	draw_polyline(rim, col.darkened(0.45), 1.6, true)
	# Source: a soft pulsing socket.
	var pulse := 0.0 if UIStyle.reduce_motion else 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 1.2)
	draw_circle(a, 9.0 + 2.0 * pulse, Color(col, 0.22), true, -1.0, true)
	draw_circle(a, 6.0, Color(0, 0, 0, 0.6), true, -1.0, true)
	draw_circle(a, 4.0, col, true, -1.0, true)
	if verdict != "":
		# Shape cue so the verdict does not rely on the arrow colour alone (UX D3).
		var vc := tip - dir * (HEAD + 22.0)
		draw_circle(vc, 16.0, Color(0, 0, 0, 0.8), true, -1.0, true)
		draw_circle(vc, 13.5, col, true, -1.0, true)
		var ink := Color(0.06, 0.05, 0.04)
		match verdict:
			"good":
				draw_polyline(PackedVector2Array([vc + Vector2(-6, 0), vc + Vector2(-1.5, 5), vc + Vector2(7, -5)]), ink, 3.5, true)
			"bad":
				draw_line(vc + Vector2(-5, -5), vc + Vector2(5, 5), ink, 3.5, true)
				draw_line(vc + Vector2(5, -5), vc + Vector2(-5, 5), ink, 3.5, true)
			_:
				draw_line(vc + Vector2(-6, -3), vc + Vector2(6, -3), ink, 3.0, true)
				draw_line(vc + Vector2(-6, 3), vc + Vector2(6, 3), ink, 3.0, true)
