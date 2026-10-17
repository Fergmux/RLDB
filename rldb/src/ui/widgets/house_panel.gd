class_name HousePanel
extends PanelContainer
## The house plate for every modal, popover and prompt (F06-01, the F04-13 PromptPlate look made
## reusable): a vertical gradient body with a faint diagonal weave, a header strip with a glowing
## pip, a title and an optional tag, a gold accent bar down the left edge, corner flourishes and
## a gold rim with a soft gold glow. Every layer follows the rim's rounded corners, so nothing
## squares off or pokes past the border.
##
## Content goes into `body` (a VBoxContainer under the header). The panel sizes to its content
## like any PanelContainer; `fit(w)` settles wrapped text at a fixed width. `appear()` pops it in;
## `attend()` adds the prompt's breathing attention loop. Both are static under reduced motion.
##
##     var p := HousePanel.new("Confirm", "")       # header strip title, optional tag
##     p.add_headline("Concede this game?", 26, true)
##     p.body.add_child(some_content)
##     parent.add_child(p)
##     p.appear()

## Height of the header strip (the header row sits on it).
const HEAD_H := 30.0
## Rim width and outer corner radius; layers inside use the inner radius RADIUS - BORDER.
const BORDER := 3
const RADIUS := 12
## Width of the accent bar and the room the content leaves for it.
const ACCENT_W := 4.0
## Body gradient (top, bottom).
const BODY_TOP := Color(0.17, 0.125, 0.06)
const BODY_BOTTOM := Color(0.075, 0.055, 0.032)
## Pop-in: start scale and the flare that settles (attention and appear).
const POP_SCALE := 0.92
const POP_TIME := 0.35
const FLARE_TIME := 0.7
const FADE_TIME := 0.15
## Breathing border period (s) of the attention loop.
const BREATH := 1.4
## Rim glow at rest and at the peak of the flare.
const GLOW_REST_A := 0.45
const GLOW_REST_SIZE := 14
const GLOW_FLARE_SIZE := 34

## Header row: the pip, `title_label` and `tag_label` (null without a header).
var head_row: HBoxContainer
## Header strip title (small caps, bright gold).
var title_label: Label
## Optional tag at the right of the header strip (hidden while empty).
var tag_label: Label
## Content column under the header; add the panel's content here.
var body: VBoxContainer
## Corner flourish arm length (px); the header row keeps its tag clear of the flourish.
var arm: float = 14.0:
	set(v):
		arm = v
		_fit_head_end()
		queue_redraw()
## Draw the faint diagonal weave over the body.
var weave: bool = true

var _box: StyleBoxFlat
var _col: VBoxContainer
var _head_end: Control
var _header: bool = true
var _tween: Tween
var _gen := 0


## `title` and `tag` fill the header strip (`header` false leaves it out). `pad` is the content
## padding: x on the left (plus the accent bar) and right, y at the bottom (and at the top
## without a header). `gap` separates the header from the body and the body's children.
func _init(title: String = "", tag: String = "", pad: Vector2 = Vector2(22, 18), gap: int = 10, header: bool = true) -> void:
	_header = header
	_box = UIStyle.flat(Color(0, 0, 0, 0), UIStyle.GOLD_HI, BORDER, RADIUS)
	_box.content_margin_left = pad.x + ACCENT_W
	_box.content_margin_right = pad.x
	_box.content_margin_top = BORDER if header else pad.y
	_box.content_margin_bottom = pad.y
	_box.shadow_color = _glow(GLOW_REST_A)
	_box.shadow_size = GLOW_REST_SIZE
	_box.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", _box)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", gap)
	add_child(_col)
	if header:
		head_row = HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 6)
		head_row.custom_minimum_size = Vector2(40, HEAD_H - BORDER)
		head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(head_row)
		head_row.add_child(Pip.new())
		title_label = UIStyle.label(title.to_upper(), 12, UIStyle.GOLD_HI, false, true)
		title_label.clip_text = true
		title_label.custom_minimum_size = Vector2(40, 0)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head_row.add_child(title_label)
		tag_label = UIStyle.label(tag.to_upper(), 11, Color(UIStyle.GOLD, 0.8), false, true)
		tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag_label.visible = tag != ""
		head_row.add_child(tag_label)
		_head_end = Control.new()
		_head_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head_row.add_child(_head_end)
		_fit_head_end()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", gap)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(body)


