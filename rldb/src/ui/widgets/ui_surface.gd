class_name UiSurface
extends RefCounted
## Material surfaces for the flat UI (2026-10-18): leather, pebbled leather, wood grain and brushed
## metal relief maps (assets/art/materials/, baked from CC0 ambientCG scans by
## tools/godot/bake_ui_materials.gd) laid over a surface's own colour. A relief map averages 0.5,
## and it is drawn tinted with twice the surface colour, so the colour and palette stay as they were
## and only the grain is added; `strength` (0..1) is how much grain.
##
## Two ways in:
##   - SurfaceBox, a StyleBox wrapping a StyleBoxFlat (buttons, panels, theme styles): the grain
##     is clipped to the flat box's rounded fill, inside its border.
##   - UiSurface.draw_round(...) for anything drawn by hand (cards, plates).
## Both need texture repeat on the canvas item they draw on (SurfaceBox sets it; for draw_round set
## `texture_repeat = TEXTURE_REPEAT_ENABLED` on the CanvasItem).

const DIR := "res://assets/art/materials/"
## Material names.
const LEATHER := "leather"
const PEBBLE := "pebble"
const WOOD := "wood"
const METAL := "metal"
## Screen px one relief tile spans at UI scale 1 (texture is 512 px: shown at about native size).
const TILE_PX := 384.0
## Segments per rounded corner of the grain polygon.
const CORNER_SEGS := 6

static var _tex := {}


