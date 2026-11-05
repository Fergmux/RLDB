class_name FxStatusArt
extends Control
## L8 (owner feedback 2026-11-05): the animated look of one status event on a card, drawn over the
## card's box (this node's rect) as `t` runs 0 -> 1. FxStatus creates two of these per event: a normal
## pass (goo, smoke, mist, cracks, shadows) and an additive pass (`glow`: fire, arcs, light, sparkles),
## and tweens their `t` together. Pure drawing, click-through, deterministic for a given `seed`.
##
## Modes: "apply" (the status lands: about one second), "tick" (Poison / Burn / Medic paying out: a
## smaller, quicker version), "blocked" (a Cleanse or Curse ward stops it: `ward` names which) and
## "expire" (it wears off: a short puff).
##
## Every look is sized from the card width (`u` = width / 85, the field card's base width) so it reads
## the same at 1080p and 4K, and reaches a little past the card so it is noticed at board scale.

## Normal-pass and additive-pass instances (see FxStatus).
var glow := false
## Status key ("poison", "burn", ...).
var key := ""
## "apply", "tick", "blocked" or "expire".
var mode := "apply"
## For "blocked": the ward that stopped it ("cleanse" or "curse").
var ward := ""
## Seed of the per-event jitter (particle positions, arc shapes).
var seed_value := 0
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t

static var _soft_tex: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


## A soft round white dot (radial falloff), shared by every instance: tinted for glows, smoke and goo.
static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


# ---------------------------------------------------------------- helpers

## Deterministic pseudo-random number in [0, 1) for particle `i` and channel `salt`.
func _rnd(i: int, salt: int = 0) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233 + float(seed_value) * 0.1731) * 43758.5453
	return v - floor(v)


static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## Fade-in over [0, a], fade-out over [b, 1].
func _env(a: float, b: float) -> float:
	return _ss(0.0, a, t) * (1.0 - _ss(b, 1.0, t))


func _soft(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.1 or col.a <= 0.003:
		return
	draw_texture_rect(soft_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _u() -> float:
	return size.x / 85.0


func _draw() -> void:
	match mode:
		"blocked":
			_blocked()
			return
		"expire":
			_expire()
			return
	var k := 0.62 if mode == "tick" else 1.0
	match key:
		"poison": _poison(k)
		"burn": _burn(k)
		"paralyse": _paralyse(k)
		"eternal": _eternal(k)
		"cleanse": _cleanse(k)
		"curse": _curse(k)
		"blind": _blind(k)
		"nimble": _nimble(k)
		"debilitate": _debilitate(k)
		"pierce": _pierce(k)
		"medic": _medic(k)
		"rune": _rune(k)
		"retain": _retain(k)
		"reveal": _reveal(k)
		"infiltrate": _infiltrate(k)


# ---------------------------------------------------------------- the fifteen looks

## Dark-green goo drips down from the card's top edge (thick at the lip, a heavy bead at each tip),
## bubbles rise and pop, a sickly tint settles.
func _poison(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.12, 0.72)
	if glow:
		_soft(s / 2.0, s.x * 0.8 * k, Color(0.3, 0.75, 0.1, 0.16 * env))
		for i in 9:
			var bt := fposmod(t * 1.6 - _rnd(i, 3) * 0.6, 1.0)
			var p := Vector2(s.x * (0.12 + 0.76 * _rnd(i, 1)), s.y * (0.95 - 0.7 * bt))
			var r := u * (2.0 + 3.5 * _rnd(i, 2)) * k
			var a := env * (1.0 - _ss(0.75, 1.0, bt))
			draw_arc(p, r, 0.0, TAU, 20, Color(0.7, 1.0, 0.4, 0.8 * a), maxf(1.0, u * 0.9), true)
			_soft(p + Vector2(-r, -r) * 0.35, r * 0.55, Color(1, 1, 1, 0.45 * a))
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.2, 0.03, 0.3 * env))
	var drip_t := 1.0 - pow(1.0 - _ss(0.0, 0.6, t), 2.0)
	var fade := 1.0 - _ss(0.7, 1.0, t)
	var body := Color(0.11, 0.36, 0.06, 0.96 * fade)
	var mid := Color(0.24, 0.6, 0.1, 0.96 * fade)
	var lit := Color(0.68, 0.98, 0.36, 0.9 * fade)
	var lip := -u * 3.0
	for i in 8:
		var x := s.x * (0.06 + 0.88 * (float(i) + _rnd(i, 4) * 0.6) / 8.0)
		var w := u * (3.4 + 2.6 * _rnd(i, 5)) * k
		var ln := s.y * (0.14 + 0.46 * _rnd(i, 6)) * drip_t * k
		# A tapering strand: wide at the lip, thinning, then the bead.
		var tip := Vector2(x, lip + ln)
		var strand := PackedVector2Array([Vector2(x - w, lip), Vector2(x + w, lip), Vector2(x + w * 0.42, tip.y - w * 0.4), Vector2(x - w * 0.42, tip.y - w * 0.4)])
		draw_colored_polygon(strand, body)
		draw_circle(tip, w * 0.8, body, true, -1.0, true)
		draw_circle(tip + Vector2(0, -w * 0.12), w * 0.62, mid, true, -1.0, true)
		draw_line(Vector2(x - w * 0.35, lip + u), Vector2(x - w * 0.22, tip.y - w * 0.5), Color(lit, lit.a * 0.55), maxf(1.0, w * 0.2), true)
		draw_circle(tip + Vector2(-w * 0.28, -w * 0.3), w * 0.2, lit, true, -1.0, true)
		# A droplet that falls from the longest strands.
		if _rnd(i, 7) > 0.55:
			var dt := _ss(0.45, 0.95, t)
			if dt > 0.0:
				var dp := tip + Vector2(0, s.y * 0.5 * dt * dt + w)
				draw_circle(dp, w * 0.42, Color(mid, mid.a * (1.0 - dt)), true, -1.0, true)
	# The goo lip along the top edge, wavy and thick.
	var band := PackedVector2Array()
	band.append(Vector2(-u * 3.0, -u * 6.0))
	for j in 17:
		var x2 := -u * 3.0 + (s.x + u * 6.0) * float(j) / 16.0
		band.append(Vector2(x2, lip + u * (2.5 + 2.5 * sin(float(j) * 1.9 + float(seed_value % 7))) * drip_t))
	band.append(Vector2(s.x + u * 3.0, -u * 6.0))
	draw_colored_polygon(band, body)
	var shine := PackedVector2Array()
	for j in 17:
		var x3 := -u * 2.0 + (s.x + u * 4.0) * float(j) / 16.0
		shine.append(Vector2(x3, -u * 3.6))
	draw_polyline(shine, Color(lit, lit.a * 0.5), maxf(1.0, u * 0.9), true)


