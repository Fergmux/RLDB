class_name JuicyButton
extends Button
## The game's button (UIStyle.button / primary_button): the theme stylebox gives the body, border
## and drop shadow; this adds a soft top gloss and a highlight line, a little lift on hover and a
## press-in on click (user feedback 2026-10-16: buttons felt flat). Reduced motion keeps the
## gloss but skips the scaling.

const HOVER_SCALE := 1.035
const PRESS_SCALE := 0.97
const SCALE_TIME := 0.09

var _hover := false
var _down := false
var _tw: Tween


func _init() -> void:
	mouse_entered.connect(func(): _hover = true; _settle(); queue_redraw())
	mouse_exited.connect(func(): _hover = false; _down = false; _settle(); queue_redraw())
	button_down.connect(func(): _down = true; _settle(); queue_redraw())
	button_up.connect(func(): _down = false; _settle(); queue_redraw())
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _settle() -> void:
	pivot_offset = size / 2.0   # scale from the centre (a size set before entering the tree emits no resize)
	var want := 1.0
	if not disabled:
		want = PRESS_SCALE if _down else (HOVER_SCALE if _hover else 1.0)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if UIStyle.reduce_motion or not is_inside_tree():
		scale = Vector2.ONE
		return
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(want, want), SCALE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if disabled or size.x < 8.0 or size.y < 8.0:
		return
	# Gloss over the upper part (stronger on hover), a crisp top highlight and a darker foot.
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.12 if _hover and not _down else (0.04 if _down else 0.07))
	gloss.corner_radius_top_left = 5
	gloss.corner_radius_top_right = 5
	draw_style_box(gloss, Rect2(2, 2, size.x - 4, size.y * 0.45))
	draw_line(Vector2(6, 2.5), Vector2(size.x - 6, 2.5), Color(1, 1, 1, 0.32 if _hover else 0.2), 1.0)
	draw_line(Vector2(6, size.y - 2.5), Vector2(size.x - 6, size.y - 2.5), Color(0, 0, 0, 0.28), 1.0)
