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


## H16: the art window's rim, a dark bronze well edge (was a bright square BRONZE rect that cut the
## kind-coloured outer frame's rounded corners off), and the thin lit lip just inside it.
const RIM := Color(0.13, 0.085, 0.045, 0.96)
const RIM_LIP := Color(0.83, 0.65, 0.29, 0.22)
## H20: the window's inner shadow, [inset px (base units), alpha] rings from the rim inwards.
const INNER_SHADOW := [[0.0, 0.5], [1.4, 0.3], [2.8, 0.15], [4.4, 0.06]]


## Draws the art window into `rect` (card-face space) with its corners rounded to `radius` px (H16:
## concentric with the frame's corner, so the window never cuts the outer border off).
static func draw(pt: CardPainter, rect: Rect2, radius: float = 0.0) -> void:
	var ci := pt.ci
	var view := pt.view
	var tex := _art_texture(view)
	var pts := CardGeometry.round_rect_pts(rect, radius)
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
		ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), _uvs(pts, rect, Rect2(src.position / ts, src.size / ts)), tex)
	else:
		var base: Color = UIStyle.type_color(view.get("type", "")) if view.has("type") and view.get("race") != null else UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), UIStyle.BRONZE)
		ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), _uvs(pts, rect, Rect2(0, 0, 1, 1)), _radial_tex(base))
		draw_glyph(ci, _glyph_kind(view), rect.get_center(), minf(rect.size.x, rect.size.y) * 0.34, Color(1, 1, 1, 0.25))
	_sheen(ci, pts, rect, String(view.get("category", "")) in FOIL_CATS)
	# H20: a recessed window: a soft shadow falling in from the rim (heavier at the top: light from
	# above), then the dark rim and a faint lit lip on the lower edge.
	var s := pt.s
	for ring in INNER_SHADOW:
		var d := float(ring[0]) * s
		var rr := Rect2(rect.position + Vector2(d, d * 1.5), rect.size - Vector2(2.0 * d, d * 1.8))
		pt.ring(Color(0, 0, 0, float(ring[1])), maxf(1.0, 1.5 * s), rr, maxf(1.0, radius - d * 0.5))
	pt.ring(RIM, maxf(1.0, 1.6 * s), rect, maxf(1.0, radius))
	ci.draw_line(Vector2(rect.position.x + radius, rect.end.y - 1.6 * s), Vector2(rect.end.x - radius, rect.end.y - 1.6 * s), RIM_LIP, maxf(1.0, 0.6 * s), true)


## H20 foil: the kinds whose art carries the stronger prismatic foil (the summoned-by-cost units);
## every other card gets a faint glass sheen. Static (no per-frame redraw).
const FOIL_CATS := ["fusion", "ritual", "arcane"]
## [band centre along the diagonal (0 = top-left corner, 1 = bottom-right), half-width share,
## peak alpha, colour] of the sheen bands; FOIL adds a second, tinted pair.
const SHEEN := [[0.3, 0.13, 0.14, Color(1, 0.97, 0.9)]]
const FOIL := [[0.28, 0.15, 0.36, Color(0.85, 0.95, 1.0)], [0.37, 0.05, 0.28, Color(1.0, 0.85, 0.98)], [0.7, 0.07, 0.16, Color(1.0, 0.98, 0.85)]]
## Sheen geometry by window size and corner (the art windows come in a few sizes).
static var _sheen_cache := {}
const SHEEN_CACHE_MAX := 64


## Diagonal sheen bands over the art window outline `pts` (clipped to it), lighter in the middle of
## each band and fading to nothing at its edges.
static func _sheen(ci: CanvasItem, pts: PackedVector2Array, rect: Rect2, foil: bool) -> void:
	var key := "%d|%d|%d|%d|%s" % [roundi(rect.size.x * 4.0), roundi(rect.size.y * 4.0), roundi(pts[0].x * 4.0 - rect.position.x * 4.0), pts.size(), foil]
	if not _sheen_cache.has(key):
		if _sheen_cache.size() > SHEEN_CACHE_MAX:
			_sheen_cache.clear()
		var local := PackedVector2Array()
		for p in pts:
			local.append(p - rect.position)
		var built := []
		for b in (FOIL if foil else SHEEN):
			built.append_array(_band(local, rect.size, float(b[0]), float(b[1]), float(b[2]), b[3]))
		_sheen_cache[key] = built
	for part in _sheen_cache[key]:
		var poly: PackedVector2Array = part[0]
		var moved := PackedVector2Array()
		for p in poly:
			moved.append(p + rect.position)
		ci.draw_polygon(moved, part[1])