## A flame flare from the card's foot and rising embers.
func _burn(k: float) -> void:
	var u := _u()
	var s := size
	var flare := _ss(0.0, 0.3, t) * (1.0 - _ss(0.55, 1.0, t))
	if not glow:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.25, 0.03, 0.0, 0.3 * flare))
		return
	_soft(Vector2(s.x / 2.0, s.y * 0.8), s.x * 1.05 * k, Color(1.0, 0.35, 0.05, 0.55 * flare))
	# Three layers of tongues: deep red, orange, yellow core.
	var layers := [[Color(0.9, 0.15, 0.02, 0.85), 1.0], [Color(1.0, 0.5, 0.08, 0.9), 0.78], [Color(1.0, 0.88, 0.45, 0.9), 0.5]]
	for L in layers:
		var col: Color = L[0]
		var hk: float = L[1]
		var pts := PackedVector2Array()
		var n := 9
		pts.append(Vector2(-u * 6.0, s.y + u * 4.0))
		for j in n:
			var fx := -u * 6.0 + (s.x + u * 12.0) * (float(j) + 0.5) / float(n)
			var h := s.y * (0.35 + 0.45 * _rnd(j, 11)) * hk * flare * k
			var sway := sin(t * 22.0 + float(j) * 1.9) * u * 2.5
			pts.append(Vector2(fx - u * 4.0, s.y - h * 0.35))
			pts.append(Vector2(fx + sway, s.y - h))
			pts.append(Vector2(fx + u * 4.0, s.y - h * 0.35))
		pts.append(Vector2(s.x + u * 6.0, s.y + u * 4.0))
		draw_colored_polygon(pts, Color(col, col.a * flare))
	for i in 16:
		var et := fposmod(t * 1.3 + _rnd(i, 12) * 0.5, 1.0)
		var p := Vector2(s.x * (0.05 + 0.9 * _rnd(i, 13)) + sin(et * 9.0 + float(i)) * u * 4.0, s.y * (1.0 - 1.35 * et))
		var a := (1.0 - et) * _env(0.1, 0.8)
		_soft(p, u * (2.4 + 2.0 * _rnd(i, 14)) * k, Color(1.0, 0.6, 0.15, 0.9 * a))
		draw_circle(p, u * 0.9 * k, Color(1.0, 0.92, 0.6, a), true, -1.0, true)


