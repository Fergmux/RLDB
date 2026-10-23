class_name TickMedallion
extends Control
## K2 (owner, 23 Oct): the "done" mark of a finished draft category (and of a taken reward): a round
## jewel in the house medallion style of the AP gems, the card jewels and RoundCloseButton. A gilded
## bevelled rim (CardJewel.setting) holds a faceted enamel disc tinted to `tint`: twelve crown facets
## round a domed table, each shaded by how much it faces the light (upper left, CardJewel.LIGHT).
## On it sits a crisp ivory tick over an engraved dark groove, then a specular arc and a glint.
## Presentation only (click-through), drawn with polygons and AA strokes: round and crisp at any size.
##
##     var done := TickMedallion.new(UIStyle.CATEGORY_COLORS["spell"], 22.0)

## Crown facets round the table.
const FACETS := 12
## Points on the round silhouette (a multiple of FACETS).
const ROUND_PTS := 48
## Table radius as a share of the enamel radius.
const TABLE_K := 0.6
## Tick ink and its engraved shadow.
const INK := Color(1.0, 0.975, 0.9)
const GROOVE := Color(0.0, 0.0, 0.0, 0.6)
## Tick polyline, in units of the enamel radius from the centre: the short and the long stroke.
const TICK := [Vector2(-0.46, 0.02), Vector2(-0.13, 0.34), Vector2(0.47, -0.34)]
## Below this diameter the glint is a bare dot instead of a flared sparkle.
const SPARKLE_MIN := 30.0

## Enamel colour (the category colour).
var tint: Color = UIStyle.GOOD:
	set(v):
		tint = v
		queue_redraw()
## Outer diameter of the gold rim (px). The control is that size plus room for the drop shadow.
var diameter: float = 22.0:
	set(v):
		diameter = v
		custom_minimum_size = Vector2(v, v) + Vector2(2, 3)
		queue_redraw()


func _init(col: Color = UIStyle.GOOD, px: float = 22.0) -> void:
	tint = col
	diameter = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Width of the gold rim for a medallion `d` px across.
static func rim_width(d: float) -> float:
	return maxf(2.0, d * 0.11)


## [hi, mid, lo] enamel shades of `col`: saturated and deep enough for the ivory tick to read.
static func enamel(col: Color) -> Array:
	var mid := Color.from_hsv(col.h, clampf(col.s * 1.1, 0.35, 0.95), clampf(col.v, 0.42, 0.78))
	return [mid.lightened(0.5), mid, mid.darkened(0.62)]


func _draw() -> void:
	var c := Vector2(size.x / 2.0, (size.y - 1.0) / 2.0)
	var r := diameter / 2.0
	var s := diameter / 22.0
	var outer := CardGeometry.poly(c, r, ROUND_PTS, -PI / 2.0)
	CardJewel.drop_shadow(self, outer, c, s, 0.5)
	var inner := CardJewel.setting(self, outer, c, rim_width(diameter), s)
	var ri := r - rim_width(diameter)
	_enamel(c, ri, inner)
	_tick(c, ri)
	# Specular arc along the lit upper-left curve of the dome, and a glint on it.
	draw_arc(c, ri * 0.8, PI * 1.08, PI * 1.42, 10, Color(1, 1, 1, 0.5), maxf(1.0, 0.9 * s), true)
	var glint := c + Vector2(-0.5, -0.52) * ri
	if diameter >= SPARKLE_MIN:
		CardJewel.sparkle(self, glint, maxf(1.0, ri * 0.16), 0.9)
	else:
		# Small: a bare dot (the sparkle's flare would cross the tick's short stroke).
		draw_circle(glint, maxf(0.8, ri * 0.11), Color(1, 1, 1, 0.85), true, -1.0, true)


## The faceted enamel disc filling `girdle` (radius `ri` around `c`).
func _enamel(c: Vector2, ri: float, girdle: PackedVector2Array) -> void:
	var sh := enamel(tint)
	var hi: Color = sh[0]
	var mid: Color = sh[1]
	var lo: Color = sh[2]
	var light := CardJewel.LIGHT.normalized()
	draw_colored_polygon(girdle, CardJewel.GEM_EDGE)
	var rim := CardGeometry.poly(c, ri - 0.5, ROUND_PTS, -PI / 2.0)
	var table := CardGeometry.poly(c, ri * TABLE_K, FACETS, -PI / 2.0)
	var per := ROUND_PTS / FACETS
	for k in FACETS:
		var pts := PackedVector2Array()
		for i in per + 1:
			pts.append(rim[(k * per + i) % ROUND_PTS])
		pts.append(table[(k + 1) % FACETS])
		pts.append(table[k])
		var dir := ((table[k] + table[(k + 1) % FACETS]) / 2.0 - c).normalized()
		var lit := clampf(0.5 + 0.5 * dir.dot(light), 0.0, 1.0)
		# Alternate facets a touch apart, so the cut reads even where the light is even.
		var fc := lo.lerp(mid, minf(1.0, lit * 1.5)).lerp(hi, maxf(0.0, lit * 1.6 - 0.95))
		if k % 2 == 1:
			fc = fc.darkened(0.08)
		draw_colored_polygon(pts, fc)
	# The domed table: a radial gradient brightest a little towards the light.
	var hot := c + light * ri * TABLE_K * 0.3
	var centre_c := mid.lerp(hi, 0.3)
	var rim_c := mid.darkened(0.18)
	for k in FACETS:
		draw_polygon(PackedVector2Array([hot, table[k], table[(k + 1) % FACETS]]), PackedColorArray([centre_c, rim_c, rim_c]))
	draw_polyline(CardGeometry.closed(table), Color(lo, 0.5), 1.0, true)
	draw_polyline(CardGeometry.closed(rim), Color(CardJewel.GEM_EDGE, 0.8), 1.0, true)


## The tick: a dark engraved groove a pixel under a crisp ivory stroke, with round ends and joint.
func _tick(c: Vector2, ri: float) -> void:
	var w := maxf(1.8, ri * 0.25)
	var pts := PackedVector2Array()
	for p in TICK:
		pts.append(c + (p as Vector2) * ri)
	var down := Vector2(0, maxf(1.0, w * 0.45))
	var groove := PackedVector2Array()
	for p in pts:
		groove.append(p + down)
	# Opaque (the enamel's deepest shade, darkened): overlapping caps would stack a translucent one.
	var lo: Color = enamel(tint)[2]
	var gc := Color(0, 0, 0).lerp(lo, 0.35)
	draw_polyline(groove, gc, w + 1.2, true)
	for p in groove:
		draw_circle(p, (w + 1.2) / 2.0, gc, true, -1.0, true)
	draw_polyline(pts, INK, w, true)
	for p in pts:
		draw_circle(p, w / 2.0, INK, true, -1.0, true)
