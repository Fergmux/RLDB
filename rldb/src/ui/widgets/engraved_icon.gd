class_name EngravedIcon
extends Control
## Engraved line-art emblem for illustrated empty states (design review WP-7: #42, #54, #79, #96):
## a glyph cut into the leather, drawn as a dark groove offset down-right under a bronze-gold
## line, inside a faint ring, with a slow `breathe` on its glow. Vector-drawn, so it scales and needs
## no art file. Static (one resting state) under UIStyle.reduce_motion.
##
##     var icon := EngravedIcon.new("magnifier", 64)
##     box.add_child(icon)

## Glyphs: "magnifier" (no search results), "card" (a card-back outline: no card selected),
## "trophy" (no statistics yet), "tome" (no saved decks), "deck" (an empty deck: three fanned cards).
const GLYPHS := ["magnifier", "card", "trophy", "tome", "deck"]
## Line colour, the groove under it and the glow behind it.
const LINE := Color(0.831, 0.651, 0.29, 0.62)
const GROOVE := Color(0, 0, 0, 0.55)
const GLOW := Color(0.941, 0.812, 0.478, 0.10)
## Groove offset (px at 64 px) and the line width as a share of the icon size.
const GROOVE_OFFSET := Vector2(1.0, 1.5)
const LINE_W_SHARE := 0.035

## Which glyph (one of GLYPHS).
var glyph: String = "card"
## Seconds clock of the breathe loop (tests inject a fixed one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0


## `kind` is one of GLYPHS; `px` the square size.
func _init(kind: String = "card", px: float = 64.0) -> void:
	glyph = kind
	custom_minimum_size = Vector2(px, px)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if not UIStyle.reduce_motion and is_visible_in_tree():
		queue_redraw()


## The glow strength now (1 +/- the breathe amplitude; exactly 1 under reduce motion).
func glow_level() -> float:
	return UIStyle.breathe(float(clock.call()), 0.35)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var k := glow_level()
	draw_circle(c, s * 0.5, Color(GLOW, GLOW.a * k), true, -1.0, true)
	draw_arc(c, s * 0.48, 0.0, TAU, 48, Color(LINE, 0.22), maxf(1.0, s * 0.015), true)
	var w := maxf(1.5, s * LINE_W_SHARE)
	var g := GROOVE_OFFSET * (s / 64.0)
	_glyph(c + g, s, w + 0.5, GROOVE)
	_glyph(c, s, w, Color(LINE, LINE.a * (0.85 + 0.15 * k)))