## Crackling electric arcs across and around the card, re-struck every few frames.
func _paralyse(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.06, 0.75)
	var strike := int(floor(t * 18.0))
	if not glow:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.08, 0.0, 0.25 * env))
		return
	var flick := 0.65 + 0.35 * _rnd(strike, 21)
	_soft(s / 2.0, s.x * 0.9 * k, Color(1.0, 0.9, 0.3, 0.35 * env * flick))
	for a in 5:
		var seed2 := strike * 7 + a
		var p0 := Vector2(-u * 8.0, s.y * _rnd(seed2, 22))
		var p1 := Vector2(s.x + u * 8.0, s.y * _rnd(seed2, 23))
		if a % 2 == 1:
			p0 = Vector2(s.x * _rnd(seed2, 24), -u * 8.0)
			p1 = Vector2(s.x * _rnd(seed2, 25), s.y + u * 8.0)
		var pts := PackedVector2Array([p0])
		var segs := 7
		for j in range(1, segs):
			var q := p0.lerp(p1, float(j) / float(segs))
			var n := (p1 - p0).normalized().orthogonal()
			pts.append(q + n * (_rnd(seed2 * 13 + j, 26) - 0.5) * u * 16.0 * k)
		pts.append(p1)
		var al := env * flick * (0.55 + 0.45 * _rnd(seed2, 27))
		draw_polyline(pts, Color(1.0, 0.85, 0.2, 0.45 * al), u * 4.5 * k, true)
		draw_polyline(pts, Color(1.0, 1.0, 0.85, al), maxf(1.0, u * 1.4 * k), true)
	# Sparks at the card corners.
	for c in [Vector2.ZERO, Vector2(s.x, 0), Vector2(0, s.y), s]:
		_soft(c, u * 9.0 * k * flick, Color(1.0, 0.95, 0.5, 0.7 * env))


## A golden halo settles over the card with turning rays and motes.
func _eternal(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.15, 0.75)
	if not glow:
		return
	var c := s / 2.0
	_soft(c, s.x * 1.1 * k, Color(1.0, 0.8, 0.35, 0.4 * env))
	# Rays.
	for i in 12:
		var ang := float(i) * TAU / 12.0 + t * 0.9
		var d := Vector2(cos(ang), sin(ang))
		var ln := s.x * (0.75 + 0.15 * _rnd(i, 31)) * _ss(0.0, 0.4, t) * k
		var w := d.orthogonal() * u * 3.2
		draw_colored_polygon(PackedVector2Array([c + w * 0.2, c + d * ln + w, c + d * ln - w, c - w * 0.2]), Color(1.0, 0.9, 0.55, 0.32 * env))
	# The halo ring, dropping onto the card's top.
	var hy := lerpf(-s.y * 0.35, s.y * 0.04, 1.0 - pow(1.0 - _ss(0.0, 0.45, t), 3.0))
	var hc := Vector2(c.x, hy)
	var rx := s.x * 0.42 * k
	var ry := rx * 0.28
	var ring := PackedVector2Array()
	for j in 41:
		var a := TAU * float(j) / 40.0
		ring.append(hc + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(ring, Color(1.0, 0.82, 0.3, 0.55 * env), u * 5.0, true)
	draw_polyline(ring, Color(1.0, 0.97, 0.8, env), maxf(1.0, u * 1.8), true)
	for i in 10:
		var mt := fposmod(t * 0.9 + _rnd(i, 32), 1.0)
		var p := Vector2(s.x * _rnd(i, 33), s.y * (1.0 - mt))
		_soft(p, u * 2.4, Color(1.0, 0.9, 0.5, env * (1.0 - mt)))


## A white-blue purifying wash sweeps down the card, leaving sparkles.
func _cleanse(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.08, 0.7)
	var y := lerpf(-s.y * 0.25, s.y * 1.25, _ss(0.0, 0.7, t))
	if not glow:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.75, 0.9, 1.0, 0.18 * env))
		return
	# The light band.
	for j in 5:
		_soft(Vector2(s.x * (0.1 + 0.2 * float(j)), y), s.x * 0.4 * k, Color(0.8, 0.93, 1.0, 0.5 * env))
	draw_line(Vector2(-u * 6.0, y), Vector2(s.x + u * 6.0, y), Color(1, 1, 1, 0.85 * env), u * 2.0, true)
	# Sparkles behind the band.
	for i in 14:
		var p := Vector2(s.x * _rnd(i, 41), s.y * _rnd(i, 42))
		if p.y > y:
			continue
		var age := clampf((y - p.y) / s.y, 0.0, 1.0)
		var a := env * (1.0 - age) * (0.6 + 0.4 * sin(t * 30.0 + float(i)))
		var r := u * (3.0 + 3.0 * _rnd(i, 43)) * k
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color(1, 1, 1, a), maxf(1.0, u * 0.9), true)
		draw_line(p - Vector2(0, r), p + Vector2(0, r), Color(1, 1, 1, a), maxf(1.0, u * 0.9), true)
		_soft(p, r * 0.7, Color(0.75, 0.9, 1.0, a))


