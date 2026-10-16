class_name ZoneRing
extends Control
## Pulsing outline over a whole zone that is being chosen while a card already stands in it
## (e.g. a Fusion summon into a material's zone). Click-through.

## Whether it is drawn.
var on: bool = false
## Colour.
var col: Color = UIStyle.TARGET

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Shows or hides the ring; it pulses while shown unless motion is reduced.
func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	visible = v
	set_process(v and not UIStyle.reduce_motion)
	queue_redraw()

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var a := 1.0
	if not UIStyle.reduce_motion:
		a = 0.55 + 0.45 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 900.0 * TAU))
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.10 + 0.10 * a)
	sb.border_color = Color(col, a)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(9)
	draw_style_box(sb, r)
	var glow := StyleBoxFlat.new()
	glow.draw_center = false
	glow.border_color = Color(col, 0.3 * a)
	glow.set_border_width_all(5)
	glow.set_corner_radius_all(12)
	draw_style_box(glow, r.grow(4))