## The relief texture of material `name` (null when missing; the surface then stays flat).
static func texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := DIR + name + ".png"
		_tex[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[name]


## Grain of material `name` over the rounded rect `rect` (corner radius `radius`) whose colour is
## `base`, at `strength`. `tile` is the px one tile spans, `offset` shifts the grain (so neighbouring
## surfaces do not show the same pattern). Draws nothing when the texture is missing.
static func draw_round(ci: CanvasItem, rect: Rect2, radius: float, name: String, base: Color, strength: float, tile: float = TILE_PX, offset: Vector2 = Vector2.ZERO) -> void:
	var tex := texture(name)
	if tex == null or strength <= 0.0 or rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var pts := round_rect_points(rect, radius)
	ci.draw_polygon(pts, PackedColorArray([tint(base, strength)]), uvs_for(pts, tile, offset), tex)


## Grain of material `name` over the arbitrary polygon `pts` (tabs, joined plates), as draw_round.
## The grain is laid by screen position, so polygons drawn on one canvas item show one seamless grain.
static func draw_poly(ci: CanvasItem, pts: PackedVector2Array, name: String, base: Color, strength: float, tile: float = TILE_PX, offset: Vector2 = Vector2.ZERO) -> void:
	var tex := texture(name)
	if tex == null or strength <= 0.0 or pts.size() < 3:
		return
	ci.draw_polygon(pts, PackedColorArray([tint(base, strength)]), uvs_for(pts, tile, offset), tex)


## Draw colour that turns a 0.5-mean relief map into `base` with grain: twice the colour, alpha = strength.
static func tint(base: Color, strength: float) -> Color:
	return Color(base.r * 2.0, base.g * 2.0, base.b * 2.0, clampf(strength, 0.0, 1.0))


## Texture coordinates for `pts`: one tile per `tile` px, shifted by `offset` px.
static func uvs_for(pts: PackedVector2Array, tile: float, offset: Vector2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(pts.size())
	for i in pts.size():
		uvs[i] = (pts[i] + offset) / tile
	return uvs


## Outline of a rounded rect (clockwise from the top-left corner's arc).
static func round_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) / 2.0)
	var pts := PackedVector2Array()
	if r < 0.5:
		return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var centres := [Vector2(rect.position.x + r, rect.position.y + r), Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r), Vector2(rect.position.x + r, rect.end.y - r)]
	for k in 4:
		var a0 := PI + float(k) * PI / 2.0
		for i in CORNER_SEGS + 1:
			var a := a0 + float(i) / float(CORNER_SEGS) * PI / 2.0
			pts.append(centres[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## The StyleBoxFlat under `sb` (itself, or a SurfaceBox's flat box), or null.
static func flat_of(sb: StyleBox) -> StyleBoxFlat:
	if sb is StyleBoxFlat:
		return sb
	if sb is SurfaceBox:
		return (sb as SurfaceBox).flat
	return null


## A copy of `sb` (StyleBoxFlat or SurfaceBox) with its flat box changed by `edit` (a Callable
## taking the copied StyleBoxFlat); the grain is kept. Returns `sb` unchanged for other boxes.
static func restyled(sb: StyleBox, edit: Callable) -> StyleBox:
	var f := flat_of(sb)
	if f == null:
		return sb
	var d := f.duplicate() as StyleBoxFlat
	edit.call(d)
	if sb is SurfaceBox:
		var o := sb as SurfaceBox
		return box(d, o.material_name, o.strength, o.sheen)
	return d


## Full-rect Control filled with `base` and the grain of material `name` (screen backdrops).
class Fill extends Control:
	var base: Color
	var material_name: String
	var strength: float
	var tile: float

	func _init(fill: Color, name: String, grain: float, tile_px: float = UiSurface.TILE_PX) -> void:
		base = fill
		material_name = name
		strength = grain
		tile = tile_px
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, base)
		UiSurface.draw_round(self, r, 0.0, material_name, base, strength, tile)


## A SurfaceBox around `flat` with material `name` at `strength`, and a top-lit `sheen` (0 = none).
static func box(flat: StyleBoxFlat, name: String, strength: float, sheen: float = 0.0) -> SurfaceBox:
	var b := SurfaceBox.new()
	b.flat = flat
	b.material_name = name
	b.strength = strength
	b.sheen = sheen
	return b


## Per-point colours of a soft top light over `pts` (inside `rect`): white at alpha `sheen` along the
## top edge, fading linearly to nothing at the bottom (polished metal).
static func sheen_colors(pts: PackedVector2Array, rect: Rect2, sheen: float) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var t := clampf((pts[i].y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
		cols[i] = Color(1, 1, 1, sheen * (1.0 - t))
	return cols


## StyleBox drawing a StyleBoxFlat (shadow, fill, border, as configured) with the grain of a
## material on its fill. Content margins follow the flat box.
class SurfaceBox extends StyleBox:
	## The flat box drawn first; its fill colour tints the grain.
	var flat: StyleBoxFlat:
		set(v):
			flat = v
			if v != null:
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					set_content_margin(side, v.get_content_margin(side))
			emit_changed()
	## Material name (UiSurface.LEATHER ...).
	var material_name: String = UiSurface.LEATHER
	## Grain strength 0..1.
	var strength: float = 0.3
	## Px one tile spans.
	var tile: float = UiSurface.TILE_PX
	## Alpha of the soft top light over the fill (0 = none): reads as polished rather than raw metal.
	var sheen: float = 0.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if flat == null:
			return
		flat.draw(to_canvas_item, rect)
		var tex := UiSurface.texture(material_name)
		if tex == null or strength <= 0.0 or not flat.draw_center or flat.bg_color.a <= 0.01:
			return
		var inner := Rect2(rect.position + Vector2(flat.border_width_left, flat.border_width_top),
			rect.size - Vector2(flat.border_width_left + flat.border_width_right, flat.border_width_top + flat.border_width_bottom))
		if inner.size.x < 1.0 or inner.size.y < 1.0:
			return
		var rad := maxf(0.0, float(flat.corner_radius_top_left) - float(maxi(flat.border_width_left, flat.border_width_top)))
		var pts := UiSurface.round_rect_points(inner, rad)
		RenderingServer.canvas_item_set_default_texture_repeat(to_canvas_item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([UiSurface.tint(flat.bg_color, strength * flat.bg_color.a)]),
			UiSurface.uvs_for(pts, tile, Vector2(rect.position.x * 0.37 + 91.0, rect.position.y * 0.61 + 53.0)), tex.get_rid())
		if sheen > 0.0:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, UiSurface.sheen_colors(pts, inner, sheen * flat.bg_color.a))

	func _get_draw_rect(rect: Rect2) -> Rect2:
		if flat == null:
			return rect
		var g := float(flat.shadow_size) + maxf(absf(flat.shadow_offset.x), absf(flat.shadow_offset.y))
		return rect.grow_individual(flat.expand_margin_left, flat.expand_margin_top, flat.expand_margin_right, flat.expand_margin_bottom).grow(g)