## Purple smoke curls up around the card while a sigil draws itself and turns.
func _curse(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.12, 0.75)
	var c := s / 2.0
	if not glow:
		for i in 14:
			var st := fposmod(t * 0.8 + _rnd(i, 51) * 0.5, 1.0)
			var p := Vector2(s.x * (-0.1 + 1.2 * _rnd(i, 52)) + sin(st * 6.0 + float(i)) * u * 6.0, s.y * (1.05 - 0.9 * st))
			_soft(p, u * (14.0 + 12.0 * st) * k, Color(0.2, 0.04, 0.3, 0.75 * env * (1.0 - st * 0.6)))
		return
	_soft(c, s.x * 0.8 * k, Color(0.55, 0.2, 0.85, 0.4 * env))
	var draw_k := _ss(0.05, 0.5, t)
	var rad := s.x * 0.42 * k
	var rot := t * 1.6
	draw_arc(c, rad, rot, rot + TAU * draw_k, 48, Color(0.85, 0.6, 1.0, 0.9 * env), maxf(1.0, u * 1.6), true)
	draw_arc(c, rad * 0.86, -rot, -rot + TAU * draw_k, 48, Color(0.7, 0.4, 1.0, 0.6 * env), maxf(1.0, u * 1.0), true)
	var star := PackedVector2Array()
	for i in 6:
		var a := -PI / 2.0 + rot * 0.5 + float(i) * TAU * 2.0 / 5.0
		star.append(c + Vector2(cos(a), sin(a)) * rad * 0.86)
	var n := int(ceil(draw_k * 5.0))
	for i in n:
		var f := clampf(draw_k * 5.0 - float(i), 0.0, 1.0)
		draw_line(star[i], star[i].lerp(star[i + 1], f), Color(0.92, 0.75, 1.0, 0.85 * env), maxf(1.0, u * 1.3), true)
	for i in 8:
		var a := rot + float(i) * TAU / 8.0
		_soft(c + Vector2(cos(a), sin(a)) * rad, u * 2.6, Color(0.95, 0.8, 1.0, env))


## A dark mist band rolls over the art from both sides and thickens; grey wisps trail.
func _blind(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.1, 0.78)
	var close := 1.0 - pow(1.0 - _ss(0.0, 0.45, t), 3.0)
	var band_y := s.y * 0.34
	if glow:
		for i in 7:
			var p := Vector2(s.x * _rnd(i, 61), band_y + (_rnd(i, 62) - 0.5) * s.y * 0.34)
			_soft(p, u * 3.0, Color(0.75, 0.75, 0.9, 0.3 * env))
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, s.y * 0.66)), Color(0.0, 0.0, 0.02, 0.35 * env * close))
	for side in [-1.0, 1.0]:
		for i in 11:
			var f := float(i) / 10.0
			var x0: float = s.x * 0.5 + side * s.x * (0.7 + 0.9 * (1.0 - close)) - side * s.x * 0.75 * f
			var p := Vector2(x0, band_y + sin(f * 6.0 + t * 4.0 + float(side)) * u * 5.0)
			_soft(p, u * (18.0 + 8.0 * _rnd(i, 63)) * k, Color(0.02, 0.02, 0.05, 0.8 * env))
	draw_rect(Rect2(-u * 4.0, band_y - u * 13.0 * k, s.x + u * 8.0, u * 26.0 * k), Color(0.01, 0.01, 0.03, 0.62 * env * close))
	for i in 3:
		var wy := band_y + (float(i) - 1.0) * u * 9.0
		var pts := PackedVector2Array()
		for j in 11:
			var x := -u * 6.0 + (s.x + u * 12.0) * float(j) / 10.0
			pts.append(Vector2(x, wy + sin(float(j) * 1.3 + t * 5.0 + float(i) * 2.0) * u * 2.0))
		draw_polyline(pts, Color(0.55, 0.55, 0.68, 0.32 * env * close), maxf(1.0, u * 1.0), true)


## Wind streaks sweep across the card with a curl at their heads.
func _nimble(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.08, 0.7)
	if not glow:
		return
	for i in 7:
		var y := s.y * (0.12 + 0.76 * (float(i) + _rnd(i, 71) * 0.5) / 7.0)
		var head := lerpf(-s.x * 0.4, s.x * 1.5, _ss(0.0, 0.85, t - _rnd(i, 72) * 0.12))
		var tail := head - s.x * (0.55 + 0.35 * _rnd(i, 73)) * k
		var pts := PackedVector2Array()
		for j in 13:
			var x := lerpf(tail, head, float(j) / 12.0)
			pts.append(Vector2(x, y + sin(x / s.x * 5.0 + float(i)) * u * 3.0))
		var col := Color(0.75, 1.0, 0.96, 0.8 * env) if i % 2 == 0 else Color(0.4, 0.95, 0.88, 0.7 * env)
		draw_polyline(pts, Color(col, col.a * 0.35), u * 3.8 * k, true)
		draw_polyline(pts, col, maxf(1.0, u * 1.2 * k), true)
		if i % 3 == 0:
			draw_arc(pts[12] + Vector2(0, -u * 3.0), u * 3.0, PI * 0.5, PI * 2.2, 12, col, maxf(1.0, u * 1.1), true)


