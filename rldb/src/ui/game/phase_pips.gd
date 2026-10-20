class_name PhasePips
extends Control
## The turn bar's phase track (design review #39): three gem capsules joined by an engraved line.
## Phases already played this turn are dimmed to DONE_A with a small tick, the current one is a gold
## capsule whose glow breathes, the next ones are bronze outlines. When the phase moves on, a light
## travels along the line from the old capsule to the new one (`slide`, 320 ms). The phase change's
## sound is the phase banner's ("phase", FxPlayer), so the track stays silent. Static under reduce
## motion (no breathing, no travelling light).

## Turn phases in order: [phase id, label].
const PHASES := [["main1", "Setup"], ["battle", "Battle"], ["main2", "Recovery"]]
## Gap between capsules (px), the done phases' opacity, the travelling light's length (share of a gap).
const GAP := 14.0
const DONE_A := 0.6
const GLOW_PX := 7
const TRAVEL_S := 0.32

## Current phase id (one of PHASES). Setting a later phase of the same turn starts the travelling light.
var phase: String = "":
	set(v):
		if v == phase:
			return
		var a := index_of(phase)
		var b := index_of(v)
		phase = v
		if a >= 0 and b > a and is_inside_tree() and not UIStyle.reduce_motion:
			_from = a
			_travel = 0.0
			if _tw != null and _tw.is_valid():
				_tw.kill()
			_tw = create_tween()
			_tw.tween_property(self, "_travel", 1.0, UIStyle.dur(TRAVEL_S)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			_travel = -1.0
		queue_redraw()
## Travelling light: 0..1 along the line from capsule `_from` to the current one (< 0: none).
var _travel: float = -1.0:
	set(v):
		_travel = v
		queue_redraw()
var _from: int = -1
var _tw: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
		set_process(is_visible_in_tree() and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


## Index of phase id `id` in PHASES (-1 when unknown).
static func index_of(id: String) -> int:
	for i in PHASES.size():
		if PHASES[i][0] == id:
			return i
	return -1


## State of capsule `i` while the current phase is `cur`: "done", "current" or "next".
static func state_of(i: int, cur: String) -> String:
	var c := index_of(cur)
	if c < 0:
		return "next"
	return "done" if i < c else ("current" if i == c else "next")


func _rect(i: int) -> Rect2:
	var n := PHASES.size()
	var h := size.y - 6.0
	var w := (size.x - GAP * (n - 1)) / n
	return Rect2(i * (w + GAP), 3.0, w, h)


func _draw() -> void:
	var n := PHASES.size()
	var font := UIStyle.font_bold()
	var mid := _rect(0).get_center().y
	# The engraved line joining the capsules: a dark cut with a faint lit edge under it.
	for i in n - 1:
		var a := Vector2(_rect(i).end.x - 2.0, mid)
		var b := Vector2(_rect(i + 1).position.x + 2.0, mid)
		draw_line(a, b, Color(0, 0, 0, 0.6), 2.0, true)
		draw_line(a + Vector2(0, 1.5), b + Vector2(0, 1.5), Color(UIStyle.GOLD, 0.16), 1.0, true)
		if state_of(i + 1, phase) != "next":
			draw_line(a, b, Color(UIStyle.GOLD, 0.45), 1.0, true)
	var cur := index_of(phase)
	var k := UIStyle.breathe(float(Time.get_ticks_msec()) / 1000.0, 0.3)
	for i in n:
		var r := _rect(i)
		var st := state_of(i, phase)
		var rad := int(r.size.y / 2.0)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(rad)
		sb.anti_aliasing = true
		sb.set_border_width_all(1)
		match st:
			"current":
				sb.bg_color = UIStyle.GOLD
				sb.border_color = UIStyle.GOLD_HI
				sb.shadow_color = Color(UIStyle.GOLD_HI, clampf(0.42 * k, 0.0, 1.0))
				sb.shadow_size = GLOW_PX
			"done":
				sb.bg_color = Color(0.16, 0.12, 0.07, DONE_A)
				sb.border_color = Color(UIStyle.GOLD, 0.45 * DONE_A)
			_:
				sb.bg_color = Color(0.07, 0.06, 0.05, 0.96)
				sb.border_color = Color(UIStyle.BRONZE, 0.85)
				sb.shadow_color = Color(0, 0, 0, 0.5)
				sb.shadow_size = 3
				sb.shadow_offset = Vector2(0, 1)
		draw_style_box(sb, r)
		# The gem's gloss: a light band over the top half.
		var gl := StyleBoxFlat.new()
		gl.bg_color = Color(1, 1, 1, 0.24 if st == "current" else 0.05)
		gl.corner_radius_top_left = rad - 1
		gl.corner_radius_top_right = rad - 1
		gl.corner_radius_bottom_left = 2
		gl.corner_radius_bottom_right = 2
		draw_style_box(gl, Rect2(r.position + Vector2(rad * 0.5, 1.5), Vector2(r.size.x - rad, r.size.y * 0.42)))
		var txt: String = PHASES[i][1]
		var fs := 13
		var tick := st == "done"
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tw := sz.x + (13.0 if tick else 0.0)
		var x := r.position.x + (r.size.x - tw) / 2.0
		var base := r.position.y + r.size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		if tick:
			var tc := Vector2(x + 4.0, r.get_center().y)
			draw_polyline(PackedVector2Array([tc + Vector2(-3.5, 0), tc + Vector2(-1, 2.6), tc + Vector2(4, -3)]), Color(UIStyle.GOOD, 0.9 * DONE_A + 0.2), 1.8, true)
			x += 13.0
		var col: Color = UIStyle.ON_GOLD if st == "current" else (Color(UIStyle.MUTED, DONE_A) if tick else UIStyle.MUTED)
		if st == "current":
			draw_string(font, Vector2(x, base + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.35))
		draw_string(font, Vector2(x, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# The light travelling along the line to the new phase.
	if _travel >= 0.0 and _travel < 1.0 and _from >= 0 and cur > _from:
		var x0 := _rect(_from).get_center().x
		var x1 := _rect(cur).get_center().x
		var p := Vector2(lerpf(x0, x1, _travel), mid)
		var fade := sin(_travel * PI)
		draw_circle(p, 9.0, Color(UIStyle.GOLD_HI, 0.18 * fade), true, -1.0, true)
		draw_circle(p, 4.0, Color(UIStyle.GOLD_HI, 0.55 * fade), true, -1.0, true)
		draw_circle(p, 1.8, Color(1, 1, 0.95, 0.95 * fade), true, -1.0, true)
