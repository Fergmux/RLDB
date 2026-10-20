class_name CardJewel
extends RefCounted
## H17 (21 Oct): the faceted-gem-in-a-metal-setting look of the AP gems (ApGemRow) for the card face's
## indicators: the cost gem, the Type pip and the ATK / DEF badges. Pure drawing helpers on any
## CanvasItem; every shape is a closed outline (CardGeometry) so one gem routine serves the round AP
## gem, the Ritual lozenge, the Arcane hexagon, the ATK rhombus and the DEF shield.
##
## Light falls from the upper left (LIGHT), as on the AP gems and the HP vial. A gem is: a dark
## girdle edge, crown facets between the girdle and an inset table (each shaded by how much it faces
## the light), a table with a radial gradient towards the light and a white glint. A setting is a
## gilded band (bright at the top, bronze at the foot) with a dark outline and an inner shadow line.
## Cheap: a handful of polygons per part, no textures, no shaders.

const LIGHT := Vector2(-0.6, -0.8)
## Gilded setting: top, middle and foot colours, and the dark outline round it.
const METAL_HI := Color("fbe7a8")
const METAL := Color("d4a64a")
const METAL_LO := Color("9a7038")
const METAL_EDGE := Color(0.06, 0.04, 0.02, 0.95)
## The darkest a gem's facets get (also its girdle edge).
const GEM_EDGE := Color(0.07, 0.04, 0.03, 0.95)


## Hi / mid / lo shades of a gem of colour `col` (lo also darkens the shaded facets).
static func shades(col: Color) -> Array:
	return [col.lightened(0.55), col, col.darkened(0.6)]


## A gilded band filling `outer` (closed outline around `c`) `width` px deep: dark outline, a
## vertical metal gradient, a fine highlight along the lit upper edge and a shadow line on the inside.
## Returns the band's inner outline (where the gem sits).
static func setting(ci: CanvasItem, outer: PackedVector2Array, c: Vector2, width: float, s: float) -> PackedVector2Array:
	ci.draw_colored_polygon(CardGeometry.grow_pts(outer, c, maxf(0.8, 0.8 * s)), METAL_EDGE)
	var top := INF
	var bot := -INF
	for p in outer:
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	var cols := PackedColorArray()
	for p in outer:
		var t := clampf((p.y - top) / maxf(1.0, bot - top), 0.0, 1.0)
		cols.append(METAL_HI.lerp(METAL, minf(1.0, t * 1.4)).lerp(METAL_LO, maxf(0.0, t * 1.4 - 0.7)))
	ci.draw_polygon(outer, cols)
	# Polygons are not anti-aliased: a fine AA stroke on the outline smooths the silhouette.
	ci.draw_polyline(CardGeometry.closed(CardGeometry.grow_pts(outer, c, 0.55 * s)), METAL_EDGE, 1.0, true)
	var inner := CardGeometry.grow_pts(outer, c, -width)
	_lit_edge(ci, CardGeometry.grow_pts(outer, c, -0.45 * s), c, Color(1, 0.97, 0.85, 0.7), maxf(0.7, 0.6 * s))
	ci.draw_polyline(CardGeometry.closed(CardGeometry.grow_pts(inner, c, 0.25 * s)), Color(0, 0, 0, 0.45), maxf(0.6, 0.55 * s), true)
	return inner


## A faceted gem filling the outline `girdle` around `c`. `col` is its colour; `table_k` the size of
## the flat table as a share of the girdle; `glint` adds the white spark. `dark_table` keeps the table
## deep (white numbers read on it) instead of bright (dark numbers read on it).
## `pal` overrides the shades with [hi, mid, lo] (the cost gem passes the AP gems' topaz).
static func gem(ci: CanvasItem, girdle: PackedVector2Array, c: Vector2, col: Color, table_k: float, glint: bool, dark_table: bool = false, pal: Array = []) -> void:
	var sh := pal if pal.size() == 3 else shades(col)
	var hi: Color = sh[0]
	var mid: Color = sh[1]
	var lo: Color = sh[2]
	var light := LIGHT.normalized()
	ci.draw_colored_polygon(girdle, GEM_EDGE)
	var outer := CardGeometry.grow_pts(girdle, c, -0.6)
	var table := PackedVector2Array()
	for p in outer:
		table.append(c + (p - c) * table_k)
	var n := outer.size()
	for k in n:
		var k2 := (k + 1) % n
		var dir := ((outer[k] + outer[k2]) / 2.0 - c).normalized()
		var lit := clampf(0.5 + 0.5 * dir.dot(light), 0.0, 1.0)
		var fc := lo.lerp(mid, minf(1.0, lit * 1.5)).lerp(hi, maxf(0.0, lit * 1.6 - 0.95))
		ci.draw_colored_polygon(PackedVector2Array([outer[k], outer[k2], table[k2], table[k]]), fc)
	# The table: a radial gradient, brightest a little towards the light.
	var span := 0.0
	for p in table:
		span = maxf(span, p.distance_to(c))
	var hot := c + light * span * 0.25
	var centre_c := mid.lerp(hi, 0.25) if dark_table else hi
	var rim_c := mid.darkened(0.25) if dark_table else mid.lerp(hi, 0.35)
	for k in n:
		ci.draw_polygon(PackedVector2Array([hot, table[k], table[(k + 1) % n]]), PackedColorArray([centre_c, rim_c, rim_c]))
	ci.draw_polyline(CardGeometry.closed(table), Color(lo, 0.45), 1.0, true)
	ci.draw_polyline(CardGeometry.closed(girdle), GEM_EDGE, 1.0, true)
	if glint and span >= 2.5:
		sparkle(ci, c + light * span * 0.62, maxf(1.0, span * 0.2), 0.95)


## A soft shadow under the closed outline `pts` (around `c`), cast down `1.4 s` px.
static func drop_shadow(ci: CanvasItem, pts: PackedVector2Array, c: Vector2, s: float, a: float = 0.42) -> void:
	var off := Vector2(0, 1.4 * s)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + off)
	ci.draw_colored_polygon(CardGeometry.grow_pts(sh, c + off, 0.9 * s), Color(0, 0, 0, a))


## A white glint: a dot with a short horizontal flare, `a` its alpha.
static func sparkle(ci: CanvasItem, p: Vector2, r: float, a: float) -> void:
	ci.draw_circle(p, r * 0.55, Color(1, 1, 1, a), true, -1.0, true)
	ci.draw_line(p + Vector2(-r * 1.3, 0), p + Vector2(r * 1.3, 0), Color(1, 1, 1, a * 0.55), maxf(1.0, r * 0.35), true)
	ci.draw_line(p + Vector2(0, -r), p + Vector2(0, r), Color(1, 1, 1, a * 0.4), maxf(1.0, r * 0.3), true)


## The rim of `pts` stroked in `col`, strongest where it faces the light and fading out elsewhere:
## one continuous AA polyline with per-point alpha (separate segments left notches at the joins).
static func _lit_edge(ci: CanvasItem, pts: PackedVector2Array, c: Vector2, col: Color, w: float) -> void:
	var light := LIGHT.normalized()
	var cols := PackedColorArray()
	for p in pts:
		var lit := clampf(((p - c).normalized().dot(light) - 0.1) * 1.4, 0.0, 1.0)
		cols.append(Color(col, col.a * lit))
	cols.append(cols[0])
	ci.draw_polyline_colors(CardGeometry.closed(pts), cols, w, true)
