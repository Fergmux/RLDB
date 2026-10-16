class_name PhasePips
extends Control
## Phase pips for the turn bar.

## Turn phases in order: [phase id, label].
const PHASES := [["main1", "Setup"], ["battle", "Battle"], ["main2", "Recovery"]]

## Current phase id (one of PHASES).
var phase: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(0, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Pill tags with depth: inset dark pills for the other phases, a glowing gold pill with a
## gloss for the current one, joined by a thin track.
func _draw() -> void:
	var n := PHASES.size()
	var gap := 8.0
	var h := size.y - 4.0
	var w := (size.x - gap * (n - 1)) / n
	var font := UIStyle.font_bold()
	draw_line(Vector2(w * 0.5, 2.0 + h / 2.0), Vector2(size.x - w * 0.5, 2.0 + h / 2.0), Color(UIStyle.BRONZE, 0.5), 2.0)
	for i in n:
		var r := Rect2(i * (w + gap), 2.0, w, h)
		var on: bool = PHASES[i][0] == phase
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(h / 2.0))
		if on:
			sb.bg_color = UIStyle.GOLD
			sb.border_color = UIStyle.GOLD_HI
			sb.set_border_width_all(1)
			sb.shadow_color = Color(UIStyle.GOLD_HI, 0.45)
			sb.shadow_size = 7
		else:
			sb.bg_color = Color(0.07, 0.06, 0.05, 0.98)
			sb.border_color = Color(UIStyle.BRONZE, 0.75)
			sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.5)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(0, 1)
		draw_style_box(sb, r)
		var gl := StyleBoxFlat.new()
		gl.bg_color = Color(1, 1, 1, 0.22 if on else 0.05)
		gl.corner_radius_top_left = int(h / 2.0) - 1
		gl.corner_radius_top_right = int(h / 2.0) - 1
		draw_style_box(gl, Rect2(r.position + Vector2(2, 1.5), Vector2(r.size.x - 4, r.size.y * 0.45)))
		var txt: String = PHASES[i][1]
		var fs := 13
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(r.position.x + (w - sz.x) / 2.0, r.position.y + h / 2.0 + 4.8)
		if on:
			draw_string(font, pos + Vector2(0, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.35))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.ON_GOLD if on else UIStyle.MUTED)
