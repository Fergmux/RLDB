class_name PromptPlate
extends HousePanel
## Plate of the input-required prompt (F04-13): the house plate (HousePanel, F06-01) with the
## prompt's margins. The header strip carries the actor tag; `attend()` is its attention loop and
## `fit()` sizes it to exactly its content for a given width.


func _init() -> void:
	super("", "", Vector2(16, 14), 7)


## L6 (owner feedback 2026-11-05): the prompt's Cancel, a real button in the house Secondary family
## (bronze-iron plate, gold rim on hover) as wide as the panel, under the answers. It reads as a
## button at a glance (the owner found the old text link too easy to miss) yet stays quieter than
## the gold answers: an engraved ✕ medallion on the left and an "Esc" keycap on the right say what
## it does and that Esc does the same. Its sound is the selection's cancel (no second click).
class CancelButton extends JuicyButton:
	const LABEL := "Cancel"
	const TIP := "Cancel this choice (Esc)"
	## Height (px), the label size, and the side room for the medallion and the keycap.
	const HEIGHT := 34.0
	const LABEL_PX := 14
	const SIDE_PAD := 40.0
	const KEY_PX := 10

	func _init() -> void:
		super()
		text = LABEL
		name = "CancelButton"
		tooltip_text = TIP
		UIStyle.style_button(self, "secondary")
		add_theme_font_override("font", UIStyle.font_display(700))
		add_theme_font_size_override("font_size", LABEL_PX)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			if has_theme_stylebox_override(st):
				var sb := get_theme_stylebox(st)
				sb.content_margin_left = SIDE_PAD
				sb.content_margin_right = SIDE_PAD
		custom_minimum_size = Vector2(120, HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_NONE
		set_meta(Sfx.BUTTON_META, "none")   # GameSelection.cancel plays "cancel"

	func _draw() -> void:
		super()
		if size.x < 60.0:
			return
		var lit := _hover or _down
		var dy := 1.0 if _down else 0.0
		var cy := size.y / 2.0 + dy - 0.5
		var gold: Color = UIStyle.GOLD_HI if lit else Color(UIStyle.GOLD, 0.85)
		# The ✕ medallion: a dark socket, a gold ring and two crossed strokes.
		var c := Vector2(19.0, cy)
		var r := 9.0
		draw_circle(c, r + 1.2, Color(0, 0, 0, 0.55), true, -1.0, true)
		draw_circle(c, r, Color("1a1512"), true, -1.0, true)
		draw_arc(c, r, 0.0, TAU, 28, gold, 1.2, true)
		var k := 3.4
		for s in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(c - s * k, c + s * k, Color(0, 0, 0, 0.5), 2.8, true)
			draw_line(c - s * k, c + s * k, UIStyle.TEXT if lit else Color(UIStyle.TEXT, 0.85), 1.5, true)
		# The Esc keycap.
		var f := UIStyle.font_bold()
		var tw := f.get_string_size("Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_PX).x
		var kr := Rect2(Vector2(size.x - 12.0 - tw - 10.0, cy - 8.0), Vector2(tw + 10.0, 16.0))
		var cap := StyleBoxFlat.new()
		cap.bg_color = Color(0, 0, 0, 0.35)
		cap.border_color = Color(UIStyle.BRONZE, 0.9 if lit else 0.6)
		cap.set_border_width_all(1)
		cap.border_width_bottom = 2
		cap.set_corner_radius_all(3)
		cap.anti_aliasing = true
		draw_style_box(cap, kr)
		draw_string(f, Vector2(kr.position.x + 5.0, kr.position.y + 12.0), "Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_PX,
			Color(UIStyle.MUTED, 1.0) if not lit else UIStyle.TEXT)
