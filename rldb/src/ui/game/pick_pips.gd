class_name PickPips
extends Control
## Remaining reward picks as faceted amber gems; spent picks are empty bronze sockets.

## Distance between gem centres.
const STEP := 40.0
const R := 15.0

## Picks left.
var left: int = 0
## Total picks.
var total: int = 0
## Per-gem scale while the gems pop in (empty: all at rest).
var _pop: Array = []


## Width needed for `n` gems.
static func width_for(n: int) -> float:
	return maxf(STEP, n * STEP)


func _init() -> void:
	custom_minimum_size = Vector2(0, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Rewards reveal (design review #63): the remaining gems pop in one after another (scale 0 -> 1.15
## -> 1, BACK OUT), `step` s apart after `delay`. Under reduce motion they are simply there.
func pop_in(delay: float = 0.0, step: float = 0.06) -> void:
	_pop = []
	if UIStyle.reduce_motion or not is_inside_tree() or left <= 0:
		queue_redraw()
		return
	for i in left:
		_pop.append(0.0)
	queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	for i in left:
		var idx := i
		var setter := func(v: float) -> void:
			if idx < _pop.size():
				_pop[idx] = v
				queue_redraw()
		tw.tween_method(setter, 0.0, 1.0, UIStyle.motion("panel_in")).set_delay(UIStyle.dur(delay + step * i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		_pop = []
		queue_redraw())


## True while the pop-in is running (tests).
func popping() -> bool:
	return not _pop.is_empty()


static func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 6:
		var a := -PI / 2.0 + TAU * float(i) / 6.0
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


func _draw() -> void:
	var amber: Color = UIStyle.COST_COLORS["ap"]
	for i in total:
		var c := Vector2(STEP / 2.0 + i * STEP, size.y / 2.0)
		if i < left:
			var k := float(_pop[i]) if i < _pop.size() else 1.0
			draw_gem(self, c, R * k, amber, clampf(k * 1.5, 0.0, 1.0))
		else:
			draw_socket(self, c, R)


## A faceted gold hex gem of radius `r` at `c` in `col` (bright crown, dark pavilion, dark rim, a
## white glint and a soft halo). `alpha` fades it. Shared with CostPips (design review #35).
static func draw_gem(ci: CanvasItem, c: Vector2, r: float, col: Color, alpha: float = 1.0) -> void:
	if r <= 0.5 or alpha <= 0.0:
		return
	var k := r / R
	ci.draw_circle(c, r + 5.0 * k, Color(col, 0.12 * alpha))
	ci.draw_circle(c, r + 2.5 * k, Color(col, 0.16 * alpha))
	var hex := _hex(c, r)
	ci.draw_colored_polygon(hex, Color(col.darkened(0.15), alpha))
	ci.draw_colored_polygon(PackedVector2Array([hex[5], hex[0], hex[1], c]), Color(col.lightened(0.35), alpha))
	ci.draw_colored_polygon(PackedVector2Array([hex[1], hex[2], c]), Color(col, alpha))
	ci.draw_colored_polygon(PackedVector2Array([hex[2], hex[3], c]), Color(col.darkened(0.3), alpha))
	ci.draw_colored_polygon(PackedVector2Array([hex[3], hex[4], c]), Color(col.darkened(0.15), alpha))
	ci.draw_colored_polygon(PackedVector2Array([hex[4], hex[5], c]), Color(col.lightened(0.1), alpha))
	var ring := hex.duplicate()
	ring.append(hex[0])
	ci.draw_polyline(ring, Color(col.darkened(0.6), alpha), maxf(1.0, 1.6 * k), true)
	ci.draw_circle(c + Vector2(-4.5, -6.5) * k, 2.6 * k, Color(1, 1, 1, 0.65 * alpha))


## An empty hex socket of radius `r` at `c`: a dark well with a bronze rim and a faint facet line.
static func draw_socket(ci: CanvasItem, c: Vector2, r: float) -> void:
	var hex2 := _hex(c, r - 1.0)
	ci.draw_colored_polygon(hex2, Color(0.06, 0.045, 0.03))
	var ring2 := hex2.duplicate()
	ring2.append(hex2[0])
	ci.draw_polyline(ring2, Color(UIStyle.BRONZE, 0.85), maxf(1.2, 2.0 * r / R), true)
	ci.draw_polyline(PackedVector2Array([hex2[0], c, hex2[2]]), Color(UIStyle.BRONZE, 0.25), 1.0, true)
