class_name MenuItem
extends Button
## One entry of the main menu's left-hand list (design review #3, #4, D3). The text is a MENU-tier
## TitleText: ivory Cinzel with a 1 px outline and the two-layer screen shadow at rest; on hover it
## blends to the gold screen gradient with a 10 px gold glow and slides 6 px right (120 ms QUAD
## OUT, 180 ms back), while a gold diamond fades and scales in at the left and a gold rule draws
## under the text. The item whose content is shown stays marked (`active`). Pressing scales it to
## 0.97 and back. The hover cue (ui_hover) and the click (click_primary, or back for the Back
## item) come from Sfx's button hook. `slide` is animated when a menu level appears.
##
## The muted variant is a sub-level's Back item: MUTED ivory, a leading "‹", the same hover.

const DEFAULT_SIZE := 30
## Row height as a multiple of the font size.
const ROW_HEIGHT_FACTOR := 1.75
const HOVER_SHIFT := 6.0
const TEXT_X := 30.0
const MARKER_X := 12.0
const MARKER_RADIUS := 5.0
const MARKER_GROW := 1.5
const RULE_DROP := 7.0
## How far the rule starts left of the text.
const RULE_LEAD := 4.0
const RULE_WIDTH := 1.5
const RULE_ALPHA := 0.6
## Press scale (motion token `press`, then `press_back`).
const PRESS_SCALE := 0.97
## Leading glyph of the muted (Back) item.
const BACK_GLYPH := "‹  "

## Text shown.
var label_text := ""
## Font size.
var fs := DEFAULT_SIZE
## Drawn dimmed (the Back item).
var muted := false
## Marked as the current choice.
var active := false: set = _set_active
## Slide-in offset (animated).
var slide := 0.0: set = _set_slide
## Highlight amount (animated).
var hl := 0.0: set = _set_hl
## The drawn title (MENU tier).
var title: TitleText
var _tw: Tween
var _press_tw: Tween


func _init(t: String, size_px: int = DEFAULT_SIZE, is_muted: bool = false) -> void:
	label_text = t
	fs = size_px
	muted = is_muted
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, fs * ROW_HEIGHT_FACTOR)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Sfx.install_button_sounds()   # F25: pressing plays the gold click, the Back item the back sound
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	title = TitleText.make((BACK_GLYPH + t) if muted else t, TitleText.Tier.MENU, fs)
	title.name = "Title"
	if muted:
		title.fill_color = UIStyle.MUTED
	add_child(title, false, Node.INTERNAL_MODE_FRONT)
	mouse_entered.connect(func(): _to_hl(1.0))
	mouse_exited.connect(func(): _to_hl(0.0))
	button_down.connect(func(): _press(true))
	button_up.connect(func(): _press(false))
	resized.connect(_place)


func _ready() -> void:
	_place()
	_sync_title(true)


func _set_active(v: bool) -> void:
	active = v
	_sync_title(not is_inside_tree())
	queue_redraw()


func _set_slide(v: float) -> void:
	slide = v
	_place()
	queue_redraw()


func _set_hl(v: float) -> void:
	hl = v
	_place()
	queue_redraw()


## Places the title at its slid / hovered x, the full row height.
func _place() -> void:
	if title == null:
		return
	title.position = Vector2(TEXT_X + HOVER_SHIFT * hl + slide, 0)
	title.size = Vector2(maxf(0.0, size.x - TEXT_X), size.y)


func _sync_title(instant: bool) -> void:
	if title != null:
		title.set_hovered(hl > 0.5 or active, instant)


func _to_hl(v: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if title != null:
		title.set_hovered(v > 0.5 or active)
	if UIStyle.reduce_motion or not is_inside_tree():
		hl = v
		return
	_tw = create_tween()
	UIStyle.tween_token(_tw, self, "hl", v, "hover" if v > 0.5 else "hover_out")


func _press(down: bool) -> void:
	if UIStyle.reduce_motion or not is_inside_tree():
		return
	if _press_tw != null and _press_tw.is_valid():
		_press_tw.kill()
	pivot_offset = Vector2(TEXT_X, size.y / 2.0)
	_press_tw = create_tween()
	UIStyle.tween_token(_press_tw, self, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0), "press" if down else "press_back")


## Width of the drawn text (px).
func text_width() -> float:
	return title.get_minimum_size().x if title != null else 0.0


func _draw() -> void:
	var mark := maxf(hl, 1.0 if active else 0.0)
	if mark <= 0.01:
		return
	var font := TitleText.tier_font(TitleText.Tier.MENU)
	var x := TEXT_X + HOVER_SHIFT * hl + slide
	var base := size.y / 2.0 + TitleText.cap_height(font, fs) / 2.0
	var y := base + RULE_DROP
	var tw := text_width()
	# The rule: a gold line under the text with a 1 px shade under it (engraved).
	draw_line(Vector2(x - RULE_LEAD, y), Vector2(x + tw * mark, y), Color(UIStyle.GOLD, RULE_ALPHA * mark), RULE_WIDTH, true)
	draw_line(Vector2(x - RULE_LEAD, y + 1.5), Vector2(x + tw * mark, y + 1.5), Color(0, 0, 0, 0.45 * mark), 1.0, true)
	# The diamond marker: fades and scales in, with a soft gold halo.
	var c := Vector2(MARKER_X + slide, size.y / 2.0)
	var r := (MARKER_RADIUS + MARKER_GROW * mark) * (0.55 + 0.45 * mark)
	Ornate.diamond(self, c, r + 4.0, Color(UIStyle.GOLD_HI, 0.18 * mark))
	Ornate.diamond(self, c + Vector2(0, 1.5), r, Color(0, 0, 0, 0.6 * mark))
	Ornate.diamond(self, c, r, Color(UIStyle.GOLD_HI, mark))
	Ornate.diamond(self, c + Vector2(0, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.55 * mark))
