class_name SeriesScoreboard
extends Control
## L26 (owner, 5 Nov): the series at a glance, always visible during a series game, in the middle
## of the top strip above the board: a dark leather plaque with each player's name and their wins as
## faceted gems in their seat colour (empty sockets for the wins still needed), my side on the left,
## and in the middle a raised cartouche with "BEST OF n" over one dot per game (the winner's colour;
## the game in play breathing). The leader's gems sit in a small gold laurel; the series winner's
## shine. When a game is won its gem pops into its socket with a burst and the series_point cue.
## Hovering shows the full SeriesResults card. Hidden in a single game (best of 1) and tutorials.
##
##     var sb := SeriesScoreboard.new()
##     sb.show_model(SeriesResults.model(view, me))       # no animation
##     sb.pop_point(0)                                    # seat 0's newest point pops in

## Plaque height, the name room per side, the gem size and step, the cartouche (px).
## Final review #11: the plaque is 40 px (2 px clear of the 44 px top strip on each side) and the
## cartouche sizes itself to its caption and dots (CART_MIN_W at least, CART_PAD each side), so
## "BEST OF n" and the game dots no longer crowd each other or its rim.
const H := 40.0
const NAME_MAX := 132.0
const NAME_PX := 14
const GEM_R := 8.5
const GEM_STEP := 21.0
const CART_MIN_W := 112.0
const CART_PAD := 15.0
const DOT_R := 3.8
const DOT_STEP := 12.0
## The cartouche's top inset in the plaque, its caption size and baseline, the dots' centre line, and
## the gap from a dot to the ring that breathes round the game in play.
const CART_TOP := 2.0
const CAPTION_PX := 12
const CAPTION_BASE := 16.0
const DOT_Y := 27.0
const RING_GAP := 2.2
## Extra space between the caption's letters (px): Cinzel's capitals read apart at this size.
const CAPTION_TRACKING := 1
## Ink height of Cinzel's capitals as a share of the font size (the caption is all capitals;
## measured on a 4K capture).
const CAP_K := 0.8
const PAD := 12.0
## Room between the outermost gem (and its laurel) and the name.
const NAME_GAP := 14.0
## Room between the cartouche and the innermost gem.
const CART_GAP := 10.0
## The point pop: seconds, and how far it overshoots.
const POP_TIME := 0.55
const POP_OVERSHOOT := 1.45

## The series shown (SeriesResults.model).
var m: Dictionary = {}
## Seconds clock (tests and frozen shots inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0
## The point being popped: its seat (-1: none) and progress 0..1 (tweened).
var pop_seat: int = -1
var pop_k: float = 1.0:
	set(v):
		pop_k = v
		queue_redraw()
## Points shown per seat (a point counted in `m` but not yet popped in is drawn as a socket).
var shown: Array = [0, 0]
## Identity of the series shown (a different series never animates).
var series_key: String = ""
## True while the plaque has stepped aside for a mode banner in the same place (yield_to).
var yielded: bool = false
var _breath: Control
var _pop_tw: Tween
var _yield_tw: Tween
var _name_w: Array = [0.0, 0.0]
## The cartouche's width for the series shown (see CART_MIN_W).
var cart_w: float = CART_MIN_W
static var _caption_font: FontVariation


func _init() -> void:
	name = "SeriesScoreboard"
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_HELP
	visible = false
	custom_minimum_size = Vector2(320, H)
	size = custom_minimum_size
	_breath = Control.new()
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_breath.draw.connect(_draw_breath)
	add_child(_breath, false, Node.INTERNAL_MODE_FRONT)


## Shows series `md` at once (no animation); `key` identifies the series.
func show_model(md: Dictionary, key: String = "") -> void:
	_kill_pop()
	m = md
	series_key = key
	shown = (md["scores"] as Array).duplicate()
	_relayout()


## Shows series `md` (same series as shown) holding back `seat`'s newest point, which pop_point
## then fills in.
func hold_point(md: Dictionary, seat: int) -> void:
	m = md
	shown = (md["scores"] as Array).duplicate()
	shown[seat] = maxi(0, int(shown[seat]) - 1)
	_relayout()


