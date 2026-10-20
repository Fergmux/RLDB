class_name AmbientMotes
extends Control
## Ambient life for an idle screen (design review #6, 1.4.5 "Ambient"): drifting petal and gold
## motes and, optionally, a soft light shaft that pulses on a slow sine. Click-through; drawn on one
## Control with an additive material, so it is cheap. Deterministic (seeded): the same seed gives
## the same field. Reduce motion: the motes rest where they are (a static, faint field) and the
## shaft holds its mid brightness.
##
##     var motes := AmbientMotes.new(26, [PETAL, GOLD])
##     motes.shaft = Rect2(0.52, 0.0, 0.2, 0.9)    # in fractions of the rect
##     backdrop.add_child(motes)

const PETAL := Color("e8a0b0")
const GOLD := Color("f0cf7a")
## Mote size range (px), lifetime range (s), alpha range, upward drift (px/s) and sideways sway.
const SIZE_MIN := 4.0
const SIZE_MAX := 10.0
const LIFE_MIN := 8.0
const LIFE_MAX := 14.0
const ALPHA_MIN := 0.35
const ALPHA_MAX := 0.5
const RISE_MIN := 10.0
const RISE_MAX := 26.0
const SWAY_PX := 22.0
## Light shaft pulse period (s) and its alpha range.
const SHAFT_PERIOD := 4.0
const SHAFT_ALPHA := Vector2(0.05, 0.11)

## Mote colours, picked in turn.
var colors: Array = [PETAL, GOLD]
## The light shaft as fractions of the rect (x, y, w, h); a zero size draws none.
var shaft: Rect2 = Rect2()
var shaft_color: Color = Color("ffd9a0")
## Seconds clock (tests and frozen shots inject one).
var clock: Callable = func() -> float: return float(Time.get_ticks_msec()) / 1000.0

var _motes: Array = []
## Round mote core and halo radii, as multiples of the mote size.
var core_k := 0.32
var halo_k := 1.6
## Halo alpha, as a multiple of the mote's alpha.
var halo_a := 0.18


## Table dust (design review #23): sparse, small, slow warm motes in the duel table's light. Tuned in
## the H1 release check to be noticed at a glance (the first pass read as two or three pinpricks)
## while staying under the cards: a brighter core and a wider, warmer halo.
const DUST := {"size": Vector2(4.0, 7.0), "life": Vector2(10.0, 16.0), "alpha": Vector2(0.6, 0.85),
	"rise": Vector2(3.0, 9.0), "sway": 14.0, "petals": false, "core": 0.55, "halo": 3.0, "halo_a": 0.3}
## Motes of the duel table.
const DUST_COUNT := 16
const DUST_COLOR := Color("ffd9a0")


## Sparse warm dust for the duel table (#23): `count` round motes on the DUST profile.
static func dust(count: int = DUST_COUNT, seed_value: int = 2310) -> AmbientMotes:
	var m := AmbientMotes.new(count, [DUST_COLOR], seed_value, DUST)
	m.name = "TableDust"
	return m


## `count` motes in `cols`, from `seed`. `profile` overrides the size, life, alpha and rise ranges
## (Vector2 min / max), the sway (px) and whether the first colour draws petals ("petals").
func _init(count: int = 26, cols: Array = [], seed_value: int = 1606, profile: Dictionary = {}) -> void:
	if not cols.is_empty():
		colors = cols
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sz: Vector2 = profile.get("size", Vector2(SIZE_MIN, SIZE_MAX))
	var lf: Vector2 = profile.get("life", Vector2(LIFE_MIN, LIFE_MAX))
	var al: Vector2 = profile.get("alpha", Vector2(ALPHA_MIN, ALPHA_MAX))
	var rs: Vector2 = profile.get("rise", Vector2(RISE_MIN, RISE_MAX))
	var sw := float(profile.get("sway", SWAY_PX))
	var petals := bool(profile.get("petals", true))
	core_k = float(profile.get("core", core_k))
	halo_k = float(profile.get("halo", halo_k))
	halo_a = float(profile.get("halo_a", halo_a))
	for i in count:
		_motes.append({
			"x": rng.randf(), "y": rng.randf(),
			"size": rng.randf_range(sz.x, sz.y),
			"life": rng.randf_range(lf.x, lf.y),
			"phase": rng.randf(),
			"alpha": rng.randf_range(al.x, al.y),
			"rise": rng.randf_range(rs.x, rs.y),
			"sway": rng.randf_range(0.4, 1.0) * sw,
			"spin": rng.randf_range(-1.0, 1.0),
			"col": colors[i % colors.size()],
			"petal": petals and i % colors.size() == 0,
		})


