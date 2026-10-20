class_name DepthBox
extends StyleBox
## The engraved and lit surfaces of the frame hierarchy (design/design-review-2026-10-20.md 1.4.3)
## that a StyleBoxFlat cannot draw on its own: a two-tone engraved edge (dark top/left, light
## bottom/right), an inner shadow falling from the top edge, a 1 px top highlight and a short top
## gradient. Built by UIStyle.inset_style() (F3 ink well) and UIStyle.chip_style() (F4 chip / pill).
##
## Layers, back to front: `base` (a StyleBoxFlat: fill, border, outer shadow), the leather grain
## (`grain` > 0), the top gradient, the inner shadow, the engraved edge lines and the highlight.
## Content margins follow `base`.

## The flat box drawn first (fill, border, corner radius, outer drop shadow).
var base: StyleBoxFlat:
	set(v):
		base = v
		if v != null:
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				set_content_margin(side, v.get_content_margin(side))
		emit_changed()
## Inner shadow under the top edge: its depth (px) and darkest alpha (0 = none).
var inner_shadow_px: float = 0.0
var inner_shadow_a: float = 0.0
## Engraved edge: dark line on the top and left, light line on the bottom and right (alpha 0 = none).
var engrave_dark: Color = Color(0, 0, 0, 0)
var engrave_light: Color = Color(0, 0, 0, 0)
## 1 px highlight just inside the top edge (alpha 0 = none).
var top_highlight: Color = Color(0, 0, 0, 0)
## Vertical gradient over the top `top_band_px` px of the fill, from `top_band` to transparent.
var top_band: Color = Color(0, 0, 0, 0)
var top_band_px: float = 0.0
## Leather grain strength over the fill (0 = none).
var grain: float = 0.0


func _draw(ci: RID, rect: Rect2) -> void:
	if base == null:
		return
	base.draw(ci, rect)
	var bw := float(maxi(base.border_width_left, base.border_width_top))
	var inner := rect.grow(-bw)
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return
	var rad := maxf(0.0, float(base.corner_radius_top_left) - bw)
	var pts := UiSurface.round_rect_points(inner, rad)
	if grain > 0.0:
		var tex := UiSurface.texture(UiSurface.LEATHER)
		if tex != null:
			RenderingServer.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
			RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([UiSurface.tint(base.bg_color, grain * base.bg_color.a)]),
				UiSurface.uvs_for(pts, UiSurface.TILE_PX, Vector2(rect.position.x * 0.41 + 37.0, rect.position.y * 0.53 + 71.0)), tex.get_rid())
	if top_band.a > 0.0 and top_band_px > 0.0:
		_band(ci, inner, rad, top_band, top_band_px)
	if inner_shadow_a > 0.0 and inner_shadow_px > 0.0:
		_band(ci, inner, rad, Color(0, 0, 0, inner_shadow_a), inner_shadow_px)
	var x0 := inner.position.x + rad * 0.6
	var x1 := inner.end.x - rad * 0.6
	var y0 := inner.position.y + rad * 0.6
	var y1 := inner.end.y - rad * 0.6
	if engrave_dark.a > 0.0:
		RenderingServer.canvas_item_add_line(ci, Vector2(x0, inner.position.y + 0.5), Vector2(x1, inner.position.y + 0.5), engrave_dark, 1.0)
		RenderingServer.canvas_item_add_line(ci, Vector2(inner.position.x + 0.5, y0), Vector2(inner.position.x + 0.5, y1), engrave_dark, 1.0)
	if engrave_light.a > 0.0:
		RenderingServer.canvas_item_add_line(ci, Vector2(x0, inner.end.y - 0.5), Vector2(x1, inner.end.y - 0.5), engrave_light, 1.0)
		RenderingServer.canvas_item_add_line(ci, Vector2(inner.end.x - 0.5, y0), Vector2(inner.end.x - 0.5, y1), engrave_light, 1.0)
	if top_highlight.a > 0.0:
		RenderingServer.canvas_item_add_line(ci, Vector2(x0, inner.position.y + 0.5), Vector2(x1, inner.position.y + 0.5), top_highlight, 1.0)


# A band `px` deep under the top of `inner` (its own rounded-top polygon, so the vertex colours
# interpolate over the band only).
func _band(ci: RID, inner: Rect2, rad: float, col: Color, px: float) -> void:
	var h := minf(px, inner.size.y)
	var r := Rect2(inner.position, Vector2(inner.size.x, h))
	var pts := Ornate.rounded_points(r, minf(rad, h), 0.0)
	RenderingServer.canvas_item_add_polygon(ci, pts, band_colors(pts, r, col, h))


func _get_draw_rect(rect: Rect2) -> Rect2:
	if base == null:
		return rect
	var g := float(base.shadow_size) + maxf(absf(base.shadow_offset.x), absf(base.shadow_offset.y))
	return rect.grow_individual(base.expand_margin_left, base.expand_margin_top, base.expand_margin_right, base.expand_margin_bottom).grow(g)


## Per-point colours of a band `px` deep under the top of `rect`: `col` at the top edge, fading
## linearly to transparent at `px` (and below). Pure, so the shading is unit-testable.
static func band_colors(pts: PackedVector2Array, rect: Rect2, col: Color, px: float) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		var k := clampf((pts[i].y - rect.position.y) / maxf(px, 0.001), 0.0, 1.0)
		cols[i] = Color(col, col.a * (1.0 - k))
	return cols
