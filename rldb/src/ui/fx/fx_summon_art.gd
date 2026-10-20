class_name FxSummonArt
extends Control
## The drawn magic of the special-summon set pieces (D8, owner feedback 2026-10-20), centred on the node
## position and driven by one progress value `t` (0 -> 1 over `life` seconds), so a single tween plays it
## and a redraw at any `t` is stable (no per-frame state, no frame-dependent timing):
##   fusion: a vortex of spiral particle arms winding faster and tighter into a white-hot core that
##           implodes at the climax, then dissolving spiral remnants;
##   ritual: a rune circle that inscribes itself (outer ring, inner ring, a seven-point star), rune glyphs
##           lit one by one by the runes drawn out of the tributed units, then a pillar of light;
##   arcane: spectral shards rising from the spent materials and assembling into a turning crystalline
##           lattice (hexagon, hexagram, a rotating cube), which bursts into flying shards at the climax.
## Every kind also draws a gathering charge: streaks converging on the centre during the anticipation.
## Additively blended, click-through; FxSummon creates, tweens and frees it.

## Which set piece: "fusion" | "ritual" | "arcane".
var kind: String = "fusion"
## The kind's two set-piece colours (FxSummon.PALETTE): the main hue and its accent.
var col: Color = Color.WHITE
var col2: Color = Color.WHITE
## Reach of the circle / vortex / lattice in pixels.
var radius: float = 140.0
## Seconds `t` spans (the set piece length), and the climax time within it.
var life: float = 1.7
var climax: float = 0.8
## Where the materials come from, relative to the node position (rune and shard origins).
var sources: PackedVector2Array = PackedVector2Array()
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t

