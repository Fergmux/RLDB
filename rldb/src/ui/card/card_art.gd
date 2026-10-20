class_name CardArt
extends RefCounted
## The card's art window: the card art image (cover-cropped; the art is square, like the windows) or,
## when there is none, a radial placeholder in the type / kind colour with a kind glyph; then the
## inner shadow and bronze border. Also draws the kind glyphs used by empty zone backgrounds.
##
## Art is found by card id alone: assets/art/cards/<id>.webp (imported by
## tools/godot/import_card_art.gd from the accepted "<id> - <name>.png" files).

const ART_DIR := "res://assets/art/cards/"
## Size (px) of the cached radial placeholder gradient texture.
const RADIAL_TEX_PX := 64

## Loaded art textures by path (null when the file does not exist).
static var _tex_cache := {}
## Radial placeholder textures by colour.
static var _radial_cache := {}


## Draws the art window into `rect` (card-face space).
static func draw(pt: CardPainter, rect: Rect2) -> void:
	var ci := pt.ci
	var view := pt.view
	var tex := _art_texture(view)
	if tex != null:
		var ts := tex.get_size()
		var ra := rect.size.x / rect.size.y
		var src: Rect2
		if ts.x / ts.y > ra:
			var w := ts.y * ra
			src = Rect2((ts.x - w) / 2.0, 0, w, ts.y)
		else:
			var h := ts.x / ra
			src = Rect2(0, (ts.y - h) / 2.0, ts.x, h)
		ci.draw_texture_rect_region(tex, rect, src)
	else:
		var base: Color = UIStyle.type_color(view.get("type", "")) if view.has("type") and view.get("race") != null else UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)
		ci.draw_texture_rect(_radial_tex(base), rect, false)
		draw_glyph(ci, _glyph_kind(view), rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, Color(1, 1, 1, 0.25))
	# inner shadow strip + defence tint + bronze border
	var sh := 7.0 * pt.s
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + sh), Vector2(rect.position.x, rect.position.y + sh)]),
		PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	ci.draw_rect(rect, Color(UIStyle.BRONZE, 0.95), false, maxf(1.0, 2.0 * pt.s), true)


## Kind glyph centred on `c` with radius `r`: "sword" (units), "star" (spells), "eye" (traps), "crown" (powers).
static func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.5, 0.12 * r)
	match kind:
		"sword":
			_draw_sword(ci, c, r, col)
		"star":
			var pts := PackedVector2Array()
			for i in 16:
				var a := -PI / 2.0 + float(i) * TAU / 16.0
				var rr := r if i % 2 == 0 else r * 0.42
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"eye":
			var top := PackedVector2Array()
			for i in 13:
				var x := lerpf(-1.0, 1.0, float(i) / 12.0)
				top.append(c + Vector2(x * r, -0.5 * r * (1.0 - x * x)))
			var lens := PackedVector2Array(top)
			for i in range(12, -1, -1):
				var x := lerpf(-1.0, 1.0, float(i) / 12.0)
				lens.append(c + Vector2(x * r, 0.5 * r * (1.0 - x * x)))
			ci.draw_colored_polygon(lens, col)
			ci.draw_circle(c, r * 0.26, Color(0, 0, 0, col.a * 1.2), true, -1.0, true)
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), col)
			ci.draw_circle(c, r * 0.3, Color(0, 0, 0, col.a * 1.2), true, -1.0, true)


## A pointed blade with a fuller, a curved cross-guard, a grip and a round pommel, `2 r` tall and centred
## on `c`. Each part is a filled polygon with a hairline rim of the same colour on top (the rim doubles
## the alpha on the very edge, which crisps the shape up and anti-aliases it); a faint halo surrounds it.
static func _draw_sword(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var rim_w := maxf(1.0, r * 0.035)
	var rim := Color(col, minf(1.0, col.a * 1.9))
	var blade := PackedVector2Array([Vector2(0, -1.0), Vector2(0.095, -0.80), Vector2(0.125, -0.06), Vector2(0.125, 0.17),
		Vector2(-0.125, 0.17), Vector2(-0.125, -0.06), Vector2(-0.095, -0.80)])
	var guard := PackedVector2Array([Vector2(-0.46, 0.185), Vector2(-0.30, 0.17), Vector2(0.30, 0.17), Vector2(0.46, 0.185),
		Vector2(0.52, 0.275), Vector2(0.43, 0.335), Vector2(0.17, 0.30), Vector2(-0.17, 0.30), Vector2(-0.43, 0.335), Vector2(-0.52, 0.275)])
	var grip := PackedVector2Array([Vector2(-0.06, 0.31), Vector2(0.06, 0.31), Vector2(0.06, 0.70), Vector2(-0.06, 0.70)])
	var parts: Array = [blade, guard, grip]
	# Soft halo first: the shape grown a little, as a wide, very faint stroke.
	for part in parts:
		var halo := _xf(part, c, r * 1.07)
		halo.append(halo[0])
		ci.draw_polyline(halo, Color(col, col.a * 0.5), maxf(2.0, r * 0.12), true)
	for part in parts:
		var pts := _xf(part, c, r)
		ci.draw_colored_polygon(pts, col)
		pts.append(pts[0])
		ci.draw_polyline(pts, rim, rim_w, true)
	# Pommel.
	var pc := c + Vector2(0, r * 0.83)
	ci.draw_circle(pc, r * 0.135, col, true, -1.0, true)
	ci.draw_arc(pc, r * 0.135, 0.0, TAU, 24, rim, rim_w, true)
	# The fuller: a fine groove down the blade.
	ci.draw_line(c + Vector2(0, -r * 0.72), c + Vector2(0, r * 0.10), Color(0, 0, 0, minf(0.4, col.a * 2.0)), maxf(1.0, r * 0.035), true)


static func _xf(pts: PackedVector2Array, c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * r)
	return out


## Resource path of card `id`'s art (whether or not it exists).
static func path_for(id: int) -> String:
	return ART_DIR + "%d.webp" % id


## True when card `id` has art.
static func has_art(id: int) -> bool:
	return ResourceLoader.exists(path_for(id))


## The art of the card in `view` (by its "id"), or null when it has none. Cached.
static func texture_for(view: Dictionary) -> Texture2D:
	return _art_texture(view)


static func _art_texture(view: Dictionary) -> Texture2D:
	if not view.has("id") or view.get("id") == null:
		return null
	var path := path_for(int(view["id"]))
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


static func _radial_tex(col: Color) -> Texture2D:
	var key := col.to_html()
	if _radial_cache.has(key):
		return _radial_cache[key]
	var g := Gradient.new()
	g.set_color(0, col.lightened(0.05))
	g.set_color(1, col.darkened(0.72))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(1.0, 0.45)
	t.width = RADIAL_TEX_PX
	t.height = RADIAL_TEX_PX
	_radial_cache[key] = t
	return t


static func _glyph_kind(view: Dictionary) -> String:
	match String(view.get("category", "")):
		"spell": return "star"
		"trap": return "eye"
		"power": return "crown"
	return "sword"
