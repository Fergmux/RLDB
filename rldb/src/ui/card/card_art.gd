class_name CardArt
extends RefCounted
## The card's art window: the card art image (cover-cropped) or, when there is none, a radial
## placeholder in the type / kind colour with a kind glyph; then the inner shadow and bronze border.
## Also draws the kind glyphs used by empty zone backgrounds.

const ART_DIR := "res://art/cards/"
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
			ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.55), col, w * 1.3, true)
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.05), c + Vector2(r * 0.5, r * 0.05), col, w, true)
			ci.draw_circle(c + Vector2(0, r * 0.75), r * 0.14, col, true, -1.0, true)
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


static func _art_texture(view: Dictionary) -> Texture2D:
	var img: String = String(view.get("art", {}).get("image", ""))
	if img == "":
		return null
	var path := ART_DIR + img
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
