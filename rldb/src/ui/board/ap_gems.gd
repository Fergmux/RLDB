class_name ApGemRow
extends Control
## Faceted topaz AP gems (D4 "AP gems", design review findings #20 and #21), matching the HP vial.
## Drop-in for PlayerPlate.ApGems: the same fields (ap, ap_start, ap_peak), the same
## set_values(ap, start, peak, snap) call and the same F02-06 slot policy (capacity_for /
## filled_for / spent_for), so the plate keeps its inputs. (Named ApGemRow because PlayerPlate
## has an inner class ApGems until integration replaces it.)
##
## Each AP is a 16 px faceted topaz (radial #fff1b0 -> #f2b544 -> #9a6416, dark outline, white glint
## top-left) in a 20 px bronze socket. A spent gem leaves a dark cracked socket with a 1 px inner
## rim. Before the first turn (capacity 0) two dark, uncracked sockets show with "AP 0/2" dimmed.
## Gaining: the gem pops in (scale 0 -> 1.15 -> 1, 260 ms BACK OUT, 60 ms stagger), `gem_gained`.
## Spending: it dims through amber to dark (200 ms) with a 3-particle puff, `gem_spent`.
## The label: "AP" in 13 px Alegreya Bold MUTED and the numbers in GOLD_HI, 10 px after the gems.
## Reduce motion: changes snap (no pop, puff or label punch) but the signals still fire, so the
## sounds play. A `snap` update (a new player / game) is silent. Time comes from `clock`.

## A gem was gained at slot `index` (the moment its pop starts: the chime hook, D6).
signal gem_gained(index: int)
## A gem was spent at slot `index` (the crack hook, D6).
signal gem_spent(index: int)

const SOCKET := 20.0
const GEM := 16.0
const GAP := 4.0
## Sockets shown before the first turn.
const IDLE_SLOTS := 2
## Width budget for the gem row; above it the gems shrink (never below MIN_SCALE).
const MAX_ROW_W := 170.0
const MIN_SCALE := 0.35
const LABEL_GAP := 10.0
const GAIN_T := 0.26
const SPEND_T := 0.2
const STAGGER := 0.06
const PUFF_T := 0.35
const POP_PEAK := 1.15
const LABEL_POP_T := 0.25
## Palette (review D4).
const TOPAZ_HI := Color("fff1b0")
const TOPAZ := Color("f2b544")
const TOPAZ_LO := Color("9a6416")
const GEM_EDGE := Color("2a1606")
const SOCKET_INK := Color("0d0906")

var ap: int = 0
var ap_start: int = 0
var ap_peak: int = 0
## Seconds clock (tests and the gallery inject a frozen one).
var clock: Callable = func() -> float: return float(Time.get_ticks_usec()) / 1000000.0

## Per-slot animation start times (clock s, stagger included).
var _gain_t0: Dictionary = {}
var _spend_t0: Dictionary = {}
var _label_t0: float = -INF
## Puff particles: [pos, vel, t0].
var _puffs: Array = []
var _emitted: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, SOCKET + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Slots shown: max(ap_start, ap_peak, ap), never negative (F02-06).
static func capacity_for(p_ap: int, p_start: int, p_peak: int) -> int:
	return maxi(0, maxi(p_ap, maxi(p_start, p_peak)))


## Filled (unspent) slots: ap clamped to the capacity.
static func filled_for(p_ap: int, p_start: int, p_peak: int) -> int:
	return clampi(p_ap, 0, capacity_for(p_ap, p_start, p_peak))


## Spent (cracked socket) slots: capacity - filled.
static func spent_for(p_ap: int, p_start: int, p_peak: int) -> int:
	return capacity_for(p_ap, p_start, p_peak) - filled_for(p_ap, p_start, p_peak)


## Sockets drawn: the capacity, or IDLE_SLOTS dark sockets before the first turn.
static func slots_for(p_ap: int, p_start: int, p_peak: int) -> int:
	var cap := capacity_for(p_ap, p_start, p_peak)
	return cap if cap > 0 else IDLE_SLOTS


## Gem scale for `slots` sockets inside MAX_ROW_W (1 = full size).
static func row_scale(slots: int) -> float:
	var full := float(slots) * SOCKET + float(maxi(0, slots - 1)) * GAP
	return clampf(MAX_ROW_W / maxf(full, 1.0), MIN_SCALE, 1.0)