## Cracks spread out from the centre; the card is weighed down.
func _debilitate(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.06, 0.78)
	var grow := _ss(0.0, 0.4, t)
	var c := Vector2(s.x * 0.5, s.y * 0.4)
	if glow:
		_soft(c, u * 18.0 * k, Color(1.0, 0.85, 0.6, 0.45 * env * (1.0 - grow)))
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.06, 0.04, 0.3 * env))
	for b in 7:
		var ang := float(b) * TAU / 7.0 + _rnd(b, 81) * 0.6
		var p := c
		var pts := PackedVector2Array([p])
		var segs := 5
		for j in segs:
			ang += (_rnd(b * 11 + j, 82) - 0.5) * 0.9
			p += Vector2(cos(ang), sin(ang)) * s.x * 0.16 * k
			pts.append(p)
		var n := int(ceil(grow * float(segs)))
		var shown := pts.slice(0, n + 1)
		if shown.size() >= 2:
			draw_polyline(shown, Color(0.95, 0.88, 0.75, 0.45 * env), u * 2.6, true)
			draw_polyline(shown, Color(0.05, 0.03, 0.02, 0.95 * env), maxf(1.0, u * 1.3), true)
	# Shackle bars closing at the top and bottom.
	var bar := u * 4.0 * k
	var close := _ss(0.2, 0.5, t)
	var col := Color(0.35, 0.32, 0.28, 0.9 * env)
	draw_rect(Rect2(-u * 4.0, s.y * 0.62 - bar / 2.0, (s.x + u * 8.0) * close, bar), col)
	draw_rect(Rect2(-u * 4.0, s.y * 0.62 - bar * 0.35, (s.x + u * 8.0) * close, bar * 0.25), Color(0.8, 0.76, 0.68, 0.7 * env))


## A spear glint shoots across the card and flashes at its tip.
func _pierce(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.04, 0.7)
	if not glow:
		return
	var go := _ss(0.0, 0.35, t)
	var a := Vector2(-s.x * 0.35, s.y * 1.1)
	var b := Vector2(s.x * 1.25, -s.y * 0.15)
	var tip := a.lerp(b, go)
	var tail := a.lerp(b, maxf(0.0, go - 0.55))
	draw_line(tail, tip, Color(0.75, 0.85, 1.0, 0.45 * env), u * 5.0 * k, true)
	draw_line(tail, tip, Color(1, 1, 1, env), maxf(1.0, u * 1.8 * k), true)
	var flash := _ss(0.2, 0.38, t) * (1.0 - _ss(0.4, 0.85, t))
	var gc := Vector2(s.x * 0.62, s.y * 0.38)
	_soft(gc, s.x * 0.5 * k, Color(0.85, 0.92, 1.0, 0.7 * flash))
	var r := s.x * 0.55 * flash * k
	draw_line(gc - Vector2(r, 0), gc + Vector2(r, 0), Color(1, 1, 1, flash), maxf(1.0, u * 1.5), true)
	draw_line(gc - Vector2(0, r * 0.7), gc + Vector2(0, r * 0.7), Color(1, 1, 1, flash), maxf(1.0, u * 1.5), true)
	# A shine sweep across the card face.
	var sx := lerpf(-s.x * 0.3, s.x * 1.3, _ss(0.3, 0.8, t))
	draw_colored_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + u * 10.0, 0), Vector2(sx - s.y * 0.3 + u * 10.0, s.y), Vector2(sx - s.y * 0.3, s.y)]), Color(1, 1, 1, 0.22 * env))


## A green cross pulses out from the centre; healing rings and rising crosses.
func _medic(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.1, 0.72)
	if not glow:
		return
	var c := s / 2.0
	_soft(c, s.x * 0.9 * k, Color(0.3, 1.0, 0.55, 0.4 * env))
	var pulse := 1.0 - pow(1.0 - _ss(0.0, 0.4, t), 3.0)
	var arm := s.x * 0.36 * (0.6 + 0.4 * pulse) * k
	var th := arm * 0.36
	var col := Color(0.75, 1.0, 0.82, 0.95 * env)
	draw_rect(Rect2(c.x - th / 2.0, c.y - arm, th, arm * 2.0), Color(0.3, 0.95, 0.5, 0.5 * env))
	draw_rect(Rect2(c.x - arm, c.y - th / 2.0, arm * 2.0, th), Color(0.3, 0.95, 0.5, 0.5 * env))
	draw_rect(Rect2(c.x - th * 0.3, c.y - arm * 0.9, th * 0.6, arm * 1.8), col)
	draw_rect(Rect2(c.x - arm * 0.9, c.y - th * 0.3, arm * 1.8, th * 0.6), col)
	for ring in 2:
		var rt := clampf(t * 1.4 - float(ring) * 0.25, 0.0, 1.0)
		draw_arc(c, s.x * (0.2 + 0.7 * rt) * k, 0.0, TAU, 40, Color(0.5, 1.0, 0.65, 0.7 * (1.0 - rt) * env), maxf(1.0, u * 1.6), true)
	for i in 6:
		var mt := fposmod(t * 1.1 + _rnd(i, 91) * 0.6, 1.0)
		var p := Vector2(s.x * (0.1 + 0.8 * _rnd(i, 92)), s.y * (1.0 - mt))
		var r := u * 2.6 * k
		var a := env * (1.0 - mt)
		draw_rect(Rect2(p.x - r * 0.3, p.y - r, r * 0.6, r * 2.0), Color(0.7, 1.0, 0.75, a))
		draw_rect(Rect2(p.x - r, p.y - r * 0.3, r * 2.0, r * 0.6), Color(0.7, 1.0, 0.75, a))