# Room at the right end of the header row so the tag never runs under the corner flourish.
func _fit_head_end() -> void:
	if _head_end != null:
		_head_end.custom_minimum_size.x = maxf(0.0, arm + 8.0 - _box.content_margin_right)


## The rim style (border colour, glow, content margins).
func box() -> StyleBoxFlat:
	return _box


## Sets the header strip title (shown in capitals).
func set_title(text: String) -> void:
	if title_label != null:
		title_label.text = text.to_upper()


## Sets the header strip tag ("" hides it).
func set_tag(text: String) -> void:
	if tag_label != null:
		tag_label.text = text.to_upper()
		tag_label.visible = text != ""


## Size the panel adds around `body`: margins, the header row and the gap under it.
func chrome_size() -> Vector2:
	var gap := float(_col.get_theme_constant("separation"))
	var h := _box.content_margin_top + _box.content_margin_bottom
	if head_row != null:
		h += head_row.custom_minimum_size.y + gap
	return Vector2(_box.content_margin_left + _box.content_margin_right, h)


## Adds the house headline to the body: a display-face title over a fading gold rule. Returns
## the title label. `wrap` word-wraps it: use it only on a panel with a set width (a wrapped label
## in a content-sized panel measures itself one word wide and makes the panel tall).
func add_headline(text: String, font_size: int = 21, centred: bool = false, rule_h: float = 8.0, wrap: bool = true) -> Label:
	var t := UIStyle.label(text, font_size, UIStyle.GOLD_HI, wrap, true)
	t.custom_minimum_size = Vector2(40, 0)
	if centred:
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	body.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.55), true, rule_h))
	return t


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
		queue_redraw()


func _draw() -> void:
	var b := float(BORDER)
	var ir := maxf(float(_box.corner_radius_top_left) - b, 0.0)
	var inset := Rect2(Vector2(b, b), size - Vector2(b, b) * 2.0)
	if inset.size.x <= 2.0 or inset.size.y <= 2.0:
		return
	Ornate.rounded_gradient(self, inset, ir, ir, BODY_TOP, BODY_BOTTOM)
	var y0 := inset.position.y + (HEAD_H if _header else 0.0)
	if weave:
		_draw_weave(inset, y0)
	if _header:
		var hs := Rect2(inset.position, Vector2(inset.size.x, minf(HEAD_H, inset.size.y)))
		Ornate.rounded_gradient(self, hs, ir, 0.0, Color(UIStyle.GOLD.darkened(0.45), 0.95), Color(UIStyle.GOLD.darkened(0.72), 0.95), true)
		Ornate.rounded_gradient(self, Rect2(hs.position, Vector2(hs.size.x, minf(12.0, hs.size.y))), ir, 0.0, Color(1, 0.9, 0.6, 0.14), Color(1, 0.9, 0.6, 0.0))
		var x0 := inset.position.x + ir * 0.4
		var x1 := inset.end.x - ir * 0.4
		draw_line(Vector2(x0, hs.end.y), Vector2(x1, hs.end.y), Color(UIStyle.GOLD, 0.85), 1.5)
		draw_line(Vector2(x0, hs.end.y + 2.5), Vector2(x1, hs.end.y + 2.5), Color(UIStyle.GOLD, 0.25), 1.0)
	# Accent bar down the left edge, clear of the rounded corners.
	var ay := maxf(14.0, b + ir + 2.0)
	if size.y - 2.0 * ay > 4.0:
		Ornate.vgradient(self, Rect2(b, ay, ACCENT_W, size.y - 2.0 * ay), Color(UIStyle.GOLD_HI, 0.95), Color(UIStyle.GOLD.darkened(0.3), 0.8))
	Ornate.corners(self, Rect2(Vector2.ZERO, size), Color(UIStyle.GOLD_HI, 0.85), arm, 6.0, 1.5)


