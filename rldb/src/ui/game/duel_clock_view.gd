class_name DuelClockView
extends Control
## The duel clock in the turn panel (C2): a small inset bronze plaque with a gold hourglass, the
## game time in the display face and the current turn's time beneath it. It stops (dims) while the
## duel is paused and settles on the final time when the game is won. Reads a DuelClock; never sends
## anything.
##
## L18 (owner feedback 2026-11-05): the hourglass is a physical glass (DuelClock.Glass). Sand runs from
## the top bulb into the bottom one over a minute of running time, as a thin stream with falling grains
## onto a mound; the top drains with a small funnel. When the top runs dry (and at a new turn if the top
## holds under half) the glass turns over with an eased half turn and a quiet "hourglass_flip": the full
## bottom bulb swings up and drains again. The sand is drawn in screen space, so while the glass turns
## it stays level and slides inside the tilting bulbs. Reduced motion: the glass turns over at once
## (no rotation, no grains, no sound).

const W := 128.0
const H := 46.0
## The turn time warms from muted to amber after this long (a gentle nudge, not a timer limit).
const LONG_TURN_MS := 120000
## The running sand is redrawn in steps this long (ms); the change between two steps is a small
## fraction of a pixel.
const SAND_STEP_MS := 250
## The falling grains move on in steps this long (ms of running time: a stopped clock stays still).
const GRAIN_STEP_MS := 100
## Hourglass geometry (px, glass frame): half width, half height (to the caps' centre lines), the
## neck's half width, and the share of a bulb the whole sand fills.
const HG_HW := 7.2
const HG_HH := 13.0
const HG_NECK := 0.8
const SAND_FILL := 0.8
## The flip's sound, quiet: it is a small ornament.
const FLIP_SFX := "hourglass_flip"
const FLIP_DB := -14.0
const SAND := Color("f3d58a")
const SAND_DEEP := Color("c08a3a")

## The clock shown (null hides the plaque).
var clock: DuelClock = null
var _shown := ""


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Game time, and the time of the current turn"


## Shows `c` (null hides the plaque).
func set_clock(c: DuelClock) -> void:
	clock = c
	visible = c != null
	_shown = ""
	queue_redraw()


## The two texts drawn: [game "m:ss", turn "m:ss"] (tests read them).
func texts() -> Array:
	if clock == null:
		return ["", ""]
	return [PlayerStats.clock(clock.game_ms()), PlayerStats.clock(clock.turn_ms())]


func _process(delta: float) -> void:
	if clock == null or not is_visible_in_tree():
		return
	var g := clock.glass
	if g.advance(clock.game_ms(), clock.turn, delta, UIStyle.reduce_motion) and not UIStyle.reduce_motion:
		Sfx.play(FLIP_SFX, FLIP_DB, 0.03)
	if g.turning():
		queue_redraw()   # the glass turns: every frame
		_shown = ""
		return
	var t := texts()
	var sig := "%s|%s|%s" % [t[0], t[1], clock.stopped()]
	# The sand falls ~10 px a minute: a redraw every SAND_STEP_MS looks the same as every frame
	# (H7, 21 Oct: the plaque no longer redraws on every idle frame); the grains step on running time.
	sig += "|%d" % (clock.game_ms() / SAND_STEP_MS)
	if _streaming() and not UIStyle.reduce_motion:
		sig += "|%d" % (clock.game_ms() / GRAIN_STEP_MS)
	if sig != _shown:
		_shown = sig
		queue_redraw()