## A circle of runes orbits the card (seen in perspective) and closes in.
func _rune(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.12, 0.75)
	if not glow:
		return
	var c := s / 2.0
	_soft(c, s.x * 0.85 * k, Color(0.3, 0.55, 1.0, 0.38 * env))
	var shrink := lerpf(1.25, 0.95, _ss(0.0, 0.6, t))
	var rx := s.x * 0.62 * shrink * k
	var ry := rx * 0.42
	var spin := t * 3.2
	var ring := PackedVector2Array()
	for j in 49:
		var a := TAU * float(j) / 48.0
		ring.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(ring, Color(0.45, 0.7, 1.0, 0.45 * env), u * 3.5, true)
	draw_polyline(ring, Color(0.85, 0.93, 1.0, 0.85 * env), maxf(1.0, u * 1.1), true)
	for i in 8:
		var a := spin + float(i) * TAU / 8.0
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		var front := 0.55 + 0.45 * sin(a)
		var r := u * 3.6 * k * (0.7 + 0.3 * front)
		var col := Color(0.9, 0.96, 1.0, env * (0.45 + 0.55 * front))
		_soft(p, r * 1.6, Color(0.4, 0.65, 1.0, 0.7 * env))
		# A small rune mark: a stave with two branches, varied per mark.
		draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, maxf(1.0, u * 0.9), true)
		var b := 1.0 if i % 2 == 0 else -1.0
		draw_line(p + Vector2(0, -r * 0.3), p + Vector2(r * 0.7 * b, -r * 0.9), col, maxf(1.0, u * 0.9), true)
		if i % 3 != 0:
			draw_line(p + Vector2(0, r * 0.2), p + Vector2(-r * 0.7 * b, -r * 0.4), col, maxf(1.0, u * 0.9), true)


## A copper padlock clasps shut at the centre, with a chain ring closing around it.
func _retain(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.1, 0.75)
	var c := Vector2(s.x / 2.0, s.y * 0.44)
	var shut := 1.0 - pow(1.0 - _ss(0.15, 0.42, t), 4.0)
	var w := s.x * 0.34 * k
	var h := w * 0.78
	if glow:
		var click := _ss(0.38, 0.44, t) * (1.0 - _ss(0.44, 0.75, t))
		_soft(c, s.x * 0.9 * k, Color(1.0, 0.6, 0.3, 0.3 * env))
		_soft(c + Vector2(0, -h * 0.2), s.x * 0.45, Color(1.0, 0.9, 0.7, 0.9 * click))
		# The chain: oval links, alternately face-on and edge-on, closing around the lock.
		var links := 16
		var shown := int(ceil(_ss(0.0, 0.35, t) * float(links)))
		var rad := s.x * 0.5 * k
		for i in shown:
			var a := -PI / 2.0 + float(i) * TAU / float(links) + t * 0.5
			var p := c + Vector2(cos(a), sin(a)) * rad
			var tang := Vector2(-sin(a), cos(a))
			var lw := u * 3.4 * k
			var lh := lw * (0.62 if i % 2 == 0 else 0.22)
			var ring := PackedVector2Array()
			for j in 17:
				var b := TAU * float(j) / 16.0
				ring.append(p + tang * cos(b) * lw + tang.orthogonal() * sin(b) * lh)
			draw_polyline(ring, Color(1.0, 0.72, 0.42, 0.9 * env), maxf(1.0, u * 1.2), true)
		return
	# Shackle (drops into the body as it shuts).
	var sy := lerpf(-h * 0.55, 0.0, shut)
	var sc := c + Vector2(0, -h * 0.35 + sy)
	draw_arc(sc, w * 0.32, PI, TAU, 20, Color(0.25, 0.12, 0.05, 0.95 * env), w * 0.2, true)
	draw_arc(sc, w * 0.32, PI, TAU, 20, Color(0.95, 0.65, 0.4, 0.95 * env), w * 0.1, true)
	draw_line(sc + Vector2(w * 0.32, 0), sc + Vector2(w * 0.32, h * 0.25 - sy), Color(0.95, 0.65, 0.4, 0.95 * env), w * 0.1, true)
	# Body.
	var body := Rect2(c.x - w / 2.0, c.y - h * 0.2, w, h * 0.8)
	draw_rect(body.grow(u * 1.2), Color(0.18, 0.08, 0.02, 0.95 * env))
	draw_rect(body, Color(0.82, 0.45, 0.2, 0.97 * env))
	draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.35)), Color(1.0, 0.75, 0.5, 0.6 * env))
	draw_circle(body.get_center() + Vector2(0, -h * 0.05), w * 0.09, Color(0.15, 0.06, 0.02, env), true, -1.0, true)
	draw_rect(Rect2(body.get_center().x - w * 0.035, body.get_center().y - h * 0.02, w * 0.07, h * 0.2), Color(0.15, 0.06, 0.02, env))


