class_name PileStack
extends Control
## A card pile drawn as a stack of card backs whose height grows with the number of cards. The
## bottom card fills the whole rect (the same size as a Power zone); extra layers rise a few
## pixels above it. Used for Draw, Extra, Spent and Exhaust beside the unit zones. Clicking emits
## `pressed` when `clickable`.
##
## Design review #24: the count sits on a struck bronze medallion (an embossed number on a coin) at
## the top card's centre, and the pile's name on an F4 bronze plate at its foot. An empty pile is an
## inlaid recess with the engraved, dashed outline of a card back and a smaller medallion showing 0.
## The number counts to a new value (`count` token) and the medallion pulses when it changes.

signal pressed(zone: String)

## Most back layers drawn, the rise (px) per layer and how many cards one layer stands for.
const MAX_LAYERS := 6
const LAYER_STEP := 1.2
const CARDS_PER_LAYER := 3.0
## Card corner radius (px) of every layer and of the empty-pile outline.
const RADIUS := 6
## Base width the card-back art is authored at (CardWidget "back" kind).
const BACK_BASE_W := 90.0
## Count font size (a full pile; an empty one uses COUNT_FS_EMPTY on its 28 px medallion).
const COUNT_FS := 20
const COUNT_FS_EMPTY := 15
## Medallion radius (px): a full pile's, an empty pile's (28 px across).
const MEDAL_R := 18.0
const MEDAL_R_EMPTY := 14.0
## The medallion's bronze: face (top-lit to bottom), rim and the dark number struck into it.
const MEDAL_TOP := Color("c79a52")
const MEDAL_BOTTOM := Color("6e4f26")
const MEDAL_RIM := Color("f0cf7a")
const MEDAL_INK := Color("2a1a08")
## Name plate: height, its largest / smallest label font size and the F4 plate colour.
const PLATE_H := 20.0
const TITLE_FS := 11
const TITLE_FS_MIN := 8
const PLATE_COL := Color("b08446")
## Empty pile: the engraved dashed outline (bronze 30%), its dash and gap (px).
const OUTLINE := Color(0.478, 0.353, 0.188, 0.3)
const DASH := 6.0
const DASH_GAP := 4.0

## Zone id emitted by `pressed` ("draw", "extra", "spent", "exhaust").
var zone: String = "draw"
## Label on the name plate and in the tooltip.
var title: String = "Deck"
var count: int = 0
## Whether clicking opens the pile (local player's inspectable piles).
var clickable: bool = false
## Steady "summon ready" glow around the top card (same look as a ready CardWidget).
var ready_mark: bool = false
## Its list is open in the side panel: drawn with the selected-card corner brackets (2026-10-18).
var selected: bool = false
## The number on the medallion, counting towards `count` (presentation only).
var shown_count: float = 0.0:
	set(v):
		shown_count = v
		queue_redraw()
var _hover: bool = false
## 1 -> 0 after the count changes: the medallion pops a little (presentation only).
var _pop: float = 0.0: set = _set_pop
var _pop_tw: Tween
var _count_tw: Tween
var _plate_box: DepthBox


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)   # only while the ready glow animates
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	_plate_box = UIStyle.chip_style(PLATE_COL, 4)