## One sheen band, as [polygon, colours] pieces clipped to `outline` (window-local coordinates).
static func _band(outline: PackedVector2Array, sz: Vector2, at: float, half: float, a: float, col: Color) -> Array:
	var diag := (sz.x + sz.y)
	var c := diag * at
	var hw := diag * half
	var out := []
	# Two halves so the alpha peaks on the band's centre line (x + y = c) and fades to its edges.
	for side in [-1.0, 1.0]:
		var lo := c if side > 0.0 else c - hw
		var hi := c + hw if side > 0.0 else c
		var band := PackedVector2Array([Vector2(lo, 0), Vector2(hi, 0), Vector2(hi - sz.y, sz.y), Vector2(lo - sz.y, sz.y)])
		for piece in Geometry2D.intersect_polygons(band, outline):
			var cols := PackedColorArray()
			for p in piece:
				var t := clampf(1.0 - absf(p.x + p.y - c) / maxf(0.001, hw), 0.0, 1.0)
				cols.append(Color(col, a * t * t))
			out.append([piece, cols])
	return out


## Texture coordinates of the outline `pts` inside `rect`, mapped onto the texture region `uv` (0..1).
static func _uvs(pts: PackedVector2Array, rect: Rect2, uv: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(uv.position + (p - rect.position) / rect.size * uv.size)
	return out


## Kind glyph centred on `c` with radius `r`: "sword" (units), "star" (spells), "eye" (traps), "crown" (powers).
static func draw_glyph(ci: Object, kind: String, c: Vector2, r: float, col: Color) -> void:
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
			_draw_eye(ci, c, r, col)
		"crown":
			_draw_crown(ci, c, r, col)


## A pointed blade with a fuller, a curved cross-guard, a grip and a round pommel, `2 r` tall and centred
## on `c`. Each part is a filled polygon with a hairline rim of the same colour on top (the rim doubles
## the alpha on the very edge, which crisps the shape up and anti-aliases it); a faint halo surrounds it.
static func _draw_sword(ci: Object, c: Vector2, r: float, col: Color) -> void:
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



## H13 (owner feedback 2026-10-21): the Trap mark in the sword's style. A pointed almond eye (`1.84 r`
## wide), an iris ring around a cut slit pupil with a glint, and a fine brow line above it. Each part is a
## filled polygon with a hairline rim of the same colour and a faint halo, as in _draw_sword.
static func _draw_eye(ci: Object, c: Vector2, r: float, col: Color) -> void:
	var rim_w := maxf(1.0, r * 0.035)
	var rim := Color(col, minf(1.0, col.a * 1.9))
	var cut := Color(0, 0, 0, minf(0.4, col.a * 2.0))
	var lens := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var x := lerpf(-1.0, 1.0, float(i) / float(steps))
		lens.append(Vector2(x * 0.92, -0.40 * pow(1.0 - x * x, 0.8)))
	for i in range(steps - 1, 0, -1):
		var x := lerpf(-1.0, 1.0, float(i) / float(steps))
		lens.append(Vector2(x * 0.92, 0.40 * pow(1.0 - x * x, 0.8)))
	var brow := PackedVector2Array()
	for i in 11:
		var x := lerpf(-0.62, 0.62, float(i) / 10.0)
		brow.append(Vector2(x, -0.56 - 0.12 * (1.0 - x * x / 0.3844)))
	var halo := _xf(lens, c, r * 1.07)
	halo.append(halo[0])
	ci.draw_polyline(halo, Color(col, col.a * 0.5), maxf(2.0, r * 0.12), true)
	ci.draw_polyline(_xf(brow, c, r), Color(col, col.a * 0.5), maxf(2.0, r * 0.12), true)
	var pts := _xf(lens, c, r)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, rim, rim_w, true)
	ci.draw_polyline(_xf(brow, c, r), rim, maxf(1.0, r * 0.05), true)
	# The iris: a cut disc inside a lit ring, the slit pupil in it and a glint.
	ci.draw_circle(c, r * 0.27, cut, true, -1.0, true)
	ci.draw_arc(c, r * 0.27, 0.0, TAU, 28, rim, maxf(1.0, r * 0.05), true)
	var slit := PackedVector2Array([Vector2(0, -0.22), Vector2(0.065, -0.08), Vector2(0.075, 0.0), Vector2(0.065, 0.08),
		Vector2(0, 0.22), Vector2(-0.065, 0.08), Vector2(-0.075, 0.0), Vector2(-0.065, -0.08)])
	var sp := _xf(slit, c, r)
	ci.draw_colored_polygon(sp, col)
	sp.append(sp[0])
	ci.draw_polyline(sp, rim, rim_w, true)
	ci.draw_circle(c + Vector2(r * 0.12, -r * 0.11), r * 0.045, rim, true, -1.0, true)