## An eye opens over the card and radiates.
func _reveal(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.08, 0.75)
	var c := Vector2(s.x / 2.0, s.y * 0.42)
	var open := 1.0 - pow(1.0 - _ss(0.08, 0.42, t), 3.0)
	var w := s.x * 0.48 * k
	var h := w * 0.48 * open
	var lid_top := PackedVector2Array()
	var lid_bot := PackedVector2Array()
	for j in 25:
		var f := float(j) / 24.0
		var x := lerpf(-w, w, f)
		var y := h * (1.0 - pow(x / w, 2.0))
		lid_top.append(c + Vector2(x, -y))
		lid_bot.append(c + Vector2(x, y))
	if glow:
		_soft(c, s.x * 0.85 * k, Color(1.0, 0.4, 0.75, 0.45 * env))
		for i in 14:
			var a := float(i) * TAU / 14.0
			var d := Vector2(cos(a), sin(a) * 0.75)
			var r0 := w * 1.05
			var r1 := w * (1.2 + 0.4 * open)
			draw_line(c + d * r0, c + d * r1, Color(1.0, 0.75, 0.9, 0.75 * env * open), maxf(1.0, u * 1.3), true)
		return
	var eye := PackedVector2Array(lid_top)
	var rev := lid_bot.duplicate()
	rev.reverse()
	eye.append_array(rev)
	if h > 0.5:
		draw_colored_polygon(eye, Color(0.98, 0.94, 0.96, 0.95 * env))
		var ir := minf(h * 0.95, w * 0.42)
		draw_circle(c, ir, Color(0.8, 0.15, 0.5, 0.95 * env), true, -1.0, true)
		draw_circle(c, ir * 0.48, Color(0.08, 0.0, 0.05, env), true, -1.0, true)
		draw_circle(c + Vector2(-ir * 0.3, -ir * 0.3), ir * 0.2, Color(1, 1, 1, 0.9 * env), true, -1.0, true)
	draw_polyline(lid_top, Color(0.25, 0.02, 0.15, env), maxf(1.0, u * 2.2), true)
	draw_polyline(lid_bot, Color(0.25, 0.02, 0.15, env), maxf(1.0, u * 1.6), true)


## Shadow tendrils curl in from the card's edges, tapering to fine points.
func _infiltrate(k: float) -> void:
	var u := _u()
	var s := size
	var env := _env(0.1, 0.75)
	var grow := _ss(0.0, 0.5, t)
	if glow:
		for i in 6:
			_soft(Vector2(s.x * _rnd(i, 101), s.y * _rnd(i, 102)), u * 3.0, Color(0.55, 0.6, 1.0, 0.5 * env))
		return
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.08, 0.35 * env))
	for i in 8:
		var side := i % 4
		var f := (float(i / 4) + 0.5 + (_rnd(i, 103) - 0.5) * 0.5) / 2.0
		var p0 := Vector2(s.x * f, -u * 6.0)
		var dir := Vector2(0, 1)
		if side == 0:
			p0 = Vector2(-u * 6.0, s.y * f)
			dir = Vector2(1, 0)
		elif side == 1:
			p0 = Vector2(s.x + u * 6.0, s.y * f)
			dir = Vector2(-1, 0)
		elif side == 2:
			p0 = Vector2(s.x * f, s.y + u * 6.0)
			dir = Vector2(0, -1)
		var segs := 16
		var ln := s.x * (0.45 + 0.25 * _rnd(i, 104)) * grow * k
		var curl := (1.0 if _rnd(i, 105) > 0.5 else -1.0) * (2.2 + 1.5 * _rnd(i, 106))
		var pts := PackedVector2Array()
		var p := p0
		var d := dir
		for j in segs + 1:
			pts.append(p)
			var f2 := float(j) / float(segs)
			d = d.rotated(curl * f2 * f2 * 0.2)
			p += d * ln / float(segs)
		# A tapered ribbon: offset both sides by a width that thins to the tip.
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for j in pts.size():
			var tang := (pts[mini(j + 1, segs)] - pts[maxi(j - 1, 0)]).normalized()
			var nrm := tang.orthogonal()
			var wj := u * 3.4 * k * (1.0 - float(j) / float(segs)) + u * 0.25
			left.append(pts[j] + nrm * wj)
			right.append(pts[j] - nrm * wj)
		if ln > u:
			draw_ribbon(self, left, right, Color(0.01, 0.01, 0.05, 0.92 * env))
			draw_polyline(pts.slice(0, segs / 2), Color(0.45, 0.5, 1.0, 0.35 * env), maxf(1.0, u * 0.8), true)


