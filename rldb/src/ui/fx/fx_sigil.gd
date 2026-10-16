class_name FxSigil
extends Control
## Small procedural magic drawings for the card-movement effects (F03-16 / F03-17), drawn centred
## on the node position as `t` runs 0 -> 1: a Fusion swirl, a Ritual light column, an Arcane
## hexagram sigil, card cracks, a collapsing void ring and a glowing mote. Presentation-only,
## click-through; FxPlayer creates, tweens and frees it.

## Which drawing: "fusion" | "ritual" | "arcane" | "crack" | "void" | "mote" | "rays" | "ash".
var kind: String = "mote"
## Main colour (alpha is driven by `t`).
var col: Color = Color.WHITE
## Reach in pixels.
var radius: float = 60.0
## Animation progress 0 -> 1; redraws on every change.
var t: float = 0.0: set = _set_t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(4, 4)


func _set_t(v: float) -> void:
	t = v
	queue_redraw()


func _draw() -> void:
	match kind:
		"fusion": _draw_swirl()
		"ritual": _draw_column()
		"arcane": _draw_sigil()
		"crack": _draw_cracks()
		"void": _draw_void()
		"rays": _draw_rays()
		"ash": _draw_ash()
		_: _draw_mote()


## Three spiral arms of sparks winding inward, ending in a bright core flash.
func _draw_swirl() -> void:
	var e := 1.0 - pow(1.0 - t, 2.0)
	for arm in 3:
		for i in 16:
			var u := float(i) / 15.0
			var r := radius * (0.15 + 0.85 * u) * (1.0 - 0.8 * e)
			var ang := float(arm) * TAU / 3.0 + u * 3.4 - t * 7.0
			var a := (1.0 - t) * (1.0 - 0.6 * u)
			draw_circle(Vector2(cos(ang), sin(ang)) * r, 3.4 * (1.0 - 0.5 * u) * (1.0 - 0.4 * t) + 0.6, Color(col.lightened(0.35 * (1.0 - u)), a), true, -1.0, true)
	var core := sin(clampf(t, 0.0, 1.0) * PI)
	draw_circle(Vector2.ZERO, radius * 0.45 * core, Color(col.lightened(0.5), 0.35 * core), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius * (1.0 - 0.7 * e), 0.0, TAU, 48, Color(col.lightened(0.4), 0.7 * (1.0 - t)), 2.0, true)


## A column of light rising from the card with a pulsing ground ring.
func _draw_column() -> void:
	var a := sin(clampf(t, 0.0, 1.0) * PI)
	var w := radius * 0.42 * (1.0 - 0.35 * t)
	var h := radius * 2.6
	for i in 4:
		var f := 1.0 - float(i) * 0.22
		draw_rect(Rect2(-w * f / 2.0, -h * 0.85 * a - radius * 0.2, w * f, h * a), Color(col.lightened(0.35), 0.16 * a), true)
	draw_circle(Vector2.ZERO, radius * 0.55 * a, Color(col.lightened(0.5), 0.3 * a), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * t), 0.0, TAU, 56, Color(col.lightened(0.45), 0.9 * (1.0 - t)), 2.5, true)


## A turning hexagram inside a ring with small diamonds on its points.
func _draw_sigil() -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	var a := 1.0 - t * t
	var r := radius * (0.35 + 0.65 * e)
	var rot := t * 2.4
	var c := Color(col.lightened(0.5), a)
	for tri in 2:
		var pts := PackedVector2Array()
		for i in 4:
			var ang := rot + float(tri) * PI / 3.0 + float(i % 3) * TAU / 3.0 - PI / 2.0
			pts.append(Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(pts, c, 1.5 + 2.0 * a, true)
	draw_arc(Vector2.ZERO, r * 1.08, 0.0, TAU, 48, Color(col, 0.8 * a), 1.5, true)
	draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 32, Color(col, 0.5 * a), 1.2, true)
	for i in 6:
		var ang := rot + float(i) * TAU / 6.0 - PI / 2.0
		var p := Vector2(cos(ang), sin(ang)) * r * 1.08
		var s := 3.5 + 2.0 * a
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)]), c)


## Jagged cracks running out from the centre, revealed over the first part of `t`.
func _draw_cracks() -> void:
	var grow := clampf(t * 1.6, 0.0, 1.0)
	var a := 1.0 - clampf((t - 0.5) * 2.0, 0.0, 1.0)
	for k in 7:
		var base := float(k) * TAU / 7.0 + 0.35
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		var segs := int(ceil(6.0 * grow))
		for i in segs:
			var jig := sin(float(k * 31 + i * 17)) * 0.55
			p += Vector2(cos(base + jig), sin(base + jig)) * radius * 0.2
			pts.append(p)
		if pts.size() > 1:
			draw_polyline(pts, Color(0, 0, 0, 0.85 * a), 4.0, true)
			draw_polyline(pts, Color(col.lightened(0.5), a), 1.8, true)


## A ring collapsing into its centre with a dark core: the void taking a card.
func _draw_void() -> void:
	var e := 1.0 - pow(1.0 - t, 2.0)
	var a := sin(clampf(t, 0.0, 1.0) * PI)
	draw_circle(Vector2.ZERO, radius * (1.0 - e) * 0.9, Color(0.03, 0.0, 0.07, 0.55 * a), true, -1.0, true)
	for i in 3:
		var u := float(i) / 3.0
		var r := radius * (1.0 - clampf(e + u * 0.25, 0.0, 1.0)) + 2.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col.lightened(0.2), (0.85 - u * 0.25) * a), 2.5 - u, true)
	for i in 10:
		var ang := float(i) * TAU / 10.0 + t * 4.0
		var r2 := radius * (1.0 - e) * (0.6 + 0.4 * float(i % 3) / 2.0)
		draw_circle(Vector2(cos(ang), sin(ang)) * r2, 2.4 * a + 0.4, Color(col.lightened(0.45), a), true, -1.0, true)


## A soft glowing ball (material travelling to its pile).
func _draw_mote() -> void:
	var a := 1.0 - 0.3 * t
	draw_circle(Vector2.ZERO, radius, Color(col, 0.18 * a), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.62, Color(col.lightened(0.3), 0.5 * a), true, -1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.9 * a), true, -1.0, true)


## Turning light rays (victory): 14 wedges from the centre, fading in and out over `t`.
func _draw_rays() -> void:
	var a := sin(clampf(t, 0.0, 1.0) * PI)
	var n := 14
	for i in n:
		var a0 := float(i) * TAU / float(n) + t * 0.9
		var a1 := a0 + TAU / float(n) * 0.45
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a0), sin(a0)) * radius, Vector2(cos(a1), sin(a1)) * radius]), Color(col, 0.2 * a))
	draw_circle(Vector2.ZERO, radius * 0.18, Color(col.lightened(0.5), 0.35 * a), true, -1.0, true)


## Slowly falling ash (defeat): 36 grey flecks drifting down a band `radius` wide and 1.4 x tall.
func _draw_ash() -> void:
	var a := sin(clampf(t, 0.0, 1.0) * PI)
	for i in 36:
		var x := (sin(float(i) * 12.9898) * 0.5) * radius * 2.0
		var speed := 0.6 + 0.5 * fposmod(sin(float(i) * 78.233), 1.0)
		var y := -radius * 0.7 + fposmod(t * speed * radius * 1.2 + float(i) * 37.0, radius * 1.4)
		draw_circle(Vector2(x + sin(t * 5.0 + float(i)) * 6.0, y), 1.6 + float(i % 3), Color(col, 0.5 * a), true, -1.0, true)