## Pop scale of a gained gem `t` s into its GAIN_T pop: 0 -> POP_PEAK -> 1 (BACK OUT), 1 after.
static func pop_scale(t: float, d: float = GAIN_T) -> float:
	if t <= 0.0:
		return 0.0
	if t >= d:
		return 1.0
	var k := t / d
	if k < 0.55:
		var u := k / 0.55
		return POP_PEAK * (1.0 - pow(1.0 - u, 3.0))
	var v := (k - 0.55) / 0.45
	return lerpf(POP_PEAK, 1.0, 1.0 - pow(1.0 - v, 2.0))


func capacity() -> int:
	return capacity_for(ap, ap_start, ap_peak)


func filled() -> int:
	return filled_for(ap, ap_start, ap_peak)


## Sockets drawn now.
func slots() -> int:
	return slots_for(ap, ap_start, ap_peak)


## Label text: "AP 1/2"; before the first turn "AP 0/2" (IDLE_SLOTS).
func ap_text() -> String:
	return "AP %d/%d" % [ap, capacity() if capacity() > 0 else IDLE_SLOTS]


## Sets the AP fields and animates: gained gems pop in, spent gems dim with a puff. `snap` (or
## reduce motion / not in the tree) = no animation.
func set_values(p_ap: int, p_start: int, p_peak: int, snap: bool = false) -> void:
	var old_filled := filled()
	var old_ap := ap
	ap = p_ap
	ap_start = p_start
	ap_peak = p_peak
	var new_filled := filled()
	if UIStyle.reduce_motion and not snap and is_inside_tree():
		# No motion, but the sound hooks still fire (sound is not motion).
		for i in range(old_filled, new_filled):
			gem_gained.emit(i)
		for i in range(old_filled - 1, new_filled - 1, -1):
			gem_spent.emit(i)
	if snap or not is_inside_tree() or UIStyle.reduce_motion:
		_gain_t0.clear()
		_spend_t0.clear()
		_puffs.clear()
		_label_t0 = -INF
		set_process(false)
		queue_redraw()
		return
	var t := _now()
	var k := 0
	for i in range(old_filled, new_filled):
		_spend_t0.erase(i)
		_gain_t0[i] = t + UIStyle.dur(STAGGER) * k
		_emitted.erase("g%d" % i)
		k += 1
	k = 0
	for i in range(old_filled - 1, new_filled - 1, -1):
		_gain_t0.erase(i)
		_spend_t0[i] = t + UIStyle.dur(STAGGER) * k
		_emitted.erase("s%d" % i)
		k += 1
	if ap != old_ap:
		_label_t0 = t
	set_process(true)
	step()


## True while a gem or label animation runs.
func animating() -> bool:
	return not _gain_t0.is_empty() or not _spend_t0.is_empty() or not _puffs.is_empty() or _label_t0 != -INF


## Advances to the clock's time (each frame while animating; tests call it after moving the clock).
func step() -> void:
	var t := _now()
	for i in _gain_t0.keys():
		var e: float = t - float(_gain_t0[i])
		if e >= 0.0 and not _emitted.has("g%d" % i):
			_emitted["g%d" % i] = true
			gem_gained.emit(int(i))
		if e >= UIStyle.dur(GAIN_T):
			_gain_t0.erase(i)
	for i in _spend_t0.keys():
		var e: float = t - float(_spend_t0[i])
		if e >= 0.0 and not _emitted.has("s%d" % i):
			_emitted["s%d" % i] = true
			gem_spent.emit(int(i))
			var c := _slot_centre(int(i))
			for j in 3:
				var a := -PI / 2.0 + (float(j) - 1.0) * 0.8
				_puffs.append([c, Vector2(cos(a), sin(a)) * 16.0, t])
		if e >= UIStyle.dur(SPEND_T):
			_spend_t0.erase(i)
	var keep: Array = []
	for p in _puffs:
		if t - float(p[2]) < UIStyle.dur(PUFF_T):
			keep.append(p)
	_puffs = keep
	if _label_t0 != -INF and t - _label_t0 >= UIStyle.dur(LABEL_POP_T):
		_label_t0 = -INF
	if not animating():
		set_process(false)
	queue_redraw()


