class_name CardOverlays
extends RefCounted
## State overlays drawn in widget space around the drawn card rect (painter.cr), after the face:
## FX flash / glow, the "can act now" ready glow and badge, hover glow, selection brackets, the
## pulsing target ring and the ordered multi-select badge. Badges are drawn last so combined
## states stay legible.

## Period (ms) of the breathing selection brackets and of the pulsing target ring.
const SELECT_PERIOD_MS := 1600.0
const TARGET_PERIOD_MS := 900.0
## F03-21: period (ms) of the available-action glow pulse and of the chevron bounce.
const READY_PERIOD_MS := 1900.0
const BOUNCE_PERIOD_MS := 1100.0
## Height (base px) the chevron badge rises on each bounce (ready_bounce(); the badge itself no longer
## bounces, #25) and the badge radius (base px).
const BOUNCE_PX := 3.5
const BADGE_R := 9.0
const BADGE_RIM := Color(1.0, 0.97, 0.86)
const BADGE_SHADOW_READY := Color(0.09, 0.06, 0.02, 0.95)
const BADGE_SHADOW_ORDER := Color(0.04, 0.03, 0.03, 0.95)
const CHEVRON := Color(0.17, 0.10, 0.02)


## Draws every active overlay of `w` (whose state the painter snapshot was taken from).
static func draw(pt: CardPainter, w: CardWidget) -> void:
	var s := pt.s
	var rect := pt.cr
	var rad := (8.0 if pt.size_kind in CardWidget.BIG_KINDS else 6.0) * s
	if w.fx_flash > 0.001:
		pt.round_rect(rect, Color(1, 1, 1, clampf(w.fx_flash, 0.0, 1.0) * 0.75), rad)
	var glow := w.fx_glow
	if glow.a > 0.001:
		pt.round_rect(rect, Color(glow, glow.a * 0.28), rad)
		pt.ring(Color(glow, glow.a), 3.0 * s, rect, rad)
		pt.ring(Color(glow, glow.a * 0.35), 3.0 * s, rect.grow(2.5 * s), rad + 2.0 * s)
	var ready := w.is_ready_on()
	# An empty zone draws its own pick highlight and hover (CardLayouts.draw_empty, #28).
	var empty := w.view.is_empty()
	if ready:
		# Steady warm-yellow glow OUTSIDE the card (its own frame colour stays visible) plus the chevron
		# badge. TARGET differs by behaviour: it pulses and fills/rings the card itself.
		_ready_glow(pt, rect, rad, ready_pulse())
	if pt.hover and not empty:
		# Soft ivory glow entirely OUTSIDE the card, no ring on it: the kind-coloured frame stays visible.
		_outer_glow(pt, rect, rad, UIStyle.HOVER_GLOW, 1.0)
	if w.selected:
		# Only the corner brackets, breathing slowly in and out (~1.6 s period); no ring, fill or
		# glow around the card (user feedback).
		var ph := 0.0
		if not UIStyle.reduce_motion:
			ph = sin(float(Time.get_ticks_msec()) / SELECT_PERIOD_MS * TAU)
		_corner_brackets(pt.ci, rect.grow((6.0 + 2.2 * ph) * s), maxf(8.0, 9.0 * s), UIStyle.SELECT.lightened(0.3), maxf(2.2, 2.4 * s))
	if w.highlighted and not empty:
		target_frame(pt.ci, rect, rad, s, target_glow(), true)
	elif w.preview_target:
		# D9: the hover preview of an effect's targets shares the target frame, toned down: a steady thin
		# border and a faint glow, no dash shimmer, no brackets and no pulse.
		target_frame(pt.ci, rect, rad, s, PREVIEW_GLOW, false)
	# Badges last so combined states (ready + selected, etc.) stay legible.
	if ready:
		_ready_badge(pt.ci, rect, s, ready_pulse())
	if w.order_no > 0:
		_order_badge(pt, rect, w.order_no)


## #27: the valid-target glow breathes between these alphas (static at TARGET_GLOW_STILL under reduce
## motion); the D9 preview uses PREVIEW_GLOW. The dash shimmer runs once round the card per DASH_PERIOD_MS.
const TARGET_GLOW_MIN := 0.55
const TARGET_GLOW_MAX := 0.85
const TARGET_GLOW_STILL := 0.7
const PREVIEW_GLOW := 0.3
const DASH_PERIOD_MS := 1400.0
const DASH_PX := 7.0
const GAP_PX := 6.0


## The valid-target glow alpha now (the `breathe` loop between TARGET_GLOW_MIN and MAX).
static func target_glow() -> float:
	if UIStyle.reduce_motion:
		return TARGET_GLOW_STILL
	var t := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 / UIStyle.MOTION["breathe"][0] * TAU)
	return lerpf(TARGET_GLOW_MIN, TARGET_GLOW_MAX, t)


