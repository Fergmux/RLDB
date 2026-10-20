class_name OrnatePanel
extends PanelContainer
## Layered panel: the theme box (rounded, gold or bronze rim, drop shadow) under a vertical
## gradient, an inner hairline frame, a top sheen and optional corner flourishes. Children sit on
## top. Set the look through the vars; change `accent` to recolour the rim and flourishes.
##
## Modal use (design review #106, D3): `add_headline()` adds a SCREEN-tier title over the house
## rule; `appear()` opens the panel with the house `panel_in` motion and the `panel_open` cue (and
## sweeps the headline once); `dismiss()` closes it with `panel_out` and `panel_close`. Both fall
## back to a 120 ms fade under reduce motion. A plate re-rendered in place (a waiting plate inside
## a modal that already opened) uses the headline only and never calls appear().
##
##     var p := OrnatePanel.new(12, 24)
##     p.add_headline("Deck locked in")
##     p.content().add_child(body)
##     parent.add_child(p)
##     p.appear()

## Default headline size (SCREEN tier, px at 1600x900).
const HEADLINE_PX := 28
## Gap between the headline and its rule.
const HEADLINE_RULE_H := 12.0

## Rim and flourish colour.
var accent: Color = UIStyle.GOLD:
	set(v):
		accent = v
		queue_redraw()
## Gradient top / bottom (drawn inside the rim).
var top_col: Color = Color(0.13, 0.105, 0.08, 1.0)
var bottom_col: Color = Color(0.06, 0.05, 0.042, 1.0)
## Corner flourishes on / off, and their arm length.
var flourish: bool = true
var arm: float = 22.0
## Inset of the hairline frame from the edge (0 hides it).
var frame_inset: float = 6.0
## The SCREEN headline (null until add_headline()).
var headline: TitleText
## True between dismiss() and the panel being hidden or freed.
var dismissing: bool = false
var _box: StyleBoxFlat
var _content: VBoxContainer
var _motion: Tween
var _mouse_before: int = -1


## `radius` rounds the rim; `margin` is the content margin on every side.
func _init(radius: int = 12, margin: int = 16) -> void:
	_box = UIStyle.flat(Color(0, 0, 0, 0), accent, 2, radius)
	for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_box.set_content_margin(s, margin)
	_box.shadow_color = Color(0, 0, 0, 0.6)
	_box.shadow_size = 18
	_box.shadow_offset = Vector2(0, 6)
	add_theme_stylebox_override("panel", _box)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the leather grain tiles (UiSurface)


## The underlying rim style (to tweak border, shadow or margins).
func box() -> StyleBoxFlat:
	return _box


## The panel's content column: its first VBoxContainer child, created (separation 12) when the
## panel has none yet. Headlines and body content go here.
func content() -> VBoxContainer:
	if _content != null and is_instance_valid(_content) and _content.get_parent() == self:
		return _content
	for c in get_children():
		if c is VBoxContainer:
			_content = c
			return _content
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", UIStyle.sp("md"))
	add_child(_content)
	return _content


## Adds the house headline to the top of content(): a SCREEN-tier TitleText (D3) at `font_size`
## over a fading gold rule, centred by default, at child `index` of the column (0 = the top).
## Returns the title. A second call replaces the text of the existing headline.
func add_headline(text: String, font_size: int = HEADLINE_PX, centred: bool = true, index: int = 0) -> TitleText:
	if headline != null and is_instance_valid(headline):
		headline.text = text.to_upper()
		return headline
	var v := content()
	headline = TitleText.make(text.to_upper(), TitleText.Tier.SCREEN, font_size)
	headline.name = "Headline"
	headline.autowrap = true
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var at := clampi(index, 0, v.get_child_count())
	v.add_child(headline)
	v.move_child(headline, at)
	var rule := Ornate.Rule.new(Color(accent, 0.6), true, HEADLINE_RULE_H)
	rule.name = "HeadlineRule"
	v.add_child(rule)
	v.move_child(rule, at + 1)
	return headline


## Opening motion of a modal: `panel_in` (fade, 0.94 -> 1 scale with a BACK overshoot, a 12 px
## rise outside a Container), the `panel_open` cue and one sweep across the headline. Under
## reduce motion a 120 ms fade; the cue still plays. `sound` false keeps it silent (a plate that
## opens inside a modal that already played its own cue).
func appear(sound: bool = true) -> void:
	_stop_motion()
	dismissing = false
	if _mouse_before >= 0:
		mouse_filter = _mouse_before as Control.MouseFilter
		_mouse_before = -1
	if sound and is_inside_tree():
		Sfx.play("panel_open")
	if headline != null and is_instance_valid(headline):
		headline.play_sweep()
	if not is_inside_tree():
		return
	# The tween needs the laid-out size for its pivot: wait one frame inside a container.
	if size == Vector2.ZERO:
		modulate.a = 0.0
		await get_tree().process_frame
		if not is_instance_valid(self) or dismissing:
			return
	_motion = UIStyle.tween_in(self)


## Closing motion: `panel_out` (fade and 0.97 scale; a 120 ms fade under reduce motion) with the
## `panel_close` cue, then hides the panel, or frees it with `free_after`. `done` (optional) runs
## once it is gone. A second call while closing is ignored.
func dismiss(free_after: bool = true, done: Callable = Callable()) -> void:
	if dismissing:
		return
	dismissing = true
	_stop_motion()
	if is_inside_tree():
		Sfx.play("panel_close")
	_mouse_before = mouse_filter
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # no clicks on a closing panel
	_motion = UIStyle.tween_out(self, free_after)
	if done.is_valid():
		if _motion == null:
			done.call()
		else:
			_motion.finished.connect(done)


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _draw() -> void:
	_box.border_color = accent
	var r := Rect2(Vector2.ZERO, size)
	var inset := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	var rad := float(_box.corner_radius_top_left)
	# Gradient body: a centre block plus a rounded-corner-safe top and bottom band.
	Ornate.vgradient(self, Rect2(inset.position + Vector2(0, rad), inset.size - Vector2(0, rad * 2.0)), top_col.lerp(bottom_col, rad / maxf(size.y, 1.0)), bottom_col.lerp(top_col, rad / maxf(size.y, 1.0)))
	draw_rect(Rect2(inset.position + Vector2(rad, 0), Vector2(inset.size.x - rad * 2.0, rad)), top_col)
	draw_rect(Rect2(inset.position + Vector2(rad, inset.size.y - rad), Vector2(inset.size.x - rad * 2.0, rad)), bottom_col)
	UiSurface.draw_round(self, inset, maxf(0.0, rad - 2.0), UiSurface.LEATHER, top_col.lerp(bottom_col, 0.5), UIStyle.PANEL_GRAIN * 0.8)
	# Soft sheen under the top rim.
	Ornate.vgradient(self, Rect2(inset.position + Vector2(rad, 1), Vector2(inset.size.x - rad * 2.0, minf(34.0, size.y * 0.2))), Color(accent, 0.13), Color(accent, 0.0))
	if frame_inset > 0.0:
		draw_rect(Rect2(frame_inset, frame_inset, size.x - frame_inset * 2.0, size.y - frame_inset * 2.0), Color(accent, 0.22), false, 1.0)
	if flourish:
		Ornate.corners(self, r, Color(accent, 0.9), arm, maxf(frame_inset - 1.0, 3.0))
