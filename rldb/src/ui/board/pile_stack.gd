class_name PileStack
extends Control
## A card pile drawn as a stack of card backs (or the top card face for public piles) whose
## height grows with the number of cards, plus a name/count plate. Used for Draw, Extra, Spent
## and Exhaust beside the unit zones (user feedback 2026-10-15). Clicking emits `pressed`
## when `clickable`. Only counts are shown for piles the viewer may not inspect.

signal pressed(zone: String)

const MAX_LAYERS := 10
const LAYER_STEP := 1.5

var zone: String = "draw"
var title: String = "Deck"
var count: int = 0
var clickable: bool = false
var ready_mark: bool = false
var _hover: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func set_pile(n: int, can_open: bool, is_ready: bool = false) -> void:
	if n == count and can_open == clickable and is_ready == ready_mark:
		return
	count = n
	clickable = can_open
	ready_mark = is_ready
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	tooltip_text = "%s: %d card%s%s" % [title, n, "" if n == 1 else "s", " — click to look through it" if clickable else ""]
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(zone)
		accept_event()


## Centre of the top card (where cards fly to/from).
func top_center() -> Vector2:
	return get_global_rect().get_center() - Vector2(0, _layers() * LAYER_STEP)


func _layers() -> int:
	if count <= 0:
		return 0
	return clampi(int(ceil(float(count) / 2.0)), 1, MAX_LAYERS)


func _draw() -> void:
	var plate_h := 20.0
	# The pile's cards keep the 2:3 card shape; the stack rises above the bottom card.
	var avail := size.y - plate_h - 6.0 - MAX_LAYERS * LAYER_STEP
	var ch := minf(avail, (size.x - 8.0) * 1.5)
	var cw := ch / 1.5
	var card := Rect2(Vector2((size.x - cw) / 2.0, 2.0 + MAX_LAYERS * LAYER_STEP), Vector2(cw, ch))
	# Empty pile outline.
	var sb := StyleBoxFlat.new()
	sb.draw_center = count == 0
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.border_color = Color(UIStyle.BRONZE, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, card)
	var n := _layers()
	for i in n:
		var r := card
		r.position.y -= float(i) * LAYER_STEP
		r.position.x += (0.6 if i % 2 == 0 else -0.6)
		var b := StyleBoxFlat.new()
		b.bg_color = Color("1d1630")
		b.border_color = Color("6e5a9a")
		b.set_border_width_all(1 if i < n - 1 else 2)
		b.set_corner_radius_all(6)
		if i == n - 1:
			b.shadow_color = Color(0, 0, 0, 0.45)
			b.shadow_size = 4
		draw_style_box(b, r)
		if i == n - 1:
			CardWidget.draw_back_art(self, r, r.size.x / 90.0)   # the same back as every card
	if _hover and clickable:
		var top := card
		top.position.y -= float(maxi(n - 1, 0)) * LAYER_STEP
		var h := StyleBoxFlat.new()
		h.draw_center = false
		h.border_color = UIStyle.GOLD_HI
		h.set_border_width_all(2)
		h.set_corner_radius_all(7)
		draw_style_box(h, top.grow(2))
	if ready_mark:
		var rr2 := card
		rr2.position.y -= float(maxi(n - 1, 0)) * LAYER_STEP
		var rb := StyleBoxFlat.new()
		rb.draw_center = false
		rb.border_color = UIStyle.READY
		rb.set_border_width_all(3)
		rb.set_corner_radius_all(8)
		draw_style_box(rb, rr2.grow(3))
	# Name / count plate.
	var pr := Rect2(Vector2(0, size.y - plate_h), Vector2(size.x, plate_h))
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	ps.border_color = Color(UIStyle.BRONZE, 0.8)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(5)
	draw_style_box(ps, pr)
	var font := UIStyle.font_bold()
	var txt := "%s %d" % [title, count]
	var fs := 13
	while fs > 9 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 6:
		fs -= 1
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - tw) / 2.0, pr.position.y + plate_h / 2.0 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT)