## Number of motes.
func count() -> int:
	return _motes.size()


func _process(_d: float) -> void:
	if is_visible_in_tree() and not UIStyle.reduce_motion:
		queue_redraw()


## Position (px), alpha multiplier and rotation of mote `i` at clock time `t` (reduce motion: its
## resting place, fully faded in).
func mote_state(i: int, t: float) -> Dictionary:
	var m: Dictionary = _motes[i]
	var life := float(m["life"])
	var k := 0.5 if UIStyle.reduce_motion else fposmod(t / life + float(m["phase"]), 1.0)
	var y := fposmod(float(m["y"]) - k * float(m["rise"]) * life / maxf(size.y, 1.0), 1.0) * size.y
	var x := float(m["x"]) * size.x + sin((k * TAU) + float(m["phase"]) * 9.0) * float(m["sway"])
	# Fade in over the first 15% of the life and out over the last 25%.
	var a := clampf(k / 0.15, 0.0, 1.0) * clampf((1.0 - k) / 0.25, 0.0, 1.0)
	if UIStyle.reduce_motion:
		a = 0.6
	return {"pos": Vector2(x, y), "alpha": a, "rot": k * TAU * float(m["spin"])}


func _draw() -> void:
	var t := float(clock.call())
	if shaft.size.x > 0.0 and shaft.size.y > 0.0:
		_draw_shaft(t)
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		var st := mote_state(i, t)
		var col: Color = m["col"]
		var a := float(m["alpha"]) * float(st["alpha"])
		if a <= 0.01:
			continue
		var p: Vector2 = st["pos"]
		var s := float(m["size"])
		draw_circle(p, s * halo_k, Color(col, a * halo_a), true, -1.0, true)
		if bool(m["petal"]):
			# A petal: a soft ellipse turned by its spin.
			var pts := PackedVector2Array()
			for j in 12:
				var ang := TAU * float(j) / 12.0
				pts.append(p + Vector2(cos(ang) * s * 0.55, sin(ang) * s * 0.3).rotated(float(st["rot"])))
			draw_colored_polygon(pts, Color(col, a))
		else:
			draw_circle(p, s * core_k, Color(col, a), true, -1.0, true)


func _draw_shaft(t: float) -> void:
	var r := Rect2(shaft.position * size, shaft.size * size)
	var k := 0.5 if UIStyle.reduce_motion else 0.5 + 0.5 * sin(t / SHAFT_PERIOD * TAU)
	var a := lerpf(SHAFT_ALPHA.x, SHAFT_ALPHA.y, k)
	# A cone, wider at the bottom, bright at the top, fading out downwards.
	var top_l := Vector2(r.position.x + r.size.x * 0.3, r.position.y)
	var top_r := Vector2(r.end.x - r.size.x * 0.3, r.position.y)
	var bot_r := Vector2(r.end.x, r.end.y)
	var bot_l := Vector2(r.position.x, r.end.y)
	var mid_l := top_l.lerp(bot_l, 0.55)
	var mid_r := top_r.lerp(bot_r, 0.55)
	var c0 := Color(shaft_color, a)
	var c1 := Color(shaft_color, a * 0.55)
	var c2 := Color(shaft_color, 0.0)
	draw_polygon(PackedVector2Array([top_l, top_r, mid_r, mid_l]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([mid_l, mid_r, bot_r, bot_l]), PackedColorArray([c1, c1, c2, c2]))