## Pops `seat`'s newest point into its socket (with the series_point cue): it swells past its size
## with a ring of light in the seat's colour and settles. Under reduce motion it simply appears.
func pop_point(seat: int) -> void:
	if m.is_empty():
		return
	_kill_pop()
	var full := (m["scores"] as Array).duplicate()
	Sfx.play("series_point")
	if UIStyle.reduce_motion or not is_inside_tree():
		shown = full
		queue_redraw()
		return
	# The popping gem is drawn in the socket after the points already shown.
	shown = full.duplicate()
	shown[seat] = maxi(0, int(full[seat]) - 1)
	pop_seat = seat
	pop_k = 0.0
	_pop_tw = create_tween()
	_pop_tw.tween_property(self, "pop_k", 1.0, UIStyle.dur(POP_TIME)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_tw.tween_callback(func():
		pop_seat = -1
		shown = full
		queue_redraw())


## Final review (2026-11-05): steps aside (`on`) for a banner that takes the middle of the top strip,
## such as sacrifice mode's hint pill, fading out and ignoring the mouse; `on` false fades it back.
## The two shared the same spot and the plaque hid the hint. Under reduce motion it is instant.
func yield_to(on: bool) -> void:
	if on == yielded:
		return
	yielded = on
	mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_PASS
	if _yield_tw != null and _yield_tw.is_valid():
		_yield_tw.kill()
	var to := 0.0 if on else 1.0
	if UIStyle.reduce_motion or not is_inside_tree():
		modulate.a = to
		return
	_yield_tw = create_tween()
	_yield_tw.tween_property(self, "modulate:a", to, UIStyle.dur(0.18 if on else 0.3)).set_trans(Tween.TRANS_SINE)


## True while a point is popping in (tests).
func popping() -> bool:
	return pop_seat != -1


func _kill_pop() -> void:
	if _pop_tw != null and _pop_tw.is_valid():
		_pop_tw.kill()
	_pop_tw = null
	if pop_seat != -1 and not m.is_empty():
		shown = (m["scores"] as Array).duplicate()   # a pop cut short ends with its point shown
	pop_seat = -1
	pop_k = 1.0


## Sizes the plaque to the names and the series length, centred where it was.
func _relayout() -> void:
	if m.is_empty():
		return
	var f := UIStyle.font_display(600)
	var me: int = m["me"]
	for k in 2:
		var seat: int = me if k == 0 else 1 - me
		var nm := SeriesResults._fit(f, String(m["names"][seat]).to_upper(), NAME_MAX, NAME_PX)
		_name_w[k] = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX).x
	var n := int(m["best_of"])
	var cap_w := caption_font().get_string_size(caption_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_PX).x
	var dots_w := DOT_STEP * float(n - 1) + 2.0 * (DOT_R + RING_GAP + 0.7)
	cart_w = ceilf(maxf(CART_MIN_W, maxf(cap_w, dots_w) + 2.0 * CART_PAD))
	var side := maxf(_name_w[0], _name_w[1]) + NAME_GAP + GEM_STEP * float(int(m["need"])) + 8.0 + (CART_GAP - 8.0)
	var w := ceilf(2.0 * (PAD + side) + cart_w)
	custom_minimum_size = Vector2(w, H)
	size = custom_minimum_size
	tooltip_text = SeriesResults.summary(m)
	place()
	queue_redraw()
	_breath.queue_redraw()