## Particles in the fusion vortex, shards per arcane material, glyphs on the ritual ring.
const VORTEX_ARMS := 4
const VORTEX_PER_ARM := 26
const SHARDS_PER_SOURCE := 7
const BURST_SHARDS := 30
const RUNE_GLYPHS := 12
const CHARGE_STREAKS := 22


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(4, 4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


## Seconds since the start for the current `t`.
func sec() -> float:
	return t * life


static func _out(x: float, p: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)


static func _in(x: float, p: float = 2.0) -> float:
	return pow(clampf(x, 0.0, 1.0), p)


## 0 -> 1 across [a, b] seconds, clamped.
func _span(s: float, a: float, b: float) -> float:
	return clampf((s - a) / maxf(b - a, 0.0001), 0.0, 1.0)


func _draw() -> void:
	var s := sec()
	_draw_charge(s)
	match kind:
		"fusion": _draw_fusion(s)
		"ritual": _draw_ritual(s)
		"arcane": _draw_arcane(s)


# ---------------------------------------------------------------- shared

## Gathering charge: thin streaks falling inward from far out, faster and denser toward the climax.
func _draw_charge(s: float) -> void:
	var a := _span(s, 0.0, 0.2) * (1.0 - _span(s, climax - 0.05, climax + 0.05))
	if a <= 0.0:
		return
	for i in CHARGE_STREAKS:
		var birth := FxBlast.rnd(i, 21.0) * (climax - 0.3)
		var u := _span(s, birth, birth + 0.36)
		if u <= 0.0 or u >= 1.0:
			continue
		var ang := FxBlast.rnd(i, 22.0) * TAU
		var d := Vector2(cos(ang), sin(ang) * 0.75)
		var r0 := radius * (1.45 + 0.5 * FxBlast.rnd(i, 23.0)) * (1.0 - _in(u, 1.5))
		var r1 := r0 + radius * 0.22 * (1.0 - u)
		var c := col.lerp(col2, FxBlast.rnd(i, 24.0))
		var al := a * sin(u * PI)
		draw_line(d * r0, d * r1, Color(c, al * 0.4), 5.0 * (1.0 - 0.5 * u), true)
		draw_line(d * r0, d * r1, Color(c.lightened(0.2), al * 0.8), 1.8, true)
		_glow(d * r0, 9.0, c, al * 0.9)


## A glowing line: a wide faint pass, a mid pass and a bright core.
func _gline(a: Vector2, b: Vector2, c: Color, al: float, w: float) -> void:
	if al <= 0.001:
		return
	draw_line(a, b, Color(c, al * 0.18), w * 4.0, true)
	draw_line(a, b, Color(c, al * 0.45), w * 2.0, true)
	draw_line(a, b, Color(c.lightened(0.3), al), w, true)


## A glowing arc (same passes as _gline).
func _garc(r: float, a0: float, a1: float, c: Color, al: float, w: float, seg: int = 96) -> void:
	if al <= 0.001:
		return
	draw_arc(Vector2.ZERO, r, a0, a1, seg, Color(c, al * 0.18), w * 4.0, true)
	draw_arc(Vector2.ZERO, r, a0, a1, seg, Color(c, al * 0.45), w * 2.0, true)
	draw_arc(Vector2.ZERO, r, a0, a1, seg, Color(c.lightened(0.45), al), w, true)


## A soft additive disc stack (glow) of `r` at `p`.
func _glow(p: Vector2, r: float, c: Color, a: float) -> void:
	if a <= 0.001 or r <= 0.5:
		return
	# Four stacked discs; soft glows need no anti-aliasing (the cheaper, non-AA path).
	for i in 4:
		var u := float(i) / 3.0
		draw_circle(p, r * (1.0 - 0.8 * u), Color(c, a * 0.2), true, -1.0, false)


# ---------------------------------------------------------------- fusion: the vortex

func _draw_fusion(s: float) -> void:
	var grow := _out(_span(s, 0.0, 0.35), 2.0)
	var pre := _span(s, 0.0, climax)
	var post := _span(s, climax, life)
	var fade := 1.0 - _out(post, 1.5)
	# Spin accelerates (angle ~ s^2) and the arms tighten as the materials are pulled in.
	var spin := 2.0 * s + 7.0 * s * s
	var tight := 1.0 - 0.55 * _in(pre, 1.4) + 0.9 * _out(post, 2.0)
	# A soft disc of the main hue under the arms: the eye of the vortex.
	_glow(Vector2.ZERO, radius * 1.15 * tight * grow, col, 0.45 * fade * grow)
	for arm in VORTEX_ARMS:
		for i in VORTEX_PER_ARM:
			var u := float(i) / float(VORTEX_PER_ARM - 1)
			var r := radius * (0.1 + 0.95 * u) * tight * grow
			var ang := float(arm) * TAU / float(VORTEX_ARMS) + u * 3.6 - spin
			var p := Vector2(cos(ang), sin(ang) * 0.62) * r
			var a := fade * (1.0 - 0.45 * u) * grow
			var c := col2.lerp(col, u)
			if i % 2 == 0:   # every other particle carries the glow (half the draw calls, same look)
				_glow(p, 26.0 * (1.0 - 0.6 * u) + 8.0, c, a * 0.85)
			draw_circle(p, (6.0 - 3.0 * u) * (0.6 + 0.4 * grow) + 0.8, Color(c.lightened(0.35 * (1.0 - u)), a), true, -1.0, true)
			# a short tail behind each particle along the spin
			var q := Vector2(cos(ang + 0.16), sin(ang + 0.16) * 0.62) * r
			draw_line(p, q, Color(c, a * 0.6), (4.0 - 2.0 * u), true)
	# Counter-turning dashed rings framing the vortex.
	for k in 2:
		var rr := radius * (1.05 + 0.22 * float(k)) * tight * grow
		var dash := 10 + 4 * k
		for j in dash:
			var a0 := float(j) * TAU / float(dash) + (spin * 0.4 if k == 0 else -spin * 0.3)
			draw_arc(Vector2.ZERO, rr, a0, a0 + TAU / float(dash) * 0.55, 8, Color((col if k == 0 else col2).lightened(0.25), 0.7 * fade * grow), 3.0 - float(k), true)
	# White-hot core: swells through the anticipation, implodes just before the climax.
	var swell := _in(pre, 1.7) * (1.0 - _span(s, climax - 0.08, climax))
	_glow(Vector2.ZERO, radius * 0.5 * swell + 6.0, col2.lightened(0.2), 0.9 * swell + 0.1 * grow * fade)
	draw_circle(Vector2.ZERO, radius * 0.1 * swell, Color(1, 1, 1, 0.85 * swell), true, -1.0, true)


# ---------------------------------------------------------------- ritual: the rune circle and the pillar

## Point `i` of a regular star polygon {7/3} on radius `r`, turned by `rot`.
static func _star_pt(i: int, r: float, rot: float) -> Vector2:
	var a := rot - PI / 2.0 + float((i * 3) % 7) * TAU / 7.0
	return Vector2(cos(a), sin(a)) * r


## One procedural rune glyph (2-4 strokes, fixed per index) of half-size `h` at `p`, turned by `ang`.
func _glyph(p: Vector2, h: float, ang: float, idx: int, c: Color, w: float) -> void:
	var xf := Transform2D(ang, p)
	var strokes := 2 + int(FxBlast.rnd(idx, 31.0) * 2.99)
	draw_line(xf * Vector2(0, -h), xf * Vector2(0, h), c, w, true)   # every rune has a stave
	for k in strokes:
		var y0 := (FxBlast.rnd(idx * 7 + k, 32.0) - 0.5) * 1.6 * h
		var y1 := y0 + (FxBlast.rnd(idx * 7 + k, 33.0) - 0.5) * 1.4 * h
		var side := 1.0 if FxBlast.rnd(idx * 7 + k, 34.0) > 0.5 else -1.0
		draw_line(xf * Vector2(0, y0), xf * Vector2(side * h * 0.75, y1), c, w, true)


func _draw_ritual(s: float) -> void:
	var post := _span(s, climax, life)
	var fade := 1.0 - _out(_span(s, climax + 0.25, life), 1.6)
	var flare := sin(clampf(post * 3.0, 0.0, 1.0) * PI)   # the circle flares as the pillar strikes
	var rot := s * 0.35
	var line_a := (0.85 + 0.15 * flare) * fade
	# Ground glow under the circle (an ellipse: the circle lies on the table).
	var ground := _span(s, 0.05, 0.45) * fade
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	_glow(Vector2.ZERO, radius * 1.1, col, 0.55 * ground + 0.5 * flare * fade)
	# Outer ring inscribing itself clockwise from the top, with a bright pen spark at its tip.
	var k_out := _out(_span(s, 0.0, 0.5), 2.0)
	if k_out > 0.0:
		_garc(radius, -PI / 2.0, -PI / 2.0 + TAU * k_out, col, line_a, 2.6 + 1.5 * flare)
		_garc(radius * 0.93, -PI / 2.0, -PI / 2.0 + TAU * k_out, col2, line_a * 0.7, 1.3)
		if k_out < 1.0:
			var tip := Vector2(cos(-PI / 2.0 + TAU * k_out), sin(-PI / 2.0 + TAU * k_out)) * radius
			_glow(tip, 30.0, col2, 1.0)
			draw_circle(tip, 4.0, Color(1, 1, 0.92), true, -1.0, true)
	# Inner ring (counter-clockwise) and the seven-point star, drawn line by line.
	var k_in := _out(_span(s, 0.18, 0.6), 2.0)
	if k_in > 0.0:
		_garc(radius * 0.62, -PI / 2.0, -PI / 2.0 - TAU * k_in, col, line_a, 2.0, 72)
	var k_star := _span(s, 0.3, 0.78)
	for i in 7:
		var u := clampf(k_star * 7.0 - float(i), 0.0, 1.0)
		if u <= 0.0:
			break
		var a := _star_pt(i, radius * 0.62, rot)
		var b := _star_pt(i + 1, radius * 0.62, rot)
		_gline(a, a.lerp(b, u), col, line_a, 1.6 + flare)
	# Rune glyphs in the band between the rings, each lit when its drawn-out rune arrives.
	for g in RUNE_GLYPHS:
		var ang := rot + float(g) * TAU / float(RUNE_GLYPHS) - PI / 2.0
		var p := Vector2(cos(ang), sin(ang)) * radius * 0.8
		var lit := _span(s, 0.32 + 0.035 * float(g), 0.42 + 0.035 * float(g))
		if lit > 0.0:
			_glow(p, radius * 0.11, col2, 0.4 * lit * fade * (1.0 - 0.6 * post) + 0.4 * flare * fade)
			_glyph(p, radius * 0.07, ang + PI / 2.0, g, Color(col2.lightened(0.3), lit * fade), 2.0 + flare)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The runes drawn out of the tributed units: motes arcing from each source into the glyph band.
	for si in sources.size():
		for g in RUNE_GLYPHS / maxi(sources.size(), 1) + 1:
			var gi := (si * 5 + g) % RUNE_GLYPHS
			var start := 0.12 + 0.035 * float(gi)
			var u := _span(s, start, start + 0.3)
			if u <= 0.0 or u >= 1.0:
				continue
			var ang := rot + float(gi) * TAU / float(RUNE_GLYPHS) - PI / 2.0
			var dst := Vector2(cos(ang), sin(ang) * 0.55) * radius * 0.8
			var src := sources[si]
			var mid := src.lerp(dst, 0.5) + Vector2(0, -radius * 0.7)
			var e := _out(u, 2.0)
			var p := src.lerp(mid, e).lerp(mid.lerp(dst, e), e)
			_glow(p, 22.0, col2, 0.8)
			_glyph(p, 8.0, u * 4.0, gi, Color(1, 0.95, 0.8, 0.95), 1.8)
	# The pillar of light striking down through the circle at the climax.
	var beam := sin(clampf(post * 1.6, 0.0, 1.0) * PI) if post > 0.0 else 0.0
	var pre_beam := _in(_span(s, climax - 0.12, climax), 2.0)
	var bw := radius * (0.18 * pre_beam + 0.62 * beam)
	if bw > 0.5:
		var top := -radius * 9.0
		_beam(top, bw * 1.6, col, 0.35 * maxf(beam, pre_beam * 0.4))
		_beam(top, bw, col2, 0.6 * maxf(beam, pre_beam * 0.4))
		_beam(top, bw * 0.34, Color(1, 0.98, 0.9), 0.9 * maxf(beam, pre_beam * 0.5))
		# motes streaming up the beam
		for i in 18:
			var u := fposmod(FxBlast.rnd(i, 35.0) + post * (1.2 + FxBlast.rnd(i, 36.0)), 1.0)
			var mp := Vector2((FxBlast.rnd(i, 37.0) - 0.5) * bw * 1.4, -u * radius * 4.0)
			draw_circle(mp, 2.0 + 2.0 * FxBlast.rnd(i, 38.0), Color(col2.lightened(0.4), beam * (1.0 - u)), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		_glow(Vector2.ZERO, bw * 2.6, col2, 0.9 * beam)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A vertical soft beam from `top` down to the centre: bright on its axis, fading to nothing at both edges.
func _beam(top: float, w: float, c: Color, a: float) -> void:
	var hot := Color(c, a)
	var none := Color(c, 0.0)
	var foot := w * 0.4
	draw_polygon(PackedVector2Array([Vector2(-w, top), Vector2(0, top), Vector2(0, foot), Vector2(-w * 0.8, foot)]),
		PackedColorArray([none, hot, hot, none]))
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w * 0.8, foot), Vector2(0, foot)]),
		PackedColorArray([hot, none, none, hot]))


