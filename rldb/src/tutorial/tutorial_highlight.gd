class_name TutorialHighlight
extends Control
## Click-through highlight layer of the tutorial (F03-15): a pulsing gold ring around each target
## rect and a bobbing pointer arrow beside the first one. Presentation only; static (no pulse or
## bob) with UIStyle.reduce_motion.
##
## Review #101: the arrow keeps ARROW_GAP from the ring at the nearest point of its bob, has a
## 1 px dark outline and a soft gold glow, bobs ARROW_BOB px on a BOB_PERIOD loop, and never lies
## over text: the overlay passes the rects of the labels and buttons around the target in `avoid`,
## and the arrow moves to the other side, or beside the target, when its side would cover one.
## Review #100: flash() pulses the rings once (a refused off-script action).

const RING_PAD := 6.0
## Ring padding in compact mode (buttons in the prompt banner).
const COMPACT_PAD := 2.0
const RING_W := 4.0
const PULSE_HZ := 1.1
const ARROW_W := 34.0
const ARROW_H := 26.0
## Least gap between the arrow's tip and the ring (at the nearest point of the bob).
const ARROW_GAP := 6.0
## Bob travel (px) and period (s).
const ARROW_BOB := 6.0
const BOB_PERIOD := 1.2
## Arrow outline and glow.
const ARROW_OUTLINE := Color(0.16, 0.1, 0.02, 0.95)
const ARROW_GLOW := Color(0.941, 0.812, 0.478, 0.22)
## The one-shot pulse of flash() (s) and how far the ring grows at its peak (px).
const FLASH_TIME := 0.6
const FLASH_GROW := 8.0
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
## Rects (layer coordinates) the arrow must not cover: the text around the target.
var avoid: Array = []
## Current arrow direction: 1 above the target (pointing down), -1 below it, 2 left of it
## (pointing right), -2 right of it (pointing left), 0 undecided.
var arrow_dir: int = 0
var _flash: float = 0.0
var _decided_rect: Rect2 = Rect2()
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	queue_redraw()


## Pulses the rings once (an off-script action was refused); a static bright ring for the same
## time under reduce motion.
func flash() -> void:
	_flash = 1.0


## Strength of the one-shot pulse now (1 right after flash(), 0 at rest).
func flash_level() -> float:
	return _flash


func _draw() -> void:
	var still := UIStyle.reduce_motion
	var pulse := 0.5 if still else 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ)
	# flash(): an eased-out burst (sin-shaped), a plain bright ring under reduce motion.
	var fl := _flash if still else sin(_flash * PI) * _flash
	for r in rects:
		var rr: Rect2 = (r as Rect2).grow(COMPACT_PAD if compact else RING_PAD + (0.0 if still else 3.0 * pulse))
		if fl > 0.0 and not still:
			rr = rr.grow(FLASH_GROW * fl)
		# Soft outer glow, then the ring itself.
		if not compact:
			draw_rect(rr.grow(5.0), Color(UIStyle.GOLD, minf(1.0, 0.2 + 0.25 * pulse + 0.5 * fl)), false, RING_W + 8.0)
		draw_rect(rr.grow(1.5), Color(0.12, 0.07, 0.0, 0.85), false, RING_W + 3.0)     # dark edge: reads on gold zones
		draw_rect(rr, Color(1.0, 0.93, 0.68).lerp(UIStyle.GOLD_HI, 1.0 - pulse).lerp(Color.WHITE, 0.6 * fl), false, RING_W)
	if arrow and not rects.is_empty():
		var first: Rect2 = rects[0]
		# 0 .. 1 over the bob: 0 = the tip at its nearest (ARROW_GAP from the ring).
		var b01 := 0.5 if still else 0.5 + 0.5 * sin(_t * TAU / BOB_PERIOD)
		arrow_dir = choose_side(first, size, arrow_from_below, avoid, arrow_dir, _decided_rect)
		if _decided_rect == Rect2() or not _same_target(first, _decided_rect):
			_decided_rect = first
		var d := RING_PAD + ARROW_GAP + ARROW_BOB * b01
		match arrow_dir:
			1: _arrow(Vector2(first.get_center().x, first.position.y - d), Vector2.DOWN)
			-1: _arrow(Vector2(first.get_center().x, first.end.y + d), Vector2.UP)
			2: _arrow(Vector2(first.position.x - d, first.get_center().y), Vector2.RIGHT)
			_: _arrow(Vector2(first.end.x + d, first.get_center().y), Vector2.LEFT)
	else:
		arrow_dir = 0
		_decided_rect = Rect2()


