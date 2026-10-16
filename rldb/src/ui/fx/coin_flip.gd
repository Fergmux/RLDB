class_name CoinFlip
extends Control
## Game-start coin flip (user feedback 2026-10-16, F04-01): a coin spins in the middle of the board and
## lands on the face of the player who goes first, then names them. It reads over any board: a soft
## pool of darkness (radial vignette, no hard edges) and a warm glow sit behind the coin, and the result
## sits on a dark plate with a gold border, shadow and outlined text. Presentation only and
## click-through; it frees itself when done. Reduced motion shows the result without spinning.

## Coin radius in pixels.
const R := 64.0
## Seconds of spin.
const SPIN_TIME := 1.7
## Seconds the result stays after landing.
const HOLD_TIME := 1.5
## Half turns of spin; the coin lands on the winner's face (see _face).
const HALF_TURNS := 9
## Peak opacity of the dark pool behind the coin and of its gold glow.
const POOL_ALPHA := 0.75
const GLOW_ALPHA := 0.95
## Uniform darkening of the whole play area (the vignette floor, so the field never competes with the coin).
const DIM_ALPHA := 0.5

static var _pool_tex: GradientTexture2D
static var _glow_tex: GradientTexture2D

## Player names [winner, other].
var names: Array = ["", ""]
## True when the local player goes first (gold face, "You go first").
var winner_is_me: bool = false
## Spin angle, 0 .. HALF_TURNS * PI.
var phase: float = 0.0: set = _set_phase
## Height the coin is thrown above the table in pixels.
var lift: float = 0.0: set = _set_lift
## Opacity of the result line under the coin.
var result_a: float = 0.0: set = _set_result
## Opacity of the dark pool and glow behind the coin (rises before the spin, falls with the fade-out).
var backdrop_a: float = 0.0: set = _set_backdrop
## Landing shockwave progress 0 -> 1 (0 = not started).
var land_t: float = 0.0: set = _set_land


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = UiLayers.COIN_FLIP


func _set_phase(v: float) -> void:
	phase = v
	queue_redraw()


func _set_lift(v: float) -> void:
	lift = v
	queue_redraw()


func _set_result(v: float) -> void:
	result_a = v
	queue_redraw()


func _set_backdrop(v: float) -> void:
	backdrop_a = v
	queue_redraw()


func _set_land(v: float) -> void:
	land_t = v
	queue_redraw()


## Starts the flip centred in this control's rect.
func play(winner_name: String, other_name: String, me_first: bool) -> void:
	names = [winner_name, other_name]
	winner_is_me = me_first
	var tw := create_tween()
	if UIStyle.reduce_motion:
		phase = float(HALF_TURNS) * PI
		result_a = 1.0
		backdrop_a = 1.0
		tw.tween_interval(HOLD_TIME + 0.6)
	else:
		modulate.a = 0.0
		backdrop_a = 0.0
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(self, "backdrop_a", 1.0, 0.35)
		tw.parallel().tween_property(self, "phase", float(HALF_TURNS) * PI, SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(t: float): lift = sin(t * PI) * 70.0, 0.0, 1.0, SPIN_TIME * 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			Sfx.play("notice")
			Sfx.play("impact", -8.0, 0.0))
		# Landing: a small bounce, a ring of light and the result plate.
		tw.tween_method(func(t: float): lift = sin(t * PI) * 12.0, 0.0, 1.0, 0.16)
		tw.parallel().tween_property(self, "land_t", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "result_a", 1.0, 0.25)
		tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


## Which face is up: the coin shows the winner's face when `phase` is a multiple of 2*PI from the
## landing angle. With an odd number of half turns the start face is the other player's.
func _face() -> int:
	var k := int(floor((float(HALF_TURNS) * PI - phase) / PI + 0.5))
	return k % 2   # 0 = winner


static func _radial(inner: Color, outer: Color, mid: float = -1.0, mid_col: Color = Color.TRANSPARENT) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	if mid > 0.0:
		g.add_point(mid, mid_col)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	return gt


