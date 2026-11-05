class_name ScrollCue
extends Control
## "Scroll for more" cue over the bottom edge of a scroll area while its content continues below
## the fold. J5 (owner, 22 Oct): an overlay, never a laid-out sibling, so the content does not jump
## when the cue fades away. `wrap` puts the scroll area in a plain frame with the cue over it and
## keeps the cue along the bottom of the visible content.

## Seconds a scroll cue takes to fade in or out.
const FADE_S := 0.18
## Height of the overlay: a soft fade from the content into the panel colour, with the caption in
## its lower part.
const H := 34.0
## Colour the content fades into under the caption (the side panel's slate).
const TINT := Color(0.085, 0.075, 0.068, 0.97)

## True while the cue is meant to be showing (it may still be fading in or out).
var shown: bool = false
## L23 follow-up: names of the sections below the fold (e.g. "Evolve", "Statuses"); the caption
## names them when they fit ("Scroll for Evolve, Statuses"), else "Scroll for more".
var more: PackedStringArray = PackedStringArray()
const PX := 13
var _host: ScrollContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


## Wraps `sc` (not yet in the tree) in a plain frame, puts the cue over its bottom edge and returns
## the frame to add where `sc` would go. The frame takes `sc`'s size flags, minimum size and
## visibility, so code that shows, hides or resizes `sc` keeps working; set the vertical size flag
## on the frame. A ScrollContainer lays out every child, even internal ones, so the cue cannot
## live inside `sc` itself.
func wrap(sc: ScrollContainer) -> Control:
	_host = sc
	var frame := Control.new()
	frame.name = "%sFrame" % sc.name
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = sc.size_flags_horizontal
	frame.size_flags_vertical = sc.size_flags_vertical
	frame.visible = sc.visible
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(sc)
	frame.add_child(self)
	sc.visibility_changed.connect(func(): frame.visible = sc.visible)
	sc.minimum_size_changed.connect(func(): frame.custom_minimum_size = sc.get_combined_minimum_size())
	sc.resized.connect(place)
	var vb := sc.get_v_scroll_bar()
	vb.visibility_changed.connect(place)
	vb.resized.connect(place)
	place()
	return frame


## Moves the cue to the bottom edge of its scroll area, as wide as the visible content.
func place() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var vb := _host.get_v_scroll_bar()
	var w := _host.size.x
	if vb.visible:
		w = minf(w, vb.position.x)
	position = _host.position + Vector2(0.0, _host.size.y - H)
	size = Vector2(maxf(0.0, w), H)
	queue_redraw()


## Sets the names of the sections below the fold (redraws when they change).
func set_more(names: PackedStringArray) -> void:
	if names == more:
		return
	more = names
	queue_redraw()


## The caption drawn now: the hidden sections by name when they fit the cue's width.
func text() -> String:
	return caption_for(more, size.x)


## The caption for hidden sections `names` in a cue `width` px wide: all of them, else the first
## "and more", else the plain "Scroll for more" (the arrows beside it need 40 px).
static func caption_for(names: PackedStringArray, width: float) -> String:
	var font := UIStyle.font_bold()
	var tries: Array[String] = []
	if not names.is_empty():
		tries.append("Scroll for %s" % ", ".join(names))
		if names.size() > 1:
			tries.append("Scroll for %s and more" % names[0])
	for t in tries:
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, PX).x + 40.0 <= width:
			return t
	return "Scroll for more"


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
	var txt := text()
	var px := PX
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var cx := size.x / 2.0
	# The content fades into the panel over the top half, then a solid band carries the caption.
	var mid := size.y * 0.42
	Ornate.vgradient(self, Rect2(0, 0, size.x, mid), Color(TINT, 0.0), TINT)
	draw_rect(Rect2(0, mid, size.x, size.y - mid), TINT)
	var base := size.y - 8.0
	draw_string(font, Vector2(cx - sz.x / 2.0, base + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(cx - sz.x / 2.0, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UIStyle.GOLD_HI)
	var cy := base - sz.y * 0.3
	for dx in [-sz.x / 2.0 - 14.0, sz.x / 2.0 + 14.0]:
		var c := Vector2(cx + dx, cy)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]), UIStyle.GOLD_HI)
