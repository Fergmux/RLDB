class_name FrameBox
extends StyleBox
## The F2 sidebar / plate frame of the frame hierarchy (design/design-review-2026-10-20.md 1.4.3,
## findings #17 and #109): a gilded bronze bevel (a 1 px gold outer line, a 1 px dark inner lip and a
## faint top bevel highlight), a tooled-leather body with a soft vignette (edges about 20% darker),
## gold corner rivets and the depth-1 drop shadow (0 3 px, 8 px, #000 50%).
##
## Live parameters for the plates: `rim` (the outer line colour: bronze for an inactive plate, gold for
## the active one, ember while low on HP), `glow` (an outer glow, the active plate's breathing rim) and
## `sweep` (0..1 position of a short GOLD_HI highlight travelling along the top edge; < 0 = none).
## Changing one emits `changed`, so the owning Control redraws.
##
## Build one with FrameBox.make(); the content padding follows the spacing tokens (UIStyle.pad works
## on it like on any StyleBox).

## Outer gilded line at rest (GOLD 70%) and the dark inner lip.
const RIM := Color(0.831, 0.651, 0.29, 0.7)
const LIP := Color(0, 0, 0, 0.6)
## Top bevel highlight just inside the lip.
const BEVEL := Color(0.941, 0.812, 0.478, 0.16)
## Vignette darkness at the edges and its depth (px).
const VIGNETTE_A := 0.2
const VIGNETTE_PX := 14.0
## Rivet radius (px) and its inset from the frame's corner.
const RIVET_R := 2.0
const RIVET_INSET := 6.0
## Top sweep highlight length (px).
const SWEEP_LEN := 70.0

## Body fill (the leather's base colour).
var fill: Color = Color(UIStyle.PANEL, 0.96):
	set(v):
		fill = v
		emit_changed()
## Outer rim colour.
var rim: Color = RIM:
	set(v):
		if v == rim:
			return
		rim = v
		emit_changed()
## Outer glow colour (alpha 0 = none) and size.
var glow: Color = Color(0, 0, 0, 0):
	set(v):
		if v == glow:
			return
		glow = v
		emit_changed()
var glow_px: float = 10.0
## Top sweep position 0..1 (< 0 = none).
var sweep: float = -1.0:
	set(v):
		if is_equal_approx(v, sweep):
			return
		sweep = v
		emit_changed()
## Corner radius (px).
var radius: int = 8
## Draw the corner rivets.
var rivets: bool = true
## Leather grain strength.
var grain: float = UIStyle.PANEL_GRAIN


## A frame with `fill`, padded `token` horizontally and `v_token` vertically (spacing tokens).
static func make(p_fill: Color = Color(UIStyle.PANEL, 0.96), token: String = "lg", v_token: String = "") -> FrameBox:
	var f := FrameBox.new()
	f.fill = p_fill
	UIStyle.pad(f, token, v_token)
	return f


