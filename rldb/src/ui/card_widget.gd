class_name CardWidget
extends Control
## Procedurally drawn card (art bible section 4): layered frame, art window (card art or
## a placeholder), name plate, cost gem (shape per cost kind), ATK diamond / DEF shield,
## status icons over the art and a face-down back. Everything is drawn from the redacted card view, so
## hidden cards can only ever show the back. Runtime stats are never baked into art.
##
## Every card face is exactly 2:3 (portrait) or 3:2 (when `rotated`, i.e. the same portrait
## card turned 90 degrees clockwise). If the widget rect has another ratio the card is
## letterboxed and centred inside it (see card_rect()); the widget rect stays the hit area.
## An EMPTY view draws a zone background that fills the whole widget rect instead.
##
## Kinds: "board" (85x128 compact field unit), "power" (85x128), "trap" (85x128, shown
## rotated on the board), "hand" (120x180), "mini" (90x135), "big" (224x336), "back" (60x90).
## Geometry is authored in base units and scaled by card width / base width.
##
## This node owns state, sizing and input; drawing is delegated to the painters in src/ui/card/
## (CardPainter context + CardArt, CardFaceParts, CardStatBadge, CardStatusIcons, CardBack, CardLayouts,
## CardOverlays), text helpers to CardText / CardTextLayout. Hovering a status icon names it at once
## (StatusTip); the card's own tooltip is held back while the pointer is on an icon.

signal pressed(widget: CardWidget)
signal right_pressed(widget: CardWidget)

## Portrait sizes, all exactly 2:3 width:height.
const SIZES := {
	"hand": Vector2(120, 180), "mini": Vector2(90, 135), "big": Vector2(224, 336), "back": Vector2(60, 90),
	"board": Vector2(85, 128), "power": Vector2(85, 128), "trap": Vector2(85, 128),
}
## Default sizes of EMPTY zone backgrounds (callers normally size these to the zone rect).
const EMPTY_SIZES := {"board": Vector2(128, 128), "trap": Vector2(128, 85), "power": Vector2(85, 128)}
const ART_DIR := CardArt.ART_DIR
const UNIT_CATS := ["basic_unit", "unit", "fusion", "ritual", "arcane"]
const BIG_KINDS := ["hand", "big", "mini", "back"]

var view: Dictionary = {}
var size_kind: String = "board"
## Draw the portrait card turned 90 degrees clockwise inside a landscape rect (defense units, backrow).
var rotated: bool = false
var highlighted: bool = false
var selected: bool = false
var dimmed: bool = false
var empty_text: String = ""
## Show the slot label on an empty zone even when not a target (first-turn hint).
var show_label: bool = false
## Self-managed hover glow (deck builder lists). GameScreen turns this off and manages hover.
var auto_hover: bool = true
## Native tooltip with name and rules text (off on the match board, where details live in the sidebar).
var show_tooltip: bool = true
var hovered: bool = false: set = _set_hovered
var fx_flash: float = 0.0: set = _set_flash
var fx_glow: Color = Color(1, 1, 1, 0): set = _set_glow
## Ordered multi-select badge: 1, 2, 3... drawn on the card while > 0.
var order_no: int = 0: set = _set_order

## Hover lift: the card grows to `lift_k` times its resting size and sits `lift_offset` away, about
## its centre. Tween these two.
## - The widget rect really grows (hit area, neighbours, F04-05), never the `scale` property.
## - The face is NOT laid out again at the lifted size (F05-03: that reflowed the text, with line
##   breaks and font sizes stepping mid-animation). It keeps its resting layout and is drawn scaled
##   by `lift_k`, with the text rasterised at its on-screen size (CardPainter.text_os) so it stays crisp.
var lift_k: float = 1.0: set = _set_lift_k
var lift_offset: Vector2 = Vector2.ZERO: set = _set_lift_offset
## Transient FX displacement (F02): effects (shakes, lunges, arrivals) animate this, never `position`.
## It is composed on top of the resting position and the hover lift, so an effect can never become
## the card's resting place (a shake writing `position.x` while lifted used to be taken for a new
## resting place every frame, and the lifted card crept upward with its status label).
var fx_offset: Vector2 = Vector2.ZERO: set = _set_fx_offset

