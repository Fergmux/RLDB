class_name FxSerpentArt
extends Control
## The spirit serpent of the Divine Serpents' strike (B5, owner feedback 2026-10-20), drawn about the
## node position (the coil centre) and driven by one progress value `t` (0 -> 1 over `life` seconds):
## it forms in a turning coil out of the merging Serpent cards, rears back away from its target, darts
## along a curve to `target` and bursts into spray on impact. A redraw at any `t` is stable (no per-frame
## state). Click-through; FxSerpent creates, tweens and frees it.

## Body samples (tail to head) and spray droplets.
const SEGMENTS := 84
const SPRAY := 44

## Body colour (bright) and rim colour (deep).
var col: Color = Color("5fd4ff")
var rim: Color = Color("0b3d66")
## Coil radius in pixels; the body thickness follows it.
var radius: float = 90.0
## The strike target relative to the node position.
var target: Vector2 = Vector2(0, -300)
## Seconds `t` spans and the phase times inside it (see FxSerpent).
var life: float = 2.15
var form_at: float = 0.35
var rear_at: float = 0.95
var strike_at: float = 1.3
var impact_at: float = 1.48
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t
## True for the additive spirit-glow pass drawn under the body (a second node with the same timing).
var glow_only: bool = false: set = _set_glow_only


func _set_glow_only(v: bool) -> void:
	glow_only = v
	if v:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(4, 4)


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


func _span(s: float, a: float, b: float) -> float:
	return clampf((s - a) / maxf(b - a, 0.0001), 0.0, 1.0)


