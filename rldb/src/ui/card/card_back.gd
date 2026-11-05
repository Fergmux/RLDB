class_name CardBack
extends RefCounted
## The card back (every kind, both players, piles): a framed body with a drop shadow, then the
## back's art inside a thin gold frame. L31 (owner, 5 Nov): the player picks the back in Options >
## Customisation (Customisation.card_back_id). It is a local display choice, so it dresses every
## face-down card on this screen, the opponent's too, and never reaches the network.
##
## Two kinds of back share the frame, so every back has the same silhouette at every size:
##   procedural  "violet", the house back: an inner gradient and a gold sigil emblem (vector).
##   painted     a painted centre (STYLES[id].art, 512x768 WebP with mipmaps) drawn cover-fit inside
##               the same inset and frame line, on its own body / border colours.
## Textures load once and are shared (one draw call per painted back).
##
##     CardBack.draw(painter, 6.0)                 # the chosen back
##     CardBack.draw_art(ci, rect, s, "wyrm")      # a given back (the picker)

const BODY := Color("1d1630")
const BORDER := Color("6e5a9a")
const GRAD_TOP := Color("2a2050")
const GRAD_BOTTOM := Color("120c22")
## Number of bands in the inner gradient.
const GRAD_STEPS := 12
## Number of rays around the emblem.
const RAYS := 24
## Inset of the art inside the card (base units; the frame line sits on its edge).
const INSET := 5.0
## The violet back's soft glow behind its emblem: its colour and number of stacked discs.
const GLOW := Color("6a55c0")
const GLOW_RINGS := 4

## How each back of Customisation.CARD_BACKS is drawn: the body and border of the card frame, the
## alpha of the thin gold frame line around the art, and (painted backs) the art and an optional
## "tint" that modulates it (the ivory Gilded Sun is calmed so it does not glare on the table). A
## back with no "art" is the procedural violet sigil.
const STYLES := {
	"violet": {"body": Color("1d1630"), "border": Color("6e5a9a"), "frame_a": 0.35},
	"wyrm": {"body": Color("240b0b"), "border": Color("8c3b2c"), "frame_a": 0.55,
		"art": "res://assets/art/card_backs/back_wyrm.webp"},
	"grove": {"body": Color("0d1a0f"), "border": Color("56763a"), "frame_a": 0.55,
		"art": "res://assets/art/card_backs/back_grove.webp"},
	"tide": {"body": Color("0a1424"), "border": Color("4d6f96"), "frame_a": 0.5,
		"art": "res://assets/art/card_backs/back_tide.webp"},
	"runes": {"body": Color("100d0c"), "border": Color("8a4622"), "frame_a": 0.5,
		"art": "res://assets/art/card_backs/back_runes.webp"},
	"sun": {"body": Color("3a2810"), "border": Color("b98f3a"), "frame_a": 0.6, "tint": Color(0.9, 0.86, 0.8),
		"art": "res://assets/art/card_backs/back_sun.webp"},
	"stars": {"body": Color("120f2c"), "border": Color("5e5a9e"), "frame_a": 0.5,
		"art": "res://assets/art/card_backs/back_stars.webp"},
}

static var _textures: Dictionary = {}


## The STYLES entry of back `id` ("" = the chosen back; an unknown id is the default back).
static func style(id: String = "") -> Dictionary:
	var want := id if id != "" else Customisation.card_back_id()
	return STYLES.get(want, STYLES[Customisation.DEFAULT_CARD_BACK])


## Body colour of back `id`'s card frame ("" = the chosen back).
static func body_color(id: String = "") -> Color:
	return style(id)["body"]


## Border colour of back `id`'s card frame ("" = the chosen back).
static func border_color(id: String = "") -> Color:
	return style(id)["border"]


## True when back `id` has a painted centre ("" = the chosen back).
static func is_painted(id: String = "") -> bool:
	return style(id).has("art")


## The painted centre of back `id` (loaded once, then shared), or null for a procedural back.
static func texture(id: String = "") -> Texture2D:
	var st := style(id)
	if not st.has("art"):
		return null
	var path := String(st["art"])
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]


## Framed card back filling the painter's portrait rect; `radius` is the corner radius in base
## units, `id` the back ("" = the chosen one).
static func draw(pt: CardPainter, radius: float, id: String = "") -> void:
	var s := pt.s
	var st := style(id)
	var sb := pt.sbox(st["body"], st["border"], maxi(2, roundi(2.8 * s)), roundi(radius * s))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = roundi(6.0 * s)
	sb.shadow_offset = pt.shadow_off(3.0 * s)
	pt.ci.draw_style_box(sb, Rect2(Vector2.ZERO, pt.ps))
	draw_art(pt.ci, Rect2(Vector2.ZERO, pt.ps), s, id)


