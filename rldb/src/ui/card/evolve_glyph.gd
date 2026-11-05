class_name EvolveGlyph
extends Control
## L23 (owner feedback 2026-11-05): the Evolve section's colour and icon. The colours come from the
## Symbiote art (luminous orchid-pink blossoms over indigo), so the section reads apart from every
## timing caption (Materials blue, On Summon green, On Field gold, On Destruction red). The icon is a
## budding blossom: three petals opening from a bud with a spark above, drawn with primitives (no
## font glyph), crisp from 12 px up. Used by the card details pane, the card tooltip, the inspector's
## "Evolves into" section, the Evolve prompt and the evolve animation.

## The Evolve colour (captions, accent bars, the icon) and its deep and light companions.
const COLOR := Color("f59bd8")
const DEEP := Color("7b6cff")
const LIGHT := Color("ffe6f6")

## Fill colour of the icon (defaults to COLOR).
var color: Color = COLOR


func _init(px: float = 14.0, col: Color = COLOR) -> void:
	color = col
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	draw_glyph(self, size / 2.0, r, color)


## The blossom icon centred on `c`, `2 r` tall, in `col` on canvas item `ci`.
static func draw_glyph(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var base := c + Vector2(0, r * 0.78)
	var dark := Color(col.darkened(0.45), col.a)
	# Side petals first (behind), then the centre petal, each with a hairline rim for a crisp edge.
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(side * r * 0.82, -r * 0.38)
		var pts := petal(base, tip, r * 0.36, side * 0.25)
		ci.draw_colored_polygon(pts, Color(col, col.a * 0.78))
		ci.draw_polyline(_closed(pts), dark, maxf(1.0, r * 0.07), true)
	var centre := petal(base, c + Vector2(0, -r * 0.78), r * 0.42, 0.0)
	ci.draw_colored_polygon(centre, col)
	ci.draw_polyline(_closed(centre), dark, maxf(1.0, r * 0.07), true)
	# The vein of the centre petal and the spark above the bud.
	ci.draw_line(base + Vector2(0, -r * 0.12), c + Vector2(0, -r * 0.45), Color(LIGHT, col.a * 0.7), maxf(1.0, r * 0.08), true)
	var sp := c + Vector2(0, -r * 1.0)
	var s := r * 0.2
	ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -s), sp + Vector2(s * 0.35, 0), sp + Vector2(0, s),
		sp + Vector2(-s * 0.35, 0)]), Color(LIGHT, col.a))
	ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(-s, 0), sp + Vector2(0, -s * 0.35), sp + Vector2(s, 0),
		sp + Vector2(0, s * 0.35)]), Color(LIGHT, col.a))


## A petal from `a` (its base) to `b` (its tip), `w` wide at the middle, its tip bent by `bend`
## (share of the length, sideways). Two quadratic edges sampled into a closed outline.
static func petal(a: Vector2, b: Vector2, w: float, bend: float = 0.0) -> PackedVector2Array:
	var d := b - a
	var n := Vector2(-d.y, d.x).normalized()
	var mid := a + d * 0.5 + n * bend * d.length() * 0.25
	var out := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var t := float(i) / steps
		out.append(_quad(a, mid + n * w, b, t))
	for i in range(steps - 1, 0, -1):
		var t := float(i) / steps
		out.append(_quad(a, mid - n * w, b, t))
	return out


static func _quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
