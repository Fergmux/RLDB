class_name DeckCrest
extends Control
## Deck crest: heater shield in the deck's dominant Type colour(s) with the Type initial.

var types: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(56, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _shield(r: Rect2) -> PackedVector2Array:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	return PackedVector2Array([Vector2(x + 0.08 * w, y), Vector2(x + 0.92 * w, y), Vector2(x + w, y + 0.12 * h), Vector2(x + w, y + 0.56 * h),
		Vector2(x + 0.5 * w, y + h), Vector2(x, y + 0.56 * h), Vector2(x, y + 0.12 * h)])

func _draw() -> void:
	var outer := Rect2(2, 2, size.x - 4, size.y - 4)
	draw_colored_polygon(_shield(outer), UIStyle.GOLD)
	var inner := Rect2(outer.position + Vector2(3, 3), outer.size - Vector2(6, 6))
	var ip := _shield(inner)
	var c0 := UIStyle.type_color(types[0] if types.size() > 0 else "")
	draw_colored_polygon(ip, c0.darkened(0.15))
	if types.size() > 1:
		var half := Geometry2D.intersect_polygons(ip, PackedVector2Array([Vector2(size.x / 2.0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x / 2.0, size.y)]))
		for poly in half:
			draw_colored_polygon(poly, UIStyle.type_color(types[1]).darkened(0.15))
	var letter := String(types[0]).substr(0, 1) if types.size() > 0 and String(types[0]) != "" else "?"
	var font := UIStyle.font_display(700)
	var sz := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	var pos := Vector2((size.x - sz.x) / 2.0, size.y * 0.5 + 9.0)
	draw_string_outline(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
