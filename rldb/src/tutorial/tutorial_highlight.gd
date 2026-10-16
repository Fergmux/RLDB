class_name TutorialHighlight
extends Control
## Click-through highlight layer of the tutorial (F03-15): a pulsing gold ring around each target
## rect and a bobbing pointer arrow above the first one. Presentation only; static (no pulse or
## bob) with UIStyle.reduce_motion.

const RING_PAD := 6.0
const RING_W := 4.0
const PULSE_HZ := 1.1
const ARROW_W := 34.0
const ARROW_H := 26.0
const ARROW_GAP := 10.0
const ARROW_BOB := 8.0

## Target rects in this layer's coordinates.
var rects: Array = []
## Draw the pointer arrow above the first rect.
var arrow: bool = true
## Point at the first rect from below instead of from above.
var arrow_from_below: bool = false
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var still := UIStyle.reduce_motion
	var pulse := 0.5 if still else 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ)
	for r in rects:
		var rr: Rect2 = (r as Rect2).grow(RING_PAD + (0.0 if still else 3.0 * pulse))
		# Soft outer glow, then the ring itself.
		draw_rect(rr.grow(5.0), Color(UIStyle.GOLD, 0.2 + 0.25 * pulse), false, RING_W + 8.0)
		draw_rect(rr.grow(1.5), Color(0.12, 0.07, 0.0, 0.85), false, RING_W + 3.0)     # dark edge: reads on gold zones
		draw_rect(rr, Color(1.0, 0.93, 0.68).lerp(UIStyle.GOLD_HI, 1.0 - pulse), false, RING_W)
	if arrow and not rects.is_empty():
		var first: Rect2 = rects[0]
		var bob := 0.0 if still else ARROW_BOB * sin(_t * TAU * PULSE_HZ * 0.8)
		var tip := Vector2(first.get_center().x, first.position.y - RING_PAD - ARROW_GAP + bob)
		if arrow_from_below or tip.y - ARROW_H < 4.0:
			# No room above (e.g. a top-edge target): point up from below instead.
			tip = Vector2(first.get_center().x, first.end.y + RING_PAD + ARROW_GAP - bob)
			_arrow(tip, -1.0)
		else:
			_arrow(tip, 1.0)


func _arrow(tip: Vector2, dir: float) -> void:
	var base_y := tip.y - ARROW_H * dir
	var pts := PackedVector2Array([tip, Vector2(tip.x - ARROW_W / 2.0, base_y), Vector2(tip.x - ARROW_W / 6.0, base_y),
		Vector2(tip.x - ARROW_W / 6.0, base_y - ARROW_H * 0.7 * dir), Vector2(tip.x + ARROW_W / 6.0, base_y - ARROW_H * 0.7 * dir),
		Vector2(tip.x + ARROW_W / 6.0, base_y), Vector2(tip.x + ARROW_W / 2.0, base_y)])
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	draw_colored_polygon(pts, UIStyle.GOLD_HI)
	pts.append(pts[0])
	draw_polyline(pts, Color(0.25, 0.16, 0.04), 2.0, true)