## #27 valid target: an outer glow in TARGET at alpha `glow` (no fill over the card), a 2 px border
## and, when `full`, a light dash shimmer travelling round the border (DASH_PERIOD_MS a lap) and gold
## corner brackets. `full` false is the D9 hover preview (the same path, quieter and static).
static func target_frame(ci: CanvasItem, rect: Rect2, rad: float, s: float, glow: float, full: bool) -> void:
	var col := UIStyle.TARGET
	_ring_on(ci, Color(col, 0.42 * glow), 2.5 * s, rect.grow(2.5 * s), rad + 2.5 * s)
	_ring_on(ci, Color(col, 0.2 * glow), 3.5 * s, rect.grow(5.5 * s), rad + 5.5 * s)
	_ring_on(ci, Color(col, 0.08 * glow), 4.0 * s, rect.grow(9.5 * s), rad + 9.5 * s)
	_ring_on(ci, Color(col, 0.55 + 0.4 * glow if full else 0.75), 2.0, rect, rad)
	if not full:
		return
	var ph := 0.0 if UIStyle.reduce_motion else fmod(float(Time.get_ticks_msec()) / DASH_PERIOD_MS, 1.0)
	_dashes(ci, rect.grow(-1.0), ph, Color(1.0, 0.97, 0.82, 0.75))
	_plain_brackets(ci, rect.grow(4.0 * s), maxf(7.0, 8.0 * s), UIStyle.GOLD_HI, maxf(1.6, 1.8 * s))


# Short light dashes along the straight runs of `r`'s edges, shifted by `ph` (0..1) of one dash
# period clockwise; the corners stay clear.
static func _dashes(ci: CanvasItem, r: Rect2, ph: float, col: Color) -> void:
	var step := DASH_PX + GAP_PX
	var edges := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var ln := a.distance_to(b)
		var dir := (b - a) / maxf(ln, 0.001)
		var x := 10.0 + ph * step - step
		while x < ln - 10.0:
			var x0 := maxf(x, 10.0)
			var x1 := minf(x + DASH_PX, ln - 10.0)
			if x1 > x0:
				ci.draw_line(a + dir * x0, a + dir * x1, col, 1.5, true)
			x += step


# Gold L brackets on the four corners of `r` (no diamonds: those mark a selection).
static func _plain_brackets(ci: CanvasItem, r: Rect2, len_px: float, col: Color, w: float) -> void:
	for i in 2:
		for j in 2:
			var p := Vector2([r.position.x, r.end.x][i], [r.position.y, r.end.y][j])
			var dx := len_px if i == 0 else -len_px
			var dy := len_px if j == 0 else -len_px
			var arm := PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)])
			ci.draw_polyline(arm, Color(0, 0, 0, 0.45), w + 2.0, true)
			ci.draw_polyline(arm, col, w, true)


## Soft glow in three bands just outside `rect` (never over the card frame). `k` scales the alpha.
static func _outer_glow(pt: CardPainter, rect: Rect2, rad: float, col: Color, k: float) -> void:
	var s := pt.s
	pt.ring(Color(col, 0.34 * k), maxf(1.5, 2.0 * s), rect.grow(2.0 * s), rad + 2.0 * s)
	pt.ring(Color(col, 0.16 * k), 3.5 * s, rect.grow(5.5 * s), rad + 5.5 * s)
	pt.ring(Color(col, 0.06 * k), 4.0 * s, rect.grow(9.5 * s), rad + 9.5 * s)


## Slow breathing 0..1 of the available-action glow (a steady 1.0 under reduced motion).
static func ready_pulse() -> float:
	if UIStyle.reduce_motion:
		return 1.0
	return 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / READY_PERIOD_MS * TAU)


## 0..1 hop of the chevron badge: a gentle bounce that rests between hops (0 under reduced motion).
static func ready_bounce() -> float:
	if UIStyle.reduce_motion:
		return 0.0
	var ph := fmod(float(Time.get_ticks_msec()) / BOUNCE_PERIOD_MS, 1.0)
	return sin(minf(ph / 0.6, 1.0) * PI)


## "Can act now" glow: a crisp thin READY ring just outside the card, then three fading bands
## beyond it. `pulse` (0..1, ready_pulse()) breathes the alpha and the outer reach; a constant 1.0 is static.
## Wider than the hover glow so both read when combined.
static func ready_glow(ci: CanvasItem, rect: Rect2, rad: float, s: float, pulse: float) -> void:
	var k := 0.7 + 0.5 * pulse
	var g := 1.0 + 1.5 * pulse * s
	_ring_on(ci, Color(UIStyle.READY, 0.30 * k), 3.5 * s, rect.grow(6.0 * s + g), rad + 6.0 * s + g)
	_ring_on(ci, Color(UIStyle.READY, 0.15 * k), 4.0 * s, rect.grow(9.5 * s + g), rad + 9.5 * s + g)
	_ring_on(ci, Color(UIStyle.READY, 0.06 * k), 4.5 * s, rect.grow(13.5 * s + g), rad + 13.5 * s + g)
	_ring_on(ci, Color(UIStyle.READY, 0.65 + 0.3 * pulse), maxf(1.5, 1.7 * s), rect.grow(3.0 * s), rad + 3.0 * s)


