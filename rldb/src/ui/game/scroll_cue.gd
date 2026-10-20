class_name ScrollCue
extends Control
## Cue shown under the details text while it continues below the fold.

## Seconds a scroll cue takes to fade in or out.
const FADE_S := 0.18

## True while the cue is meant to be showing (it may still be fading in or out).
var shown: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


## Shows or hides the cue with a fade (instant with reduced motion).
func set_shown(on: bool) -> void:
	if on == shown:
		return
	shown = on
	fade(self, on)


## Fades `c` in or out (and hides it once faded out). Shared by every scroll cue and edge shadow so
## none of them pop in or out; with UIStyle.reduce_motion the change is immediate.
static func fade(c: CanvasItem, on: bool) -> void:
	if c.has_meta("cue_tw"):
		var old: Tween = c.get_meta("cue_tw")
		if old != null and old.is_valid():
			old.kill()
	if UIStyle.reduce_motion or not c.is_inside_tree():
		c.modulate.a = 1.0 if on else 0.0
		c.visible = on
		return
	if on:
		c.visible = true
	var tw := c.create_tween()
	c.set_meta("cue_tw", tw)
	tw.tween_property(c, "modulate:a", 1.0 if on else 0.0, FADE_S).set_trans(Tween.TRANS_SINE)
	if not on:
		tw.tween_callback(func(): c.visible = false)

func _draw() -> void:
	var font := UIStyle.font_bold()
	var txt := "Scroll for more"
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var cx := size.x / 2.0
	draw_rect(Rect2(0, 0, size.x, size.y), Color(UIStyle.GOLD, 0.12))
	draw_string(font, Vector2(cx - sz.x / 2.0, size.y / 2.0 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD_HI)
	for dx in [-sz.x / 2.0 - 14.0, sz.x / 2.0 + 14.0]:
		var c := Vector2(cx + dx, size.y / 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]), UIStyle.GOLD_HI)
