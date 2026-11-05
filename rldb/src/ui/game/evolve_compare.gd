class_name EvolveCompare
extends PanelContainer
## Final review #10 (design/review-final-2026-11-05.md): the Evolve prompt's hover enlargement. While
## the pointer is over the prompt's Evolve strip, both forms show side by side at a readable size
## ("Now" -> "Evolves into") in a violet-inked flyout beside the prompt panel, so the player can read
## what the unit becomes before answering. Display only: it never receives the mouse and never sends
## anything. It opens with the `tooltip_in` motion (a short fade under reduce motion) and closes after
## CLOSE_DELAY, so moving between the two rows never flickers it.

## Each form's card (2:3): the hovered hand card's size (GameHoverController.HAND_SCALE x 120x180),
## the size the owner already reads a whole card at.
const CARD := Vector2(210, 315)
## Gap between the flyout and the prompt panel, and the least distance from the screen edges.
const GAP := 14.0
const EDGE := 8.0
## Width of the arrow column between the two cards.
const ARROW_W := 46.0
## Caption size over each card.
const CAPTION_PX := 13
## Seconds the pointer may leave the strip before the flyout closes.
const CLOSE_DELAY := 0.12

## The prompt panel the flyout sits beside, and the strip whose hover opens it.
var anchor: Control
var trigger: Control
var _from: CardWidget
var _to: CardWidget
var _armed := false
var _hover := false
var _mouse_in := false
var _close_at := -1.0


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = UiLayers.PROMPT_FLYOUT
	# A floating surface (depth 3) in the inspector's Evolve ink: faint violet under a blossom rim.
	var sb := UIStyle.flat(Color(0.075, 0.05, 0.085, 0.97), Color(EvolveGlyph.COLOR, 0.55), 1, 10)
	UIStyle.pad(sb, "lg", "md")
	UIStyle.lift(sb, 3)
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_from = _form(row, "NOW", UIStyle.MUTED)
	var arrow := EvolveArrow.new()
	arrow.custom_minimum_size = Vector2(ARROW_W, 0)
	arrow.size_flags_vertical = Control.SIZE_FILL
	arrow.caption_h = CAPTION_PX + 8.0
	row.add_child(arrow)
	_to = _form(row, "EVOLVES INTO", EvolveGlyph.COLOR)


func _form(row: HBoxContainer, caption: String, col: Color) -> CardWidget:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var cap := UIStyle.label(caption, CAPTION_PX, col)
	cap.add_theme_font_override("font", UIStyle.font_bold())
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var w := CardWidget.new()
	w.auto_hover = false
	w.show_tooltip = false
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(w)
	GameUi.resize_card(w, CARD)
	return w


## Arms the flyout for an Evolve prompt: `from` (the unit as it is now) and `to` (the card it
## evolves into), opened by hovering `strip` beside `panel`. Closes it if it was showing another pair.
func arm(from: Dictionary, to: Dictionary, strip: Control, panel: Control) -> void:
	var same: bool = _armed and _from.view.get("uid") == from.get("uid") and _to.view.get("id") == to.get("id")
	_armed = true
	trigger = strip
	anchor = panel
	_from.setup(from, "mini")
	_to.setup(to, "mini")
	GameUi.resize_card(_from, CARD)
	GameUi.resize_card(_to, CARD)
	if not same:
		_set_open(false, true)


## Disarms and hides the flyout (the prompt is gone or is not an Evolve).
func disarm() -> void:
	_armed = false
	_hover = false
	_mouse_in = false
	_close_at = -1.0
	_set_open(false, true)


## True while an Evolve prompt has armed the flyout.
func armed() -> bool:
	return _armed


## Opens (`on`) or starts closing the flyout as if the pointer entered or left the strip.
func set_hover(on: bool) -> void:
	if not _armed:
		return
	_hover = on
	if on:
		_close_at = -1.0
		_set_open(true)
	else:
		_close_at = Time.get_ticks_msec() / 1000.0 + CLOSE_DELAY


