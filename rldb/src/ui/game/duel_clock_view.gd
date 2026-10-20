class_name DuelClockView
extends Control
## The duel clock in the turn panel (C2): a small inset bronze plaque with a gold hourglass, the
## game time in the display face and the current turn's time beneath it. The hourglass sand runs
## down over each minute of the turn and the glass turns over at the minute (a still glass under
## reduce motion). It stops (dims) while the duel is paused and settles on the final time when
## the game is won. Reads a DuelClock; never sends anything.

const W := 128.0
const H := 46.0
## The turn time warms from muted to amber after this long (a gentle nudge, not a timer limit).
const LONG_TURN_MS := 120000

## The clock shown (null hides the plaque).
var clock: DuelClock = null
var _shown := ""
var _flip_t := 0.0
var _last_min := -1


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Game time, and the time of the current turn"


## Shows `c` (null hides the plaque).
func set_clock(c: DuelClock) -> void:
	clock = c
	visible = c != null
	_shown = ""
	queue_redraw()


## The two texts drawn: [game "m:ss", turn "m:ss"] (tests read them).
func texts() -> Array:
	if clock == null:
		return ["", ""]
	return [PlayerStats.clock(clock.game_ms()), PlayerStats.clock(clock.turn_ms())]


func _process(delta: float) -> void:
	if clock == null or not is_visible_in_tree():
		return
	var t := texts()
	var sig := "%s|%s|%s" % [t[0], t[1], clock.stopped()]
	var minute := clock.turn_ms() / 60000
	if minute != _last_min:
		if _last_min != -1 and minute > _last_min and not UIStyle.reduce_motion:
			_flip_t = 0.45
		_last_min = minute
	if _flip_t > 0.0:
		_flip_t = maxf(0.0, _flip_t - delta)
		queue_redraw()
	elif sig != _shown or not UIStyle.reduce_motion:
		_shown = sig
		queue_redraw()


func _draw() -> void:
	if clock == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	# Inset plaque: dark well, bronze rim, a faint gold top light.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.045, 0.035, 0.96)
	sb.border_color = Color(UIStyle.BRONZE, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 1)
	draw_style_box(sb, r)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.border_color = Color(UIStyle.GOLD, 0.16)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(5)
	draw_style_box(inner, r.grow(-3))
	var gl := StyleBoxFlat.new()
	gl.bg_color = Color(UIStyle.GOLD_HI, 0.05)
	gl.corner_radius_top_left = 6
	gl.corner_radius_top_right = 6
	draw_style_box(gl, Rect2(Vector2(2, 2), Vector2(size.x - 4, size.y * 0.42)))
	var dim := 0.55 if clock.stopped() and clock.frozen_at == -1 else 1.0
	_draw_hourglass(Vector2(20, size.y / 2.0), dim)
	# Divider between glass and numbers.
	draw_line(Vector2(37, 9), Vector2(37, size.y - 9), Color(UIStyle.BRONZE, 0.55), 1.0)
	var t := texts()
	var big := UIStyle.font_display(700)
	var small := UIStyle.font_bold()
	var x := 45.0
	var right := size.x - 10.0
	var gw := big.get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var gpos := Vector2(right - gw, 23)
	draw_string(big, gpos + Vector2(0, 1.5), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0, 0, 0, 0.6))
	draw_string(big, gpos, t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(UIStyle.GOLD_HI, dim))
	var long_turn := clock.turn_ms() >= LONG_TURN_MS
	var tc := Color("e9a14a") if long_turn else UIStyle.TEXT_DIM
	var cap := "TURN"
	draw_string(small, Vector2(x, 38), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UIStyle.BRONZE.lightened(0.35), dim))
	var tw := small.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(small, Vector2(right - tw, 39), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tc, dim))


## A gold-framed hourglass whose sand drains over each minute of the turn.
func _draw_hourglass(c: Vector2, dim: float) -> void:
	var hw := 7.5
	var hh := 13.0
	var rot := 0.0
	if _flip_t > 0.0:
		rot = PI * (1.0 - _flip_t / 0.45)
	draw_set_transform(c, rot, Vector2.ONE)
	var gold := Color(UIStyle.GOLD, dim)
	var glass := Color(0.75, 0.82, 0.9, 0.12 * dim)
	var top := PackedVector2Array([Vector2(-hw, -hh + 2), Vector2(hw, -hh + 2), Vector2(1.2, -0.8), Vector2(-1.2, -0.8)])
	var bot := PackedVector2Array([Vector2(-1.2, 0.8), Vector2(1.2, 0.8), Vector2(hw, hh - 2), Vector2(-hw, hh - 2)])
	draw_colored_polygon(top, glass)
	draw_colored_polygon(bot, glass)
	# Sand: the top bulb empties and the bottom fills over the minute.
	var f := 0.0 if _flip_t > 0.0 else float(clock.turn_ms() % 60000) / 60000.0
	if clock.frozen_at != -1:
		f = 1.0
	var sand := Color(UIStyle.GOLD_HI, 0.85 * dim)
	var ty := lerpf(-hh + 3.0, -1.5, f)
	var tx := lerpf(hw - 1.0, 1.0, f)
	if f < 0.98:
		draw_colored_polygon(PackedVector2Array([Vector2(-tx, ty), Vector2(tx, ty), Vector2(1.0, -1.2), Vector2(-1.0, -1.2)]), sand)
		if not clock.stopped():
			draw_line(Vector2(0, -0.8), Vector2(0, hh - 3.0), Color(sand, 0.7 * dim), 1.0)
	var by := lerpf(hh - 3.0, 2.5, f)
	var bx := lerpf(hw - 1.5, 2.0, f)
	if f > 0.02:
		draw_colored_polygon(PackedVector2Array([Vector2(-hw + 1.0, hh - 3.0), Vector2(hw - 1.0, hh - 3.0), Vector2(bx, by), Vector2(-bx, by)]), sand)
	# Glass outline and the gold end caps with their posts.
	draw_polyline(PackedVector2Array([Vector2(-hw, -hh + 2), Vector2(-1.2, -0.8), Vector2(-1.2, 0.8), Vector2(-hw, hh - 2)]), Color(gold, 0.8), 1.2, true)
	draw_polyline(PackedVector2Array([Vector2(hw, -hh + 2), Vector2(1.2, -0.8), Vector2(1.2, 0.8), Vector2(hw, hh - 2)]), Color(gold, 0.8), 1.2, true)
	for s in [-1.0, 1.0]:
		draw_rect(Rect2(Vector2(-hw - 2.5, s * hh - 1.5), Vector2(hw * 2 + 5, 3)), gold)
		draw_line(Vector2(-hw - 1.5, s * hh), Vector2(-hw - 1.5, 0), Color(gold, 0.65), 1.2)
		draw_line(Vector2(hw + 1.5, s * hh), Vector2(hw + 1.5, 0), Color(gold, 0.65), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
