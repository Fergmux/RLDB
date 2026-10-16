class_name MenuItem
extends Button
## One entry of the main menu's left-hand list: large Cinzel text, left-aligned. Hover slides it a
## touch right, turns it gold and draws a gold rule with a diamond marker; the item whose content
## is shown stays marked (`active`). `slide` is animated when a menu level appears.

const DEFAULT_SIZE := 30
## Row height as a multiple of the font size.
const ROW_HEIGHT_FACTOR := 1.75
const HOVER_TIME := 0.14
const HOVER_SHIFT := 8.0
const TEXT_X := 30.0
const MARKER_X := 12.0
const MARKER_RADIUS := 5.0
const MARKER_GROW := 1.5
const RULE_DROP := 8.0
## How far the rule starts left of the text.
const RULE_LEAD := 4.0
const RULE_WIDTH := 1.5
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.55
const RULE_ALPHA := 0.55
## Gold mix of the text colour while the item is the active one (not hovered).
const ACTIVE_TINT := 0.85

var label_text := ""
var fs := DEFAULT_SIZE
var muted := false
var active := false: set = _set_active
var slide := 0.0: set = _set_slide
var hl := 0.0: set = _set_hl
var _tw: Tween


func _init(t: String, size_px: int = DEFAULT_SIZE, is_muted: bool = false) -> void:
	label_text = t
	fs = size_px
	muted = is_muted
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, fs * ROW_HEIGHT_FACTOR)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(func(): _to_hl(1.0); Sfx.play("select", 0.0, 0.03))
	mouse_exited.connect(func(): _to_hl(0.0))


func _set_active(v: bool) -> void:
	active = v
	queue_redraw()


func _set_slide(v: float) -> void:
	slide = v
	queue_redraw()


func _set_hl(v: float) -> void:
	hl = v
	queue_redraw()


func _to_hl(v: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if UIStyle.reduce_motion:
		hl = v
		return
	_tw = create_tween()
	_tw.tween_property(self, "hl", v, HOVER_TIME).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var font: Font = UIStyle.font_title()
	var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mark := maxf(hl, 1.0 if active else 0.0)
	var x := TEXT_X + HOVER_SHIFT * hl + slide
	var base := size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	var col := (UIStyle.TEXT_DIM if muted else UIStyle.TEXT).lerp(UIStyle.GOLD_HI, maxf(hl, ACTIVE_TINT if active else 0.0))
	draw_string(font, Vector2(x, base) + SHADOW_OFFSET, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, SHADOW_ALPHA * modulate.a))
	draw_string(font, Vector2(x, base), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if mark > 0.01:
		var y := base + RULE_DROP
		draw_line(Vector2(x - RULE_LEAD, y), Vector2(x + tw, y), Color(UIStyle.GOLD, RULE_ALPHA * mark), RULE_WIDTH, true)
		var c := Vector2(MARKER_X + slide, size.y / 2.0)
		var r := MARKER_RADIUS + MARKER_GROW * mark
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), Color(UIStyle.GOLD_HI, mark))
