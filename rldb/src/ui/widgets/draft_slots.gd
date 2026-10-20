class_name DraftSlots
extends Control
## The draft's progress as card slots (design review #59): one engraved card outline per pick,
## four to a row. A slot already picked is filled with a small card in its kind colour (a soft top
## light, a gold rim and the kind glyph), the next slot breathes, the rest stay engraved in the
## leather. Display only.
##
##     var s := DraftSlots.new()
##     s.setup(20, ["unit", "spell"])     # 20 picks, two made

## Slot size, gaps and columns (px).
const SLOT := Vector2(40, 56)
const GAP := Vector2(10, 10)
const COLS := 4

## Picks in the whole draft.
var total: int = 20
## The kind ("unit", "spell", ...) of each pick made so far, in order.
var kinds: Array = []
## Seconds clock (tests and frozen shots inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Sets the draft shown: `n` picks in all, `picked` the kinds of those made.
func setup(n: int, picked: Array) -> DraftSlots:
	total = maxi(n, picked.size())
	kinds = picked.duplicate()
	var rows := ceili(float(total) / COLS)
	custom_minimum_size = Vector2(COLS * SLOT.x + (COLS - 1) * GAP.x, rows * SLOT.y + maxi(rows - 1, 0) * GAP.y + 8.0)
	queue_redraw()
	return self


## Top-left of slot `i` (the grid is centred in the control's width).
func slot_pos(i: int) -> Vector2:
	var w := COLS * SLOT.x + (COLS - 1) * GAP.x
	var x0 := floorf((size.x - w) / 2.0)
	return Vector2(x0 + (i % COLS) * (SLOT.x + GAP.x), 4.0 + floorf(float(i) / COLS) * (SLOT.y + GAP.y))


func _process(_d: float) -> void:
	if kinds.size() < total and is_visible_in_tree() and not UIStyle.reduce_motion:
		queue_redraw()


func _draw() -> void:
	var t := float(clock.call())
	for i in total:
		var r := Rect2(slot_pos(i), SLOT)
		if i < kinds.size():
			_filled(r, String(kinds[i]))
		else:
			_engraved(r, i == kinds.size(), t)


## An empty slot: an engraved card outline (a dark line with a faint lit line under it) and a
## small diamond; the next slot's rim breathes gold.
func _engraved(r: Rect2, next: bool, t: float) -> void:
	var rad := 4
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0, 0, 0, 0.22)
	well.set_corner_radius_all(rad)
	draw_style_box(well, r)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0, 0, 0, 0)
	lit.set_corner_radius_all(rad)
	lit.set_border_width_all(1)
	lit.border_color = Color(UIStyle.GOLD, 0.16)
	draw_style_box(lit, Rect2(r.position + Vector2(0, 1), r.size))
	var dark := lit.duplicate() as StyleBoxFlat
	dark.border_color = Color(0, 0, 0, 0.6)
	draw_style_box(dark, r)
	if next:
		var k := 0.8 if UIStyle.reduce_motion else 0.55 + 0.45 * (0.5 + 0.5 * sin(t / 2.4 * TAU))
		var ring := lit.duplicate() as StyleBoxFlat
		ring.border_color = Color(UIStyle.GOLD_HI, 0.55 * k)
		ring.set_border_width_all(2)
		draw_style_box(ring, r.grow(1.0))
	var c := r.get_center()
	var d := 5.0
	var dia := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0), c + Vector2(0, -d)])
	draw_polyline(dia, Color(UIStyle.GOLD, 0.2 if not next else 0.45), 1.0, true)


## A picked slot: a little card in its kind colour, lit from the top, with a gold rim and its glyph.
func _filled(r: Rect2, kind: String) -> void:
	var col: Color = UIStyle.CATEGORY_COLORS.get(kind, UIStyle.BRONZE)
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.45))
	Ornate.vgradient(self, r, col.lightened(0.12), col.darkened(0.55))
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.set_corner_radius_all(4)
	frame.set_border_width_all(1)
	frame.border_color = Color(UIStyle.GOLD, 0.85)
	draw_style_box(frame, r)
	draw_line(r.position + Vector2(4, 2.5), Vector2(r.end.x - 4, r.position.y + 2.5), Color(UIStyle.GOLD_HI, 0.45), 1.0)
	CardArt.draw_glyph(self, CardArt._glyph_kind({"category": kind}), r.get_center(), r.size.x * 0.22, Color(1, 1, 1, 0.6))
