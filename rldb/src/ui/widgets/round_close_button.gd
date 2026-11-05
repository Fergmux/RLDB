class_name RoundCloseButton
extends Button
## J20: the round close button of the house popovers (chat, lobby list). A forged medallion: a dark
## enamel disc in a bevelled gold ring with a crisp engraved cross, a soft drop shadow and a faint
## gold halo so it reads at a glance against the gold header strip. Hover warms the ring, adds a
## glow and a small lift (1.08); a press sinks it (0.92) with the ring brightened. Reduced motion
## keeps the colour changes and skips the scaling. Drawn with circles and lines, crisp at any size.
##
##     var x := RoundCloseButton.new(30.0)
##     x.tooltip_text = "Close"
##     x.pressed.connect(close_me)

const HOVER_SCALE := 1.08
const PRESS_SCALE := 0.92

## Diameter of the medallion (px). The control is that size plus room for the halo.
var diameter: float = 30.0:
	set(v):
		diameter = v
		custom_minimum_size = Vector2(v, v) + Vector2(4, 4)
		queue_redraw()

var _hover := false
var _down := false
var _tw: Tween


func _init(px: float = 30.0) -> void:
	diameter = px
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	Sfx.install_button_sounds()
	mouse_entered.connect(func(): _hover = true; _settle())
	mouse_exited.connect(func(): _hover = false; _down = false; _settle())
	button_down.connect(func(): _down = true; _settle())
	button_up.connect(func(): _down = false; _settle())
	resized.connect(func(): pivot_offset = size / 2.0)


## Only the disc itself takes the click (not the halo room around it).
func _has_point(p: Vector2) -> bool:
	return p.distance_to(size / 2.0) <= diameter / 2.0 + 2.0


func _settle() -> void:
	queue_redraw()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var to := PRESS_SCALE if _down else (HOVER_SCALE if _hover else 1.0)
	if UIStyle.reduce_motion or not is_inside_tree():
		scale = Vector2.ONE
		return
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(to, to), 0.06 if _down else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var c := size / 2.0
	var r := diameter / 2.0
	var hot := _hover or _down
	# Halo and drop shadow.
	draw_circle(c + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.5))
	if hot:
		for i in 3:
			draw_circle(c, r + 1.5 + i * 1.6, Color(UIStyle.GOLD_HI, 0.16 - i * 0.045))
	# Bevelled gold ring: dark outer edge, bright upper-left light, the ring body.
	draw_circle(c, r, UIStyle.GOLD.darkened(0.55))
	draw_circle(c, r - 1.0, UIStyle.GOLD_HI if hot else UIStyle.GOLD)
	draw_arc(c, r - 1.6, PI * 1.05, PI * 1.75, 16, Color(1, 0.95, 0.8, 0.75), 1.2, true)
	# Enamel disc: deep oxblood when hot, dark umber at rest, with a soft top sheen.
	var face := Color(0.36, 0.09, 0.06) if hot else Color(0.14, 0.09, 0.05)
	draw_circle(c, r - 3.2, face.darkened(0.35))
	draw_circle(c + Vector2(0, -0.6), r - 3.8, face)
	draw_circle(c + Vector2(-r * 0.18, -r * 0.28), r * 0.42, Color(1, 0.9, 0.7, 0.07))
	# Engraved cross: a dark groove under a bright stroke.
	var k := (r - 3.8) * 0.48
	var w := maxf(2.0, diameter / 13.0)
	var ink := Color(1.0, 0.93, 0.78) if hot else UIStyle.GOLD_HI
	if _down:
		ink = Color.WHITE
	for s in [Vector2(1, 1), Vector2(1, -1)]:
		var a: Vector2 = c - s * k
		var b: Vector2 = c + s * k
		draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0, 0, 0, 0.6), w + 0.6, true)
		draw_line(a, b, ink, w, true)
