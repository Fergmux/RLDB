class_name JuicyButton
extends Button
## The game's button (UIStyle.button / primary_button / secondary_button / danger_button): the
## theme stylebox gives the body, border and drop shadow; this adds a soft top gloss and a highlight
## line, the family's inner hover glow, a lift on hover (1.03, 120 ms in / 180 ms out), a press-in
## (0.97 in 60 ms, back in 140 ms with a BACK overshoot) and the keyboard focus ring (2 px GOLD_HI,
## 3 px outside, pulsing on the 2.4 s breathe loop). Design review 1.4.4 / 1.4.5. Reduced motion
## keeps the gloss, glow and a static ring but skips the scaling.

const HOVER_SCALE := 1.03
const PRESS_SCALE := 0.97
## Inner glow depth (px) of the hover state (Secondary / Danger families).
const INNER_GLOW_PX := 6.0
const INNER_GLOW_STEPS := 4

## Inner glow drawn while hovered (alpha 0 = none). Set by UIStyle.style_button per family.
var hover_inner_glow: Color = Color(0, 0, 0, 0):
	set(v):
		hover_inner_glow = v
		queue_redraw()

## Dev / screenshots: draw the focus ring without focus (only one control can hold focus).
var force_focus_ring: bool = false:
	set(v):
		force_focus_ring = v
		queue_redraw()

var _hover := false
var _down := false
## Focus came from the keyboard or from code (grab_focus), not from a click: show the ring.
var _ring := false
var _tw: Tween


func _init() -> void:
	Sfx.install_button_sounds()   # F25: the click comes from the shared hook (Sfx.button_sound)
	mouse_entered.connect(func(): _hover = true; _settle(); queue_redraw())
	mouse_exited.connect(func(): _hover = false; _down = false; _settle(); queue_redraw())
	button_down.connect(func(): _down = true; _settle(); queue_redraw())
	button_up.connect(func(): _down = false; _settle(); queue_redraw())
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(func(): _ring = false; set_process(false); queue_redraw())
	resized.connect(func(): pivot_offset = size / 2.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(false)


## True while the keyboard focus ring is shown.
func focus_ring_shown() -> bool:
	return force_focus_ring or (_ring and has_focus())


func _on_focus_entered() -> void:
	# A click focuses a FOCUS_ALL button too: no ring for the mouse, only for keys and grab_focus.
	_ring = not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	set_process(_ring and not UIStyle.reduce_motion)
	queue_redraw()


func _process(_d: float) -> void:
	queue_redraw()   # the ring breathes


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
	var token := "press" if _down else ("press_back" if scale.x < 0.995 else ("hover" if _hover else "hover_out"))
	_tw = create_tween()
	UIStyle.tween_token(_tw, self, "scale", Vector2(want, want), token)


func _draw() -> void:
	if focus_ring_shown():
		_draw_focus_ring()
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
	if _hover and hover_inner_glow.a > 0.0:
		# Stacked inset rings, strongest at the border, fading inwards over INNER_GLOW_PX.
		for i in INNER_GLOW_STEPS:
			var k := float(i) / float(INNER_GLOW_STEPS)
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.set_corner_radius_all(maxi(1, 6 - i))
			ring.set_border_width_all(int(INNER_GLOW_PX / INNER_GLOW_STEPS) + 1)
			ring.border_color = Color(hover_inner_glow, hover_inner_glow.a * (1.0 - k))
			draw_style_box(ring, Rect2(Vector2.ONE * (1.0 + k * INNER_GLOW_PX), size - Vector2.ONE * (2.0 + 2.0 * k * INNER_GLOW_PX)))


func _draw_focus_ring() -> void:
	var a := 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) / 1000.0 / 2.4 * TAU)
	if UIStyle.reduce_motion:
		a = 1.0
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(int(UIStyle.FOCUS_RING_W))
	ring.set_corner_radius_all(9)
	ring.border_color = Color(UIStyle.FOCUS_RING, a)
	ring.shadow_color = Color(UIStyle.FOCUS_RING, 0.25 * a)
	ring.shadow_size = 4
	var g := UIStyle.FOCUS_RING_GAP + UIStyle.FOCUS_RING_W
	draw_style_box(ring, Rect2(-Vector2.ONE * g, size + Vector2.ONE * g * 2.0))


## A tooltip naming a status gets a section describing it (owner feedback 2026-10-18).
func _make_custom_tooltip(for_text: String) -> Object:
	return StatusHelp.tooltip(for_text)
