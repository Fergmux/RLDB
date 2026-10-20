class_name SpectatorCursor
extends Control
## A2: the watched player's mouse cursor on a spectator's screen, drawn as a gilded arrowhead with
## a soft glow and a small name tag. Position comes from a CursorTrack (interpolated); purely
## presentation, it never takes input.

## Interpolated samples of the watched cursor.
var track := CursorTrack.new()
## Screen-local position to draw at.
var at := Vector2.ZERO
## Name on the tag.
var label := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The arrow outline with its tip at the origin (screen px).
static func arrow_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(5.5, 17), Vector2(9.5, 26),
		Vector2(13.5, 24.2), Vector2(9.6, 15.6), Vector2(16.5, 15.2)])


func _draw() -> void:
	var pts := arrow_points()
	var moved := PackedVector2Array()
	var shadow := PackedVector2Array()
	for p in pts:
		moved.append(at + p)
		shadow.append(at + p + Vector2(2, 3))
	for r in 3:
		draw_circle(at + Vector2(5, 9), 14.0 + r * 6.0, Color(UIStyle.GOLD_HI, 0.07))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(moved, UIStyle.GOLD)
	# Bevel: a lighter inner face on the left half.
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(0, 22), at + Vector2(5.5, 17), at + Vector2(7.5, 14)]), Color(UIStyle.GOLD_HI, 0.85))
	var loop := moved.duplicate()
	loop.append(moved[0])
	draw_polyline(loop, Color(0.12, 0.07, 0.02), 1.6, true)
	if label == "":
		return
	var f := UIStyle.font_bold()
	var fs := 12
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(at + Vector2(16, 24), Vector2(tw + 14, 20))
	var sb := UIStyle.flat(Color(0.08, 0.055, 0.025, 0.92), Color(UIStyle.GOLD, 0.8), 1, 9)
	draw_style_box(sb, r)
	draw_string(f, r.position + Vector2(7, 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.GOLD_HI)
