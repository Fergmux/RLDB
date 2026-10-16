class_name SmoothScroll
extends ScrollContainer
## Vertical scroll container with eased mouse-wheel scrolling and the themed gold scroll bar.
## The wheel moves a target position and the view glides to it; dragging the bar or any other
## programmatic scroll takes over immediately. Reduced motion jumps straight to the target.

## Pixels one wheel notch moves.
const WHEEL_STEP := 96.0
## Ease speed (higher = snappier).
const EASE_K := 16.0

var _target: float = 0.0
var _last: int = 0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	theme = Ornate.scroll_theme()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var bar := get_v_scroll_bar()
		if bar.max_value - bar.page <= 0.0:
			return
		_sync()
		var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		_target = clampf(_target + dir * WHEEL_STEP * maxf(event.factor, 1.0), 0.0, maxf(0.0, bar.max_value - bar.page))
		accept_event()   # the built-in instant jump must not also run


## Re-reads the position when something else moved the view (scroll bar drag, focus, code).
func _sync() -> void:
	if scroll_vertical != _last:
		_target = float(scroll_vertical)
		_last = scroll_vertical


func _process(delta: float) -> void:
	_sync()
	var cur := float(scroll_vertical)
	if absf(_target - cur) < 0.6:
		return
	var nxt := _target if UIStyle.reduce_motion else lerpf(cur, _target, 1.0 - exp(-EASE_K * delta))
	scroll_vertical = int(round(nxt))
	_last = scroll_vertical


## Eases so that `y` becomes the top of the view.
func scroll_to(y: float) -> void:
	_sync()
	_target = clampf(y, 0.0, maxf(0.0, get_v_scroll_bar().max_value - get_v_scroll_bar().page))
