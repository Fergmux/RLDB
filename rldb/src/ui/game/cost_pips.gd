class_name CostPips
extends Control
## F08: the exact cost of an Arcane material choice as a row of circles (wrapping when needed).
## Each circle is one point of the required total: empty sockets while unpaid, filled silver gems
## for the points the selected materials pay (a material fills as many circles as its current
## cost, each material its own shade so the split reads), and a gold rim on every circle once the
## total is paid exactly. The fill eases in; with UIStyle.reduce_motion it is immediate.
##
##     var pips := CostPips.new()
##     pips.set_payment(5, [2, 3])     # 5 required, two materials of cost 2 and 3: exact

## Circle diameter and the gap between circles.
const D := 22.0
const GAP := 6.0
## Seconds the fill takes to ease to a new total.
const FILL_TIME := 0.18

## Required total (circles drawn).
var need: int = 0
## Current cost of each selected material, in selection order.
var parts: Array = []
## Points paid as currently drawn (eases toward the paid total).
var shown: float = 0.0:
	set(v):
		shown = v
		queue_redraw()

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, D + 4.0)


## Points paid by the selected materials.
func paid() -> int:
	var t := 0
	for v in parts:
		t += int(v)
	return t


## Shows `total` required points paid by materials of the given current costs.
func set_payment(total: int, costs: Array) -> void:
	var first := need != total
	need = maxi(total, 0)
	parts = costs.duplicate()
	_update_height()
	var target := float(mini(paid(), need))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if first or UIStyle.reduce_motion or not is_inside_tree():
		shown = target
	else:
		_tween = create_tween()
		_tween.tween_property(self, "shown", target, UIStyle.dur(FILL_TIME)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Circles per row at the current width (at least one).
func columns() -> int:
	return maxi(1, int(floor((size.x + GAP) / (D + GAP)))) if size.x > 0.0 else maxi(need, 1)


func _update_height() -> void:
	var rows := int(ceil(float(maxi(need, 1)) / float(columns())))
	var h := rows * D + (rows - 1) * GAP + 4.0
	if not is_equal_approx(custom_minimum_size.y, h):
		custom_minimum_size = Vector2(0, h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_height()
		queue_redraw()


## Index of the material paying circle `i` (-1 when unpaid).
func owner_of(i: int) -> int:
	var acc := 0
	for k in parts.size():
		acc += int(parts[k])
		if i < acc:
			return k
	return -1


func _draw() -> void:
	if need <= 0:
		return
	var cols := columns()
	var exact := paid() == need
	var silver: Color = UIStyle.COST_COLORS["arcane"]
	for i in need:
		var row := i / cols
		var in_row := mini(cols, need - row * cols)
		var row_w := in_row * D + (in_row - 1) * GAP
		var x0 := (size.x - row_w) / 2.0
		var c := Vector2(x0 + (i % cols) * (D + GAP) + D / 2.0, 2.0 + row * (D + GAP) + D / 2.0)
		var r := D / 2.0
		var fill := clampf(shown - float(i), 0.0, 1.0)
		# Socket.
		draw_circle(c, r, Color(0.05, 0.04, 0.03, 0.95))
		draw_arc(c, r - 1.0, 0.0, TAU, 28, Color(UIStyle.BRONZE, 0.9), 2.0, true)
		if fill > 0.0:
			var k := owner_of(i)
			var col := silver.lightened(0.12) if k % 2 == 0 else silver.darkened(0.12)
			var rr := (r - 3.0) * fill
			draw_circle(c, rr + 1.5, Color(silver, 0.25 * fill))
			draw_circle(c, rr, col)
			draw_circle(c + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.32, Color(1, 1, 1, 0.55 * fill))
		if exact:
			draw_arc(c, r, 0.0, TAU, 28, UIStyle.GOLD_HI, 1.6, true)