## Back art inside `card` at scale `s` (no body or border): the painted centre or the violet
## gradient and emblem, then the thin gold frame line. `id` is the back ("" = the chosen one).
static func draw_art(ci: CanvasItem, card: Rect2, s: float, id: String = "") -> void:
	var inner := card.grow(-INSET * s)
	var st := style(id)
	var tex := texture(id)
	if tex != null:
		ci.draw_texture_rect_region(tex, inner, cover_region(tex.get_size(), inner.size), st.get("tint", Color.WHITE))
		# A soft dark keyline just inside the frame line seats the painting in the mat.
		ci.draw_rect(inner.grow(-maxf(1.0, s)), Color(0, 0, 0, 0.35), false, maxf(1.0, s), true)
		ci.draw_rect(inner, Color(UIStyle.GOLD, float(st.get("frame_a", 0.5))), false, maxf(1.0, s), true)
		return
	_draw_sigil(ci, card, inner, s, float(st.get("frame_a", 0.35)))


## The source rect of a texture of size `tex` that covers a `dst`-sized rect without stretching
## (centred crop of the longer side).
static func cover_region(tex: Vector2, dst: Vector2) -> Rect2:
	if tex.x <= 0.0 or tex.y <= 0.0 or dst.x <= 0.0 or dst.y <= 0.0:
		return Rect2(Vector2.ZERO, tex)
	var want := dst.x / dst.y
	if tex.x / tex.y > want:
		var w := tex.y * want
		return Rect2((tex.x - w) / 2.0, 0.0, w, tex.y)
	var h := tex.x / want
	return Rect2(0.0, (tex.y - h) / 2.0, tex.x, h)


# The procedural house back: inner gradient, a soft violet glow behind the emblem, a double gold
# frame with corner brackets, two squares, a ring with studs, an inner ring, a lit boss and rays.
# The ring keeps its radius (r * 0.8): a pile's count medallion sits exactly in it (PileStack).
static func _draw_sigil(ci: CanvasItem, card: Rect2, inner: Rect2, s: float, frame_a: float) -> void:
	var steps := GRAD_STEPS
	for i in steps:
		var t := float(i) / float(steps - 1)
		var band := Rect2(inner.position.x, inner.position.y + inner.size.y * float(i) / steps, inner.size.x, inner.size.y / steps + 1.0).intersection(inner)
		ci.draw_rect(band, GRAD_TOP.lerp(GRAD_BOTTOM, t))
	var c := card.get_center()
	var r := minf(inner.size.x, inner.size.y) * 0.34
	for k in GLOW_RINGS:
		ci.draw_circle(c, r * (1.42 - 0.24 * float(k)), Color(GLOW, 0.07), true, -1.0, true)
	ci.draw_rect(inner, Color(UIStyle.GOLD, frame_a), false, maxf(1.0, s), true)
	var lw := maxf(1.0, 0.8 * s)
	var in2 := inner.grow(-3.0 * s)
	ci.draw_rect(in2, Color(UIStyle.GOLD, 0.16), false, lw, true)
	var arm := 9.0 * s
	var br := in2.grow(-3.0 * s)
	for corner in [[br.position, Vector2(1, 1)], [Vector2(br.end.x, br.position.y), Vector2(-1, 1)],
			[br.end, Vector2(-1, -1)], [Vector2(br.position.x, br.end.y), Vector2(1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		ci.draw_polyline(PackedVector2Array([p + Vector2(arm * d.x, 0), p, p + Vector2(0, arm * d.y)]), Color(UIStyle.GOLD, 0.42), lw, true)
		_diamond(ci, (corner[0] as Vector2) - d * 3.0 * s, 1.6 * s, Color(UIStyle.GOLD, 0.6))
	var gold := Color(UIStyle.GOLD, 0.7)
	var w := maxf(1.0, 1.4 * s)
	for rot in [PI / 4.0, 0.0]:
		var sq := PackedVector2Array()
		for k in 5:
			var a: float = rot + float(k) * TAU / 4.0
			sq.append(c + Vector2(cos(a), sin(a)) * r * 1.2)
		ci.draw_polyline(sq, gold, w, true)
	ci.draw_arc(c, r * 0.8, 0.0, TAU, 32, gold, w, true)
	ci.draw_arc(c, r * 0.52, 0.0, TAU, 28, Color(UIStyle.GOLD, 0.35), lw, true)
	for k in 4:
		var a := float(k) * TAU / 4.0
		_diamond(ci, c + Vector2(cos(a), sin(a)) * r * 0.52, 1.8 * s, gold)
	ci.draw_circle(c, r * 0.16, gold, true, -1.0, true)
	ci.draw_circle(c + Vector2(-0.3, -0.3) * r * 0.16, r * 0.07, Color(UIStyle.GOLD_HI, 0.55), true, -1.0, true)
	for i in RAYS:
		var a := float(i) * TAU / float(RAYS)
		var d := Vector2(cos(a), sin(a))
		var r0 := r * 1.55
		var p0 := c + d * r0
		if inner.has_point(p0) and inner.has_point(c + d * (r0 + 3.0 * s)):
			ci.draw_line(p0, c + d * (r0 + 3.0 * s), Color(UIStyle.GOLD, 0.35), w, true)


# A filled diamond (a gold stud) of half-size `h` at `p`.
static func _diamond(ci: CanvasItem, p: Vector2, h: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -h), p + Vector2(h, 0), p + Vector2(0, h), p + Vector2(-h, 0)]), col)