func _draw_weave(inset: Rect2, y: float) -> void:
	var wc := Color(UIStyle.GOLD, 0.035)
	var step := 9.0
	var x0 := inset.position.x + 10.0
	var x1 := inset.end.x - 4.0
	var yb := inset.end.y - 4.0
	var n := int((x1 - x0 + yb - y) / step)
	for i in n:
		var sx := x0 + i * step
		var sy := y
		if sx > x1:
			sy += sx - x1
			sx = x1
		var ln := minf(sx - x0, yb - sy)
		if ln > 2.0:
			draw_line(Vector2(sx, sy), Vector2(sx - ln, sy + ln), wc, 1.0)


## Sizes the panel to its content at width `w`. Wrapped labels report a minimum height measured at
## whatever width they had when last laid out, so the panel is resized in passes, one frame apart,
## until the measured height stops changing (usually two passes).
func fit(w: float) -> void:
	_gen += 1
	var gen := _gen
	custom_minimum_size.x = w
	size = Vector2(w, 0)
	size = Vector2(w, get_combined_minimum_size().y)
	if not is_inside_tree():
		return
	_settle(w, gen)


func _settle(w: float, gen: int) -> void:
	var last := -1.0
	for i in 4:
		await get_tree().process_frame
		if gen != _gen or not is_instance_valid(self):
			return
		size = Vector2(w, 0)
		var h := get_combined_minimum_size().y
		size = Vector2(w, h)
		if is_equal_approx(h, last):
			return
		last = h


## Opening animation of a modal: fades in and pops from 92 % with a gold flare that settles.
## Nothing moves under reduced motion (the panel simply shows at rest).
func appear() -> void:
	_kill()
	_rest()
	if UIStyle.reduce_motion or not is_inside_tree():
		return
	modulate.a = 0.0
	_pop()
	_tween.tween_property(self, "modulate:a", 1.0, UIStyle.dur(FADE_TIME))


## Attention treatment of the input prompt (F03-25): a pop and gold flare when `fresh` (a new
## choice), then a gentle breathing border and glow. Static (bright rim) under reduced motion.
func attend(fresh: bool) -> void:
	_kill()
	_rest()
	if UIStyle.reduce_motion or not is_inside_tree():
		return
	if not fresh:
		_breathe()
		return
	_pop()
	_tween.chain().tween_callback(_breathe)


## Stops any animation and leaves the panel at rest.
func calm() -> void:
	_kill()
	_rest()


func _rest() -> void:
	_box.border_color = UIStyle.GOLD_HI
	_box.shadow_color = _glow(GLOW_REST_A)
	_box.shadow_size = GLOW_REST_SIZE
	scale = Vector2.ONE
	modulate.a = 1.0


func _pop() -> void:
	scale = Vector2(POP_SCALE, POP_SCALE)
	_box.shadow_color = Color(UIStyle.GOLD_HI, 0.95)
	_box.shadow_size = GLOW_FLARE_SIZE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, UIStyle.dur(POP_TIME)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_box, "shadow_size", GLOW_REST_SIZE, UIStyle.dur(FLARE_TIME)).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_box, "shadow_color", _glow(GLOW_REST_A), UIStyle.dur(FLARE_TIME)).set_trans(Tween.TRANS_SINE)


func _breathe() -> void:
	_kill()
	_tween = create_tween().set_loops()
	var half := UIStyle.dur(BREATH) / 2.0
	_tween.tween_property(_box, "border_color", UIStyle.GOLD.darkened(0.25), half).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_box, "shadow_color", _glow(0.12), half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_box, "border_color", UIStyle.GOLD_HI, half).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_box, "shadow_color", _glow(0.5), half).set_trans(Tween.TRANS_SINE)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


static func _glow(a: float) -> Color:
	return Color(UIStyle.GOLD, a)


## Glowing diamond that leads the header strip title.
class Pip extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(14, HousePanel.HEAD_H - 4.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		Ornate.diamond(self, c, 7.0, Color(UIStyle.GOLD_HI, 0.3))
		Ornate.diamond(self, c, 5.0, UIStyle.GOLD_HI)
		Ornate.diamond(self, c, 2.0, Color(0.2, 0.13, 0.04))
