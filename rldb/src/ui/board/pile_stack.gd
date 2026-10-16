class_name PileStack
extends Control
## A card pile drawn as a stack of card backs whose height grows with the number of cards. The
## bottom card fills the whole rect (the same size as a Power zone); extra layers rise a few
## pixels above it. The pile's name sits on a plate at the foot of the top card and the count is
## overlaid on its vertical centre (user feedback 2026-10-16). Used for Draw, Extra, Spent and Exhaust
## beside the unit zones. Clicking emits `pressed` when `clickable`.

signal pressed(zone: String)

## Most back layers drawn, the rise (px) per layer and how many cards one layer stands for.
const MAX_LAYERS := 6
const LAYER_STEP := 1.2
const CARDS_PER_LAYER := 3.0
## Card corner radius (px) of every layer and of the empty-pile outline.
const RADIUS := 6
## Base width the card-back art is authored at (CardWidget "back" kind).
const BACK_BASE_W := 90.0
## Count font size; the count badge is sized once for "99" at this size.
const COUNT_FS := 22
## Name-plate height and its largest / smallest label font size.
const PLATE_H := 17.0
const TITLE_FS := 10
const TITLE_FS_MIN := 8

## Zone id emitted by `pressed` ("draw", "extra", "spent", "exhaust").
var zone: String = "draw"
## Label on the name plate and in the tooltip.
var title: String = "Deck"
var count: int = 0
## Whether clicking opens the pile (local player's inspectable piles).
var clickable: bool = false
## Steady "summon ready" glow around the top card (same look as a ready CardWidget).
var ready_mark: bool = false
var _hover: bool = false
## 1 -> 0 after the count changes: the count badge pops a little (presentation only).
var _pop: float = 0.0: set = _set_pop
var _pop_tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())


## Updates the count, clickability and ready glow; a changed count pops the badge (unless reduce motion).
func set_pile(n: int, can_open: bool, is_ready: bool = false) -> void:
	if n == count and can_open == clickable and is_ready == ready_mark:
		return
	if n != count and is_inside_tree() and not UIStyle.reduce_motion:
		if _pop_tw != null and _pop_tw.is_valid():
			_pop_tw.kill()
		_pop = 1.0
		_pop_tw = create_tween()
		_pop_tw.tween_property(self, "_pop", 0.0, UIStyle.dur(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	count = n
	clickable = can_open
	ready_mark = is_ready
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	tooltip_text = "%s: %d card%s%s" % [title, n, "" if n == 1 else "s", " — click to look through it" if clickable else ""]
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
		# Empty pile: a zone-like outline with the name.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.22)
		sb.border_color = Color(UIStyle.BRONZE, 0.55)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(RADIUS)
		draw_style_box(sb, card)
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
	if ready_mark:
		# Same steady soft yellow glow as a ready CardWidget: thin ring plus fading bands outside.
		_ring(Color(UIStyle.READY, 0.30), 3.5, top.grow(6.0), 12.0)
		_ring(Color(UIStyle.READY, 0.15), 4.0, top.grow(9.5), 15.5)
		_ring(Color(UIStyle.READY, 0.06), 4.5, top.grow(13.5), 19.5)
		_ring(Color(UIStyle.READY, 0.9), 2.0, top.grow(3.0), 9.0)
	# Count overlaid on the vertical centre of the top card: one fixed badge sized for "99" and one fixed
	# font size, so the badge never grows when the count gains a digit (user feedback). 100+ steps down.
	var font := UIStyle.font_display(700)
	var num := str(count)
	var c := top.get_center()
	var badge_r := font.get_string_size("99", HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FS).x / 2.0 + 7.0
	var fs := COUNT_FS
	while fs > 10 and font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > badge_r * 2.0 - 10.0:
		fs -= 1
	var tsz := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_set_transform(c, 0.0, Vector2.ONE * (1.0 + 0.16 * _pop))
	c = Vector2.ZERO
	draw_circle(c, badge_r, Color(0.05, 0.04, 0.08, 0.82 if n > 0 else 0.5), true, -1.0, true)
	draw_arc(c, badge_r - 0.75, 0.0, TAU, 40, Color(UIStyle.GOLD, 0.45 if n > 0 else 0.25), 1.5, true)
	var pos := Vector2(c.x - tsz.x / 2.0, c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	draw_string_outline(font, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.85))
	draw_string(font, pos, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.GOLD_HI if n > 0 else UIStyle.MUTED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Name plate at the foot of the top card.
	var plate_h := PLATE_H
	var pr := Rect2(Vector2(top.position.x + 6.0, top.end.y - plate_h - 6.0), Vector2(top.size.x - 12.0, plate_h))
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	ps.border_color = Color(UIStyle.GOLD, 0.65)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(4)
	draw_style_box(ps, pr)
	var tf := UIStyle.font_display(600)
	var tfs := TITLE_FS
	while tfs > TITLE_FS_MIN and tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > pr.size.x - 6:
		tfs -= 1
	var tw := tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var base_y := pr.position.y + plate_h / 2.0 + (tf.get_ascent(tfs) - tf.get_descent(tfs)) / 2.0
	draw_string(tf, Vector2(pr.position.x + (pr.size.x - tw) / 2.0, base_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, UIStyle.TEXT)


## Unfilled rounded ring of width `w` around `rect`.
func _ring(col: Color, w: float, rect: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(maxi(1, roundi(w)))
	sb.set_corner_radius_all(maxi(1, roundi(radius)))
	draw_style_box(sb, rect)