func _draw(ci: RID, rect: Rect2) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = fill
	shadow.set_corner_radius_all(radius)
	var d: Array = UIStyle.DEPTH[UIStyle.DEPTH_PLATE]
	if glow.a > 0.0:
		shadow.shadow_color = glow
		shadow.shadow_size = int(glow_px)
		shadow.shadow_offset = Vector2(0, 1)
	else:
		shadow.shadow_color = d[2]
		shadow.shadow_size = int(d[1])
		shadow.shadow_offset = Vector2(0, float(d[0]))
	shadow.anti_aliasing = true
	shadow.draw(ci, rect)
	var inner := rect.grow(-2.0)
	var irad := maxf(0.0, float(radius) - 2.0)
	var pts := UiSurface.round_rect_points(inner, irad)
	var tex := UiSurface.texture(UiSurface.LEATHER)
	if tex != null and grain > 0.0:
		RenderingServer.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([UiSurface.tint(fill, grain * fill.a)]),
			UiSurface.uvs_for(pts, UiSurface.TILE_PX, Vector2(rect.position.x * 0.43 + 17.0, rect.position.y * 0.57 + 29.0)), tex.get_rid())
	_vignette(ci, inner, irad)
	# The gilded bevel: the outer line, the dark lip inside it and a faint top highlight.
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.set_corner_radius_all(radius)
	edge.set_border_width_all(1)
	edge.border_color = rim
	edge.anti_aliasing = true
	edge.draw(ci, rect)
	var lip := StyleBoxFlat.new()
	lip.draw_center = false
	lip.set_corner_radius_all(maxi(0, radius - 1))
	lip.set_border_width_all(1)
	lip.border_color = LIP
	lip.anti_aliasing = true
	lip.draw(ci, rect.grow(-1.0))
	var x0 := inner.position.x + irad
	var x1 := inner.end.x - irad
	RenderingServer.canvas_item_add_line(ci, Vector2(x0, inner.position.y + 0.5), Vector2(x1, inner.position.y + 0.5), BEVEL, 1.0)
	if sweep >= 0.0 and x1 - x0 > 4.0:
		var cx := lerpf(x0 - SWEEP_LEN * 0.5, x1 + SWEEP_LEN * 0.5, clampf(sweep, 0.0, 1.0))
		var a := maxf(x0, cx - SWEEP_LEN * 0.5)
		var b := minf(x1, cx + SWEEP_LEN * 0.5)
		if b > a:
			var hi := UIStyle.GOLD_HI
			var y := rect.position.y + 0.5
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2(a, y), Vector2(cx, y), Vector2(b, y)]),
				PackedColorArray([Color(hi, 0.0), Color(hi, 0.95), Color(hi, 0.0)]), 1.5, true)
	if rivets and rect.size.x > RIVET_INSET * 4.0 and rect.size.y > RIVET_INSET * 4.0:
		var k := RIVET_INSET + float(radius) * 0.3
		for p in [Vector2(rect.position.x + k, rect.position.y + k), Vector2(rect.end.x - k, rect.position.y + k),
				Vector2(rect.position.x + k, rect.end.y - k), Vector2(rect.end.x - k, rect.end.y - k)]:
			RenderingServer.canvas_item_add_circle(ci, p + Vector2(0, 0.6), RIVET_R + 0.6, Color(0, 0, 0, 0.55))
			RenderingServer.canvas_item_add_circle(ci, p, RIVET_R, Color(rim.lerp(UIStyle.GOLD, 0.5), 0.95))
			RenderingServer.canvas_item_add_circle(ci, p + Vector2(-0.6, -0.6), RIVET_R * 0.45, Color(1, 0.95, 0.8, 0.75))


# Edges about 20% darker: four bands fading inwards (the corners are covered by the rounded shadow).
func _vignette(ci: RID, r: Rect2, rad: float) -> void:
	var px := minf(VIGNETTE_PX, minf(r.size.x, r.size.y) / 3.0)
	if px < 2.0:
		return
	var dark := Color(0, 0, 0, VIGNETTE_A)
	var clear := Color(0, 0, 0, 0)
	var y0 := r.position.y + rad
	var y1 := r.end.y - rad
	var x0 := r.position.x + rad
	var x1 := r.end.x - rad
	# top, bottom (between the corner arcs), left, right
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(x0, r.position.y), Vector2(x1, r.position.y), Vector2(x1, r.position.y + px), Vector2(x0, r.position.y + px)]),
		PackedColorArray([dark, dark, clear, clear]))
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(x0, r.end.y - px), Vector2(x1, r.end.y - px), Vector2(x1, r.end.y), Vector2(x0, r.end.y)]),
		PackedColorArray([clear, clear, dark, dark]))
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.position.x + px, y0), Vector2(r.position.x + px, y1), Vector2(r.position.x, y1)]),
		PackedColorArray([dark, clear, clear, dark]))
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(r.end.x - px, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.end.x - px, y1)]),
		PackedColorArray([clear, dark, dark, clear]))


func _get_draw_rect(rect: Rect2) -> Rect2:
	var d: Array = UIStyle.DEPTH[UIStyle.DEPTH_PLATE]
	return rect.grow(maxf(glow_px, float(d[1])) + float(d[0]) + 2.0)