## H13: the Power mark in the sword's style. A three-pointed crown (`1.4 r` wide) on a band split from
## the points by a fine groove, a pearl on every point and a cut jewel in the band. Filled parts with a
## hairline rim and a faint halo, as in _draw_sword.
static func _draw_crown(ci: Object, c: Vector2, r: float, col: Color) -> void:
	var rim_w := maxf(1.0, r * 0.035)
	var rim := Color(col, minf(1.0, col.a * 1.9))
	var cut := Color(0, 0, 0, minf(0.4, col.a * 2.0))
	var body := PackedVector2Array([Vector2(-0.58, 0.62), Vector2(0.58, 0.62), Vector2(0.62, 0.30), Vector2(0.72, -0.34),
		Vector2(0.30, 0.02), Vector2(0.0, -0.52), Vector2(-0.30, 0.02), Vector2(-0.72, -0.34), Vector2(-0.62, 0.30)])
	var pearls := [[Vector2(-0.72, -0.45), 0.095], [Vector2(0.0, -0.64), 0.11], [Vector2(0.72, -0.45), 0.095]]
	var halo := _xf(body, c, r * 1.07)
	halo.append(halo[0])
	ci.draw_polyline(halo, Color(col, col.a * 0.5), maxf(2.0, r * 0.12), true)
	var pts := _xf(body, c, r)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, rim, rim_w, true)
	for pe in pearls:
		var pc: Vector2 = c + (pe[0] as Vector2) * r
		var pr: float = float(pe[1]) * r
		ci.draw_circle(pc, pr, col, true, -1.0, true)
		ci.draw_arc(pc, pr, 0.0, TAU, 20, rim, rim_w, true)
	# The groove between the band and the points, and the band's cut jewel (a small lozenge).
	ci.draw_line(c + Vector2(-0.6, 0.34) * r, c + Vector2(0.6, 0.34) * r, cut, maxf(1.0, r * 0.035), true)
	var gem := _xf(PackedVector2Array([Vector2(0, 0.38), Vector2(0.11, 0.48), Vector2(0, 0.58), Vector2(-0.11, 0.48)]), c, r)
	ci.draw_colored_polygon(gem, cut)
	gem.append(gem[0])
	ci.draw_polyline(gem, rim, rim_w, true)

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


## L11: the card id whose art a card view shows: `art_id` (a unit on the Field showing a copied
## unit's art, MatchView.card_view) when present, else the card's own id.
static func art_id_of(view: Dictionary) -> int:
	var a = view.get("art_id")
	if a != null:
		return int(a)
	return int(view.get("id", -1))


static func _art_texture(view: Dictionary) -> Texture2D:
	if not view.has("id") or view.get("id") == null:
		return null
	var path := path_for(art_id_of(view))
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
