class_name TypeIcons
extends RefCounted
## Vector damage-type icons (F02-14). One cohesive set: light ivory outline (so the icons read on the
## dark card body, panels and pips — user feedback 2026-10-16), type-colour fill, a light gloss
## accent, drawn in a unit box of `radius` around `center`. Silhouettes differ so the type reads by
## shape and not by colour alone:
##   Water = drop, Fire = flame, Earth = mountain, Lightning = bolt, Heavenly = radiant sun,
##   Necrotic = skull, Physical = crossed blades, typeless = hollow neutral ring.
## Colours come from UIStyle.TYPE_COLORS; nothing here is baked into a texture.

## Light ivory outline around every silhouette.
const OUTLINE := Color(0.97, 0.93, 0.83, 0.95)
## Outer radius of a pip (disc + rim) relative to its `radius` argument.
const PIP_K := 1.18
## Near-opaque dark disc behind a pip's icon, and the icon size relative to the pip radius.
const PIP_BACKING := Color(0.04, 0.03, 0.03, 0.94)
const PIP_ICON_K := 0.86
## Dark inner detail colour of the skull (eyes, nose, teeth).
const SKULL_DARK := Color(0.06, 0.03, 0.1, 0.95)
## Mountain silhouette (unit coordinates), filled and then outlined over its shading.
const EARTH_PTS := [-1.0, 0.8, -0.58, -0.2, -0.36, 0.12, 0.08, -0.88, 1.0, 0.8]


## Draws the icon for `type` ("" or an unknown name = typeless ring) onto any CanvasItem.
static func draw_icon(ci: CanvasItem, type: String, center: Vector2, radius: float) -> void:
	var col := UIStyle.type_color(type)
	var ow := maxf(0.6, radius * 0.05)
	match type:
		"Water": _water(ci, center, radius, col, ow)
		"Fire": _fire(ci, center, radius, col, ow)
		"Earth": _earth(ci, center, radius, col, ow)
		"Lightning": _bolt(ci, center, radius, col, ow)
		"Heavenly": _sun(ci, center, radius, col, ow)
		"Necrotic": _skull(ci, center, radius, col, ow)
		"Physical": _blades(ci, center, radius, col, ow)
		_: _typeless(ci, center, radius, ow)


## Icon on a dark disc with a type-colour rim: used where the icon sits on busy art.
static func draw_pip(ci: CanvasItem, type: String, center: Vector2, radius: float) -> void:
	# Near-opaque dark backing + light rim so every type (dark Earth, pale Heavenly, yellow Lightning)
	# keeps contrast on any art.
	ci.draw_circle(center, radius * PIP_K, PIP_BACKING)
	ci.draw_arc(center, radius * PIP_K, 0.0, TAU, 28, UIStyle.type_color(type).lightened(0.25), maxf(0.7, radius * 0.04), true)
	draw_icon(ci, type, center, radius * PIP_ICON_K)


## Small Control that shows one type icon (for panels, deck builder rows, etc).
class TypeBadge extends Control:
	## Damage type shown ("" = typeless ring); setting it redraws.
	var type_name: String = "":
		set(v):
			type_name = v
			queue_redraw()

	## `px` is the square side; tags pass their text line height so the icon never makes the tag taller
	## than its text-only peers (F03-03). The icon is drawn from vectors into this box and scales to it.
	func _init(t: String = "", px: float = 22.0) -> void:
		type_name = t
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		TypeIcons.draw_icon(self, type_name, size / 2.0, minf(size.x, size.y) * 0.46)


# ---------------------------------------------------------------- helpers