# ---------------------------------------------------------------- arcane: shards and the crystal lattice

## Vertex `i` of the lattice the shards assemble into (hexagon then hexagram points), turned by `rot`.
func _lattice_pt(i: int, rot: float) -> Vector2:
	var ring := i % 2
	var a := rot + float(i / 2) * TAU / 6.0 + (PI / 6.0 if ring == 1 else 0.0) - PI / 2.0
	return Vector2(cos(a), sin(a)) * radius * (0.95 if ring == 0 else 0.55)


## A thin spectral shard (triangle) of length `l` at `p`, pointing along `ang`.
func _shard(p: Vector2, ang: float, l: float, c: Color, a: float) -> void:
	if a <= 0.001:
		return
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array([p + d * l, p + n * l * 0.28 - d * l * 0.3, p - n * l * 0.28 - d * l * 0.3])
	draw_circle(p, l * 0.9, Color(c, a * 0.08), true, -1.0, true)
	draw_colored_polygon(pts, Color(c, a * 0.5))
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], p]), Color(c2_of(c), a * 0.35))
	pts.append(pts[0])
	draw_polyline(pts, Color(c.lightened(0.55), a), 1.5, true)


## A paler facet tone of `c` (one side of a shard catches the light).
static func c2_of(c: Color) -> Color:
	return c.lightened(0.55)


