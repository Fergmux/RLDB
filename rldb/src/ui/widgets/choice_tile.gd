class_name ChoiceTile
extends PanelContainer
## Illustrated choice tile: a drawn icon over a title and optional caption, on a gradient plate with
## a rim that warms on hover and turns gold when selected. Used for the reward kinds and the card
## kinds of the rewards screen. Emits `pressed` on a left click; reduced motion skips the easing.

signal pressed

## Icon names beyond card-kind names: "add", "remove", "swap".
var icon: String = ""
var accent: Color = UIStyle.GOLD
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
var _hover := 0.0
var _box: StyleBoxFlat
var _compact := false
var _title: Label


## `kind` is "add", "remove", "swap" or a card category ("unit", "spell", ...). `compact` lays the
## icon beside the title (small tiles).
func _init(title: String = "", caption: String = "", color: Color = UIStyle.GOLD, kind: String = "", compact: bool = false) -> void:
	icon = kind
	accent = color
	_compact = compact
	_box = UIStyle.flat(Color(0, 0, 0, 0), Color(accent, 0.65), 2, 10)
	_box.content_margin_left = 12
	_box.content_margin_right = 12
	_box.content_margin_top = 10 if not compact else 7
	_box.content_margin_bottom = 12 if not compact else 7
	_box.shadow_color = Color(0, 0, 0, 0.5)
	_box.shadow_size = 6
	_box.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", _box)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if compact else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var ic := Icon.new(kind, accent, 34.0 if compact else 66.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var tl := UIStyle.label(title, 15 if compact else 17, UIStyle.TEXT, false, true)
	_title = tl
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if compact:
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
	else:
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long title wraps instead of widening its tile
	box.add_child(tl)
	if caption != "":
		var cl := UIStyle.label(caption, 13, UIStyle.TEXT_DIM, true)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cl)


## Overrides the title's font size (narrow tiles, e.g. the basic-unit pickers).
func set_title_size(px: int) -> void:
	_title.add_theme_font_size_override("font_size", px)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click()
		pressed.emit()
		accept_event()
	elif has_focus() and event.is_action_pressed("ui_accept"):
		# Keyboard use when a host makes the tile focusable (F06-05 / F06-06 pickers).
		_click()
		pressed.emit()
		accept_event()


## F25: a choice is a gold-family click (coalesced with any sound the host plays for the same pick);
## meta Sfx.BUTTON_META overrides it ("none" = silent).
func _click() -> void:
	var s := String(get_meta(Sfx.BUTTON_META, "click_primary"))
	if s != "none":
		Sfx.play(s, 0.0, 0.03)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _process(delta: float) -> void:
	var h := get_viewport().gui_get_hovered_control() if is_inside_tree() else null
	var want := 1.0 if h != null and (h == self or is_ancestor_of(h)) else 0.0
	var tgt := 1.0 if selected else want
	var cur := _hover
	_hover = tgt if UIStyle.reduce_motion else move_toward(_hover, tgt, delta * 8.0)
	if _hover != cur:
		queue_redraw()
		_box.border_color = Color(accent, 0.65).lerp(UIStyle.GOLD_HI if selected else accent.lightened(0.35), _hover)
		_box.shadow_color = Color(0, 0, 0, 0.5).lerp(Color(accent, 0.38), _hover)
		_box.shadow_size = int(lerpf(6.0, 15.0, _hover))
		_box.shadow_offset = Vector2(0, lerpf(3.0, 0.0, _hover))