## Updates the count, clickability and ready glow; a changed count counts up or down on the medallion and
## pops it (the number jumps straight to the new value under reduce motion).
func set_pile(n: int, can_open: bool, is_ready: bool = false) -> void:
	if n == count and can_open == clickable and is_ready == ready_mark:
		return
	if n != count:
		if is_inside_tree() and not UIStyle.reduce_motion:
			if _pop_tw != null and _pop_tw.is_valid():
				_pop_tw.kill()
			_pop = 1.0
			_pop_tw = create_tween()
			_pop_tw.tween_property(self, "_pop", 0.0, UIStyle.dur(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if _count_tw != null and _count_tw.is_valid():
				_count_tw.kill()
			_count_tw = create_tween()
			UIStyle.tween_token(_count_tw, self, "shown_count", float(n), "count")
		else:
			shown_count = float(n)
	count = n
	clickable = can_open
	ready_mark = is_ready
	_update_process()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	tooltip_text = "%s: %d card%s%s" % [title, n, "" if n == 1 else "s", " — click to look through it" if clickable else ""]
	queue_redraw()


## The number the medallion shows now (the count while it is still counting).
func displayed_count() -> int:
	return roundi(shown_count)


## Shows (or drops) the selected brackets while this pile's list is open in the side panel.
func set_selected(on: bool) -> void:
	if on == selected:
		return
	selected = on
	_update_process()
	queue_redraw()


## Redraw every frame only while something animates (the ready glow, the breathing brackets).
func _update_process() -> void:
	set_process((ready_mark or selected) and not UIStyle.reduce_motion)


func _process(_d: float) -> void:
	queue_redraw()


func _set_pop(v: float) -> void:
	_pop = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(zone)
		accept_event()


## Centre of the top card (where cards fly to/from).
func top_center() -> Vector2:
	return get_global_rect().get_center() - Vector2(0, maxi(_layers() - 1, 0) * LAYER_STEP)


## Number of back layers drawn for the current count (0 = empty pile).
func _layers() -> int:
	if count <= 0:
		return 0
	return clampi(int(ceil(float(count) / CARDS_PER_LAYER)), 1, MAX_LAYERS)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	var n := _layers()
	if n == 0:
		_draw_empty(card)
	for i in n:
		var r := card
		r.position.y -= float(i) * LAYER_STEP
		var b := StyleBoxFlat.new()
		b.bg_color = CardBack.BODY
		b.border_color = CardBack.BORDER
		b.set_border_width_all(1 if i < n - 1 else 2)
		b.set_corner_radius_all(RADIUS)
		if i == 0:
			b.shadow_color = Color(0, 0, 0, 0.45)
			b.shadow_size = 4
		draw_style_box(b, r)
		if i == n - 1:
			CardBack.draw_art(self, r, r.size.x / BACK_BASE_W)   # the same back as every card
	var top := card
	top.position.y -= float(maxi(n - 1, 0)) * LAYER_STEP
	if _hover and clickable:
		var h := StyleBoxFlat.new()
		h.draw_center = false
		h.border_color = UIStyle.GOLD_HI
		h.set_border_width_all(2)
		h.set_corner_radius_all(7)
		draw_style_box(h, top.grow(2))
	if selected:
		# The same breathing corner brackets as a selected card (CardOverlays).
		var ph := 0.0
		if not UIStyle.reduce_motion:
			ph = sin(float(Time.get_ticks_msec()) / CardOverlays.SELECT_PERIOD_MS * TAU)
		CardOverlays._corner_brackets(self, top.grow(6.0 + 2.2 * ph), 9.0, UIStyle.SELECT.lightened(0.3), 2.4)
	if ready_mark:
		# Same animated glow and breathing badge as a ready CardWidget (F03-21, #25).
		CardOverlays.ready_glow(self, top, 9.0, 1.0, CardOverlays.ready_pulse())
		CardOverlays.ready_badge_draw(self, top, 1.0, CardOverlays.ready_pulse())
	var c := top.get_center() - Vector2(0, PLATE_H * 0.35)
	medallion(self, c, MEDAL_R if n > 0 else MEDAL_R_EMPTY, displayed_count(), COUNT_FS if n > 0 else COUNT_FS_EMPTY, 1.0 + 0.16 * _pop, n == 0)
	_draw_plate(top)


# An empty pile: an inlaid recess (as an empty zone, #22) with the engraved dashed outline of a card.
func _draw_empty(card: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.24)
	sb.set_corner_radius_all(RADIUS)
	sb.anti_aliasing = true
	draw_style_box(sb, card)
	CardLayouts.inner_shadow(self, card, RADIUS, 7.0, 0.42)
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.set_border_width_all(1)
	sb.border_color = CardLayouts.ZONE_RIM
	draw_style_box(sb, card)
	var o := card.grow(-7.0)
	for seg in dashed_rect(o, DASH, DASH_GAP):
		draw_line(seg[0] + Vector2(0, 1), seg[1] + Vector2(0, 1), Color(CardLayouts.MARK_LIT, 0.08), 1.0, true)
		draw_line(seg[0], seg[1], OUTLINE, 1.0, true)


## Dash segments [[a, b], ...] along the four edges of `r` (each edge starts on a dash).
static func dashed_rect(r: Rect2, dash: float, gap: float) -> Array:
	var out := []
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var ln := a.distance_to(b)
		var d := (b - a) / maxf(ln, 0.001)
		var x := 0.0
		while x < ln:
			out.append([a + d * x, a + d * minf(x + dash, ln)])
			x += dash + gap
	return out


## A struck bronze medallion of radius `r` centred on `c` with `num` embossed on it at `fs` px, scaled
## by `k` (the change pulse). `quiet` (an empty pile) tones it down. Shared by the pile counts.
static func medallion(ci: CanvasItem, c: Vector2, r: float, num: int, fs: int, k: float = 1.0, quiet: bool = false) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * k)
	var a := 0.78 if quiet else 1.0
	ci.draw_circle(Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.55 * a), true, -1.0, true)
	ci.draw_circle(Vector2.ZERO, r, Color(MEDAL_BOTTOM, a), true, -1.0, true)
	# Top-lit face: smaller, lighter discs drifting up (a soft vertical gradient on a round face).
	var steps := 6
	for i in steps:
		var t := float(i + 1) / float(steps)
		ci.draw_circle(Vector2(0, -r * 0.18 * t), r * (1.0 - 0.1 * t), Color(MEDAL_BOTTOM.lerp(MEDAL_TOP, t), a * 0.55), true, -1.0, true)
	ci.draw_arc(Vector2.ZERO, r - 0.75, 0.0, TAU, 40, Color(MEDAL_RIM, 0.85 * a), 1.5, true)
	ci.draw_arc(Vector2.ZERO, r - 3.2, 0.0, TAU, 40, Color(0, 0, 0, 0.35 * a), 1.0, true)
	ci.draw_arc(Vector2.ZERO, r - 3.2, PI * 1.1, PI * 1.9, 16, Color(1, 0.95, 0.8, 0.3 * a), 1.0, true)
	var font := UIStyle.font_display(700)
	var txt := str(num)
	var f := fs
	while f > 9 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > r * 2.0 - 9.0:
		f -= 1
	var tsz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f)
	var pos := Vector2(-tsz.x / 2.0, (font.get_ascent(f) - font.get_descent(f)) / 2.0)
	# Embossed: a lit edge below, the dark face of the number, a faint top highlight.
	ci.draw_string(font, pos + Vector2(0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, Color(1, 0.93, 0.75, 0.45 * a))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f, Color(MEDAL_INK, 0.95 * a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The F4 bronze name plate at the foot of the top card.
func _draw_plate(top: Rect2) -> void:
	var pr := Rect2(Vector2(top.position.x + 5.0, top.end.y - PLATE_H - 5.0), Vector2(top.size.x - 10.0, PLATE_H))
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0)
	sh.shadow_color = Color(0, 0, 0, 0.5)
	sh.shadow_size = 3
	sh.shadow_offset = Vector2(0, 1)
	sh.set_corner_radius_all(4)
	draw_style_box(sh, pr)
	draw_style_box(UIStyle.flat(Color(0.06, 0.05, 0.04, 0.92), Color(0, 0, 0, 0), 0, 4), pr)
	draw_style_box(_plate_box, pr)
	var tf := UIStyle.font_display(600)
	var tfs := TITLE_FS
	var label := title.to_upper()
	while tfs > TITLE_FS_MIN and tf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > pr.size.x - 8:
		tfs -= 1
	var tw := tf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var base_y := pr.position.y + PLATE_H / 2.0 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) / 2.0
	var tp := Vector2(pr.position.x + (pr.size.x - tw) / 2.0, base_y)
	draw_string(tf, tp + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0, 0, 0, 0.8))
	draw_string(tf, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UIStyle.TEXT)
