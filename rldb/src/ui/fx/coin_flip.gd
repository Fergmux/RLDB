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
## The result title (design review #72): T1 hero text on its own child above the veil, landing with
## an impact punch, and its gap under the coin.
const RESULT_PX := 56
const RESULT_GAP := 40.0
const RESULT_PUNCH := 1.25
## House metals of the two faces: seat 1's sun face (gold) and seat 2's moon face (bronze).
const SUN_METAL := Color("e2b54a")
const MOON_METAL := Color("b9864a")

static var _pool_tex: GradientTexture2D
static var _glow_tex: GradientTexture2D

## Player names [winner, other].
## Emitted as the coin starts to fade out: the opening hands are dealt then (2026-10-18).
signal finished

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
## Seat (0 / 1) of the player who goes first: their face shows the sun crest, the other the moon.
var first_seat: int = 0
## The result title ("You go first" / "Ben goes first"): a TitleText child, so it draws above the
## veil this control paints (#72).
var result_title: TitleText


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
	if result_title != null:
		result_title.modulate.a = v
	queue_redraw()


func _set_backdrop(v: float) -> void:
	backdrop_a = v
	queue_redraw()


func _set_land(v: float) -> void:
	land_t = v
	queue_redraw()


## Starts the flip centred in this control's rect. `seat` is the first player's seat (its crest).
func play(winner_name: String, other_name: String, me_first: bool, seat: int = 0) -> void:
	names = [winner_name, other_name]
	winner_is_me = me_first
	first_seat = seat
	result_title = TitleText.make("You go first" if me_first else "%s goes first" % winner_name, TitleText.Tier.HERO, RESULT_PX)
	result_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.modulate.a = 0.0
	add_child(result_title)
	_place_result()
	resized.connect(_place_result)
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
			Sfx.play("impact", -8.0, 0.0)
			_land_title())
		# Landing: a small bounce, a ring of light and the result plate.
		tw.tween_method(func(t: float): lift = sin(t * PI) * 12.0, 0.0, 1.0, 0.16)
		tw.parallel().tween_property(self, "land_t", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "result_a", 1.0, 0.25)
		tw.tween_interval(HOLD_TIME)
	tw.tween_callback(func(): finished.emit())
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


## Centres the result title under the coin.
func _place_result() -> void:
	if result_title == null:
		return
	result_title.reset_size()
	var sz := result_title.get_combined_minimum_size()
	result_title.size = sz
	result_title.pivot_offset = sz / 2.0
	result_title.position = Vector2(size.x / 2.0 - sz.x / 2.0, size.y / 2.0 + R + RESULT_GAP)


## The title lands with the coin (motion token `impact`): it drops in from RESULT_PUNCH scale, holds a
## hit-stop beat and settles with an elastic shake. Reduce motion: it fades in (result_a).
func _land_title() -> void:
	if result_title == null:
		return
	result_title.scale = Vector2(RESULT_PUNCH, RESULT_PUNCH)
	var tt := create_tween()
	tt.tween_interval(UIStyle.motion("hit_stop"))
	UIStyle.tween_token(tt, result_title, "scale", Vector2.ONE, "impact")


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
	# The face's seat: face 0 is the first player's. Seat 1 wears the sun on gold, seat 2 the moon on bronze.
	var seat := first_seat if face == 0 else 1 - first_seat
	var metal := SUN_METAL if seat == 0 else MOON_METAL
	var dark := metal.darkened(0.45)
	draw_set_transform(c, 0.0, Vector2(maxf(sx, 0.04), 1.0))
	draw_circle(Vector2.ZERO, R + 6.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, R + 4.0, dark.darkened(0.4))
	draw_circle(Vector2.ZERO, R, dark)
	draw_circle(Vector2.ZERO, R - 6.0, metal)
	draw_arc(Vector2.ZERO, R - 12.0, 0.0, TAU, 48, Color(dark, 0.8), 2.0, true)
	draw_arc(Vector2.ZERO, R - 3.0, PI * 1.1, PI * 1.8, 24, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(Vector2(-R * 0.58, -R * 0.5), R * 0.1, Color(1, 1, 1, 0.3), true, -1.0, true)
	# Embossed crest (a sun or a crescent moon) with the player's initial small under it.
	_draw_crest(Vector2(0, -R * 0.1), R * 0.46, seat == 0, metal)
	var nm: String = String(names[face])
	var letter := nm.substr(0, 1).to_upper() if nm != "" else "?"
	var font := UIStyle.font_display(700)
	var fs := 20
	var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(-ts.x / 2.0, R * 0.56 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	draw_string(font, pos + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.3))
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dark.darkened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The "COIN FLIP" caption under the result title (the title itself is the TitleText child).
	if result_a > 0.001:
		var sf := UIStyle.font_display(600)
		var sub := "COIN FLIP"
		var ss := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var ty := result_title.position.y + result_title.size.y if result_title != null else mid.y + R + RESULT_GAP + 60.0
		var sp := Vector2(mid.x - ss.x / 2.0, ty + 14.0)
		draw_string_outline(sf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8 * result_a))
		draw_string(sf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIStyle.GOLD, 0.9 * result_a))
	if not UIStyle.reduce_motion:
		queue_redraw()   # the glow breathes while the coin is up


## A raised crest of radius `r` at `c` (in the coin's face space): a sun (a disc with twelve rays) or
## a crescent moon, embossed: a dark offset relief under a lighter face of the coin's `metal`.
func _draw_crest(c: Vector2, r: float, sun: bool, metal: Color) -> void:
	var lo := metal.darkened(0.55)
	var hi := metal.lightened(0.28)
	for layer in 2:
		var off := Vector2(1.5, 1.5) if layer == 0 else Vector2.ZERO
		var col := Color(lo, 0.9) if layer == 0 else hi
		if sun:
			for i in 12:
				var a := TAU * float(i) / 12.0
				var d := Vector2(cos(a), sin(a))
				var t := Vector2(-d.y, d.x)
				var long := 1.0 if i % 2 == 0 else 0.78
				draw_colored_polygon(PackedVector2Array([c + off + d * r * 0.62 + t * r * 0.13, c + off + d * r * long, c + off + d * r * 0.62 - t * r * 0.13]), col)
			draw_circle(c + off, r * 0.5, col, true, -1.0, true)
		else:
			# Crescent: the moon disc, then the coin's own metal cut out of it, offset to the right.
			draw_circle(c + off, r * 0.86, col, true, -1.0, true)
	if not sun:
		draw_circle(c + Vector2(r * 0.38, -r * 0.08), r * 0.7, metal, true, -1.0, true)
		draw_arc(c + Vector2(r * 0.38, -r * 0.08), r * 0.7, PI * 0.55, PI * 1.45, 24, Color(lo, 0.45), 1.2, true)
	if sun:
		draw_circle(c, r * 0.5, Color(lo, 0.35), false, 1.2, true)
		draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.14, Color(1, 1, 1, 0.35), true, -1.0, true)
