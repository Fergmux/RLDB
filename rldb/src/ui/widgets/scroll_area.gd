class_name ScrollArea
extends Control
## SmoothScroll with soft fade shadows over its top and bottom edges while more content lies
## beyond them. Add content with `set_content`; the content is stretched to the area's width.

var scroll: SmoothScroll
var _top: Fade
var _bot: Fade


## Edge shadow that is only visible while there is more to scroll in its direction.
class Fade extends Control:
	var up: bool = true
	## True while the shadow is meant to show (it fades in and out).
	var shown: bool = false
	var tint: Color = Color(0.05, 0.04, 0.03, 0.95)

	func _init(is_up: bool) -> void:
		up = is_up
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		modulate.a = 0.0

	## Fades the shadow in or out.
	func set_shown(on: bool) -> void:
		if on != shown:
			shown = on
			ScrollCue.fade(self, on)

	func _draw() -> void:
		var b := Color(tint, 0.0)
		Ornate.vgradient(self, Rect2(Vector2.ZERO, size), tint if up else b, b if up else tint)


func _init() -> void:
	scroll = SmoothScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	_top = Fade.new(true)
	_bot = Fade.new(false)
	add_child(_top)
	add_child(_bot)


## Puts `c` into the scroll view (expanding horizontally).
func set_content(c: Control) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(c)


func _process(_d: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	var max_y := bar.max_value - bar.page
	var fh := 26.0
	var bar_w := bar.size.x + 4.0 if bar.visible else 0.0
	_top.position = Vector2.ZERO
	_top.size = Vector2(maxf(0.0, size.x - bar_w), fh)
	_bot.position = Vector2(0, size.y - fh)
	_bot.size = Vector2(maxf(0.0, size.x - bar_w), fh)
	var t := max_y > 1.0 and scroll.scroll_vertical > 2
	var b := max_y > 1.0 and scroll.scroll_vertical < max_y - 2.0
	_top.set_shown(t)
	_bot.set_shown(b)