## Flat [x0, y0, x1, y1, ...] in unit coordinates -> scaled points around `c`.
static func _pts(c: Vector2, r: float, flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(c + Vector2(float(flat[i]), float(flat[i + 1])) * r)
	return out


## Filled polygon with an OUTLINE border `ow` px wide (no border when ow is 0).
static func _fill(ci: CanvasItem, p: PackedVector2Array, fill: Color, ow: float) -> void:
	ci.draw_colored_polygon(p, fill)
	if ow > 0.0:
		var o := PackedVector2Array(p)
		o.append(p[0])
		ci.draw_polyline(o, OUTLINE, ow, true)


static func _water(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	var p := PackedVector2Array([c + Vector2(0, -1.0) * r])
	for i in 25:
		var a := deg_to_rad(-29.5 + 240.0 * float(i) / 24.0)
		p.append(c + (Vector2(cos(a), sin(a)) * 0.64 + Vector2(0, 0.3)) * r)
	_fill(ci, p, col, ow)
	# Lower-right shade + upper-left gloss.
	ci.draw_arc(c + Vector2(0, 0.3) * r, 0.44 * r, deg_to_rad(105.0), deg_to_rad(175.0), 8, Color(1, 1, 1, 0.65), maxf(1.0, r * 0.11), true)
	ci.draw_arc(c + Vector2(0, 0.3) * r, 0.5 * r, deg_to_rad(-20.0), deg_to_rad(70.0), 8, Color(0, 0, 0, 0.22), maxf(1.0, r * 0.12), true)


static func _fire(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	_fill(ci, _pts(c, r, [0.06, -1.0, 0.30, -0.64, 0.52, -0.28, 0.68, 0.14, 0.60, 0.58, 0.32, 0.88, 0.0, 0.98,
		-0.32, 0.88, -0.6, 0.58, -0.68, 0.12, -0.52, -0.22, -0.36, -0.02, -0.30, -0.42, -0.12, -0.72]), col, ow)
	_fill(ci, _pts(c, r, [0.0, -0.12, 0.24, 0.26, 0.30, 0.56, 0.0, 0.82, -0.30, 0.56, -0.24, 0.26]), col.lerp(Color("ffe27a"), 0.7), 0.0)


static func _earth(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	_fill(ci, _pts(c, r, EARTH_PTS), col, ow)
	ci.draw_colored_polygon(_pts(c, r, [0.08, -0.88, 1.0, 0.8, 0.1, 0.8, 0.0, -0.2]), col.darkened(0.32))
	ci.draw_colored_polygon(_pts(c, r, [0.08, -0.88, 0.34, -0.40, 0.18, -0.48, 0.06, -0.38, -0.06, -0.52]), col.lightened(0.6))
	var o := _pts(c, r, EARTH_PTS)
	o.append(o[0])
	ci.draw_polyline(o, OUTLINE, ow, true)


static func _bolt(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	_fill(ci, _pts(c, r, [0.30, -1.0, -0.58, 0.14, -0.08, 0.14, -0.36, 1.0, 0.62, -0.22, 0.10, -0.22, 0.58, -1.0]), col, ow)
	ci.draw_colored_polygon(_pts(c, r, [0.30, -0.88, 0.1, -0.5, 0.28, -0.5]), col.lightened(0.6))


static func _sun(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	var p := PackedVector2Array()
	for i in 16:
		var a := -PI / 2.0 + float(i) * TAU / 16.0
		p.append(c + Vector2(cos(a), sin(a)) * r * (1.0 if i % 2 == 0 else 0.5))
	_fill(ci, p, col, ow)
	ci.draw_circle(c, r * 0.44, Color("fff6cf"))
	ci.draw_arc(c, r * 0.44, 0.0, TAU, 20, col.darkened(0.45), maxf(1.0, ow * 0.9), true)
	ci.draw_arc(c, r * 0.24, 0.0, TAU, 14, Color(col.darkened(0.25), 0.8), maxf(1.0, ow * 0.6), true)


static func _skull(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	var p := PackedVector2Array()
	for i in 21:
		var a := deg_to_rad(125.0 + 290.0 * float(i) / 20.0)
		p.append(c + (Vector2(cos(a), sin(a)) * 0.72 + Vector2(0, -0.2)) * r)
	p.append(c + Vector2(0.40, 0.88) * r)
	p.append(c + Vector2(-0.40, 0.88) * r)
	_fill(ci, p, col, ow)
	var dark := SKULL_DARK
	ci.draw_circle(c + Vector2(-0.28, -0.14) * r, 0.2 * r, dark)
	ci.draw_circle(c + Vector2(0.28, -0.14) * r, 0.2 * r, dark)
	ci.draw_colored_polygon(_pts(c, r, [0.0, 0.08, 0.1, 0.3, -0.1, 0.3]), dark)
	# teeth ticks
	for dx in [-0.16, 0.0, 0.16]:
		ci.draw_line(c + Vector2(dx, 0.58) * r, c + Vector2(dx, 0.86) * r, Color(dark, 0.8), maxf(1.0, r * 0.07))


static func _blades(ci: CanvasItem, c: Vector2, r: float, col: Color, ow: float) -> void:
	_sword(ci, c, r, Vector2(-0.8, 0.8), Vector2(0.86, -0.9), col, ow)
	_sword(ci, c, r, Vector2(0.8, 0.8), Vector2(-0.86, -0.9), col, ow)


## One blade from `hilt` to `tip` (unit coordinates): outlined handle and guard, then the blade.
static func _sword(ci: CanvasItem, c: Vector2, r: float, hilt: Vector2, tip: Vector2, col: Color, ow: float) -> void:
	var d := (tip - hilt).normalized()
	var n := Vector2(-d.y, d.x)
	var g := hilt + d * 0.42
	var hw := 0.16
	var dark := col.darkened(0.45)
	# handle + guard (outline pass then fill pass)
	var hw_px := maxf(1.5, r * 0.2)
	ci.draw_line(c + hilt * r, c + g * r, OUTLINE, hw_px + ow * 2.0)
	ci.draw_line(c + (g - n * 0.36) * r, c + (g + n * 0.36) * r, OUTLINE, hw_px * 0.85 + ow * 2.0)
	ci.draw_line(c + hilt * r, c + g * r, dark, hw_px)
	var blade := PackedVector2Array([c + (g + n * hw) * r, c + (tip - d * 0.24 + n * hw) * r, c + tip * r, c + (tip - d * 0.24 - n * hw) * r, c + (g - n * hw) * r])
	_fill(ci, blade, col.lightened(0.18), ow)
	ci.draw_line(c + (g - n * 0.36) * r, c + (g + n * 0.36) * r, col.darkened(0.15), hw_px * 0.85)
	ci.draw_line(c + (g + d * 0.1) * r, c + (tip - d * 0.3) * r, Color(1, 1, 1, 0.45), maxf(1.0, r * 0.06))


## Hollow neutral ring for typeless.
static func _typeless(ci: CanvasItem, c: Vector2, r: float, ow: float) -> void:
	var col := UIStyle.type_color("").lightened(0.2)
	var rr := r * 0.66
	ci.draw_arc(c, rr, 0.0, TAU, 32, OUTLINE, r * 0.3 + ow * 2.0, true)
	ci.draw_arc(c, rr, 0.0, TAU, 32, col, r * 0.3, true)
