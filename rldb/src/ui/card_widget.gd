class_name CardWidget
extends Control
## Procedurally drawn card (art bible section 4): layered frame, art window (card art or
## a placeholder), name plate, cost gem (shape per cost kind), ATK diamond / DEF shield,
## status chips and a face-down back. Everything is drawn from the redacted card view, so
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
## (CardPainter context + CardArt, CardFaceParts, CardStatBadge, CardChips, CardBack, CardLayouts,
## CardOverlays), text helpers to CardText / CardTextLayout.

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

## Hover lift (F04-05): the card grows to `lift_k` times its resting size and sits `lift_offset`
## away, about its centre. It is a REAL size change, never the `scale` property: the face is
## redrawn at the larger size, so text is rasterised at its final pixel size and stays crisp
## (a scaled Control would stretch the already-rasterised glyphs and blur them). Tween these two.
var lift_k: float = 1.0: set = _set_lift_k
var lift_offset: Vector2 = Vector2.ZERO: set = _set_lift_offset

var _lifting := false
var _lift_rest_pos := Vector2.ZERO
var _self_hover := false
var _is_ready := false
var _pv_stat := ""
var _pv_value := 0
var _pv_bonus := 0
## Drawing context: the state snapshot and scaled primitives every card part draws with.
var _paint := CardPainter.new(self)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func(): _self_hover = auto_hover; queue_redraw())
	mouse_exited.connect(func(): _self_hover = false; queue_redraw())
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
	var aspect := 1.5 if rotated else (2.0 / 3.0)   # width / height
	var w := size.x
	var h := size.y
	# 85x128 is 2:3 to within half a pixel; treat that as exact so the face is not offset by half a pixel.
	if absf(w / maxf(h, 0.001) - aspect) < 0.006:
		return Rect2(Vector2.ZERO, size)
	if w / maxf(h, 0.001) > aspect:
		w = h * aspect
	else:
		h = w / aspect
	return Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)


func _set_hovered(v: bool) -> void:
	hovered = v
	queue_redraw()


func _set_lift_k(v: float) -> void:
	lift_k = v
	_apply_lift()


func _set_lift_offset(v: Vector2) -> void:
	lift_offset = v
	_apply_lift()


## Sizes and places the card for the current lift: whole-pixel size, growth about the centre, whole-pixel
## position relative to where the card rested when the lift began.
func _apply_lift() -> void:
	var rest := custom_minimum_size
	if rest == Vector2.ZERO:
		return
	var neutral := is_equal_approx(lift_k, 1.0) and lift_offset.is_zero_approx()
	if not neutral and not _lifting:
		_lifting = true
		_lift_rest_pos = position
	var sz := rest if neutral else (rest * lift_k).round()
	size = sz
	if neutral:
		if _lifting:
			position = _lift_rest_pos
		_lifting = false
	else:
		position = (_lift_rest_pos + lift_offset - (sz - rest) / 2.0).round()


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit(self)
			accept_event()


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
	if view.is_empty():
		pt.s = clampf(minf(size.x, size.y) / 85.0, 0.5, 1.3)
		pt.cr = Rect2(Vector2.ZERO, size)
		CardLayouts.draw_empty(pt, size, highlighted)
		CardOverlays.draw(pt, self)
		return
	pt.cr = card_rect()
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
			"hand", "mini": CardLayouts.draw_tall(pt, false)
			"big": CardLayouts.draw_tall(pt, true)
			_: CardLayouts.draw_square(pt)
	pt.reset_transform()
	CardOverlays.draw(pt, self)


## Base (unscaled) portrait size the layout of this kind is authored in.
func _base() -> Vector2:
	return SIZES["hand"] if size_kind == "mini" else SIZES[size_kind]


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
