class_name CardBack
extends RefCounted
## The one card-back design (every kind, both players, piles): a violet framed body with a drop
## shadow, an inner gradient, a thin gold frame and the emblem.

const BODY := Color("1d1630")
const BORDER := Color("6e5a9a")
const GRAD_TOP := Color("2a2050")
const GRAD_BOTTOM := Color("120c22")
## Number of bands in the inner gradient.
const GRAD_STEPS := 12
## Number of rays around the emblem.
const RAYS := 24


## Framed card back filling the painter's portrait rect; `radius` is the corner radius in base units.
static func draw(pt: CardPainter, radius: float) -> void:
	var s := pt.s
	var sb := pt.sbox(BODY, BORDER, maxi(2, roundi(2.8 * s)), roundi(radius * s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi(6.0 * s)
	sb.shadow_offset = pt.shadow_off(3.0 * s)
	pt.ci.draw_style_box(sb, Rect2(Vector2.ZERO, pt.ps))
	draw_art(pt.ci, Rect2(Vector2.ZERO, pt.ps), s)


## Back art inside `card` at scale `s`: inner gradient, gold frame, emblem (no body or border).
static func draw_art(ci: CanvasItem, card: Rect2, s: float) -> void:
	var inner := card.grow(-5.0 * s)
	var steps := GRAD_STEPS
	for i in steps:
		var t := float(i) / float(steps - 1)
		var band := Rect2(inner.position.x, inner.position.y + inner.size.y * float(i) / steps, inner.size.x, inner.size.y / steps + 1.0).intersection(inner)
		ci.draw_rect(band, GRAD_TOP.lerp(GRAD_BOTTOM, t))
	ci.draw_rect(inner, Color(UIStyle.GOLD, 0.35), false, maxf(1.0, s), true)
	var c := card.get_center()
	var r := minf(inner.size.x, inner.size.y) * 0.34
	var gold := Color(UIStyle.GOLD, 0.7)
	var w := maxf(1.0, 1.4 * s)
	for rot in [PI / 4.0, 0.0]:
		var sq := PackedVector2Array()
		for k in 5:
			var a: float = rot + float(k) * TAU / 4.0
			sq.append(c + Vector2(cos(a), sin(a)) * r * 1.2)
		ci.draw_polyline(sq, gold, w, true)
	ci.draw_arc(c, r * 0.8, 0.0, TAU, 32, gold, w, true)
	ci.draw_circle(c, r * 0.16, gold, true, -1.0, true)
	for i in RAYS:
		var a := float(i) * TAU / float(RAYS)
		var d := Vector2(cos(a), sin(a))
		var r0 := r * 1.55
		var p0 := c + d * r0
		if inner.has_point(p0) and inner.has_point(c + d * (r0 + 3.0 * s)):
			ci.draw_line(p0, c + d * (r0 + 3.0 * s), Color(UIStyle.GOLD, 0.35), w, true)