func _process(_d: float) -> void:
	step()


func _now() -> float:
	return float(clock.call())


func _pitch() -> float:
	return (SOCKET + GAP) * row_scale(slots())


func _slot_centre(i: int) -> Vector2:
	var s := row_scale(slots())
	return Vector2(SOCKET * s / 2.0 + 1.0 + float(i) * _pitch(), size.y / 2.0)


func _draw() -> void:
	var t := _now()
	var n := slots()
	var cap := capacity()
	var full := filled()
	var s := row_scale(n)
	for i in n:
		var c := _slot_centre(i)
		var spent := cap > 0 and i >= full
		_draw_socket(c, s, spent and not _spend_t0.has(i), cap > 0)
		if i < full:
			var g := 1.0
			if _gain_t0.has(i):
				g = pop_scale(t - float(_gain_t0[i]), UIStyle.dur(GAIN_T))
			if g > 0.0:
				if _gain_t0.has(i) and g < 1.0:
					var e := clampf((t - float(_gain_t0[i])) / UIStyle.dur(GAIN_T), 0.0, 1.0)
					draw_arc(c, SOCKET * s * (0.5 + 0.45 * e), 0.0, TAU, 28, Color(UIStyle.GOLD_HI, 0.75 * (1.0 - e)), 1.5, true)
				_draw_gem(c, GEM * s * 0.5 * g, 0.0, 1.0)
		elif _spend_t0.has(i):
			var k := clampf((t - float(_spend_t0[i])) / UIStyle.dur(SPEND_T), 0.0, 1.0)
			_draw_socket(c, s, true, true, k)
			_draw_gem(c, GEM * s * 0.5 * lerpf(1.0, 0.8, k), k, 1.0 - k * k)
	for p in _puffs:
		var e: float = (t - float(p[2])) / UIStyle.dur(PUFF_T)
		var pos: Vector2 = p[0] + (p[1] as Vector2) * e
		draw_circle(pos, 1.5 + 2.5 * e, Color(0.85, 0.62, 0.3, 0.45 * (1.0 - e)), true, -1.0, true)
	_draw_label(n, s, t, cap)


## The bronze socket: a gilded ring, an ink well and a 1 px inner rim; `cracked` adds the spent
## crack (faded in by `crack_a`); `lit` false = the dark idle socket before the first turn.
func _draw_socket(c: Vector2, s: float, cracked: bool, lit: bool, crack_a: float = 1.0) -> void:
	var r := SOCKET * s * 0.5
	draw_circle(c + Vector2(0, 1), r + 0.5, Color(0, 0, 0, 0.45), true, -1.0, true)
	var ring := PackedVector2Array()
	var cols := PackedColorArray()
	for k in 24:
		var a := TAU * float(k) / 24.0
		var q := c + Vector2(cos(a), sin(a)) * r
		ring.append(q)
		var ty := clampf((q.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)
		cols.append(UIStyle.GOLD_HI.lerp(UIStyle.GOLD, minf(1.0, ty * 2.0)).lerp(UIStyle.BRONZE, maxf(0.0, ty * 2.0 - 1.0)))
	draw_polygon(ring, cols)
	draw_arc(c, r, 0.0, TAU, 24, Color("1a1006"), 1.0, true)
	draw_circle(c, r - 2.0 * maxf(s, 0.6), SOCKET_INK, true, -1.0, true)
	draw_arc(c, r - 2.5 * maxf(s, 0.6), PI * 0.15, PI * 0.85, 12, Color(TOPAZ, 0.22 if lit else 0.1), 1.0, true)
	draw_arc(c, r - 2.0 * maxf(s, 0.6), PI * 1.1, PI * 1.9, 12, Color(0, 0, 0, 0.6), 1.0, true)
	if cracked and r >= 4.5:
		var ir := r - 2.5
		var line := PackedVector2Array([c + Vector2(-0.15, -0.8) * ir, c + Vector2(0.12, -0.2) * ir,
			c + Vector2(-0.18, 0.22) * ir, c + Vector2(0.1, 0.8) * ir])
		draw_polyline(line, Color(TOPAZ, 0.45 * crack_a), 1.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(0.12, -0.2) * ir, c + Vector2(0.5, -0.05) * ir]), Color(TOPAZ, 0.3 * crack_a), 1.0, true)