func _draw() -> void:
	var rad := 9.0
	var inset := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var top := Color(accent.darkened(0.72), 1.0).lerp(Color(accent.darkened(0.55), 1.0), _hover)
	var bot := Color(accent.darkened(0.88), 1.0).lerp(Color(accent.darkened(0.78), 1.0), _hover)
	Ornate.vgradient(self, Rect2(inset.position + Vector2(0, rad), inset.size - Vector2(0, rad * 2.0)), top, bot)
	draw_rect(Rect2(inset.position + Vector2(rad, 0), Vector2(inset.size.x - rad * 2.0, rad)), top)
	draw_rect(Rect2(inset.position + Vector2(rad, inset.size.y - rad), Vector2(inset.size.x - rad * 2.0, rad)), bot)
	Ornate.vgradient(self, Rect2(inset.position + Vector2(rad, 1), Vector2(inset.size.x - rad * 2.0, 22)), Color(1, 1, 1, 0.07 + 0.05 * _hover), Color(1, 1, 1, 0))
	if not _compact:
		Ornate.corners(self, Rect2(Vector2.ZERO, size), Color(accent.lightened(0.2), 0.45 + 0.45 * _hover), 11.0, 5.0, 1.3)
	if selected:
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(UIStyle.GOLD, 0.5), false, 1.0)
	if has_focus():
		draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color(UIStyle.GOLD_HI, 0.9), false, 1.5)


## The drawn icon.
class Icon extends Control:
	var kind := ""
	var col := UIStyle.GOLD

	func _init(k: String, c: Color, px: float) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2.0
		var cw := s * 0.56
		var ch := s * 0.8
		var card := Rect2(c - Vector2(cw, ch) / 2.0 + Vector2(-s * 0.04, 0), Vector2(cw, ch))
		if kind != "" and UIStyle.TYPE_COLORS.has(kind):
			TypeIcons.draw_pip(self, kind, c, s * 0.38)
			return
		match kind:
			"add", "remove", "swap":
				_card(card, col)
				if kind == "swap":
					_card(Rect2(card.position + Vector2(s * 0.2, s * 0.06), card.size), col.lightened(0.15))
					_arrow(c + Vector2(0, -s * 0.38), s * 0.3, true)
					_arrow(c + Vector2(0, s * 0.38), s * 0.3, false)
				else:
					var b := c + Vector2(s * 0.3, s * 0.3)
					var bc: Color = UIStyle.GOOD if kind == "add" else UIStyle.BAD
					draw_circle(b, s * 0.22, Color(0.04, 0.03, 0.03, 0.95))
					draw_circle(b, s * 0.19, bc.darkened(0.2))
					draw_arc(b, s * 0.19, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 1.0, true)
					var k := s * 0.1
					draw_line(b + Vector2(-k, 0), b + Vector2(k, 0), Color.WHITE, maxf(2.0, s * 0.06), true)
					if kind == "add":
						draw_line(b + Vector2(0, -k), b + Vector2(0, k), Color.WHITE, maxf(2.0, s * 0.06), true)
			_:
				_card(card, col)
				CardArt.draw_glyph(self, CardArt._glyph_kind({"category": kind}), card.get_center(), cw * 0.32, Color(1, 1, 1, 0.55))

	func _card(r: Rect2, cc: Color) -> void:
		draw_rect(Rect2(r.position + Vector2(1.5, 2.5), r.size), Color(0, 0, 0, 0.45))
		Ornate.vgradient(self, r, cc.lightened(0.1), cc.darkened(0.55))
		draw_rect(r, Color(UIStyle.GOLD, 0.9), false, maxf(1.2, size.x * 0.03))
		var inner := Rect2(r.position + r.size * Vector2(0.14, 0.12), r.size * Vector2(0.72, 0.5))
		draw_rect(inner, Color(0, 0, 0, 0.3))
		draw_rect(inner, Color(UIStyle.GOLD, 0.5), false, 1.0)

	func _arrow(p: Vector2, w: float, right: bool) -> void:
		var d := 1.0 if right else -1.0
		var a := p + Vector2(-w * d, 0)
		var b := p + Vector2(w * d, 0)
		draw_line(a, b, UIStyle.GOLD_HI, maxf(2.0, size.x * 0.05), true)
		draw_colored_polygon(PackedVector2Array([b + Vector2(w * 0.4 * d, 0), b + Vector2(-w * 0.15 * d, -w * 0.35), b + Vector2(-w * 0.15 * d, w * 0.35)]), UIStyle.GOLD_HI)