## Where the flyout of size `sz` goes for a prompt panel at `panel` (global rect): to its right,
## else to its left, else below it, vertically centred on `focus_y` (the strip) and kept `EDGE` px
## inside `bounds`.
static func place(panel: Rect2, focus_y: float, sz: Vector2, bounds: Rect2) -> Vector2:
	var y := clampf(focus_y - sz.y / 2.0, bounds.position.y + EDGE, bounds.end.y - sz.y - EDGE)
	var right := panel.end.x + GAP
	if right + sz.x <= bounds.end.x - EDGE:
		return Vector2(right, y)
	var left := panel.position.x - GAP - sz.x
	if left >= bounds.position.x + EDGE:
		return Vector2(left, y)
	var x := clampf(panel.get_center().x - sz.x / 2.0, bounds.position.x + EDGE, bounds.end.x - sz.x - EDGE)
	return Vector2(x, panel.end.y + GAP)


func _process(_delta: float) -> void:
	if not _armed:
		return
	if not is_instance_valid(trigger) or not trigger.is_visible_in_tree() or not is_instance_valid(anchor) \
			or not anchor.is_visible_in_tree():
		if visible:
			_set_open(false)
		return
	# The pointer entering or leaving the strip (edges only, so a test or driver can hold it open).
	var inside := trigger.get_global_rect().has_point(trigger.get_global_mouse_position())
	if inside != _mouse_in:
		_mouse_in = inside
		set_hover(inside)
	if _close_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _close_at:
		_close_at = -1.0
		_set_open(false)
	if visible:
		_place()


func _place() -> void:
	var sz := get_combined_minimum_size()
	size = sz
	var parent := get_parent() as Control
	var bounds := parent.get_global_rect() if parent != null else get_viewport_rect()
	var tr := trigger.get_global_rect()
	global_position = place(anchor.get_global_rect(), tr.get_center().y, sz, bounds)


func _set_open(on: bool, instant: bool = false) -> void:
	if on == visible and not instant:
		return
	if on:
		visible = true
		if is_instance_valid(trigger) and is_instance_valid(anchor):
			_place()
		UIStyle.tween_in(self, "tooltip_in")
		return
	if instant or not is_inside_tree() or not visible:
		visible = false
		modulate.a = 1.0
		return
	var tw := UIStyle.restart_tween(self, &"evolve_compare_out")
	tw.tween_property(self, "modulate:a", 0.0, UIStyle.motion("reduced" if UIStyle.reduce_motion else "hover_out"))
	tw.tween_callback(func():
		if not _hover:
			visible = false
		modulate.a = 1.0)


## The Evolve arrow between the two forms (and between the prompt's two rows): a tapered shaft in the
## Evolve colour with the blossom glyph riding on it. `down` points it down (the prompt's rows).
class EvolveArrow extends Control:
	## Points down instead of right.
	var down := false
	## Height of the caption over the cards (the arrow sits on the cards' middle, below it).
	var caption_h := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := EvolveGlyph.COLOR
		if down:
			var cx := size.x / 2.0
			var y0 := 1.0
			var y1 := size.y - 1.0
			_shaft(Vector2(cx, y0), Vector2(cx, y1), col)
			return
		var cy := caption_h + (size.y - caption_h) / 2.0
		_shaft(Vector2(4.0, cy), Vector2(size.x - 4.0, cy), col)
		EvolveGlyph.draw_glyph(self, Vector2(size.x / 2.0, cy - 22.0), 9.0, col)

	func _shaft(a: Vector2, b: Vector2, col: Color) -> void:
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var head := minf(11.0, (b - a).length() * 0.45)
		var tip := b
		var base := b - d * head
		# A soft dark under-stroke so the violet reads on leather and on the ink well alike.
		draw_line(a, base, Color(0, 0, 0, 0.45), 5.0, true)
		draw_line(a, base, col, 3.0, true)
		var tri := PackedVector2Array([tip, base + n * head * 0.62, base - n * head * 0.62])
		draw_colored_polygon(tri, col)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(col.darkened(0.45), 0.9), 1.0, true)
