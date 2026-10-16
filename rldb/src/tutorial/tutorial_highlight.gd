class_name TutorialHighlight
extends Control
## Click-through highlight layer of the tutorial (F03-15): a pulsing gold ring around each target
## rect and a bobbing pointer arrow above the first one. Presentation only; static (no pulse or
## bob) with UIStyle.reduce_motion.

const RING_PAD := 6.0
## Ring padding in compact mode (buttons in the prompt banner).
const COMPACT_PAD := 2.0
const RING_W := 4.0
const PULSE_HZ := 1.1
const ARROW_W := 34.0
const ARROW_H := 26.0
const ARROW_GAP := 10.0
const ARROW_BOB := 8.0
## Margin kept between the arrow and the layer's edge.
const ARROW_EDGE := 4.0
## Slack before a decided arrow direction may flip (px of overshoot).
const ARROW_HYSTERESIS := 12.0

## Target rects in this layer's coordinates.
var rects: Array = []
## Draw the pointer arrow above the first rect.
var arrow: bool = true
## Point at the first rect from below instead of from above.
var arrow_from_below: bool = false
## Tight ring for small controls packed next to others (no outward pulse, thin glow).
var compact: bool = false
## Current arrow direction: 1 above the target (pointing down), -1 below it, 0 undecided.
var arrow_dir: int = 0
var _decided_rect: Rect2 = Rect2()
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
		var rr: Rect2 = (r as Rect2).grow(COMPACT_PAD if compact else RING_PAD + (0.0 if still else 3.0 * pulse))
		# Soft outer glow, then the ring itself.
		if not compact:
			draw_rect(rr.grow(5.0), Color(UIStyle.GOLD, 0.2 + 0.25 * pulse), false, RING_W + 8.0)
		draw_rect(rr.grow(1.5), Color(0.12, 0.07, 0.0, 0.85), false, RING_W + 3.0)     # dark edge: reads on gold zones
		draw_rect(rr, Color(1.0, 0.93, 0.68).lerp(UIStyle.GOLD_HI, 1.0 - pulse), false, RING_W)
	if arrow and not rects.is_empty():
		var first: Rect2 = rects[0]
		var bob := 0.0 if still else ARROW_BOB * sin(_t * TAU * PULSE_HZ * 0.8)
		arrow_dir = choose_direction(first, size.y, arrow_from_below, arrow_dir, _decided_rect)
		if _decided_rect == Rect2() or not _same_target(first, _decided_rect):
			_decided_rect = first
		if arrow_dir > 0:
			_arrow(Vector2(first.get_center().x, first.position.y - RING_PAD - ARROW_GAP + bob), 1.0)
		else:
			_arrow(Vector2(first.get_center().x, first.end.y + RING_PAD + ARROW_GAP - bob), -1.0)
	else:
		arrow_dir = 0
		_decided_rect = Rect2()


## Free pixels above (or below) `r` for the arrow over its whole bob animation: the tip travels
## +-ARROW_BOB around its rest point and the arrow body extends ARROW_H beyond the tip (negative
## = does not fit). `height` is the layer's height.
static func arrow_space(r: Rect2, height: float, above: bool) -> float:
	var need := RING_PAD + ARROW_GAP + ARROW_BOB + ARROW_H + ARROW_EDGE
	return (r.position.y - need) if above else (height - r.end.y - need)


## True when `r` is the same target as `prev` (same size, centre moved less than a card width / 2).
static func _same_target(r: Rect2, prev: Rect2) -> bool:
	return prev != Rect2() and r.size.is_equal_approx(prev.size) and r.get_center().distance_to(prev.get_center()) < 48.0


## Arrow direction for target `r`: 1 = above it pointing down, -1 = below it pointing up (F04-10).
## Decided from the full space the arrow covers over its bob (not its current frame), once per
## target: `prev` (0 = undecided) is kept while `r` is still the target decided at `prev_rect`,
## unless it clearly no longer fits (beyond ARROW_HYSTERESIS) and the other side has more room.
static func choose_direction(r: Rect2, height: float, prefer_below: bool, prev: int = 0, prev_rect: Rect2 = Rect2()) -> int:
	var pref := -1 if prefer_below else 1
	var sp_pref := arrow_space(r, height, pref > 0)
	var sp_other := arrow_space(r, height, pref < 0)
	if prev == 0 or not _same_target(r, prev_rect):
		# A new target: the preferred side when the whole bob fits there, else the other, else the roomier.
		if sp_pref >= 0.0 or sp_pref >= sp_other:
			return pref
		return -pref
	var sp_prev := sp_pref if prev == pref else sp_other
	var sp_alt := sp_other if prev == pref else sp_pref
	if prev != pref and sp_pref >= 0.0:
		return pref          # the step now wants the other side and it fits
	if sp_prev < -ARROW_HYSTERESIS and sp_alt > sp_prev:
		return -prev          # no longer fits at all (the target moved)
	return prev


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
