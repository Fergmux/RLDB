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
		var n := 14
		var ra := sin(clampf(t, 0.0, 1.0) * PI) * 0.34
		for i in n:
			var a0 := float(i) * TAU / float(n) + t * 0.7 + rnd(i, 1.0) * 0.2
			var w := TAU / float(n) * (0.16 + 0.16 * rnd(i, 2.0))
			var ln := radius * (1.7 + 1.5 * rnd(i, 3.0)) * (0.3 + 0.7 * e)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * ln, Vector2(cos(a0 + w), sin(a0 + w)) * ln]), Color(col.lightened(0.6), ra))
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
