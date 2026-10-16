class_name CardOverlays
extends RefCounted
## State overlays drawn in widget space around the drawn card rect (painter.cr), after the face:
## FX flash / glow, the "can act now" ready glow and badge, hover glow, selection brackets, the
## pulsing target ring and the ordered multi-select badge. Badges are drawn last so combined
## states stay legible.

## Period (ms) of the breathing selection brackets and of the pulsing target ring.
const SELECT_PERIOD_MS := 1600.0
const TARGET_PERIOD_MS := 900.0
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
	if ready:
		# Steady warm-yellow glow OUTSIDE the card (its own frame colour stays visible) plus the chevron
		# badge. TARGET differs by behaviour: it pulses and fills/rings the card itself.
		_ready_glow(pt, rect, rad)
	if pt.hover:
		# Soft ivory glow entirely OUTSIDE the card, no ring on it: the kind-coloured frame stays visible.
		_outer_glow(pt, rect, rad, UIStyle.HOVER_GLOW, 1.0)
	if w.selected:
		# Only the corner brackets, breathing slowly in and out (~1.6 s period); no ring, fill or
		# glow around the card (user feedback).
		var ph := 0.0
		if not UIStyle.reduce_motion:
			ph = sin(float(Time.get_ticks_msec()) / SELECT_PERIOD_MS * TAU)
		_corner_brackets(pt.ci, rect.grow((6.0 + 2.2 * ph) * s), maxf(8.0, 9.0 * s), UIStyle.SELECT.lightened(0.3), maxf(2.2, 2.4 * s))
	if w.highlighted:
		var a := 1.0
		if not UIStyle.reduce_motion:
			a = 0.55 + 0.45 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / TARGET_PERIOD_MS * TAU))
		pt.round_rect(rect, Color(UIStyle.TARGET, 0.07 + 0.12 * a), rad)
		pt.ring(Color(UIStyle.TARGET, 0.35 * a), 5.0 * s, rect.grow(3.5 * s), rad + 3.0 * s)
		pt.ring(Color(UIStyle.TARGET, a), 3.5 * s, rect, rad)
	# Badges last so combined states (ready + selected, etc.) stay legible.
	if ready:
		_ready_badge(pt, rect)
	if w.order_no > 0:
		_order_badge(pt, rect, w.order_no)


## Soft glow in three bands just outside `rect` (never over the card frame). `k` scales the alpha.
static func _outer_glow(pt: CardPainter, rect: Rect2, rad: float, col: Color, k: float) -> void:
	var s := pt.s
	pt.ring(Color(col, 0.34 * k), maxf(1.5, 2.0 * s), rect.grow(2.0 * s), rad + 2.0 * s)
	pt.ring(Color(col, 0.16 * k), 3.5 * s, rect.grow(5.5 * s), rad + 5.5 * s)
	pt.ring(Color(col, 0.06 * k), 4.0 * s, rect.grow(9.5 * s), rad + 9.5 * s)


## "Can act now" glow: a crisp thin READY ring just outside the card, then three fading bands
## beyond it. Static (no per-frame redraw). Wider than the hover glow so both read when combined.
static func _ready_glow(pt: CardPainter, rect: Rect2, rad: float) -> void:
	var s := pt.s
	pt.ring(Color(UIStyle.READY, 0.30), 3.5 * s, rect.grow(6.0 * s), rad + 6.0 * s)
	pt.ring(Color(UIStyle.READY, 0.15), 4.0 * s, rect.grow(9.5 * s), rad + 9.5 * s)
	pt.ring(Color(UIStyle.READY, 0.06), 4.5 * s, rect.grow(13.5 * s), rad + 13.5 * s)
	pt.ring(Color(UIStyle.READY, 0.9), maxf(1.5, 1.7 * s), rect.grow(3.0 * s), rad + 3.0 * s)


## Yellow circle with a bold dark double up-chevron on the top edge: "can act now" by shape, not
## colour alone.
static func _ready_badge(pt: CardPainter, rect: Rect2) -> void:
	var ci := pt.ci
	var s := pt.s
	var rr := maxf(10.0, 10.5 * s)
	var c := Vector2(rect.get_center().x, rect.position.y - 5.0 * s)
	ci.draw_circle(c, rr + 1.8 * s, BADGE_SHADOW_READY, true, -1.0, true)
	ci.draw_circle(c, rr, UIStyle.READY, true, -1.0, true)
	ci.draw_arc(c, rr, 0.0, TAU, 24, BADGE_RIM, maxf(1.2, 1.3 * s), true)
	var w := rr * 0.52
	for y in [c.y + rr * 0.42, c.y - rr * 0.12]:
		ci.draw_polyline(PackedVector2Array([Vector2(c.x - w, y), Vector2(c.x, y - w * 0.9), Vector2(c.x + w, y)]), CHEVRON, maxf(2.2, 2.4 * s), true)


## Four L-shaped corner brackets on `r`, each arm `len_px` long.
static func _corner_brackets(ci: CanvasItem, r: Rect2, len_px: float, col: Color, w: float) -> void:
	var xs := [r.position.x, r.end.x]
	var ys := [r.position.y, r.end.y]
	for i in 2:
		for j in 2:
			var p := Vector2(xs[i], ys[j])
			var dx := len_px if i == 0 else -len_px
			var dy := len_px if j == 0 else -len_px
			ci.draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), col, w, true)


## Numbered circle (`order_no`) on the top-right corner for ordered multi-select.
static func _order_badge(pt: CardPainter, rect: Rect2, order_no: int) -> void:
	var ci := pt.ci
	var s := pt.s
	var rr := maxf(9.5, 10.5 * s)
	var c := Vector2(rect.end.x - 3.0 * s, rect.position.y + 3.0 * s)
	ci.draw_circle(c, rr + 1.8 * s, BADGE_SHADOW_ORDER, true, -1.0, true)
	ci.draw_circle(c, rr, UIStyle.SELECT.darkened(0.1), true, -1.0, true)
	ci.draw_arc(c, rr, 0.0, TAU, 24, Color.WHITE, maxf(1.3, 1.5 * s), true)
	pt.text_c(UIStyle.font_display(700), str(order_no), c, maxi(10 if order_no < 10 else 8, roundi(rr * (1.1 if order_no < 10 else 0.85))), Color.WHITE, 1.0)