## Centres the plaque in its parent's width, in the middle of the strip's height.
func place() -> void:
	var p := get_parent() as Control
	if p == null:
		return
	position = Vector2(roundf((p.size.x - size.x) / 2.0), roundf((p.size.y - size.y) / 2.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		var p := get_parent() as Control
		if p != null and not p.resized.is_connected(place):
			p.resized.connect(place)


func _process(_d: float) -> void:
	if visible and not m.is_empty() and int(m["current"]) >= 0 and not UIStyle.reduce_motion:
		_breath.queue_redraw()


## The full results card as this plaque's tooltip.
func _make_custom_tooltip(_for_text: String) -> Object:
	if m.is_empty():
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := UIStyle.label("SERIES", 12, UIStyle.GOLD, false, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	box.add_child(SeriesResults.new().setup(m))
	return box


## Centre of the cartouche's dot for game `i`.
func dot_pos(i: int) -> Vector2:
	var n: int = m.get("best_of", 3)
	var x0 := size.x / 2.0 - DOT_STEP * float(n - 1) / 2.0
	return Vector2(x0 + DOT_STEP * i, DOT_Y)


## The raised middle cartouche (local rect).
func cartouche_rect() -> Rect2:
	return Rect2(size.x / 2.0 - cart_w / 2.0, CART_TOP, cart_w, H - 2.0 * CART_TOP)


## The "BEST OF n" caption.
func caption_text() -> String:
	return "BEST OF %d" % int(m.get("best_of", 3))


## The caption's ink box (local rect): its width at CAPTION_PX and the capitals' height over the
## baseline.
func caption_rect() -> Rect2:
	var w := caption_font().get_string_size(caption_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_PX).x
	var cap := CAP_K * float(CAPTION_PX)
	return Rect2(size.x / 2.0 - w / 2.0, CAPTION_BASE - cap, w, cap)


## The caption's font: the display face, bold, tracked out by CAPTION_TRACKING.
func caption_font() -> Font:
	if _caption_font == null:
		# A copy of the bold display variation (a FontVariation over it would drop its weight axis).
		var base := UIStyle.font_display(700)
		_caption_font = (base as FontVariation).duplicate() if base is FontVariation else FontVariation.new()
		if not (base is FontVariation):
			_caption_font.base_font = base
		_caption_font.spacing_glyph = CAPTION_TRACKING
	return _caption_font


## The box the game dots take, the breathing ring round the game in play included (local rect).
func dots_rect() -> Rect2:
	var n: int = m.get("best_of", 3)
	var r := DOT_R + RING_GAP + 0.7
	var a := dot_pos(0)
	var b := dot_pos(n - 1)
	return Rect2(a.x - r, DOT_Y - r, b.x - a.x + 2.0 * r, 2.0 * r)


## Centre of gem `i` (0 nearest the cartouche) of the side `left` or right.
func gem_pos(left: bool, i: int) -> Vector2:
	var cx := size.x / 2.0
	var inner := cart_w / 2.0 + CART_GAP + GEM_R
	return Vector2(cx + (-1.0 if left else 1.0) * (inner + GEM_STEP * i), H / 2.0)


func _draw() -> void:
	if m.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	# The plaque: a drop shadow, dark leather, a gold hairline rim with a lit top edge.
	var sh := UIStyle.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10)
	sh.shadow_color = Color(0, 0, 0, 0.45)
	sh.shadow_size = 6
	sh.shadow_offset = Vector2(0, 2)
	draw_style_box(sh, r)
	var plate := UIStyle.flat(Color(0.075, 0.058, 0.04, 0.94), Color(UIStyle.GOLD, 0.55), 1, 10)
	draw_style_box(plate, r)
	draw_line(Vector2(12, 1.5), Vector2(size.x - 12, 1.5), Color(UIStyle.GOLD_HI, 0.18), 1.0)
	var me: int = m["me"]
	var lead: int = int(m["winner"]) if bool(m["over"]) else int(m["leader"])
	for k in 2:
		var seat: int = me if k == 0 else 1 - me
		_draw_side(seat, k == 0, lead == seat)
	_draw_cartouche()


## One side: the wins as gems from the cartouche outward (the leader's in a laurel), then the name.
func _draw_side(seat: int, left: bool, leading: bool) -> void:
	var col: Color = SeriesResults.SEAT_COLORS[seat]
	var need: int = m["need"]
	var have: int = int(shown[seat])
	var dir := -1.0 if left else 1.0
	if leading and (have > 0 or pop_seat == seat):
		# A laurel wreath around the leader's gems (brighter once the series is won).
		var a := gem_pos(left, 0)
		var b := gem_pos(left, need - 1)
		var mid := (a + b) / 2.0
		var rx := absf(b.x - a.x) / 2.0 + GEM_R + 5.0
		var gold := Color(UIStyle.GOLD_HI, 0.95 if bool(m["over"]) else 0.7)
		for sd in [-1.0, 1.0]:
			SeriesResults.Laurel.draw_half(self, mid + Vector2(0, 1), rx, H / 2.0 - 5.0, sd, gold, 4 + need)
	for i in need:
		var p := gem_pos(left, i)
		if i < have:
			PickPips.draw_gem(self, p, GEM_R, col)
		elif i == have and pop_seat == seat:
			_draw_pop(p, col)
		else:
			PickPips.draw_socket(self, p, GEM_R)
	var f := UIStyle.font_display(600)
	var nm := SeriesResults._fit(f, String(m["names"][seat]).to_upper(), NAME_MAX, NAME_PX)
	var nw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX).x
	var edge := gem_pos(left, need - 1).x + dir * (GEM_R + NAME_GAP)
	var x := edge - nw if left else edge
	var y := H / 2.0 + 5.0
	var winner := bool(m["over"]) and int(m["winner"]) == seat
	draw_string(f, Vector2(x, y + 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX, UIStyle.GOLD_HI if winner else col.lightened(0.4))


## The popping gem: it swells past its size and settles, with a ring of light spreading and fading.
func _draw_pop(p: Vector2, col: Color) -> void:
	PickPips.draw_socket(self, p, GEM_R)
	var t := pop_k
	var s := 0.0
	if t < 0.6:
		s = POP_OVERSHOOT * ease(t / 0.6, 0.4)
	else:
		s = lerpf(POP_OVERSHOOT, 1.0, ease((t - 0.6) / 0.4, 0.5))
	PickPips.draw_gem(self, p, GEM_R * s, col, clampf(t * 3.0, 0.0, 1.0))
	var ring := GEM_R + 4.0 + 18.0 * t
	draw_arc(p, ring, 0.0, TAU, 36, Color(col.lightened(0.4), 0.8 * (1.0 - t)), 2.5 * (1.0 - t) + 0.5, true)
	draw_circle(p, GEM_R * 2.2 * (1.0 - t * 0.5), Color(1, 1, 1, 0.22 * (1.0 - t)), true, -1.0, true)


## The raised middle cartouche: "BEST OF n" over one dot per game.
func _draw_cartouche() -> void:
	var cx := size.x / 2.0
	var cr := cartouche_rect()
	var box := UIStyle.flat(Color(0.13, 0.1, 0.06, 1.0), Color(UIStyle.GOLD, 0.8), 1, 8)
	box.shadow_color = Color(UIStyle.GOLD, 0.12)
	box.shadow_size = 3
	draw_style_box(box, cr)
	draw_line(cr.position + Vector2(8, 1.5), Vector2(cr.end.x - 8, cr.position.y + 1.5), Color(UIStyle.GOLD_HI, 0.3), 1.0)
	SeriesResults.Txt.centred(self, caption_font(), caption_text(), Vector2(cx, CAPTION_BASE), CAPTION_PX, UIStyle.GOLD_HI)
	var res: Array = m["results"]
	for i in int(m["best_of"]):
		var p := dot_pos(i)
		var popping_this := pop_seat != -1 and i == res.size() - 1
		if i < res.size() and not popping_this:
			var c: Color = SeriesResults.SEAT_COLORS[int(res[i])]
			draw_circle(p, DOT_R + 1.0, Color(0, 0, 0, 0.6), true, -1.0, true)
			draw_circle(p, DOT_R, c, true, -1.0, true)
			draw_circle(p + Vector2(-0.9, -1.0), 1.0, Color(1, 1, 1, 0.6), true, -1.0, true)
		elif popping_this:
			var c2: Color = SeriesResults.SEAT_COLORS[int(res[i])]
			draw_circle(p, DOT_R + 1.0, Color(0, 0, 0, 0.6), true, -1.0, true)
			draw_circle(p, DOT_R * clampf(pop_k * 1.6, 0.0, 1.0), c2, true, -1.0, true)
		else:
			var dim := bool(m["over"])
			draw_circle(p, DOT_R, Color(0.05, 0.04, 0.03), true, -1.0, true)
			draw_arc(p, DOT_R, 0.0, TAU, 16, Color(UIStyle.BRONZE, 0.4 if dim else 0.8), 1.0, true)


# The game in play's dot breathes (its own canvas item, H7).
func _draw_breath() -> void:
	if m.is_empty() or int(m["current"]) < 0:
		return
	var p := dot_pos(int(m["current"]))
	var k := 0.75 if UIStyle.reduce_motion else UIStyle.breathe(float(clock.call()), 0.35)
	_breath.draw_arc(p, DOT_R + RING_GAP, 0.0, TAU, 20, Color(UIStyle.GOLD_HI, clampf(0.75 * k, 0.0, 1.0)), 1.4, true)