static func _ready_glow(pt: CardPainter, rect: Rect2, rad: float, pulse: float) -> void:
	ready_glow(pt.ci, rect, rad, pt.s, pulse)


static func _ring_on(ci: CanvasItem, col: Color, w: float, r: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(maxi(1, roundi(w)))
	sb.set_corner_radius_all(maxi(1, roundi(radius)))
	ci.draw_style_box(sb, r)


## Yellow circle with a bold dark double up-chevron, set just inside the card's top border (#25: 18 px
## at board size, so it no longer pokes into the zone above): "can act now" by shape, not colour alone.
## `glow` (0..1, ready_pulse()) breathes the soft halo round it; the badge itself never moves.
static func ready_badge_draw(ci: CanvasItem, rect: Rect2, s: float, glow: float) -> void:
	_ready_badge(ci, rect, s, glow)


## Badge radius at card scale `s` (base 9 px: an 18 px badge on a board card).
static func ready_badge_radius(s: float) -> float:
	return maxf(8.0, BADGE_R * s)


## Badge centre on the drawn card `rect`: inside the top border, a little below the top edge.
static func ready_badge_center(rect: Rect2, s: float) -> Vector2:
	return Vector2(rect.get_center().x, rect.position.y + ready_badge_radius(s) * 0.35)


static func _ready_badge(ci: CanvasItem, rect: Rect2, s: float, glow: float) -> void:
	var rr := ready_badge_radius(s)
	var c := ready_badge_center(rect, s)
	ci.draw_circle(c, rr + 5.0 * s, Color(UIStyle.READY, 0.06 + 0.12 * glow), true, -1.0, true)
	ci.draw_circle(c, rr + 2.5 * s, Color(UIStyle.READY, 0.1 + 0.14 * glow), true, -1.0, true)
	ci.draw_circle(c, rr + 1.6 * s, BADGE_SHADOW_READY, true, -1.0, true)
	ci.draw_circle(c, rr, UIStyle.READY, true, -1.0, true)
	ci.draw_arc(c, rr, 0.0, TAU, 24, BADGE_RIM, maxf(1.2, 1.3 * s), true)
	var w := rr * 0.52
	for y in [c.y + rr * 0.42, c.y - rr * 0.12]:
		ci.draw_polyline(PackedVector2Array([Vector2(c.x - w, y), Vector2(c.x, y - w * 0.9), Vector2(c.x + w, y)]), CHEVRON, maxf(2.2, 2.4 * s), true)


## Four L-shaped corner brackets on `r`, each arm `len_px` long.
## Selection brackets (#29): a gold filigree L at each corner of `r` with a soft glow under it and
## a small diamond set on the corner.
static func _corner_brackets(ci: CanvasItem, r: Rect2, len_px: float, col: Color, w: float) -> void:
	var xs := [r.position.x, r.end.x]
	var ys := [r.position.y, r.end.y]
	var glow := Color(col, col.a * 0.16)
	for i in 2:
		for j in 2:
			var p := Vector2(xs[i], ys[j])
			var dx := len_px if i == 0 else -len_px
			var dy := len_px if j == 0 else -len_px
			var arm := PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)])
			ci.draw_polyline(arm, glow, w + 6.0, true)
			ci.draw_polyline(arm, Color(col, col.a * 0.3), w + 2.5, true)
			ci.draw_polyline(arm, col, w, true)
			var d := w * 1.25 + 0.5
			var q := p - Vector2(signf(dx), signf(dy)) * (w * 0.9)
			ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -d), q + Vector2(d, 0), q + Vector2(0, d), q + Vector2(-d, 0)]), col)


## Numbered circle (`order_no`) on the top-right corner for ordered multi-select.
static func _order_badge(pt: CardPainter, rect: Rect2, order_no: int) -> void:
	var ci := pt.ci
	var s := pt.s
	var rr := maxf(9.5, 10.5 * s)
	var c := Vector2(rect.end.x - 3.0 * s, rect.position.y + 3.0 * s)
	ci.draw_circle(c, rr + 1.8 * s, BADGE_SHADOW_ORDER, true, -1.0, true)
	ci.draw_circle(c, rr, UIStyle.SELECT.darkened(0.1), true, -1.0, true)
	ci.draw_arc(c, rr, 0.0, TAU, 24, UIStyle.ON_GOLD, maxf(1.3, 1.5 * s), true)
	pt.text_c(UIStyle.font_display(700), str(order_no), c, maxi(10 if order_no < 10 else 8, roundi(rr * (1.1 if order_no < 10 else 0.85))), UIStyle.ON_GOLD, 0.0)