## The rect the arrow covers over its whole bob when it points at `r` from `dir` (1 above, -1
## below, 2 left, -2 right; see arrow_dir).
static func arrow_box(r: Rect2, dir: int) -> Rect2:
	var near := RING_PAD + ARROW_GAP
	var far := near + ARROW_BOB + ARROW_H
	var c := r.get_center()
	match dir:
		1: return Rect2(c.x - ARROW_W / 2.0, r.position.y - far, ARROW_W, far - near)
		-1: return Rect2(c.x - ARROW_W / 2.0, r.end.y + near, ARROW_W, far - near)
		2: return Rect2(r.position.x - far, c.y - ARROW_W / 2.0, far - near, ARROW_W)
	return Rect2(r.end.x + near, c.y - ARROW_W / 2.0, far - near, ARROW_W)


## Side for the arrow at target `r` in a layer of `layer` size: the vertical choice of
## choose_direction() unless its box covers one of the `avoid` rects (text near the target), then
## the other vertical side, then left, then right, the first that fits the layer and covers
## nothing (else the vertical choice). Decided once per target like choose_direction().
static func choose_side(r: Rect2, layer: Vector2, prefer_below: bool, avoid_rects: Array, prev: int = 0, prev_rect: Rect2 = Rect2()) -> int:
	var same := prev != 0 and _same_target(r, prev_rect)
	if same and absi(prev) == 2:
		return prev   # a decided side placement stays for the target
	var vprev := prev if absi(prev) == 1 else 0
	var v := choose_direction(r, layer.y, prefer_below, vprev, prev_rect)
	if same and v == prev:
		return prev   # decided once per target: the text check never flips it mid-bob
	var order := [v, -v, 2, -2]
	for dir in order:
		var box := arrow_box(r, dir)
		if box.position.x < ARROW_EDGE or box.position.y < ARROW_EDGE or box.end.x > layer.x - ARROW_EDGE or box.end.y > layer.y - ARROW_EDGE:
			continue
		var hit := false
		for a in avoid_rects:
			if box.intersects(a as Rect2):
				hit = true
				break
		if not hit:
			return dir
	return v


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


## Arrow with its tip at `tip`, pointing along `dir` (a unit axis vector): a soft glow, a drop
## shadow, the gold body with a lit top half and a 1 px dark outline.
func _arrow(tip: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var head := ARROW_H * 0.5
	var stem := ARROW_H * 0.5
	var pts := PackedVector2Array([tip,
		tip - dir * head + side * (ARROW_W / 2.0), tip - dir * head + side * (ARROW_W / 6.0),
		tip - dir * (head + stem) + side * (ARROW_W / 6.0), tip - dir * (head + stem) - side * (ARROW_W / 6.0),
		tip - dir * head - side * (ARROW_W / 6.0), tip - dir * head - side * (ARROW_W / 2.0)])
	var closed := pts.duplicate()
	closed.append(pts[0])
	for g in [[9.0, 0.35], [5.0, 0.6]]:
		draw_polyline(closed, Color(ARROW_GLOW, ARROW_GLOW.a * float(g[1])), float(g[0]), true)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(1.5, 2.5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	draw_colored_polygon(pts, UIStyle.GOLD_HI)
	# Lit half (the light comes from above-left): a lighter sliver along one side of the axis.
	var lit := PackedVector2Array([tip, pts[1], pts[2], pts[3], tip - dir * (head + stem)])
	draw_colored_polygon(lit, Color(1.0, 0.97, 0.84, 0.45))
	draw_polyline(closed, ARROW_OUTLINE, 1.0, true)
