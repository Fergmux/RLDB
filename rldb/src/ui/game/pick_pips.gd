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


## Width needed for `n` gems.
static func width_for(n: int) -> float:
	return maxf(STEP, n * STEP)


func _init() -> void:
	custom_minimum_size = Vector2(0, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
			draw_circle(c, R + 5.0, Color(amber, 0.12))
			draw_circle(c, R + 2.5, Color(amber, 0.16))
			var hex := _hex(c, R)
			draw_colored_polygon(hex, amber.darkened(0.15))
			# Facets: bright crown, dark pavilion.
			draw_colored_polygon(PackedVector2Array([hex[5], hex[0], hex[1], c]), amber.lightened(0.35))
			draw_colored_polygon(PackedVector2Array([hex[1], hex[2], c]), amber)
			draw_colored_polygon(PackedVector2Array([hex[2], hex[3], c]), amber.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([hex[3], hex[4], c]), amber.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([hex[4], hex[5], c]), amber.lightened(0.1))
			var ring := hex.duplicate()
			ring.append(hex[0])
			draw_polyline(ring, amber.darkened(0.6), 1.6, true)
			draw_circle(c + Vector2(-4.5, -6.5), 2.6, Color(1, 1, 1, 0.65))
		else:
			var hex2 := _hex(c, R - 1.0)
			draw_colored_polygon(hex2, Color(0.06, 0.045, 0.03))
			var ring2 := hex2.duplicate()
			ring2.append(hex2[0])
			draw_polyline(ring2, Color(UIStyle.BRONZE, 0.85), 2.0, true)
			draw_polyline(PackedVector2Array([hex2[0], c, hex2[2]]), Color(UIStyle.BRONZE, 0.25), 1.0, true)
