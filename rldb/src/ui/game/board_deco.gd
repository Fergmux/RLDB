class_name BoardDeco
extends Control
## Table decoration: centre line with ornament and the active player's underglow.

## Y of the dividing line between the sides.
var mid_y: float = 0.0
## Left edge of the deco.
var x0: float = 0.0
## Right edge of the deco.
var x1: float = 0.0
## Side whose edge glows (-1 none).
var glow_side: int = -1
## Top edge of the field.
var top_edge: float = 0.0
## Bottom edge of the field.
var bottom_edge: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Plain centre line (no ornament) and a soft gradient under the active half (no hard gold line).
	draw_line(Vector2(x0, mid_y), Vector2(x1, mid_y), Color(UIStyle.TABLE_INLAY.lightened(0.2), 0.9), 2.0)
	if glow_side >= 0:
		var y := top_edge if glow_side == 0 else bottom_edge
		var dir := -1.0 if glow_side == 0 else 1.0
		var gc := Color(UIStyle.GOLD, 0.0)
		var gs := Color(UIStyle.GOLD, 0.2)
		draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + dir * 22.0), Vector2(x0, y + dir * 22.0)]), PackedColorArray([gs, gs, gc, gc]))