## Draws a ribbon between the paired edge points `left[j]` / `right[j]` filled in `col` on `ci`. A
## simple outline is one polygon, as before; a ribbon whose curl crosses itself (Infiltrate's shadow
## tendrils, QA 2026-11-05: Godot logged "Invalid polygon data" and dropped the tendril) is drawn as
## its strip of quads instead. Returns the triangle indices of the strip, or empty when it was drawn
## as a polygon (tests).
static func draw_ribbon(ci: CanvasItem, left: PackedVector2Array, right: PackedVector2Array, col: Color) -> PackedInt32Array:
	var outline := left.duplicate()
	var back := right.duplicate()
	back.reverse()
	outline.append_array(back)
	if not Geometry2D.triangulate_polygon(outline).is_empty():
		ci.draw_colored_polygon(outline, col)
		return PackedInt32Array()
	var idx := ribbon_strip(mini(left.size(), right.size()))
	var pts := left.slice(0, mini(left.size(), right.size()))
	pts.append_array(right.slice(0, pts.size()))
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	return idx


## Triangle indices of a strip of `n` point pairs laid out as [left 0..n-1, right 0..n-1].
static func ribbon_strip(n: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in n - 1:
		idx.append_array([j, j + 1, n + j, j + 1, n + j + 1, n + j])
	return idx


# ---------------------------------------------------------------- blocked and expire

## The ward: a shield dome flashes in front of the card; the stopped status's badge (FxStatus draws
## it) bounces off it. Cleanse is white-gold, Curse violet.
func _blocked() -> void:
	var u := _u()
	var s := size
	var c := Vector2(s.x / 2.0, s.y * 0.45)
	var col := Color(1.0, 0.92, 0.65) if ward == "cleanse" else Color(0.72, 0.45, 1.0)
	var hit := _ss(0.22, 0.3, t)
	var env := _env(0.1, 0.65)
	var flash := hit * (1.0 - _ss(0.3, 0.75, t))
	var r := s.x * 0.62
	if not glow:
		draw_circle(c, r, Color(col.darkened(0.6), 0.25 * env), true, -1.0, true)
		return
	_soft(c, r * 1.5, Color(col, 0.45 * env + 0.4 * flash))
	# Hexagonal ward cells on the dome.
	for i in 7:
		var hc := c + (Vector2.ZERO if i == 0 else Vector2(cos(float(i) * TAU / 6.0), sin(float(i) * TAU / 6.0)) * r * 0.55)
		draw_polyline(CardGeometry.poly(hc, r * 0.3, 6, PI / 6.0) + PackedVector2Array([CardGeometry.poly(hc, r * 0.3, 6, PI / 6.0)[0]]), Color(col.lightened(0.3), (0.35 + 0.6 * flash) * env), maxf(1.0, u * 1.1), true)
	draw_arc(c, r, 0.0, TAU, 56, Color(col, 0.6 * env), u * 4.5, true)
	draw_arc(c, r, 0.0, TAU, 56, Color(1, 1, 1, (0.6 + 0.4 * flash) * env), maxf(1.0, u * 1.6), true)
	# Impact sparks where the badge strikes (the top of the dome).
	if flash > 0.0:
		var ip := c + Vector2(0, -r)
		for i in 10:
			var a := PI + float(i) * PI / 9.0
			var d := Vector2(cos(a), sin(a))
			draw_line(ip + d * u * 3.0, ip + d * u * (6.0 + 16.0 * (1.0 - flash)), Color(1, 1, 1, flash), maxf(1.0, u * 1.2), true)


## Wearing off: a ring of the status colour expands and fades with a few motes drifting up.
func _expire() -> void:
	var u := _u()
	var s := size
	var c := Vector2(s.x / 2.0, s.y * 0.42)
	var col: Color = CardStatusIcons.accent(key)
	var env := _env(0.1, 0.6)
	if not glow:
		return
	draw_arc(c, s.x * (0.18 + 0.4 * t), 0.0, TAU, 36, Color(col, 0.7 * env), maxf(1.0, u * 1.4), true)
	for i in 6:
		var p := c + Vector2((_rnd(i, 111) - 0.5) * s.x * 0.6, -s.y * 0.35 * t * (0.6 + 0.4 * _rnd(i, 112)))
		_soft(p, u * 3.0, Color(col, 0.8 * env))