func _draw_arcane(s: float) -> void:
	var post := _span(s, climax, life)
	var rot := s * 1.1
	var assemble := _span(s, 0.35, climax - 0.05)
	var lattice_a := _out(_span(s, 0.4, climax), 2.0) * (1.0 - _span(s, climax, climax + 0.35))
	var n_v := 12
	# Shards: rise from each spent material, hang, then fly to the lattice vertices and lock in place.
	if post <= 0.0:
		for si in sources.size():
			for k in SHARDS_PER_SOURCE:
				var idx := si * SHARDS_PER_SOURCE + k
				var rise := _out(_span(s, 0.15 + 0.02 * float(k), 0.4 + 0.02 * float(k)), 2.0)
				if rise <= 0.0:
					continue
				var src := sources[si] + Vector2((FxBlast.rnd(idx, 41.0) - 0.5) * 60.0, -rise * (40.0 + 50.0 * FxBlast.rnd(idx, 42.0)))
				var dst := _lattice_pt(idx % n_v, rot)
				var u := _in(_span(s, 0.38 + 0.025 * float(k), climax - 0.08), 1.8)
				var p := src.lerp(dst, u)
				var ang := FxBlast.rnd(idx, 43.0) * TAU + s * (3.0 + 4.0 * FxBlast.rnd(idx, 44.0)) * (1.0 - u) + u * (p.angle() + PI)
				_glow(p, 18.0, col, 0.45 * rise)
				_shard(p, ang, 16.0 + 10.0 * FxBlast.rnd(idx, 45.0), col, 0.95 * rise)
	# The lattice: hexagon, hexagram and a rotating wire cube, brightening as the shards lock in.
	if lattice_a > 0.0:
		var la := lattice_a * (0.45 + 0.55 * assemble)
		var lc := Color(col.lightened(0.5), la)
		_glow(Vector2.ZERO, radius * 1.05, col, 0.35 * la)
		# Facets: alternating translucent triangles between the outer and inner rings (a cut gem from above).
		for i in 6:
			var o0 := _lattice_pt(i * 2, rot)
			var o1 := _lattice_pt(((i + 1) % 6) * 2, rot)
			var inn := _lattice_pt(i * 2 + 1, rot)
			draw_colored_polygon(PackedVector2Array([o0, o1, inn]), Color(col if i % 2 == 0 else col2, la * (0.26 if i % 2 == 0 else 0.14)))
			draw_colored_polygon(PackedVector2Array([inn, o1, Vector2.ZERO]), Color(col, la * (0.12 if i % 2 == 0 else 0.2)))
		for i in 6:
			_gline(_lattice_pt(i * 2, rot), _lattice_pt(((i + 1) % 6) * 2, rot), col, la, 1.4)
			_gline(_lattice_pt(i * 2, rot), _lattice_pt(i * 2 + 1, rot), col2, la * 0.6, 0.9)
			_gline(_lattice_pt(i * 2 + 1, rot), _lattice_pt(((i + 2) % 6) * 2 + 1, rot), col, la * 0.75, 1.0)
		_cube(radius * 0.42, s * 1.7, Color(col.lightened(0.2), la * 0.8))
		for i in n_v:
			var p := _lattice_pt(i, rot)
			var sz := 4.0 + 4.0 * assemble
			_glow(p, sz * 3.0, col2, 0.5 * la)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz), p + Vector2(sz * 0.7, 0), p + Vector2(0, sz), p + Vector2(-sz * 0.7, 0)]), Color(col2.lightened(0.3), la))
		_glow(Vector2.ZERO, radius * 0.5 * assemble, col2, 0.6 * lattice_a * assemble)
	# The crystalline burst: the lattice shatters outward into spinning shards.
	if post > 0.0:
		var a := 1.0 - _in(post, 1.3)
		for i in BURST_SHARDS:
			var ang := float(i) * TAU / float(BURST_SHARDS) + FxBlast.rnd(i, 46.0) * 0.4
			var sp := 0.6 + 0.8 * FxBlast.rnd(i, 47.0)
			var d := Vector2(cos(ang), sin(ang) * 0.8)
			var p := d * radius * (0.5 + 1.35 * _out(post * sp, 2.4))
			_shard(p, ang + post * (6.0 + 6.0 * FxBlast.rnd(i, 48.0)), 16.0 + 14.0 * FxBlast.rnd(i, 49.0), col if i % 3 else col2, a)
		# Hexagonal shockwaves: the lattice's shape thrown outward twice.
		for k in 2:
			var ring := _out(clampf(post * 1.4 - 0.15 * float(k), 0.0, 1.0), 2.5)
			if ring > 0.0 and ring < 1.0:
				var hp := PackedVector2Array()
				for i in 7:
					var ha := rot + float(i % 6) * TAU / 6.0 - PI / 2.0
					hp.append(Vector2(cos(ha), sin(ha) * 0.85) * radius * (0.7 + 1.7 * ring))
				for i in 6:
					_gline(hp[i], hp[i + 1], col if k == 0 else col2, 0.85 * (1.0 - ring), 2.5 * (1.0 - ring) + 1.0)


## A wire cube of half-size `h` turning about two axes by `a`, in perspective-free projection.
func _cube(h: float, a: float, c: Color) -> void:
	var v: Array[Vector2] = []
	for i in 8:
		var p := Vector3(-1.0 if i & 1 == 0 else 1.0, -1.0 if i & 2 == 0 else 1.0, -1.0 if i & 4 == 0 else 1.0) * h
		var y := p.y * cos(a) - p.z * sin(a)
		var z := p.y * sin(a) + p.z * cos(a)
		var x := p.x * cos(a * 0.7) + z * sin(a * 0.7)
		v.append(Vector2(x, y))
	for e in [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]]:
		draw_line(v[e[0]], v[e[1]], Color(c, c.a * 0.7), 1.3, true)