## Text oversampling is quantised to 1/TEXT_OS_STEPS of the on-screen scale: a lift animation then
## rasterises a bounded set of glyph sizes (the font caches one set per size) while the mismatch
## between raster and display size stays under 1/(2 * TEXT_OS_STEPS), i.e. below 1%.
const TEXT_OS_STEPS := 64.0

var _lifting := false
var _lift_rest_pos := Vector2.ZERO
## Position the lift itself last set (anything else moving the card is a new resting place).
var _lift_applied_pos := Vector2.ZERO
var _lift_applying := false
var _self_hover := false
## Quantised on-screen scale the face text was last rasterised for (1.0 = the viewport's own).
var _text_k := 1.0
var _is_ready := false
var _pv_stat := ""
var _pv_value := 0
var _pv_bonus := 0
## Drawing context: the state snapshot and scaled primitives every card part draws with.
var _paint := CardPainter.new(self)


func _init() -> void:
	item_rect_changed.connect(_on_rect_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Card art is mipmapped (smooth at board size) and the surface grain tiles (UiSurface).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# A `scale` on the card or above it (FX pulses, the deck builder click, a scaled sidebar) changes the
	# on-screen text size: redraw so the glyphs are rasterised for it (see _screen_text_k).
	set_notify_transform(true)


func _ready() -> void:
	mouse_entered.connect(func(): _self_hover = auto_hover; queue_redraw())
	mouse_exited.connect(func(): _self_hover = false; StatusTip.hide_for(self); queue_redraw())
	# Godot turns processing on at ready because _process exists: only redraw per frame while animating.
	_update_process()


## `is_rotated` turns the portrait card 90 degrees clockwise (size becomes SIZES[kind] swapped).
func setup(v, kind: String = "board", empty_label: String = "", is_rotated: bool = false) -> CardWidget:
	view = v if v != null else {}
	size_kind = kind
	empty_text = empty_label
	rotated = is_rotated
	_apply_size()
	if view.is_empty() or view.get("hidden", false) or not show_tooltip:
		tooltip_text = ""
	else:
		tooltip_text = tooltip_for(view)
	queue_redraw()
	return self


## Switches the portrait/landscape orientation of a card widget (defense stance, backrow) and resizes it.
func set_rotated(on: bool) -> void:
	if rotated == on:
		return
	rotated = on
	_apply_size()
	queue_redraw()


## Card widgets get their 2:3 (or 3:2) size as both size and minimum. Empty zone backgrounds get the
## default zone rect (unit slot 128x128, trap zone 128x85, power zone 85x128) with NO minimum, so the
## caller can size them freely to the zone rect.
func _apply_size() -> void:
	if view.is_empty():
		custom_minimum_size = Vector2.ZERO
		size = EMPTY_SIZES.get(size_kind, Vector2(128, 128))
	else:
		var sz: Vector2 = SIZES[size_kind]
		if rotated:
			sz = Vector2(sz.y, sz.x)
		custom_minimum_size = sz
		size = sz
	pivot_offset = size / 2.0


## `is_dimmed` = hard dim (non-target while a target is being chosen, ~0.55);
## `soft_dim` = gentle dim for cards that cannot act right now.
func set_marks(is_target: bool, is_selected: bool, is_dimmed: bool = false, soft_dim: bool = false) -> void:
	highlighted = is_target
	selected = is_selected
	dimmed = is_dimmed
	if is_dimmed:
		self_modulate = Color(0.55, 0.55, 0.55, 1.0)
	elif soft_dim:
		self_modulate = Color(0.8, 0.8, 0.8, 1.0)
	else:
		self_modulate = Color.WHITE
	_update_process()
	queue_redraw()


## "This card can act now" highlight (F02-11). Static (no per-frame redraw); independent of hover/select/target.
func set_ready(on: bool) -> void:
	if _is_ready != on:
		_is_ready = on
		_update_process()   # F03-21: the glow pulses and the chevrons bounce while ready
		queue_redraw()


func is_ready_on() -> bool:
	return _is_ready


## Combat preview (F02-12): shows `value` on the ATK or DEF badge in a provisional style with a
## "+N"/"-N" tag when `bonus` != 0. Purely visual: `view` is never modified.
func set_preview(stat: String, value: int, bonus: int) -> void:
	var st := stat if stat in ["atk", "def"] else ""
	if st == _pv_stat and value == _pv_value and bonus == _pv_bonus:
		return
	_pv_stat = st
	_pv_value = value
	_pv_bonus = bonus
	queue_redraw()


func clear_preview() -> void:
	if _pv_stat != "":
		_pv_stat = ""
		_pv_value = 0
		_pv_bonus = 0
		queue_redraw()


func has_preview() -> bool:
	return _pv_stat != ""


## The rect (widget space) the card face occupies: exactly 2:3 (3:2 when rotated), centred and
## letterboxed inside the widget rect, never stretched.
func card_rect() -> Rect2:
	return _card_rect_in(size)


## card_rect() for a widget of size `sz` (the face is laid out in the resting size while lifted).
func _card_rect_in(sz: Vector2) -> Rect2:
	var aspect := 1.5 if rotated else (2.0 / 3.0)   # width / height
	var w := sz.x
	var h := sz.y
	# 85x128 is 2:3 to within half a pixel; treat that as exact so the face is not offset by half a pixel.
	if absf(w / maxf(h, 0.001) - aspect) < 0.006:
		return Rect2(Vector2.ZERO, sz)
	if w / maxf(h, 0.001) > aspect:
		w = h * aspect
	else:
		h = w / aspect
	return Rect2((sz.x - w) / 2.0, (sz.y - h) / 2.0, w, h)


## Scale the face is drawn at: `lift_k` while lifted, else 1 (laid out at size / draw_k).
func draw_k() -> float:
	return lift_k if _lifting else 1.0


## The face's on-screen scale relative to the viewport (lift times any `scale` on the card or its
## parents), quantised to 1/TEXT_OS_STEPS. 1.0 means the text needs no oversampling of its own.
func _screen_text_k() -> float:
	var xf := get_global_transform_with_canvas() if is_inside_tree() else get_transform()
	var sk := maxf(xf.x.length(), xf.y.length()) * draw_k()
	return maxf(1.0 / TEXT_OS_STEPS, roundf(sk * TEXT_OS_STEPS) / TEXT_OS_STEPS)


## Raster oversampling for the face text (CardPainter.text_os): 0.0 (the viewport's own) at scale 1,
## else the viewport's oversampling times the on-screen scale.
func text_oversampling() -> float:
	var k := _screen_text_k()
	if is_equal_approx(k, 1.0):
		return 0.0
	var vp := get_viewport()
	return (vp.get_oversampling() if vp != null else 1.0) * k


func _set_hovered(v: bool) -> void:
	hovered = v
	queue_redraw()


func _set_lift_k(v: float) -> void:
	lift_k = v
	_apply_lift()


func _set_lift_offset(v: Vector2) -> void:
	lift_offset = v
	_apply_lift()


func _set_fx_offset(v: Vector2) -> void:
	if v.is_equal_approx(fx_offset):
		return
	var d := v - fx_offset
	fx_offset = v
	if _lifting:
		_apply_lift()
		return
	_lift_applying = true
	position += d
	_lift_applied_pos = position
	_lift_applying = false


## The position the card rests at, without the hover lift and the FX offset (layout space).
func rest_position() -> Vector2:
	return _lift_rest_pos if _lifting else position - fx_offset


## Sizes and places the card for the current lift: growth about the centre, relative to where the card
## rested when the lift began. Not rounded to whole pixels: the face is drawn scaled (see lift_k), so a
## fractional size animates smoothly instead of in 1 px steps (Controls still snap to pixels on screen).
func _apply_lift() -> void:
	var rest := custom_minimum_size
	if rest == Vector2.ZERO:
		return
	var neutral := is_equal_approx(lift_k, 1.0) and lift_offset.is_zero_approx()
	if not neutral and not _lifting:
		_lifting = true
		_lift_rest_pos = position - fx_offset
	var sz := rest if neutral else rest * lift_k
	_lift_applying = true
	size = sz
	if neutral:
		if _lifting:
			position = _lift_rest_pos + fx_offset
		_lifting = false
	else:
		position = _lift_rest_pos + lift_offset - (sz - rest) / 2.0 + fx_offset
	_lift_applied_pos = position
	_lift_applying = false


## Something else moved the card while it is lifted (the board re-laying it out, or a summon
## flying it into its zone): that is its new resting place, so the lift follows it instead of
## later snapping the card back to where it was when the hover began.
func _on_rect_changed() -> void:
	if not _lifting or _lift_applying or position.is_equal_approx(_lift_applied_pos):
		return
	_lift_rest_pos = position   # movers place the card's resting position
	_apply_lift()


func _set_flash(v: float) -> void:
	fx_flash = v
	queue_redraw()


func _set_glow(v: Color) -> void:
	fx_glow = v
	queue_redraw()


func _set_order(v: int) -> void:
	if v != order_no:
		order_no = v
		queue_redraw()


## Per-frame redraw only while something animates: the pulsing target ring or the breathing
## selection brackets. Static under reduce_motion.
func _update_process() -> void:
	set_process((highlighted or selected or _is_ready) and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()
	elif what == NOTIFICATION_TRANSFORM_CHANGED:
		if not is_equal_approx(_screen_text_k(), _text_k):
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_status_tip(event.position)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit(self)
			accept_event()


## The status icon under widget point `at` ({"rect", "label"}), or {} when there is none.
func status_hit_at(at: Vector2) -> Dictionary:
	for h in _paint.hits:
		if (h["rect"] as Rect2).has_point(at):
			return h
	return {}


## Status icons drawn by the last redraw: [{"rect": widget-space Rect2, "label": String}].
func status_hits() -> Array:
	return _paint.hits.duplicate()


## The status whose name in the card's rules text is under widget point `at`, or "".
func text_status_at(at: Vector2) -> String:
	for th in _paint.text_hits:
		var tp: TextParagraph = th["para"]
		var local: Vector2 = (th["inv"] as Transform2D) * at - (th["pos"] as Vector2)
		if not Rect2(Vector2.ZERO, tp.get_size()).has_point(local):
			continue
		# hit_test gives the caret nearest the point: the character under it is that one or the
		# one before (the right half of a character).
		var idx := tp.hit_test(local)
		var k := StatusHelp.key_at(String(th["text"]), idx)
		if k == "":
			k = StatusHelp.key_at(String(th["text"]), idx - 1)
		return k
	return ""


func _update_status_tip(at: Vector2) -> void:
	var h := status_hit_at(at)
	if not h.is_empty():
		StatusTip.show_for(self, h["label"], get_global_transform_with_canvas() * (h["rect"] as Rect2), String(h.get("detail", "")))
		return
	var k := text_status_at(at)
	if k != "":
		StatusTip.show_for(self, "", get_global_transform_with_canvas() * Rect2(at - Vector2(6, 9), Vector2(12, 18)), StatusHelp.describe(k))
		return
	StatusTip.hide_for(self)


## No card tooltip while the pointer is on a status icon or a status name (its own tip shows).
func _get_tooltip(at_position: Vector2) -> String:
	if not status_hit_at(at_position).is_empty() or text_status_at(at_position) != "":
		return ""
	return tooltip_text


## The card's tooltip, with a section describing each status it names (2026-10-18).
func _make_custom_tooltip(for_text: String) -> Object:
	return StatusHelp.tooltip(for_text)


func _exit_tree() -> void:
	StatusTip.hide_for(self)


# ---------------------------------------------------------------- main draw

func _draw() -> void:
	var pt := _paint
	pt.view = view
	pt.size_kind = size_kind
	pt.rotated = rotated
	pt.hover = hovered or _self_hover
	pt.pv_stat = _pv_stat
	pt.pv_value = _pv_value
	pt.pv_bonus = _pv_bonus
	# Lifted: lay out at the resting size, draw scaled by k (F05-03, see lift_k).
	pt.k = draw_k()
	# The exact resting size (size / k would carry float error into the layout's width keys).
	var ls := custom_minimum_size if _lifting else size
	_text_k = _screen_text_k()
	pt.text_os = text_oversampling()
	pt.hits.clear()
	pt.text_hits.clear()
	if pt.tracing:
		pt.trace.clear()
	if view.is_empty():
		pt.s = clampf(minf(ls.x, ls.y) / 85.0, 0.5, 1.3)
		pt.cr = Rect2(Vector2.ZERO, ls)
		pt.reset_transform()
		CardLayouts.draw_empty(pt, ls, highlighted)
		CardOverlays.draw(pt, self)
		return
	pt.cr = _card_rect_in(ls)
	pt.ps = Vector2(pt.cr.size.y, pt.cr.size.x) if rotated else pt.cr.size
	pt.s = maxf(0.2, pt.ps.x / _base().x)
	pt.set_face_transform()
	if view.get("hidden", false):
		_draw_back()
	elif _is_own_set_card():
		_draw_back()
		# The name reads upright even though the card lies turned in the Trap/Spell zone.
		pt.reset_transform()
		CardLayouts.draw_set_name(pt)
	else:
		match size_kind:
			"power", "trap": CardLayouts.draw_power(pt)
			"back": _draw_back()
			"hand", "mini", "big": CardLayouts.draw_tall(pt)
			_: CardLayouts.draw_square(pt)
	pt.reset_transform()
	CardOverlays.draw(pt, self)


## Tests (F05-03): records every text draw's layout (text, font size, face-space position, paragraph
## line ranges) from the next redraw on; read it with text_trace().
func set_text_tracing(on: bool) -> void:
	_paint.tracing = on
	queue_redraw()


## The text layout recorded by the last redraw while tracing (see set_text_tracing).
func text_trace() -> Array:
	return _paint.trace.duplicate(true)


## The painter's draw scale and text oversampling of the last redraw: [k, text_os].
func last_draw_scale() -> Array:
	return [_paint.k, _paint.text_os]


## Base (unscaled) portrait size the layout of this kind is authored in: mini and big are the hand
## layout drawn smaller / larger.
func _base() -> Vector2:
	return SIZES["hand"] if size_kind in ["mini", "big"] else SIZES[size_kind]


## True for a backrow card the viewer can see but that is still face down: it is drawn as a card
## back with only its name. Face up (view.face_up) or Revealed (statuses.reveal > 0) shows the face.
func _is_own_set_card() -> bool:
	if view.get("zone", "") != "backrow" or view.get("face_up", true):
		return false
	return int(view.get("statuses", {}).get("reveal", 0)) <= 0


func _draw_back() -> void:
	CardBack.draw(_paint, 8.0 if size_kind in BIG_KINDS else 6.0)


# ---------------------------------------------------------------- forwarders (stable public statics)

## Splits a long name for a two-line plate. See CardTextLayout.split_name.
static func split_name(nm: String) -> PackedStringArray:
	return CardTextLayout.split_name(nm)


## Hover tooltip: name plus wrapped card text. See CardText.tooltip_for.
static func tooltip_for(v: Dictionary, width: int = CardText.TOOLTIP_WIDTH) -> String:
	return CardText.tooltip_for(v, width)


## Rules text as printed on the card face. See CardText.card_text.
static func card_text(v: Dictionary) -> String:
	return CardText.card_text(v)


## The one card-back design onto any CanvasItem. See CardBack.draw_art.
static func draw_back_art(ci: CanvasItem, card: Rect2, s: float) -> void:
	CardBack.draw_art(ci, card, s)
