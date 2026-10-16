class_name FxRuneRing
extends Control
## Rune-ring burst for a triggered effect: two expanding rings carrying a turning circle of rune
## marks, fading out as `t` goes 0 -> 1. Drawn centred on the node position; click-through.

## Number of rune marks on the turning circle.
const RUNE_COUNT := 12

## Ring colour.
var col: Color = Color.WHITE
## Full-size radius in pixels.
var radius: float = 70.0
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


func _draw() -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	var a := 1.0 - t
	var r := radius * (0.45 + 0.75 * e)
	draw_circle(Vector2.ZERO, r * 0.95, Color(col, 0.16 * a * a), true, -1.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(col.lightened(0.4), 0.95 * a), 1.0 + 3.0 * a, true)
	draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 56, Color(col, 0.55 * a), 1.0 + 1.2 * a, true)
	var rr := r * 0.9
	for i in RUNE_COUNT:
		var ang := float(i) * TAU / float(RUNE_COUNT) + t * 1.4
		var c := Vector2(cos(ang), sin(ang)) * rr
		var u := Vector2(cos(ang), sin(ang)) * (2.0 + 3.0 * a)
		var v := Vector2(-u.y, u.x) * 0.6
		draw_colored_polygon(PackedVector2Array([c + u, c + v, c - u, c - v]), Color(col.lightened(0.5), a))
