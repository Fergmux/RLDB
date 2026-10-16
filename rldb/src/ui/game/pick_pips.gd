class_name PickPips
extends Control
## Remaining reward picks as filled / empty gems.

## Picks left.
var left: int = 0
## Total picks.
var total: int = 0

func _init() -> void:
	custom_minimum_size = Vector2(0, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var amber: Color = UIStyle.COST_COLORS["ap"]
	for i in total:
		var c := Vector2(14.0 + i * 28.0, size.y / 2.0)
		if i < left:
			draw_circle(c, 11.0, amber.darkened(0.65))
			draw_circle(c, 9.0, amber)
			draw_circle(c + Vector2(-3, -3.5), 3.5, Color(1, 1, 1, 0.35))
		else:
			draw_circle(c, 11.0, Color(0.1, 0.08, 0.06))
			draw_arc(c, 9.5, 0.0, TAU, 24, Color(amber, 0.4), 2.0)
