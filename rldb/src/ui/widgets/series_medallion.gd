class_name SeriesMedallion
extends Control
## The series medallion of the sidebar between games (design review #49): a gilded bronze coin
## engraved "BEST OF n", and under it one hex socket per game: a gold gem for a game I won, an
## ember gem for a game my opponent won, an empty socket for a game still to play. The socket of
## the game about to be played breathes on the 2.4 s loop (one static bright rim under reduce
## motion). Display only: it reads what the series view already shows.
##
##     var med := SeriesMedallion.new()
##     med.setup(3, [0, 1], 2)    # best of 3; I won game 1, they won game 2; game 3 is next

## Coin radius, the socket radius and the distance between socket centres (px).
const COIN_R := 62.0
const SOCKET_R := 13.0
const SOCKET_STEP := 40.0
## Space between the coin and the sockets row, and the row's height.
const ROW_GAP := 22.0
const ROW_H := 30.0
const EMBER := Color("e8605a")

## Games in the series.
var best_of: int = 3
## Winner of each finished game from my side: 0 = I won, 1 = my opponent won.
var results: Array = []
## Index of the next game (its socket breathes); -1 for none (the series is over).
var current: int = -1
## Seconds clock (tests and frozen shots inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, COIN_R * 2.0 + 16.0 + ROW_GAP + ROW_H)


## Sets the series shown: `n` games, the finished `res` (0 mine, 1 theirs) and the next game `cur`.
func setup(n: int, res: Array, cur: int) -> SeriesMedallion:
	best_of = maxi(1, n)
	results = res.duplicate()
	current = cur
	tooltip_text = "Best of %d: first to %d wins the series" % [best_of, best_of / 2 + 1]
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()
	return self


## The state of socket `i`: "won", "lost", "next" or "empty".
func socket_state(i: int) -> String:
	if i < results.size():
		return "won" if int(results[i]) == 0 else "lost"
	return "next" if i == current else "empty"


func _process(_d: float) -> void:
	if current >= 0 and is_visible_in_tree() and not UIStyle.reduce_motion:
		queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, COIN_R + 8.0)
	_draw_coin(c)
	var y := c.y + COIN_R + ROW_GAP + ROW_H / 2.0 - 6.0
	var x0 := size.x / 2.0 - SOCKET_STEP * float(best_of - 1) / 2.0
	var amber: Color = UIStyle.GOLD
	var t := float(clock.call())
	for i in best_of:
		var p := Vector2(x0 + SOCKET_STEP * i, y)
		match socket_state(i):
			"won":
				PickPips.draw_gem(self, p, SOCKET_R, amber)
			"lost":
				PickPips.draw_gem(self, p, SOCKET_R, EMBER)
			"next":
				PickPips.draw_socket(self, p, SOCKET_R)
				var k := 0.75 if UIStyle.reduce_motion else 0.55 + 0.35 * (0.5 + 0.5 * sin(t / 2.4 * TAU))
				draw_arc(p, SOCKET_R + 4.0, 0.0, TAU, 32, Color(UIStyle.GOLD_HI, 0.55 * k), 2.0, true)
				draw_arc(p, SOCKET_R + 7.0, 0.0, TAU, 32, Color(UIStyle.GOLD, 0.18 * k), 3.0, true)
			_:
				PickPips.draw_socket(self, p, SOCKET_R)


## The coin: a soft gold halo, a gilded rim (light top, dark foot), a dark tooled field with an
## engraved inner ring and eight studs, and "BEST OF" over the number in Cinzel with a hard shadow.
func _draw_coin(c: Vector2) -> void:
	var r := COIN_R
	draw_circle(c, r + 9.0, Color(UIStyle.GOLD, 0.06), true, -1.0, true)
	draw_circle(c, r + 4.0, Color(UIStyle.GOLD, 0.08), true, -1.0, true)
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.55), true, -1.0, true)   # depth-1 drop
	draw_circle(c, r, UIStyle.BRONZE, true, -1.0, true)
	# Gilded rim: brighter towards the top-left light.
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		var lit := 0.5 + 0.5 * cos(a0 + PI * 0.75)
		draw_arc(c, r - 2.5, a0, a0 + TAU / 24.0 + 0.02, 4, UIStyle.BRONZE.lerp(UIStyle.GOLD_HI, lit), 5.0, true)
	draw_arc(c, r, 0.0, TAU, 64, Color("1a1006"), 1.0, true)
	var field := r - 6.0
	draw_circle(c, field, Color("1d1712"), true, -1.0, true)
	draw_circle(c + Vector2(0, -field * 0.35), field * 0.6, Color(1, 0.9, 0.6, 0.035), true, -1.0, true)
	# Engraved inner ring: a dark line with a faint lit line under it.
	draw_arc(c, field - 8.0, 0.0, TAU, 64, Color(0, 0, 0, 0.6), 1.5, true)
	draw_arc(c + Vector2(0, 1), field - 8.0, 0.0, TAU, 64, Color(UIStyle.GOLD, 0.3), 1.0, true)
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		var p := c + Vector2(cos(a), sin(a)) * (field - 3.5)
		draw_circle(p, 1.6, Color(UIStyle.GOLD_HI, 0.7), true, -1.0, true)
	var small := UIStyle.font_display(600)
	var big := UIStyle.font_display(700)
	_shadowed(small, "BEST OF", c + Vector2(0, -16), 12, Color(UIStyle.GOLD, 0.9))
	_shadowed(big, str(best_of), c + Vector2(0, 26), 44, UIStyle.GOLD_HI)


## `text` centred on x = `at.x` with its baseline at `at.y`, over a hard 2 px dark shadow.
func _shadowed(f: Font, text: String, at: Vector2, px: int, col: Color) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := Vector2(at.x - w / 2.0, at.y)
	draw_string(f, p + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.85))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
