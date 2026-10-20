class_name TextLink
extends Button
## A text-only link button for escape hatches and secondary navigation (design review #34, #61,
## #99): no plate, MUTED text that turns GOLD_HI with a 1 px underline on hover. It is a real
## Button, so the shared Sfx hook gives it its click ("back" for Cancel / Back) and hover cue.

## Gap between the baseline area and the underline (px).
const UNDERLINE_GAP := 2.0

var _hover := false


## A link reading `text` at `size` px.
static func make(p_text: String, size: int = 13) -> TextLink:
	var l := TextLink.new()
	l.text = p_text
	l.add_theme_font_size_override("font_size", size)
	return l


func _init() -> void:
	Sfx.install_button_sounds()
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", UIStyle.font_bold())
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var e := StyleBoxEmpty.new()
		UIStyle.pad(e, "sm", "xs")
		add_theme_stylebox_override(st, e)
	add_theme_color_override("font_color", UIStyle.MUTED)
	add_theme_color_override("font_focus_color", UIStyle.MUTED)
	add_theme_color_override("font_hover_color", UIStyle.GOLD_HI)
	add_theme_color_override("font_pressed_color", UIStyle.GOLD)
	add_theme_color_override("font_hover_pressed_color", UIStyle.GOLD)
	add_theme_color_override("font_disabled_color", UIStyle.DISABLED)
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


## True while the pointer is over the link (the underline shows).
func hovered() -> bool:
	return _hover


func _draw() -> void:
	if not _hover or disabled:
		return
	var font := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := (size.x - w) / 2.0
	var y := size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0 + UNDERLINE_GAP
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(UIStyle.GOLD_HI, 0.85), 1.0)
