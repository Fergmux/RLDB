class_name DetailsEmptyArt
extends Control
## The Card Details panel's empty state (design review #42): instead of one dim line over a large empty
## leather field, an engraved card outline (bronze line art at LINE_A, a double frame, corner studs and a
## sunburst diamond like the card back) centred in the space, with the hint under it. The engraving
## breathes slowly; still under reduce motion. Click-through.

## The outline's size at rest (px; it shrinks to fit a short panel) and the line alpha.
const CARD := Vector2(140, 196)
const LINE_A := 0.25
## Hint sizes (px) and the gap between the outline and the hint.
const HINT_PX := 14
const SUB_PX := 12
const GAP := 18.0

## The hint lines.
var hint: String = "Click a card to read it"
var sub: String = "Your own cards show their actions too."


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
		set_process(is_visible_in_tree() and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


## The outline rect inside a `area` big control: CARD scaled down to leave room for the hint, centred
## horizontally, the outline and hint together centred vertically (a little above the middle).
static func card_rect(area: Vector2) -> Rect2:
	var text_h := float(HINT_PX + SUB_PX) * 1.4 + GAP
	var k := clampf((area.y - text_h - 24.0) / CARD.y, 0.35, 1.0)
	k = minf(k, (area.x - 32.0) / CARD.x)
	var sz := CARD * maxf(k, 0.1)
	var top := maxf(8.0, (area.y - sz.y - text_h) * 0.42)
	return Rect2(Vector2((area.x - sz.x) / 2.0, top), sz)


func _draw() -> void:
	if size.y < 60.0:
		return
	var r := card_rect(size)
	var k := UIStyle.breathe(float(Time.get_ticks_msec()) / 1000.0, 0.18, 4.8)
	var col := Color(UIStyle.BRONZE.lightened(0.25), LINE_A * k)
	var lit := Color(UIStyle.GOLD_HI, 0.06 * k)
	var s := r.size.x / CARD.x
	# The engraving: each line has a lit edge 1 px below it (cut into the leather).
	_frame(r, 10.0 * s, col, lit)
	_frame(r.grow(-7.0 * s), 6.0 * s, Color(col, col.a * 0.7), lit)
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var q: Vector2 = p + (r.get_center() - p).normalized() * 12.0 * s
		draw_circle(q, 2.2 * s, Color(col, col.a * 1.2), true, -1.0, true)
	var c := r.get_center()
	var d := 30.0 * s
	var dia := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.8, 0), c + Vector2(0, d), c + Vector2(-d * 0.8, 0), c + Vector2(0, -d)])
	draw_polyline(dia, lit, 1.0, true)
	draw_polyline(dia, col, 1.4, true)
	var d2 := d * 0.55
	var dia2 := PackedVector2Array([c + Vector2(0, -d2), c + Vector2(d2 * 0.8, 0), c + Vector2(0, d2), c + Vector2(-d2 * 0.8, 0), c + Vector2(0, -d2)])
	draw_polyline(dia2, col, 1.0, true)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var u := Vector2(cos(a), sin(a))
		draw_line(c + u * d * 1.15, c + u * d * (1.45 if i % 3 == 0 else 1.3), Color(col, col.a * 0.8), 1.0, true)
	draw_circle(c, 3.0 * s, Color(col, col.a * 1.4), true, -1.0, true)
	# The hint.
	var f := UIStyle.font_italic()
	var y := r.end.y + GAP + float(HINT_PX)
	draw_string(f, Vector2(0, y), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, HINT_PX, UIStyle.MUTED)
	draw_string(UIStyle.font_body(), Vector2(0, y + float(SUB_PX) * 1.5), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, SUB_PX, UIStyle.TEXT_DIM)


func _frame(r: Rect2, rad: float, col: Color, lit: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(maxi(1, roundi(rad)))
	sb.anti_aliasing = true
	sb.border_color = lit
	draw_style_box(sb, Rect2(r.position + Vector2(0, 1), r.size))
	sb.border_color = col
	draw_style_box(sb, r)