func _draw() -> void:
	if clock == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	# Inset plaque: dark well, bronze rim, a faint gold top light.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.045, 0.035, 0.96)
	sb.border_color = Color(UIStyle.BRONZE, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 1)
	draw_style_box(sb, r)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.border_color = Color(UIStyle.GOLD, 0.16)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(5)
	draw_style_box(inner, r.grow(-3))
	var gl := StyleBoxFlat.new()
	gl.bg_color = Color(UIStyle.GOLD_HI, 0.05)
	gl.corner_radius_top_left = 6
	gl.corner_radius_top_right = 6
	draw_style_box(gl, Rect2(Vector2(2, 2), Vector2(size.x - 4, size.y * 0.42)))
	var dim := 0.55 if clock.stopped() and clock.frozen_at == -1 else 1.0
	_draw_hourglass(Vector2(20, size.y / 2.0), dim)
	# Divider between glass and numbers.
	draw_line(Vector2(37, 9), Vector2(37, size.y - 9), Color(UIStyle.BRONZE, 0.55), 1.0)
	var t := texts()
	var big := UIStyle.font_display(700)
	var small := UIStyle.font_bold()
	var x := 45.0
	var right := size.x - 10.0
	var gw := big.get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var gpos := Vector2(right - gw, 23)
	draw_string(big, gpos + Vector2(0, 1.5), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0, 0, 0, 0.6))
	draw_string(big, gpos, t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(UIStyle.GOLD_HI, dim))
	var long_turn := clock.turn_ms() >= LONG_TURN_MS
	var tc := Color("e9a14a") if long_turn else UIStyle.TEXT_DIM
	var cap := "TURN"
	draw_string(small, Vector2(x, 38), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UIStyle.BRONZE.lightened(0.35), dim))
	var tw := small.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(small, Vector2(right - tw, 39), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tc, dim))


## True while sand runs through the neck: upright, running and some sand still on top.
func _streaming() -> bool:
	return clock != null and not clock.stopped() and not clock.glass.turning() and clock.glass.top > 0.0005


## The upper bulb's outline in the glass frame (the lower bulb is its mirror image): a rounded bulb from
## the cap down to the narrow neck.
static func bulb_outline(upper: bool) -> PackedVector2Array:
	var n := 9
	var y0 := -(HG_HH - 1.6)
	var y1 := -0.55
	var left := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		var w := HG_NECK + (HG_HW - HG_NECK) * pow(cos(t * PI / 2.0), 0.75)
		left.append(Vector2(-w, lerpf(y0, y1, t)))
	var out := PackedVector2Array(left)
	for i in range(left.size() - 1, -1, -1):
		out.append(Vector2(-left[i].x, left[i].y))
	if not upper:
		for i in out.size():
			out[i].y = -out[i].y
	return out


## Area of a simple polygon.
static func poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5


## The sand in `bulb` (a polygon in screen space) holding `share` of the bulb's area, settled under
## gravity: the bulb cut below a level surface found by bisection. `shape` bends the surface: > 0 heaps
## a mound up in the middle (the bottom bulb), < 0 sinks a funnel (a draining top), both `shape` px
## deep at the centre `cx`. Returns the sand polygons ([] when empty).
static func settle(bulb: PackedVector2Array, share: float, shape: float = 0.0, cx: float = 0.0) -> Array:
	if share <= 0.001:
		return []
	var target := poly_area(bulb) * clampf(share, 0.0, 1.0)
	var lo := INF
	var hi := -INF
	var x0 := INF
	var x1 := -INF
	for p in bulb:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
	lo -= absf(shape) + 1.0
	var bottom := hi + 20.0
	var best: Array = []
	for i in 18:
		var lv := (lo + hi) * 0.5
		var parts := Geometry2D.intersect_polygons(bulb, _below(lv, shape, cx, x0 - 5.0, x1 + 5.0, bottom))
		var a := 0.0
		for q in parts:
			a += poly_area(q)
		if a > target:
			lo = lv        # too much sand under this level: the surface is lower (larger y)
		else:
			hi = lv
			best = parts
	return best


## The region below a surface at height `lv` (screen y grows downwards) between `x0` and `x1`, down to
## `bottom`, shaped as in settle().
static func _below(lv: float, shape: float, cx: float, x0: float, x1: float, bottom: float) -> PackedVector2Array:
	if shape == 0.0:
		return PackedVector2Array([Vector2(x0, lv), Vector2(x1, lv), Vector2(x1, bottom), Vector2(x0, bottom)])
	var span := 5.5
	return PackedVector2Array([Vector2(x0, lv), Vector2(cx - span, lv), Vector2(cx, lv - shape), Vector2(cx + span, lv),
		Vector2(x1, lv), Vector2(x1, bottom), Vector2(x0, bottom)])


