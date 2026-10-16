class_name ScrollCue
extends Control
## Cue shown under the details text while it continues below the fold.

func _init() -> void:
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _draw() -> void:
	var font := UIStyle.font_bold()
	var txt := "Scroll for more"
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var cx := size.x / 2.0
	draw_rect(Rect2(0, 0, size.x, size.y), Color(UIStyle.GOLD, 0.12))
	draw_string(font, Vector2(cx - sz.x / 2.0, size.y / 2.0 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD_HI)
	for dx in [-sz.x / 2.0 - 14.0, sz.x / 2.0 + 14.0]:
		var c := Vector2(cx + dx, size.y / 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]), UIStyle.GOLD_HI)
