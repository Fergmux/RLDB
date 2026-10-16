class_name FxBanner
extends FxPart
## Turn / phase banners and the game-over strip: short, click-through pills in the top strip above
## the board. Banners run one at a time from a small queue; the game-over strip is final.

## Phase banner titles by phase id.
const PHASE_NAMES := {"main1": "SETUP PHASE", "battle": "BATTLE PHASE", "main2": "RECOVERY PHASE", "end": "END PHASE"}
## Banners waiting behind the one on screen; the oldest is dropped beyond this.
const MAX_QUEUED := 3
## Seconds a turn / phase banner holds before sliding away.
const HOLD := 0.55
## Seconds the game-over strip holds.
const GAME_OVER_HOLD := 1.2
## How far above its resting place the pill waits (and returns to) outside the screen.
const OFFSCREEN_RISE := 70.0

var _queue: Array = []
var _active: bool = false


## True while a banner is on screen (or queued).
func is_active() -> bool:
	return _active


## Drops the queue and forgets the running banner (its node and tween are freed by FxPlayer).
func reset() -> void:
	_queue.clear()
	_active = false


## Queues a banner (`flare` adds a spark burst) and starts it at once when none is running.
func enqueue(text: String, sub: String, col: Color, flare: bool) -> void:
	if _queue.size() >= MAX_QUEUED:
		_queue.pop_front()
	_queue.append({"text": text, "sub": sub, "col": col, "flare": flare})
	if not _active:
		_next()


## Shows the final VICTORY / DEFEAT strip for `winner`; nothing follows it.
func show_game_over(winner: int) -> void:
	var won: bool = winner == _fx.screen.me()
	_active = true
	_show_strip("VICTORY" if won else "DEFEAT", "", UIStyle.GOLD_HI if won else Color("e8605a"), won, GAME_OVER_HOLD, true)


func _next() -> void:
	if _queue.is_empty():
		_active = false
		return
	_active = true
	var e: Dictionary = _queue.pop_front()
	_show_strip(String(e["text"]), String(e["sub"]), e["col"], e["flare"], HOLD)


## Short, click-through pill in the top strip (above the board) so it can never cover a zone the
## player has to pick. Slides down, holds, slides back.
func _show_strip(text: String, sub: String, col: Color, flare: bool, hold: float, final: bool = false) -> void:
	var area: Rect2 = _fx.screen.board_global_rect()
	var layer: Control = _fx.screen.banner_layer
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _pill_style(0.92, UIStyle.GOLD, 22, 26, 2))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	pill.add_child(row)
	row.add_child(_title_label(text, 26, col, 4))
	if sub != "":
		var sl := UIStyle.label(sub, 17, UIStyle.MUTED)
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sl)
	pill.reset_size()
	var lp := layer.get_global_transform().affine_inverse() * Vector2(area.get_center().x, 4.0)
	pill.position = Vector2(lp.x - pill.size.x / 2.0, lp.y)
	_fx.add_node(pill, layer)
	pill.size = pill.get_combined_minimum_size()
	pill.position.x = lp.x - pill.size.x / 2.0
	var home := pill.position
	var tw := _fx.new_tween()
	if UIStyle.reduce_motion:
		pill.modulate.a = 0.0
		tw.tween_property(pill, "modulate:a", 1.0, 0.12)
		tw.tween_interval(hold)
		tw.tween_property(pill, "modulate:a", 0.0, 0.12)
	else:
		pill.position.y = home.y - OFFSCREEN_RISE
		tw.tween_property(pill, "position:y", home.y, UIStyle.dur(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if flare:
			tw.tween_callback(func(): _fx.burst(FxBurst.Kind.SPARK, Rect2(pill.global_position, pill.size).get_center(), UIStyle.GOLD_HI, 10, 70.0, 0.4))
		tw.tween_interval(UIStyle.dur(hold))
		tw.tween_property(pill, "position:y", home.y - OFFSCREEN_RISE, UIStyle.dur(0.14)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_fx.free_node(pill)
		if final:
			_active = false
		else:
			_next())
