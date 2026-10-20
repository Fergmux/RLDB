class_name WaitNotice
extends PanelContainer
## "Ben is responding..." (design review #38): an F5 tooltip plate docked under the opponent's plate
## (no longer over the centre line, where it covered the units' ATK / DEF), with a small pointer notch
## up towards that plate, an hourglass that turns over and animated dots (WaitingDots). It fades in only
## after APPEAR_DELAY so a fast reply never flashes it. Click-through.

## Delay before it shows (s) and its fade (the tooltip_in token).
const APPEAR_DELAY := 0.25
## F5: parchment-dark body, its leather grain, the gold edge and the notch size (px).
const BODY := Color("1b1712")
const GRAIN := 0.3
const EDGE := Color(0.831, 0.651, 0.29, 0.6)
const NOTCH := 6.0

## The animated text.
var label: WaitingDots
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = UiLayers.WAIT
	visible = false
	var sb := UIStyle.flat(Color(BODY, 0.96), EDGE, 1, 4)
	UIStyle.pad(sb, "md", "sm")
	UIStyle.lift(sb, UIStyle.DEPTH_FLOATING)
	add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, GRAIN))
	var row := HBoxContainer.new()
	UIStyle.pad(row, "sm")
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var hg := Hourglass.new()
	hg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hg)
	label = WaitingDots.new("", 15, UIStyle.GOLD_HI)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)


## Shows `text` (its trailing ellipsis becomes the animated dots); fades in after APPEAR_DELAY the first
## time. An empty `text` hides it.
func show_text(text: String) -> void:
	if text == "":
		if _tw != null and _tw.is_valid():
			_tw.kill()
		visible = false
		return
	label.base = base_text(text)
	label._n = -2
	label._refresh(3 if not UIStyle.reduce_motion else -1)
	reset_size()
	size = get_combined_minimum_size()
	if visible:
		return
	visible = true
	modulate.a = 0.0
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_interval(APPEAR_DELAY)
	_tw.tween_property(self, "modulate:a", 1.0, UIStyle.motion("reduced" if UIStyle.reduce_motion else "tooltip_in"))


## `text` without its trailing dots or ellipsis (the dots are animated).
static func base_text(text: String) -> String:
	var t := text.strip_edges()
	while t.ends_with("…") or t.ends_with("."):
		t = t.substr(0, t.length() - 1)
	return t


func _draw() -> void:
	# The pointer notch, centred on the top edge, pointing up to the opponent's plate.
	var c := Vector2(size.x - 44.0, 0.0)
	var pts := PackedVector2Array([c + Vector2(-NOTCH, 0.5), c + Vector2(0, -NOTCH), c + Vector2(NOTCH, 0.5)])
	draw_colored_polygon(pts, Color(BODY, 0.96))
	draw_polyline(pts, EDGE, 1.0, true)


## A small brass hourglass whose sand runs down and which turns over every PERIOD seconds (still under
## reduce motion).
class Hourglass extends Control:
	const PERIOD := 2.4
	const FLIP := 0.45

	func _init() -> void:
		custom_minimum_size = Vector2(20, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
			set_process(is_visible_in_tree() and not UIStyle.reduce_motion)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := 0.0 if UIStyle.reduce_motion else fmod(float(Time.get_ticks_msec()) / 1000.0, PERIOD)
		var run := clampf(t / (PERIOD - FLIP), 0.0, 1.0)
		var turn := 0.0
		if t > PERIOD - FLIP:
			var k := (t - (PERIOD - FLIP)) / FLIP
			turn = PI * (k * k * (3.0 - 2.0 * k))
			run = 1.0
		var c := size / 2.0
		draw_set_transform(c, turn, Vector2.ONE)
		var w := 6.5
		var h := 9.0
		var glass := Color(1, 0.95, 0.85, 0.16)
		var sand := Color(UIStyle.GOLD_HI, 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(1.2, 0), Vector2(-1.2, 0)]), glass)
		draw_colored_polygon(PackedVector2Array([Vector2(-1.2, 0), Vector2(1.2, 0), Vector2(w, h), Vector2(-w, h)]), glass)
		# Sand: the top cone shrinks while the bottom heap grows.
		var top_k := 1.0 - run
		if top_k > 0.02:
			var ty := -h * top_k
			var tw := lerpf(1.2, w, top_k)
			draw_colored_polygon(PackedVector2Array([Vector2(-tw, ty), Vector2(tw, ty), Vector2(1.0, -0.5), Vector2(-1.0, -0.5)]), sand)
			draw_line(Vector2(0, 0), Vector2(0, h - 1.0), Color(sand, 0.7), 1.0)
		if run > 0.02:
			var by := h - h * 0.8 * run
			draw_colored_polygon(PackedVector2Array([Vector2(-w + 0.6, h), Vector2(w - 0.6, h), Vector2(0, by)]), sand)
		var brass := UIStyle.GOLD
		draw_line(Vector2(-w - 2.0, -h - 1.0), Vector2(w + 2.0, -h - 1.0), brass, 2.0, true)
		draw_line(Vector2(-w - 2.0, h + 1.0), Vector2(w + 2.0, h + 1.0), brass, 2.0, true)
		draw_polyline(PackedVector2Array([Vector2(-w, -h), Vector2(-1.2, 0), Vector2(-w, h)]), Color(brass, 0.8), 1.0, true)
		draw_polyline(PackedVector2Array([Vector2(w, -h), Vector2(1.2, 0), Vector2(w, h)]), Color(brass, 0.8), 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