func _draw() -> void:
	if _pool_tex == null:
		_pool_tex = _radial(Color(0.03, 0.015, 0.0, 1.0), Color(0.03, 0.015, 0.0, 0.0), 0.5, Color(0.03, 0.015, 0.0, 0.55))
		_glow_tex = _radial(Color(1.0, 0.78, 0.35, 1.0), Color(1.0, 0.7, 0.25, 0.0), 0.45, Color(1.0, 0.72, 0.28, 0.5))
	var mid := size / 2.0
	# Dark pool over the field (ellipse, fades to nothing at the edges) and the warm glow around the coin.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.014, 0.006, DIM_ALPHA * backdrop_a))
	draw_texture_rect(_pool_tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, POOL_ALPHA * backdrop_a))
	var gr := R * (3.9 + 0.4 * sin(Time.get_ticks_msec() * 0.004))
	var gc := mid + Vector2(0, -lift * 0.5)
	draw_texture_rect(_glow_tex, Rect2(gc - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1, 1, 1, GLOW_ALPHA * backdrop_a))
	# Shadow on the table.
	var c := mid + Vector2(0, -lift)
	var shrink := 1.0 - lift / 200.0
	draw_set_transform(mid + Vector2(0, R + 18.0), 0.0, Vector2(1.0, 0.28))
	for k in 5:
		draw_circle(Vector2.ZERO, R * shrink * (1.45 - 0.1 * float(k)), Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Landing shockwave ring and sparks.
	if land_t > 0.0 and land_t < 1.0:
		var lr := R * (1.0 + 2.6 * land_t)
		draw_arc(mid, lr, 0.0, TAU, 64, Color(UIStyle.GOLD_HI, 0.8 * (1.0 - land_t)), 2.0 + 8.0 * (1.0 - land_t), true)
		for i in 10:
			var a := float(i) * TAU / 10.0 + 0.3
			var d := Vector2(cos(a), sin(a))
			draw_line(mid + d * lr * 0.8, mid + d * lr * (0.8 + 0.28 * (1.0 - land_t)), Color(1, 0.93, 0.7, 1.0 - land_t), 2.5, true)
	var sx := absf(cos(phase))
	var face := _face()
	var mine_face: bool = (face == 0) == winner_is_me
	var metal := Color("e2b54a") if mine_face else Color("c9ccd4")
	var dark := metal.darkened(0.45)
	draw_set_transform(c, 0.0, Vector2(maxf(sx, 0.04), 1.0))
	draw_circle(Vector2.ZERO, R + 6.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, R + 4.0, dark.darkened(0.4))
	draw_circle(Vector2.ZERO, R, dark)
	draw_circle(Vector2.ZERO, R - 6.0, metal)
	draw_arc(Vector2.ZERO, R - 12.0, 0.0, TAU, 48, Color(dark, 0.8), 2.0, true)
	draw_arc(Vector2.ZERO, R - 3.0, PI * 1.1, PI * 1.8, 24, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(Vector2(-R * 0.3, -R * 0.35), R * 0.28, Color(1, 1, 1, 0.22))
	var nm: String = String(names[face])
	var letter := nm.substr(0, 1).to_upper() if nm != "" else "?"
	var font := UIStyle.font_display(700)
	var fs := 64
	var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(-ts.x / 2.0, (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	draw_string(font, pos + Vector2(2, 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dark.darkened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Result plate under the coin: dark fill, gold border, soft shadow; outlined text on top.
	if result_a > 0.001:
		var txt := "You go first" if winner_is_me else "%s goes first" % String(names[0])
		var rf := UIStyle.font_display(700)
		var rfs := 40
		var rs := rf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs)
		var sub := "COIN FLIP"
		var sf := UIStyle.font_bold()
		var ss := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var pw := maxf(rs.x, ss.x) + 72.0
		var ph := rs.y + 20.0 + 36.0
		var top := mid.y + R + 46.0
		var prect := Rect2(mid.x - pw / 2.0, top, pw, ph)
		var edge := UIStyle.GOLD_HI if winner_is_me else Color("b9ab8c")
		var sb := UIStyle.flat(Color(0.05, 0.035, 0.025, 0.9 * result_a), Color(edge, result_a), 2, 16)
		sb.shadow_color = Color(0, 0, 0, 0.6 * result_a)
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(0, 5)
		draw_style_box(sb, prect)
		draw_rect(Rect2(prect.position + Vector2(14, 5), Vector2(prect.size.x - 28, 1)), Color(edge, 0.35 * result_a))
		var col := Color(UIStyle.GOLD_HI, result_a) if winner_is_me else Color(Color("efe3c6"), result_a)
		var rp := Vector2(mid.x - rs.x / 2.0, top + 14.0 + rf.get_ascent(rfs))
		draw_string(rf, rp + Vector2(0, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(0, 0, 0, 0.6 * result_a))
		draw_string_outline(rf, rp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, 7, Color(0, 0, 0, 0.85 * result_a))
		draw_string(rf, rp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, col)
		var sp := Vector2(mid.x - ss.x / 2.0, rp.y + 26.0)
		draw_string(sf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIStyle.MUTED.lightened(0.15), result_a))
	if not UIStyle.reduce_motion:
		queue_redraw()   # the glow breathes while the coin is up