## One faceted topaz of girdle radius `r`: an outlined octagon with eight shaded crown facets
## around a radial-gradient table and a white glint. `dim` 0..1 runs it through amber to dark.
func _draw_gem(c: Vector2, r: float, dim: float, alpha: float) -> void:
	if r <= 0.3 or alpha <= 0.0:
		return
	var light := Vector2(-0.6, -0.8).normalized()
	var dark_to := Color("2a1a0c")
	var hi := TOPAZ_HI.lerp(TOPAZ, dim * 0.8).lerp(dark_to, maxf(0.0, dim * 1.6 - 0.6))
	var mid := TOPAZ.lerp(Color("e08a2a"), dim).lerp(dark_to, maxf(0.0, dim * 1.6 - 0.6))
	var lo := TOPAZ_LO.lerp(dark_to, dim)
	var girdle := PackedVector2Array()
	var table := PackedVector2Array()
	var outer := PackedVector2Array()
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var d := Vector2(cos(a), sin(a))
		girdle.append(c + d * r)
		table.append(c + d * r * 0.52)
		outer.append(c + d * (r + 1.0))
	draw_colored_polygon(outer, Color(GEM_EDGE, alpha))
	for k in 8:
		var k2 := (k + 1) % 8
		var mid_dir := ((girdle[k] + girdle[k2]) / 2.0 - c).normalized()
		var lit := clampf(0.5 + 0.5 * mid_dir.dot(light), 0.0, 1.0)
		var fc := lo.lerp(mid, minf(1.0, lit * 1.6)).lerp(hi, maxf(0.0, lit * 1.6 - 0.9))
		draw_colored_polygon(PackedVector2Array([girdle[k], girdle[k2], table[k2], table[k]]), Color(fc, alpha))
	# The table: a radial gradient, brightest a little towards the light.
	var hot := c + light * r * 0.12
	var rim_c := Color(mid.lerp(hi, 0.35), alpha)
	for k in 8:
		draw_polygon(PackedVector2Array([hot, table[k], table[(k + 1) % 8]]), PackedColorArray([Color(hi, alpha), rim_c, rim_c]))
	draw_polyline(table + PackedVector2Array([table[0]]), Color(lo, 0.35 * alpha), 1.0, true)
	if r >= 3.0:
		var g := c + light * r * 0.5
		draw_circle(g, maxf(1.0, r * 0.14), Color(1, 1, 1, 0.95 * alpha * (1.0 - dim)), true, -1.0, true)
		draw_line(g + Vector2(-r * 0.22, 0), g + Vector2(r * 0.22, 0), Color(1, 1, 1, 0.55 * alpha * (1.0 - dim)), 1.0, true)


func _draw_label(n: int, s: float, t: float, cap: int) -> void:
	var x := float(n) * _pitch() - GAP * s + 1.0 + LABEL_GAP
	var bold := UIStyle.font_bold()
	var y := size.y / 2.0 + (bold.get_ascent(15) - bold.get_descent(15)) / 2.0
	var idle := cap == 0
	var lab_col := UIStyle.TEXT_DIM if idle else UIStyle.MUTED
	var num_col := UIStyle.TEXT_DIM if idle else UIStyle.GOLD_HI
	var nums := "%d/%d" % [ap, cap if cap > 0 else IDLE_SLOTS]
	draw_string_outline(bold, Vector2(x, y - 1), "AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.6))
	draw_string(bold, Vector2(x, y - 1), "AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, lab_col)
	var nx := x + bold.get_string_size("AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 5.0
	var sc := 1.0
	if _label_t0 != -INF:
		sc = 1.0 + 0.15 * sin(clampf((t - _label_t0) / UIStyle.dur(LABEL_POP_T), 0.0, 1.0) * PI)
	var piv := Vector2(nx, y - 5.0)
	draw_set_transform(piv - piv * sc, 0.0, Vector2(sc, sc))
	draw_string_outline(bold, Vector2(nx, y), nums, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color(0, 0, 0, 0.65))
	draw_string(bold, Vector2(nx, y), nums, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, num_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
