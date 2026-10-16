class_name FxBlast
extends Control
## Magic impact drawn around the node position as `t` runs 0 -> 1 (F04-07): a white-hot core, an inner
## glow, expanding shockwave rings, radial streaks and, for the bigger looks, turning light rays and
## rising embers. Additively blended, presentation-only and click-through; FxPlayer creates,
## tweens and frees it.
##
## Looks: HIT (direct attack landing: rings and streaks), BLAST (killing blow: everything, big) and
## FINAL (lethal damage from an effect: rings, streaks and a few embers).

enum Look { HIT, BLAST, FINAL }

## Which look is drawn.
var look: Look = Look.HIT
## Accent colour (the attacker's Type colour); the core is always white-hot.
var col: Color = Color.WHITE
## Reach of the shockwave in pixels.
var radius: float = 120.0
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(4, 4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


## Deterministic pseudo-random 0..1 for particle `i` and stream `s` (no state, so redraws are stable).
static func rnd(i: int, s: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + s * 78.233) * 43758.5453, 1.0)


## Draws one soft light ray from the origin of `ci`: a tapered wedge whose alpha fades along its length and
## toward both edges (per-vertex colours; blend additively for a glow). `a` is the peak alpha near the origin.
static func soft_ray(ci: CanvasItem, ang: float, width: float, length: float, col: Color, a: float) -> void:
	var d0 := ang - width * 0.5
	var d1 := ang + width * 0.5
	var o := Vector2.ZERO
	var l1 := Vector2(cos(d0), sin(d0)) * length * 0.55
	var r1 := Vector2(cos(d1), sin(d1)) * length * 0.55
	var c1 := Vector2(cos(ang), sin(ang)) * length * 0.55
	var l2 := Vector2(cos(d0 * 0.5 + ang * 0.5), sin(d0 * 0.5 + ang * 0.5)) * length
	var r2 := Vector2(cos(d1 * 0.5 + ang * 0.5), sin(d1 * 0.5 + ang * 0.5)) * length
	var c2 := Vector2(cos(ang), sin(ang)) * length
	var hot := Color(col, a)
	var mid := Color(col, a * 0.5)
	var none := Color(col, 0.0)
	ci.draw_polygon(PackedVector2Array([o, l1, c1]), PackedColorArray([hot, none, mid]))
	ci.draw_polygon(PackedVector2Array([o, c1, r1]), PackedColorArray([hot, mid, none]))
	ci.draw_polygon(PackedVector2Array([l1, c1, c2]), PackedColorArray([none, mid, none]))
	ci.draw_polygon(PackedVector2Array([l1, c2, l2]), PackedColorArray([none, none, none]))
	ci.draw_polygon(PackedVector2Array([c1, r1, c2]), PackedColorArray([mid, none, none]))
	ci.draw_polygon(PackedVector2Array([r1, r2, c2]), PackedColorArray([none, none, none]))


## Soft radial bloom of `radius` at the origin of `ci`: stacked translucent discs, `a` = alpha of the centre.
static func bloom(ci: CanvasItem, radius: float, col: Color, a: float) -> void:
	for i in 10:
		var u := float(i) / 9.0
		ci.draw_circle(Vector2.ZERO, radius * (1.0 - 0.9 * u), Color(col, a * 0.12), true, -1.0, true)


static func _out(x: float, p: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)


func _draw() -> void:
	var big := look == Look.BLAST
	var e := _out(t)
	var fade := 1.0 - t
	# Inner glow: stacked translucent discs swelling outward.
	for i in 6:
		var r := radius * (0.25 + 0.14 * float(i)) * (0.35 + 0.65 * e)
		draw_circle(Vector2.ZERO, r, Color(col.lightened(0.35), 0.10 * pow(fade, 1.6)), true, -1.0, true)
	# White-hot core.
	var core := pow(1.0 - clampf(t * (2.6 if big else 4.0), 0.0, 1.0), 2.0)
	if core > 0.001:
		draw_circle(Vector2.ZERO, radius * (0.62 if big else 0.4) * (0.5 + 0.5 * core), Color(1, 1, 1, core), true, -1.0, true)
		draw_circle(Vector2.ZERO, radius * (0.3 if big else 0.2), Color(1, 1, 0.9, core), true, -1.0, true)
	# Shockwave rings.
	var rings := 3 if big else 2
	for k in rings:
		var tt := clampf((t - float(k) * 0.09) / (1.0 - float(k) * 0.09), 0.0, 1.0)
		if tt <= 0.0:
			continue
		var r2 := radius * (0.12 + 1.0 * _out(tt, 2.6)) * (1.0 + 0.35 * float(k))
		var c2 := Color(1, 1, 1).lerp(col.lightened(0.25), clampf(tt * 1.4, 0.0, 1.0))
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 72, Color(c2, 0.9 * (1.0 - tt)), 2.0 + 16.0 * (1.0 - tt) * (1.0 if big else 0.6), true)
	# Light rays (killing blow).
	if big:
		var n := 16
		var ra := sin(clampf(t, 0.0, 1.0) * PI) * 0.7
		bloom(self, radius * 1.1 * (0.5 + 0.5 * e), col.lightened(0.5), ra)
		for i in n:
			var a0 := float(i) * TAU / float(n) + t * 0.25 + rnd(i, 1.0) * 0.3
			var w := TAU / float(n) * (0.25 + 0.55 * rnd(i, 2.0))
			var ln := radius * (1.6 + 2.0 * rnd(i, 3.0)) * (0.3 + 0.7 * e)
			soft_ray(self, a0, w, ln, col.lightened(0.55), ra)
	# Radial streaks.
	var ns := 44 if big else 22
	for i in ns:
		var a := float(i) * TAU / float(ns) + rnd(i, 4.0) * 0.5
		var d := Vector2(cos(a), sin(a))
		var sp := 0.6 + 0.8 * rnd(i, 5.0)
		var e2 := _out(t * sp, 3.0)
		var r0 := radius * (0.2 + 1.1 * e2) * sp
		var r1 := r0 + radius * 0.5 * (1.0 - t) * (0.4 + rnd(i, 6.0))
		draw_line(d * r0, d * r1, Color(col.lightened(0.5 - 0.3 * rnd(i, 7.0)), clampf(1.0 - t * 1.15, 0.0, 1.0)), 1.5 + 3.5 * (1.0 - t), true)
	# Embers rising out of the blast.
	if look != Look.HIT:
		var ne := 56 if big else 16
		for i in ne:
			var birth := rnd(i, 8.0) * 0.28
			var u := clampf((t - birth) / (1.0 - birth), 0.0, 1.0)
			if u <= 0.0:
				continue
			var a2 := rnd(i, 9.0) * TAU
			var spread := radius * (0.3 + 1.3 * rnd(i, 10.0)) * _out(u, 2.0)
			var p := Vector2(cos(a2), sin(a2) * 0.7) * spread + Vector2(sin(u * 6.0 + float(i)) * 8.0, -u * radius * (0.5 + 0.9 * rnd(i, 11.0)))
			var flick := 0.65 + 0.35 * sin(t * 40.0 + float(i) * 3.1)
			var ec := Color(1, 0.95, 0.75).lerp(col.lightened(0.15), clampf(u * 1.5, 0.0, 1.0))
			draw_circle(p, (1.6 + 3.2 * rnd(i, 12.0)) * (1.0 - u * 0.7), Color(ec, (1.0 - u) * flick), true, -1.0, true)