func _glyph(c: Vector2, s: float, w: float, col: Color) -> void:
	match glyph:
		"magnifier":
			var r := s * 0.2
			var o := c + Vector2(-s * 0.06, -s * 0.06)
			draw_arc(o, r, 0.0, TAU, 40, col, w, true)
			var d := Vector2(1, 1).normalized()
			draw_line(o + d * (r + w * 0.5), o + d * (r + s * 0.2), col, w * 1.6, true)
			draw_arc(o, r * 0.62, PI * 1.05, PI * 1.45, 10, Color(col, col.a * 0.6), w * 0.6, true)
		"card":
			_card_outline(c, s * 0.36, s * 0.52, 0.0, col, w)
			var r2 := s * 0.08
			_diamond(c, r2, col, w)
			_diamond(c, r2 * 2.0, Color(col, col.a * 0.5), w * 0.6)
		"deck":
			for i in 3:
				var a := deg_to_rad(-14.0 + 14.0 * i)
				_card_outline(c + Vector2((i - 1) * s * 0.09, s * 0.03), s * 0.3, s * 0.44, a, Color(col, col.a * (0.55 + 0.225 * i)), w)
		"trophy":
			var top := c.y - s * 0.24
			var cw := s * 0.36
			var cup := PackedVector2Array([
				Vector2(c.x - cw / 2.0, top), Vector2(c.x - cw * 0.42, c.y + s * 0.02), Vector2(c.x - cw * 0.16, c.y + s * 0.1),
				Vector2(c.x + cw * 0.16, c.y + s * 0.1), Vector2(c.x + cw * 0.42, c.y + s * 0.02), Vector2(c.x + cw / 2.0, top)])
			cup.append(cup[0])
			draw_polyline(cup, col, w, true)
			draw_arc(Vector2(c.x - cw / 2.0, top + s * 0.08), s * 0.07, PI * 0.5, PI * 1.5, 12, col, w, true)
			draw_arc(Vector2(c.x + cw / 2.0, top + s * 0.08), s * 0.07, -PI * 0.5, PI * 0.5, 12, col, w, true)
			draw_line(Vector2(c.x, c.y + s * 0.1), Vector2(c.x, c.y + s * 0.2), col, w, true)
			draw_line(Vector2(c.x - s * 0.13, c.y + s * 0.22), Vector2(c.x + s * 0.13, c.y + s * 0.22), col, w * 1.3, true)
			_diamond(Vector2(c.x, top + s * 0.1), s * 0.05, col, w * 0.8)
		"tome":
			var bw := s * 0.44
			var bh := s * 0.5
			var r := Rect2(c - Vector2(bw, bh) / 2.0, Vector2(bw, bh))
			draw_rect(r, col, false, w)
			draw_line(r.position + Vector2(bw * 0.14, 0), r.position + Vector2(bw * 0.14, bh), col, w, true)
			_diamond(r.get_center() + Vector2(bw * 0.07, 0), s * 0.07, col, w * 0.8)
			draw_line(Vector2(r.position.x + bw * 0.3, r.position.y + bh * 0.18), Vector2(r.end.x - bw * 0.16, r.position.y + bh * 0.18), Color(col, col.a * 0.6), w * 0.6, true)
			draw_line(Vector2(r.position.x + bw * 0.3, r.end.y - bh * 0.18), Vector2(r.end.x - bw * 0.16, r.end.y - bh * 0.18), Color(col, col.a * 0.6), w * 0.6, true)


func _card_outline(c: Vector2, cw: float, ch: float, angle: float, col: Color, w: float) -> void:
	var rad := cw * 0.1
	var pts := PackedVector2Array()
	var half := Vector2(cw, ch) / 2.0
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in 4:
		var cc: Vector2 = (corners[i] as Vector2) * (half - Vector2(rad, rad))
		for j in 5:
			var a: float = starts[i] + PI * 0.5 * float(j) / 4.0
			pts.append(c + (cc + Vector2(cos(a), sin(a)) * rad).rotated(angle))
	pts.append(pts[0])
	draw_polyline(pts, col, w, true)
	var inner := PackedVector2Array()
	var ih := half * 0.78
	for v in [Vector2(-ih.x, -ih.y), Vector2(ih.x, -ih.y), Vector2(ih.x, ih.y), Vector2(-ih.x, ih.y), Vector2(-ih.x, -ih.y)]:
		inner.append(c + (v as Vector2).rotated(angle))
	draw_polyline(inner, Color(col, col.a * 0.45), maxf(1.0, w * 0.5), true)


func _diamond(c: Vector2, r: float, col: Color, w: float) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), col, w, true)


## A centred illustrated empty state laid directly on the surface (no box, design review #54/#79):
## the engraved `glyph` (64 px), a SCREEN title, the body text and an optional 44 px secondary
## button running `on_action`. Returns the VBoxContainer; the button (if any) is its "Action" child.
static func empty_state(kind: String, title: String, body: String, action: String = "", on_action: Callable = Callable(), width: float = 320.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "EmptyState"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(width, 0)
	UIStyle.pad(v, "md")
	v.add_child(EngravedIcon.new(kind, 64.0))
	var t := UIStyle.label(title, 22, UIStyle.GOLD_HI)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.name = "Title"
	v.add_child(t)
	TitleText.apply(t, TitleText.Tier.SCREEN, 22)
	if body != "":
		var b := UIStyle.label(body, 15, UIStyle.MUTED, true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("line_spacing", 4)
		b.name = "Body"
		v.add_child(b)
	if action != "":
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, UIStyle.sp("xs"))
		v.add_child(gap)
		var btn := UIStyle.size_button(UIStyle.secondary_button(action, 15), "standard")
		btn.name = "Action"
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if on_action.is_valid():
			btn.pressed.connect(on_action)
		v.add_child(btn)
	return v
