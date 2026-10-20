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
## J31 (performance): the engraving, drawn once at full breath on this internal layer; it breathes by
## the layer's alpha (modulate.a = the breath), so no frame repaints it. Every engraved colour's alpha
## is a multiple of the breath, and modulate multiplies each draw's colour: the pixels are the same.
var _art: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.draw.connect(_draw_engraving)
	add_child(_art, false, Node.INTERNAL_MODE_FRONT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
		set_process(is_visible_in_tree() and not UIStyle.reduce_motion)
		_breathe()
	elif what == NOTIFICATION_RESIZED:
		_art.queue_redraw()


func _process(_d: float) -> void:
	_breathe()


func _breathe() -> void:
	_art.modulate.a = UIStyle.breathe(float(Time.get_ticks_msec()) / 1000.0, 0.18, 4.8)


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
	# The hint.
	var f := UIStyle.font_italic()
	var y := r.end.y + GAP + float(HINT_PX)
	draw_string(f, Vector2(0, y), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, HINT_PX, UIStyle.MUTED)
	draw_string(UIStyle.font_body(), Vector2(0, y + float(SUB_PX) * 1.5), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, SUB_PX, UIStyle.TEXT_DIM)


# The engraving at full breath (k = 1), on the _art layer whose alpha breathes.
func _draw_engraving() -> void:
	if size.y < 60.0:
		return
	var r := card_rect(size)
	var col := Color(UIStyle.BRONZE.lightened(0.25), LINE_A)
	var lit := Color(UIStyle.GOLD_HI, 0.06)
	var s := r.size.x / CARD.x
	# The engraving: each line has a lit edge 1 px below it (cut into the leather).
	_frame(r, 10.0 * s, col, lit)
	_frame(r.grow(-7.0 * s), 6.0 * s, Color(col, col.a * 0.7), lit)
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var q: Vector2 = p + (r.get_center() - p).normalized() * 12.0 * s
		_art.draw_circle(q, 2.2 * s, Color(col, col.a * 1.2), true, -1.0, true)
	var c := r.get_center()
	var d := 30.0 * s
	var dia := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.8, 0), c + Vector2(0, d), c + Vector2(-d * 0.8, 0), c + Vector2(0, -d)])
	_art.draw_polyline(dia, lit, 1.0, true)
	_art.draw_polyline(dia, col, 1.4, true)
	var d2 := d * 0.55
	var dia2 := PackedVector2Array([c + Vector2(0, -d2), c + Vector2(d2 * 0.8, 0), c + Vector2(0, d2), c + Vector2(-d2 * 0.8, 0), c + Vector2(0, -d2)])
	_art.draw_polyline(dia2, col, 1.0, true)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var u := Vector2(cos(a), sin(a))
		_art.draw_line(c + u * d * 1.15, c + u * d * (1.45 if i % 3 == 0 else 1.3), Color(col, col.a * 0.8), 1.0, true)
	_art.draw_circle(c, 3.0 * s, Color(col, col.a * 1.4), true, -1.0, true)


func _frame(r: Rect2, rad: float, col: Color, lit: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(maxi(1, roundi(rad)))
	sb.anti_aliasing = true
	sb.border_color = lit
	_art.draw_style_box(sb, Rect2(r.position + Vector2(0, 1), r.size))
	sb.border_color = col
	_art.draw_style_box(sb, r)
