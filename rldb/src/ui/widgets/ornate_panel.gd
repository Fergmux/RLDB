class_name OrnatePanel
extends PanelContainer
## Layered panel: the theme box (rounded, gold or bronze rim, drop shadow) under a vertical
## gradient, an inner hairline frame, a top sheen and optional corner flourishes. Children sit on
## top. Set the look through the vars; change `accent` to recolour the rim and flourishes.

## Rim and flourish colour.
var accent: Color = UIStyle.GOLD:
	set(v):
		accent = v
		queue_redraw()
## Gradient top / bottom (drawn inside the rim).
var top_col: Color = Color(0.13, 0.105, 0.08, 1.0)
var bottom_col: Color = Color(0.06, 0.05, 0.042, 1.0)
## Corner flourishes on / off, and their arm length.
var flourish: bool = true
var arm: float = 22.0
## Inset of the hairline frame from the edge (0 hides it).
var frame_inset: float = 6.0
var _box: StyleBoxFlat


## `radius` rounds the rim; `margin` is the content margin on every side.
func _init(radius: int = 12, margin: int = 16) -> void:
	_box = UIStyle.flat(Color(0, 0, 0, 0), accent, 2, radius)
	for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_box.set_content_margin(s, margin)
	_box.shadow_color = Color(0, 0, 0, 0.6)
	_box.shadow_size = 18
	_box.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", _box)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the leather grain tiles (UiSurface)


## The underlying rim style (to tweak border, shadow or margins).
func box() -> StyleBoxFlat:
	return _box


func _draw() -> void:
	_box.border_color = accent
	var r := Rect2(Vector2.ZERO, size)
	var inset := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	var rad := float(_box.corner_radius_top_left)
	# Gradient body: a centre block plus a rounded-corner-safe top and bottom band.
	Ornate.vgradient(self, Rect2(inset.position + Vector2(0, rad), inset.size - Vector2(0, rad * 2.0)), top_col.lerp(bottom_col, rad / maxf(size.y, 1.0)), bottom_col.lerp(top_col, rad / maxf(size.y, 1.0)))
	draw_rect(Rect2(inset.position + Vector2(rad, 0), Vector2(inset.size.x - rad * 2.0, rad)), top_col)
	draw_rect(Rect2(inset.position + Vector2(rad, inset.size.y - rad), Vector2(inset.size.x - rad * 2.0, rad)), bottom_col)
	UiSurface.draw_round(self, inset, maxf(0.0, rad - 2.0), UiSurface.LEATHER, top_col.lerp(bottom_col, 0.5), UIStyle.PANEL_GRAIN * 0.8)
	# Soft sheen under the top rim.
	Ornate.vgradient(self, Rect2(inset.position + Vector2(rad, 1), Vector2(inset.size.x - rad * 2.0, minf(34.0, size.y * 0.2))), Color(accent, 0.13), Color(accent, 0.0))
	if frame_inset > 0.0:
		draw_rect(Rect2(frame_inset, frame_inset, size.x - frame_inset * 2.0, size.y - frame_inset * 2.0), Color(accent, 0.22), false, 1.0)
	if flourish:
		Ornate.corners(self, r, Color(accent, 0.9), arm, maxf(frame_inset - 1.0, 3.0))
