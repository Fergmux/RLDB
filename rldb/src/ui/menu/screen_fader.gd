class_name ScreenFader
extends RefCounted
## Screen transition: fades a full-screen black rect in, swaps the screen while it is black and
## fades back out (menu -> game, game -> menu and the collection screens). Input is blocked while
## the black rect is up. One transition at a time.

const Z_INDEX := 300
const OUT_TIME := 0.35
const IN_TIME := 0.55
const OUT_TIME_REDUCED := 0.2
const IN_TIME_REDUCED := 0.25
## Time spent fully black after the swap, so the new screen can lay itself out.
const HOLD_TIME := 0.12

var busy: bool = false


## Fades `host` to black, calls `swap` (which builds the next screen under `host`), keeps the
## black rect on top and fades back in. Ignored while a transition is already running.
func fade(host: Control, swap: Callable) -> void:
	if busy:
		return
	busy = true
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.z_index = Z_INDEX
	host.add_child(black)
	var out_s := OUT_TIME_REDUCED if UIStyle.reduce_motion else OUT_TIME
	var in_s := IN_TIME_REDUCED if UIStyle.reduce_motion else IN_TIME
	var tw := host.create_tween()
	tw.tween_property(black, "color:a", 1.0, out_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		swap.call()
		host.move_child(black, -1))
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(black, "color:a", 0.0, in_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		black.queue_free()
		busy = false)
