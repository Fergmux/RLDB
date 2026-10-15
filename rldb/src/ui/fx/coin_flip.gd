class_name CoinFlip
extends Control
## Game-start coin flip (user feedback 2026-10-16): a coin spins in the middle of the board and
## lands on the face of the player who goes first, then names them. Presentation only and
## click-through; it frees itself when done. Reduced motion shows the result without spinning.

const R := 64.0
const SPIN_TIME := 1.7
const HOLD_TIME := 1.3
const HALF_TURNS := 9          # half turns of spin; the coin lands on the winner's face (see _face)

var names: Array = ["", ""]    # [winner, other]
var winner_is_me: bool = false
var phase: float = 0.0: set = _set_phase   # 0 .. HALF_TURNS * PI
var lift: float = 0.0: set = _set_lift
var result_a: float = 0.0: set = _set_result


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85


func _set_phase(v: float) -> void:
	phase = v
	queue_redraw()


func _set_lift(v: float) -> void:
	lift = v
	queue_redraw()


func _set_result(v: float) -> void:
	result_a = v
	queue_redraw()


## Starts the flip centred in this control's rect.
func play(winner_name: String, other_name: String, me_first: bool) -> void:
	names = [winner_name, other_name]
	winner_is_me = me_first
	var tw := create_tween()
	if UIStyle.reduce_motion:
		phase = float(HALF_TURNS) * PI
		result_a = 1.0
		tw.tween_interval(HOLD_TIME + 0.6)
	else:
		modulate.a = 0.0
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.parallel().tween_property(self, "phase", float(HALF_TURNS) * PI, SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(t: float): lift = sin(t * PI) * 70.0, 0.0, 1.0, SPIN_TIME * 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): Sfx.play("notice"))
		tw.tween_property(self, "result_a", 1.0, 0.2)
		tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


## Which face is up: the coin shows the winner's face when `phase` is a multiple of 2*PI from the
## landing angle. With an odd number of half turns the start face is the other player's.
func _face() -> int:
	var k := int(floor((float(HALF_TURNS) * PI - phase) / PI + 0.5))
	return k % 2   # 0 = winner


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, -lift)
	# Shadow on the table.
	var shrink := 1.0 - lift / 200.0
	draw_set_transform(size / 2.0 + Vector2(0, R + 18.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, R * shrink, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sx := absf(cos(phase))
	var face := _face()
	var mine_face: bool = (face == 0) == winner_is_me
	var metal := Color("e2b54a") if mine_face else Color("c9ccd4")
	var dark := metal.darkened(0.45)
	draw_set_transform(c, 0.0, Vector2(maxf(sx, 0.04), 1.0))
	draw_circle(Vector2.ZERO, R + 4.0, dark.darkened(0.4))
	draw_circle(Vector2.ZERO, R, dark)
	draw_circle(Vector2.ZERO, R - 6.0, metal)
	draw_arc(Vector2.ZERO, R - 12.0, 0.0, TAU, 48, Color(dark, 0.8), 2.0, true)
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
	# Result line under the coin.
	if result_a > 0.001:
		var txt := "You go first" if winner_is_me else "%s goes first" % String(names[0])
		var rf := UIStyle.font_display(700)
		var rfs := 34
		var rs := rf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs)
		var rp := Vector2(size.x / 2.0 - rs.x / 2.0, size.y / 2.0 + R + 64.0)
		var col := Color(UIStyle.GOLD_HI, result_a) if winner_is_me else Color(Color("e8dcc0"), result_a)
		draw_string_outline(rf, rp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, 6, Color(0, 0, 0, 0.8 * result_a))
		draw_string(rf, rp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, col)
		var sub := "Coin flip"
		var sf := UIStyle.font_bold()
		var ss := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string_outline(sf, Vector2(size.x / 2.0 - ss.x / 2.0, rp.y + 26.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.7 * result_a))
		draw_string(sf, Vector2(size.x / 2.0 - ss.x / 2.0, rp.y + 26.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIStyle.MUTED, result_a))