static func _smooth(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Body point `u` (0 = head, 1 = tail) of the coiled pose turned by `spin`: a helix seen from the side,
## wide at its base and rising to the head, so it reads as a serpent coiled upon itself.
func _coil(u: float, spin: float) -> Vector2:
	var ang := spin + u * 2.6 * TAU
	var r := radius * (0.35 + 0.55 * u)
	return Vector2(cos(ang) * r, sin(ang) * r * 0.3 - (1.0 - u) * radius * 0.95 + radius * 0.35)


## The reared head position: pulled back away from the target and raised.
func _rear_head() -> Vector2:
	var back := -target.normalized()
	return back * radius * 0.7 + Vector2(0, -radius * 1.25)


## Body point `u` of the reared pose: an S-curve from the coil base up to the drawn-back head.
func _rear(u: float) -> Vector2:
	var head := _rear_head()
	var base := Vector2(0, radius * 0.25)
	var p := head.lerp(base, u)
	var dir := (base - head).normalized()
	var n := Vector2(-dir.y, dir.x)
	return p + n * sin(u * TAU) * radius * 0.42 * (1.0 - 0.3 * u)


## Body point `u` of the strike with progress `k`: the head darts to the target along a bowed curve and
## the body streams behind it, its wave flattening as it stretches.
func _strike(u: float, k: float) -> Vector2:
	var head := _rear_head().lerp(target, k)
	var base := Vector2(0, radius * 0.25)
	var ctrl := (_rear_head() + base) * 0.5 + Vector2(0, -radius * 1.1) * (1.0 - k) + target * 0.25 * k
	var a := base.lerp(ctrl, 1.0 - u)
	var b := ctrl.lerp(head, 1.0 - u)
	var p := a.lerp(b, 1.0 - u)
	var dir := (head - base).normalized()
	var n := Vector2(-dir.y, dir.x)
	return p + n * sin(u * TAU * 1.5 + k * 4.0) * radius * 0.3 * (1.0 - k * 0.85) * (1.0 - u * 0.4)


## Body point `u` at time `s`, blending the three poses.
func body_point(u: float, s: float) -> Vector2:
	var spin := s * 3.2
	var p := _coil(u, spin)
	var w_rear := _smooth(_span(s, rear_at, strike_at))
	if w_rear > 0.0:
		p = p.lerp(_rear(u), w_rear)
	var k := pow(_span(s, strike_at, impact_at), 2.2)
	if k > 0.0:
		p = p.lerp(_strike(u, k), minf(1.0, k * 1.6))
	return p


func _draw() -> void:
	var s := t * life
	var grow := _smooth(_span(s, form_at, rear_at - 0.1))
	var fade := 1.0 - _span(s, impact_at, impact_at + 0.35)
	if grow <= 0.0:
		return
	var thick := radius * 0.19
	var pulse := 1.0 + 0.08 * sin(s * 18.0)
	if glow_only:
		_draw_glow(s, grow, fade, thick)
		return
	if fade > 0.0:
		var head_u := 1.0 - grow   # the body forms from the tail; the head leads the growing end
		# Halo pass first (soft glow under the whole body), then the body from the tail to the head.
		var pts: Array[Vector2] = []
		var rad: Array[float] = []
		for i in SEGMENTS:
			var u := lerpf(1.0, head_u, float(i) / float(SEGMENTS - 1))
			pts.append(body_point(u, s))
			var along := (u - head_u) / maxf(grow, 0.0001)   # 0 at the head, 1 at the tail
			rad.append(thick * (1.0 - 0.7 * along) * (0.85 + 0.15 * sin(along * 9.0)) * pulse)
		# Dorsal fins along the back (drawn first, so the body overlaps their roots).
		for i in range(5, SEGMENTS - 5, 7):
			var d := (pts[i + 1] - pts[i - 1]).normalized()
			var n := Vector2(-d.y, d.x)
			if n.y > 0.0:
				n = -n
			var r0: float = rad[i]
			var tip: Vector2 = pts[i] + n * r0 * 2.0 - d * r0 * 0.9
			draw_colored_polygon(PackedVector2Array([pts[i] - d * r0 * 0.8, tip, pts[i] + d * r0 * 0.7]), Color(col.lightened(0.25), 0.75 * fade))
			draw_polyline(PackedVector2Array([pts[i] - d * r0 * 0.8, tip, pts[i] + d * r0 * 0.7]), Color(rim, 0.8 * fade), 1.4, true)
		# Rim, then the body: round joints plus thick segments between them, so it reads as one continuous body.
		for i in SEGMENTS:
			draw_circle(pts[i], rad[i] * 1.14, Color(rim, 0.95 * fade), true, -1.0, true)
			if i > 0:
				draw_line(pts[i - 1], pts[i], Color(rim, 0.95 * fade), rad[i] * 2.28, true)
		for i in SEGMENTS:
			if i > 0:
				var kk := float(i) / float(SEGMENTS - 1)
				draw_line(pts[i - 1], pts[i], Color(rim.lerp(col, 0.45 + 0.55 * kk), fade), rad[i] * 2.0, true)
		for i in SEGMENTS:
			# deep at the tail, bright toward the head, with lighter scale bands
			var k := float(i) / float(SEGMENTS - 1)
			var shade := rim.lerp(col, 0.45 + 0.55 * k).lerp(Color(0.85, 0.98, 1.0), 0.18 * float(i % 6 == 0))
			draw_circle(pts[i], rad[i], Color(shade, fade), true, -1.0, true)
			draw_circle(pts[i] + Vector2(-0.25, -0.35) * rad[i], rad[i] * 0.4, Color(1, 1, 1, 0.16 * fade), true, -1.0, true)
			if i % 5 == 2 and i < SEGMENTS - 2:
				var d2 := (pts[i + 1] - pts[i]).normalized()
				draw_arc(pts[i], rad[i] * 0.8, d2.angle() + PI * 0.6, d2.angle() + PI * 1.4, 8, Color(rim.lightened(0.35), 0.6 * fade), 1.6, true)
		_head(pts[SEGMENTS - 1], (pts[SEGMENTS - 1] - pts[SEGMENTS - 3]).normalized(), rad[SEGMENTS - 1] * 1.55, fade, s)
	# Spray: the body bursts into droplets at the impact.
	var sp := _span(s, impact_at, life)
	if sp > 0.0 and sp < 1.0:
		for i in SPRAY:
			var u := FxBlast.rnd(i, 61.0)
			var o := body_point(u * 0.7, impact_at)
			var ang := FxBlast.rnd(i, 62.0) * TAU
			var v := Vector2(cos(ang), sin(ang)) * radius * (0.6 + 1.4 * FxBlast.rnd(i, 63.0))
			var p := o + v * (1.0 - pow(1.0 - sp, 2.0)) + Vector2(0, radius * 1.2 * sp * sp)
			draw_circle(p, (2.0 + 3.0 * FxBlast.rnd(i, 64.0)) * (1.0 - sp * 0.6), Color(col.lightened(0.4), (1.0 - sp) * 0.9), true, -1.0, true)


## The additive spirit glow: a soft aura along the body, motes orbiting it, and a bright wake on the strike.
func _draw_glow(s: float, grow: float, fade: float, thick: float) -> void:
	var head_u := 1.0 - grow
	if fade > 0.0:
		for i in 24:
			var u := lerpf(1.0, head_u, float(i) / 23.0)
			var p := body_point(u, s)
			draw_circle(p, thick * 2.8, Color(col, 0.025 * fade), true, -1.0, false)
			draw_circle(p, thick * 1.6, Color(col, 0.05 * fade), true, -1.0, false)
		for i in 30:
			var u := lerpf(1.0, head_u, FxBlast.rnd(i, 65.0))
			var p := body_point(u, s) + Vector2(cos(s * 6.0 + float(i)), sin(s * 5.0 + float(i) * 1.7)) * thick * (1.6 + FxBlast.rnd(i, 66.0))
			draw_circle(p, 1.5 + 2.0 * FxBlast.rnd(i, 67.0), Color(col.lightened(0.5), 0.8 * fade), true, -1.0, true)
	var k := _span(s, strike_at, impact_at)
	if k > 0.0 and fade > 0.0:
		for i in 12:
			var u := float(i) / 11.0 * 0.5
			var p := body_point(u, s)
			draw_circle(p, thick * (2.4 - 3.0 * u), Color(Color(0.9, 0.98, 1.0), 0.12 * k * fade), true, -1.0, true)


## The serpent head at `p` facing `dir`: a wedge skull with a crest, glowing eyes and an open jaw on the strike.
func _head(p: Vector2, dir: Vector2, h: float, a: float, s: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	var jaw := 0.35 * _span(s, strike_at, impact_at)
	var snout := p + dir * h * 1.5
	var skull := PackedVector2Array([p - dir * h * 0.6 + n * h * 0.75, p + dir * h * 0.5 + n * h * 0.6, snout + n * h * jaw,
		snout - n * h * jaw, p + dir * h * 0.5 - n * h * 0.6, p - dir * h * 0.6 - n * h * 0.75])
	draw_circle(p, h * 1.9, Color(col, 0.12 * a), true, -1.0, true)
	var rim_pts := PackedVector2Array()
	for q in skull:
		rim_pts.append(p + (q - p) * 1.12)
	draw_colored_polygon(rim_pts, Color(rim, 0.95 * a))
	draw_colored_polygon(skull, Color(col.lightened(0.1), a))
	# Crest fins sweeping back from the brow.
	for side in [-1.0, 1.0]:
		var root: Vector2 = p - dir * h * 0.2 + n * side * h * 0.55
		draw_colored_polygon(PackedVector2Array([root, root - dir * h * 1.3 + n * side * h * 0.9, root - dir * h * 0.6]), Color(col.lightened(0.35), 0.85 * a))
	# Swept-back horns.
	for side in [-1.0, 1.0]:
		var hr: Vector2 = p - dir * h * 0.1 + n * side * h * 0.35
		var tip: Vector2 = hr - dir * h * 1.15 + n * side * h * 0.35
		draw_colored_polygon(PackedVector2Array([hr - n * side * h * 0.1, tip, hr + n * side * h * 0.1 + dir * h * 0.12]), Color(col.lightened(0.55), 0.9 * a))
	# Golden eyes with a slit.
	for side in [-1.0, 1.0]:
		var e: Vector2 = p + dir * h * 0.35 + n * side * h * 0.38
		draw_circle(e, h * 0.4, Color(1.0, 0.85, 0.4, 0.3 * a), true, -1.0, true)
		draw_circle(e, h * 0.2, Color(1.0, 0.86, 0.35, a), true, -1.0, true)
		draw_line(e - dir * h * 0.12, e + dir * h * 0.12, Color(0.1, 0.05, 0.0, a), 1.6, true)
