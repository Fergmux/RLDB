class_name CostPips
extends Control
## F08: the exact cost of an Arcane material choice as a row of hex gem sockets (wrapping when
## needed; design review #35 uses the rewards' PickPips gems).
## Each circle is one point of the required total: hollow dark sockets while unpaid, filled gold
## coins for the points the selected materials pay (a material fills as many circles as its current
## cost, each material its own shade of gold so the split reads), and a bright rim on every circle
## once the total is paid exactly. A newly paid circle grows in with a small overshoot and a flash
## (UI review F08); with UIStyle.reduce_motion it is immediate.
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


## Coin radius factor for a circle `f` (0..1) of the way through its fill: an ease-out with a small
## overshoot (peaks about 1.1 near f = 0.75), exactly 1 when filled.
static func pop(f: float) -> float:
	f = clampf(f, 0.0, 1.0)
	var c1 := 1.70158
	var t := f - 1.0
	return 1.0 + (c1 + 1.0) * t * t * t + c1 * t * t


func _draw() -> void:
	if need <= 0:
		return
	var cols := columns()
	var exact := paid() == need
	for i in need:
		var row := i / cols
		var in_row := mini(cols, need - row * cols)
		var row_w := in_row * D + (in_row - 1) * GAP
		var x0 := (size.x - row_w) / 2.0
		var c := Vector2(x0 + (i % cols) * (D + GAP) + D / 2.0, 2.0 + row * (D + GAP) + D / 2.0)
		var r := D / 2.0
		var fill := clampf(shown - float(i), 0.0, 1.0)
		# Design review #35: the rewards' hex gems. An empty hex socket still to fill; a paid point
		# pops in as a faceted gem (each material its own shade of gold, so the split reads).
		PickPips.draw_socket(self, c, r)
		if fill > 0.0:
			var k := owner_of(i)
			var col: Color = UIStyle.COST_COLORS["ap"] if k % 2 == 0 else UIStyle.GOLD.lerp(Color("c9822e"), 0.45)
			PickPips.draw_gem(self, c, (r - 1.0) * pop(fill), col, minf(1.0, fill * 2.0))
			# The fill flash: a bright hex ring that blooms and fades while the gem grows in.
			var fl := sin(PI * fill)
			if fl > 0.01:
				var ring := PickPips._hex(c, r + 2.0)
				ring.append(ring[0])
				draw_polyline(ring, Color(UIStyle.GOLD_HI, 0.8 * fl), 2.0, true)
		if exact:
			var ring2 := PickPips._hex(c, r + 0.5)
			ring2.append(ring2[0])
			draw_polyline(ring2, UIStyle.GOLD_HI, 1.8, true)
