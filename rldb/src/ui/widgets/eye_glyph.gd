class_name EyeGlyph
extends Control
## A2: a drawn eye for the spectator controls. Open (gold almond, iris and a soft glow) means
## "can see"; closed (a lowered lid with lashes, muted) means the default, hidden view. Drawn with
## polygons so it stays crisp at any size; purely decorative (ignores the mouse).

## True: open eye. False: closed lid.
var open: bool = false:
	set(v):
		open = v
		queue_redraw()
## Main colour (the open eye uses it brightened, the closed lid as is).
var col: Color = UIStyle.GOLD:
	set(v):
		col = v
		queue_redraw()
## 0..1 glow strength around an open eye (animated by its owner).
var glow: float = 0.0:
	set(v):
		glow = v
		queue_redraw()


func _init(is_open: bool = false, c: Color = UIStyle.GOLD, px: float = 20.0) -> void:
	open = is_open
	col = c
	custom_minimum_size = Vector2(px * 1.5, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Points of an almond eye outline of half-width `hw` and half-height `hh` around `c` (upper
## arc then lower arc), `n` steps per arc.
static func almond(c: Vector2, hw: float, hh: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(-hw, hw, t)
		pts.append(c + Vector2(x, -hh * sin(PI * t)))
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		var x := lerpf(-hw, hw, t)
		pts.append(c + Vector2(x, hh * sin(PI * t)))
	return pts


func _draw() -> void:
	var c := size / 2.0
	var hw := minf(size.x * 0.46, size.y * 0.72)
	var hh := hw * 0.52
	var outline := Color(0.05, 0.03, 0.01, 0.85)
	if open:
		if glow > 0.0:
			for r in 3:
				draw_circle(c, hw * (0.9 + 0.25 * r), Color(col.lightened(0.3), 0.07 * glow))
		var eye := almond(c, hw, hh)
		draw_colored_polygon(eye, Color(0.96, 0.9, 0.76))
		draw_circle(c, hh * 0.86, col.darkened(0.15))
		draw_circle(c, hh * 0.62, col.lightened(0.25))
		draw_circle(c, hh * 0.34, Color(0.06, 0.04, 0.02))
		draw_circle(c + Vector2(hh * 0.25, -hh * 0.3), hh * 0.16, Color(1, 1, 1, 0.9))
		var loop := eye.duplicate()
		loop.append(eye[0])
		draw_polyline(loop, outline, 2.4, true)
		draw_polyline(loop, col.lightened(0.35), 1.1, true)
	else:
		# Closed: the lower lid curve with three lashes, in the muted colour.
		var lid := PackedVector2Array()
		var n := 14
		for i in n + 1:
			var t := float(i) / n
			lid.append(c + Vector2(lerpf(-hw, hw, t), hh * 0.35 * sin(PI * t) - hh * 0.1))
		draw_polyline(lid, outline, 3.4, true)
		draw_polyline(lid, col, 1.8, true)
		for k in [-0.55, 0.0, 0.55]:
			var t: float = (k + 1.0) / 2.0
			var base := c + Vector2(lerpf(-hw, hw, t), hh * 0.35 * sin(PI * t) - hh * 0.1)
			var tip := base + Vector2(k * hh * 0.5, hh * 0.55)
			draw_line(base, tip, outline, 3.0, true)
			draw_line(base, tip, col, 1.5, true)