## A gold-framed hourglass: glass bulbs with the sand settled in them, the stream through the neck,
## and the end caps on their posts, turned by the glass's angle about `c`.
func _draw_hourglass(c: Vector2, dim: float) -> void:
	var g := clock.glass
	var rot := g.angle()
	var gold := Color(UIStyle.GOLD, dim)
	var xf := Transform2D(rot, c)
	var upper := xf * bulb_outline(true)
	var lower := xf * bulb_outline(false)
	# Glass: a faint cool body behind the sand.
	draw_colored_polygon(upper, Color(0.75, 0.82, 0.9, 0.1 * dim))
	draw_colored_polygon(lower, Color(0.75, 0.82, 0.9, 0.1 * dim))
	# Sand, settled in screen space. The upper bulb (glass frame) holds `top`, the lower one the rest.
	var upright := not g.turning()
	var flowing := upright and _streaming()
	var top_parts := settle(upper, g.top * SAND_FILL, -1.6 if flowing else 0.0, c.x)
	var bottom_parts := settle(lower, (1.0 - g.top) * SAND_FILL, 1.8 if upright else 0.0, c.x)
	for parts in [top_parts, bottom_parts]:
		for q in parts:
			_draw_sand(q, dim)
	if flowing:
		_draw_stream(c, bottom_parts, dim)
	# Glass: a highlight down each bulb's lit side and the gold outline.
	for up in [true, false]:
		var b := bulb_outline(up)
		var hl := PackedVector2Array()
		for i in range(2, 7):
			hl.append(xf * (b[i] * Vector2(0.62, 1.0) + Vector2(0.3, 0.0)))
		draw_polyline(hl, Color(1, 1, 1, 0.22 * dim), 0.9, true)
	var rim := Color(gold, 0.85)
	var ou := bulb_outline(true)
	var ol := bulb_outline(false)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var half := ou.size() / 2
	for i in half:
		left.append(xf * ou[i])
	for i in range(half - 1, -1, -1):
		left.append(xf * ol[i])
	for i in range(ou.size() - 1, half - 1, -1):
		right.append(xf * ou[i])
	for i in range(half, ol.size()):
		right.append(xf * ol[i])
	draw_polyline(left, rim, 1.1, true)
	draw_polyline(right, rim, 1.1, true)
	# Gilded end caps (a bevelled bar with a lit edge) and the turned posts between them.
	for s in [-1.0, 1.0]:
		var cap := PackedVector2Array([Vector2(-HG_HW - 2.6, s * HG_HH - 1.6), Vector2(HG_HW + 2.6, s * HG_HH - 1.6),
			Vector2(HG_HW + 2.6, s * HG_HH + 1.6), Vector2(-HG_HW - 2.6, s * HG_HH + 1.6)])
		draw_colored_polygon(xf * cap, gold)
		draw_polyline(xf * PackedVector2Array([cap[0], cap[1]]), Color(UIStyle.GOLD_HI, 0.8 * dim), 0.8, true)
		draw_polyline(xf * PackedVector2Array([cap[3], cap[2]]), Color(0.35, 0.22, 0.08, 0.7 * dim), 0.8, true)
	for sx in [-1.0, 1.0]:
		draw_line(xf * Vector2(sx * (HG_HW + 1.6), -HG_HH + 1.5), xf * Vector2(sx * (HG_HW + 1.6), HG_HH - 1.5), Color(gold, 0.7), 1.2, true)


## One settled sand polygon, lighter at its surface and deeper below.
func _draw_sand(q: PackedVector2Array, dim: float) -> void:
	var y0 := INF
	var y1 := -INF
	for p in q:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p in q:
		var t := clampf((p.y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)
		cols.append(Color(SAND.lerp(SAND_DEEP, t * 0.75), 0.95 * dim))
	draw_polygon(q, cols)


## The thin stream from the neck to the top of the heap below, with a few grains falling down it.
func _draw_stream(c: Vector2, bottom_parts: Array, dim: float) -> void:
	var floor_y := c.y + HG_HH - 1.6
	for q in bottom_parts:
		for p in q:
			if absf(p.x - c.x) < 1.2:
				floor_y = minf(floor_y, p.y)
	var a := c + Vector2(0, 0.4)
	draw_line(a, Vector2(c.x, floor_y), Color(SAND, 0.75 * dim), 0.9, true)
	if UIStyle.reduce_motion:
		return
	var ph := float(clock.game_ms() / GRAIN_STEP_MS) * 0.27
	for i in 3:
		var k := fmod(ph + float(i) / 3.0, 1.0)
		var gp := a.lerp(Vector2(c.x, floor_y), k)
		draw_circle(gp + Vector2(0.45 if i == 1 else -0.35, 0.0), 0.55, Color(1.0, 0.93, 0.7, 0.9 * dim), true, -1.0, true)
