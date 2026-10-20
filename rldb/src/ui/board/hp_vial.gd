class_name HpVial
extends Control
## The "Vial of Life" HP display (D4, design/design-review-2026-10-20.md): an enamelled ruby vial
## in a gilded bronze bezel. Drop-in for PlayerPlate.HpBar: the same `hp`, `max_hp`, `flash` and
## `set_hp(v, snap)` API, so the plate keeps its inputs (it calls set_hp with each view's HP and
## tweens `flash` in pulse()).
##
## Layers: the body shader (canvas_ui_hp_vial: bezel, glass, liquid, trail, heal glow, ticks, glass
## highlights, low-HP glow) on a child, then the overlay (end studs, the crack decal, the number,
## particles) on a second child.
##
## Motion (all through UIStyle.dur()):
##   damage  a 90 ms white flash over the lost segment, which turns amber and holds 350 ms, then
##           drains to the new value over 450 ms (QUAD IN_OUT) shedding 3-6 falling embers; the vial
##           (and `shake_target`) shakes 4 px for 220 ms, the number punches to 1.18x and tints BAD.
##           A hit of BIG_HIT or more also emits `big_hit` (for a HitVignette pulse).
##   heal    the gained segment glows emerald-gold, the liquid pours into it over 500 ms (QUART
##           OUT), a shimmer band runs along the new fill (600 ms), 5-8 sparkles rise; the number
##           tints GOOD and punches to 1.12x.
##   low     at <= 25% of max the fill brightens, the bezel's inner glow pulses (1.1 s), a crack
##           decal shows, `low_hp_changed(true)` fires (the plate shifts its border to
##           LOW_PLATE_BORDER) and a heartbeat plays on entry, then every 2.2 s on the local
##           player's turn. At <= 10% ember motes drift up (2 per second).
##   max     a max-HP change re-scales over 300 ms (the fill is never rescaled instantly).
##   lethal  shatter(): the glass cracks (150 ms), the liquid drains, 8-12 shards fall.
## Reduce motion: values snap, the trail and heal glow fade out over 120 ms, no shake, punch,
## particles, drift or glint, and the low-HP glow is a static 35%.
##
## Time comes from `clock` (seconds), so tests and the gallery can freeze any frame.

## Emitted on entering the low-HP state, then every HEARTBEAT_PERIOD while `my_turn` (local only).
signal heartbeat
## The low-HP state (<= 25% of max) was entered (true) or left (false).
signal low_hp_changed(low: bool)
## A damage hit of `amount` HP was shown.
signal damaged(amount: int)
## A damage hit of BIG_HIT or more: the screen-side red vignette pulse hook.
signal big_hit(amount: int)
## A heal of `amount` HP was shown.
signal healed(amount: int)

const SHADER := preload("res://assets/shaders/canvas_ui_hp_vial.gdshader")
## HP scale floor (PlayerPlate.DEFAULT_MAX_HP).
const DEFAULT_MAX_HP := 60
## Layout size at 1600x900 (the plate grows by 4 px for it).
const VIAL_SIZE := Vector2(228, 30)
## One segment tick every this many HP.
const TICK_HP := 10
## Low and critical thresholds (fractions of max, inclusive).
const LOW_FRACTION := 0.25
const CRITICAL_FRACTION := 0.10
## The plate border colour while low (the plate applies it on low_hp_changed).
const LOW_PLATE_BORDER := Color("8e2a22")
## Sound requested on each heartbeat (registered by the audio pass; Sfx ignores unknown names).
const HEARTBEAT_SFX := "hp_low_heartbeat"
const HEARTBEAT_DB := -12.0
const HEARTBEAT_PERIOD := 2.2
## Damage timeline (s): flash, amber hold (from the hit), drain, liquid drop (during the flash).
const DMG_FLASH := 0.09
const DMG_HOLD := 0.35
const DMG_DRAIN := 0.45
const DMG_DROP := 0.09
## Heal timeline (s): pour, shimmer pass, glow fade after the pour.
const HEAL_POUR := 0.5
const HEAL_SHIMMER := 0.6
const HEAL_GLOW_FADE := 0.25
## Number: count to the new value, punch scales and duration, tint fade.
const COUNT_T := 0.4
const PUNCH_DMG := 1.18
const PUNCH_HEAL := 1.12
const PUNCH_T := 0.22
const TINT_T := 0.6
## Shake (motion token `impact`).
const SHAKE_PX := 4.0
const SHAKE_T := 0.22
## A hit of at least this many HP emits big_hit.
const BIG_HIT := 10
## Max-HP stretch.
const MAX_STRETCH_T := 0.3
## Reduce-motion replacement fade.
const REDUCED_FADE := 0.12
## Particles: embers (damage), sparkles (heal), motes (critical), shards (shatter).
const EMBER_LIFE := 0.4
const EMBER_FALL := 12.0
const SPARKLE_LIFE := 0.6
const MOTE_RATE := 2.0
const MOTE_LIFE := 1.4
const SHATTER_CRACK := 0.15
const SHATTER_DRAIN := 0.5
const SHARD_LIFE := 0.9
const SHARD_GRAVITY := 260.0
## Sparkle velocity kept per second (they slow as they rise).
const SPARKLE_DRAG := 0.25
## Hard cap on live particles per vial (performance budget: about 2 x 24 small draws per frame).
const MAX_PARTICLES := 24
## Number layout.
const NUMBER_X := 10.0
const NUMBER_SIZE := 22
const SMALL_SIZE := 11
## "/ max" is shown at the right end only when the vial is at least this wide.
const SCALE_LABEL_MIN_W := 160.0

## Real HP (what set_hp was last given, never below 0).
var hp: int = 0
## Full scale. Setting it re-scales over MAX_STRETCH_T (instantly when snapping or not in the tree).
var max_hp: int = DEFAULT_MAX_HP:
	set(v):
		v = maxi(1, v)
		if v == max_hp:
			return
		_max_from = shown_max()
		_max_t0 = _now()
		max_hp = v
		if _animating_allowed():
			_wake()
		else:
			_max_t0 = -INF
		_refresh()
## The number shown now (PlayerPlate.HpBar compatibility: `shown`).
var shown: float:
	get:
		return shown_number()
## White pulse over the glass (PlayerPlate.pulse tweens it 0 -> 0.6 -> 0).
var flash: float = 0.0:
	set(v):
		flash = v
		_over_redraw()
## This vial belongs to the local player (only then does it heartbeat).
var is_local: bool = false
## It is the local player's turn: the heartbeat repeats while low.
var my_turn: bool = false:
	set(v):
		my_turn = v
		_wake()
## Control moved by the hit shake as well as the vial (the player plate; null = the vial only).
## It must not be laid out by a Container (the plates are positioned by GameBoardView).
var shake_target: Control = null
## Seconds clock (tests and the gallery inject a frozen one).
var clock: Callable = func() -> float: return float(Time.get_ticks_usec()) / 1000000.0
## Deterministic particle scatter.
var rng := RandomNumberGenerator.new()

## Damage event: start time, level before, level after (HP). -INF = none.
var _dmg_t0: float = -INF
var _dmg_old: float = 0.0
var _dmg_new: float = 0.0
var _embers_left: int = 0
var _embers_total: int = 0
## Heal event.
var _heal_t0: float = -INF
var _heal_from: float = 0.0
var _heal_to: float = 0.0
## Number count, punch and tint.
var _num_from: float = 0.0
var _num_t0: float = -INF
var _punch_t0: float = -INF
var _punch_scale: float = 1.0
var _tint: Color = Color(1, 1, 1, 0)
var _tint_t0: float = -INF
## Shake.
var _shake_t0: float = -INF
var _shake_base: Vector2 = Vector2.ZERO
var _shake_target_base: Vector2 = Vector2.ZERO
## Max stretch.
var _max_from: float = DEFAULT_MAX_HP
var _max_t0: float = -INF
## Reduced-motion fades (trail / heal glow) and their spans.
var _fade_t0: float = -INF
var _fade_kind: String = ""
var _fade_a: float = 0.0
var _fade_b: float = 0.0
## Low state, crack fade-in, heartbeat schedule, mote spawning.
var _low: bool = false
var _low_t0: float = -INF
var _next_beat: float = INF
var _mote_acc: float = 0.0
## Shatter.
var _shatter_t0: float = -INF
var _shatter_from: float = 0.0
## Particles and the last step time.
var _parts: Array[Particle] = []
var _last_t: float = -1.0
var _settled_level: float = 0.0
var _has_value: bool = false

var _body: Control
var _over: Control
var _mat := ShaderMaterial.new()

static var _noise: ImageTexture = null


## One overlay particle.
class Particle extends RefCounted:
	var kind: String = ""
	## Position now (derived from `origin`, `vel` and the age each step) and at birth.
	var pos: Vector2 = Vector2.ZERO
	var origin: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	## Birth time (clock s; later than now for a staggered start) and the age at the last step.
	var born: float = 0.0
	var age: float = 0.0
	var life: float = 1.0
	var size: float = 2.0
	var spin: float = 0.0
	var angle: float = 0.0
	var col: Color = Color.WHITE


## Body layer: one quad under the vial shader.
class Body extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


## Overlay layer: studs, crack, number, particles (drawn by the vial).
class Overlay extends Control:
	var vial: HpVial

	func _init(v: HpVial) -> void:
		vial = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		vial._draw_overlay(self)


## Screen-edge red vignette for big hits (design review D4: 120 ms, 8% alpha, on the hit side).
## Add one full-rect over the board and call pulse(left) on HpVial.big_hit.
class HitVignette extends Control:
	const PULSE_T := 0.12
	const ALPHA := 0.08
	const REACH := 0.35
	var clock: Callable = func() -> float: return float(Time.get_ticks_usec()) / 1000000.0
	var _t0: float = -INF
	var _left: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_process(false)

	## Pulses the vignette on the left (true) or right side. Skipped under reduce motion.
	func pulse(left: bool) -> void:
		if UIStyle.reduce_motion:
			return
		_left = left
		_t0 = float(clock.call())
		set_process(true)
		queue_redraw()

	## 0..1 strength `t` s into a pulse (fast rise, sine fall).
	static func strength_at(t: float) -> float:
		var d := UIStyle.dur(PULSE_T)
		if t < 0.0 or t >= d:
			return 0.0
		var k := t / d
		return k / 0.25 if k < 0.25 else sin((1.0 - k) / 0.75 * PI / 2.0)

	func _process(_d: float) -> void:
		queue_redraw()
		if float(clock.call()) - _t0 >= UIStyle.dur(PULSE_T):
			set_process(false)

	func _draw() -> void:
		var a := strength_at(float(clock.call()) - _t0) * ALPHA
		if a <= 0.0:
			return
		var w := size.x * REACH
		var x0 := 0.0 if _left else size.x
		var x1 := w if _left else size.x - w
		var red := Color("c4141a")
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
			PackedColorArray([Color(red, a), Color(red, 0.0), Color(red, 0.0), Color(red, a)]))


func _init() -> void:
	custom_minimum_size = VIAL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 7
	_body = Body.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise_tex", noise_texture())
	_mat.set_shader_parameter("glass_tex", UiSurface.texture(UiSurface.LEATHER))
	_mat.set_shader_parameter("metal_tex", UiSurface.texture(UiSurface.METAL))
	_body.material = _mat
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	_over = Overlay.new(self)
	add_child(_over, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_on_resized)
	set_process(false)


func _ready() -> void:
	_on_resized()
	_mat.set_shader_parameter("time_offset", float(get_instance_id() % 997) * 0.37)
	_refresh()


# ---------------------------------------------------------------- pure rules (unit-tested)

## HP clamped to the drawable range 0..max.
static func clamp_hp(v: float, p_max: int) -> float:
	return clampf(v, 0.0, float(maxi(1, p_max)))


## Fraction of the well filled by `v` HP of `p_max`.
static func fraction(v: float, p_max: float) -> float:
	return clampf(v / maxf(1.0, p_max), 0.0, 1.0)


## Low-HP state: HP at or under 25% of max (15 of 60).
static func is_low(v: int, p_max: int) -> bool:
	return float(v) <= float(maxi(1, p_max)) * LOW_FRACTION


## Critical state: HP at or under 10% of max (6 of 60).
static func is_critical(v: int, p_max: int) -> bool:
	return float(v) <= float(maxi(1, p_max)) * CRITICAL_FRACTION


## HP values of the segment ticks for `p_max` (every TICK_HP, excluding 0 and max).
static func tick_values(p_max: int) -> Array[int]:
	var out: Array[int] = []
	var v := TICK_HP
	while v < p_max:
		out.append(v)
		v += TICK_HP
	return out


## Top of the damage trail `t` s after a hit from `old` to `new` HP (durations already scaled):
## `old` through the flash and hold, then a QUAD IN_OUT drain to `new`; `new` after.
static func trail_top(t: float, old: float, new: float, hold_end: float, drain: float) -> float:
	if t < hold_end:
		return old
	if t >= hold_end + drain or drain <= 0.0:
		return new
	var k := (t - hold_end) / drain
	var e := 2.0 * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 2.0) / 2.0
	return lerpf(old, new, e)


## The hit flash strength `t` s after a hit (1 -> 0 over `flash_t`).
static func flash_at(t: float, flash_t: float) -> float:
	if t < 0.0 or t >= flash_t or flash_t <= 0.0:
		return 0.0
	return 1.0 - t / flash_t


## QUART OUT progress of `t` over `d` (clamped).
static func quart_out(t: float, d: float) -> float:
	var k := clampf(t / maxf(d, 0.0001), 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 4.0)


## Ember count for a hit of `amount` HP (3-6).
static func ember_count(amount: int) -> int:
	return clampi(3 + amount / 6, 3, 6)


## Sparkle count for a heal of `amount` HP (5-8).
static func sparkle_count(amount: int) -> int:
	return clampi(5 + amount / 5, 5, 8)


## Tileable 64 x 32 value-noise texture (two octaves, deterministic), shared by every vial.
static func noise_texture() -> ImageTexture:
	if _noise != null:
		return _noise
	var w := 64
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var lattice := func(ix: int, iy: int, per_x: int, per_y: int) -> float:
		var x := posmod(ix, per_x)
		var y := posmod(iy, per_y)
		var n := (x * 374761393 + y * 668265263) & 0x7fffffff
		n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
		return float(n & 0xffff) / 65535.0
	for y in h:
		for x in w:
			var v := 0.0
			var amp := 0.65
			for o in 2:
				var cell := 16.0 / pow(2.0, o)
				var px := x / cell
				var py := y / cell
				var ix := floori(px)
				var iy := floori(py)
				var fx := px - ix
				var fy := py - iy
				fx = fx * fx * (3.0 - 2.0 * fx)
				fy = fy * fy * (3.0 - 2.0 * fy)
				var per_x := int(w / cell)
				var per_y := int(h / cell)
				var a: float = lattice.call(ix, iy, per_x, per_y)
				var b: float = lattice.call(ix + 1, iy, per_x, per_y)
				var c: float = lattice.call(ix, iy + 1, per_x, per_y)
				var d: float = lattice.call(ix + 1, iy + 1, per_x, per_y)
				v += amp * lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
				amp = 0.35
			img.set_pixel(x, y, Color(v, v, v))
	_noise = ImageTexture.create_from_image(img)
	return _noise


# ---------------------------------------------------------------- public API

## Sets the real HP and animates the vial to it (damage trail or heal pour). `snap` = no
## animation (first update, a different player on the plate, not in the tree). The PlayerPlate.HpBar
## contract: the same call with the same value is a no-op.
func set_hp(v: int, snap: bool = false) -> void:
	v = maxi(0, v)
	var t := _now()
	var level := liquid_level(t)
	var number := shown_number(t)
	# The value the vial is showing (normally `hp`; an effect that held the vial at an earlier value
	# and set `hp` back to the real one is measured from what is shown, so its blow still animates).
	var old := roundi(_settled_level) if _has_value else hp
	hp = v
	if snap or not _has_value or not is_inside_tree():
		_has_value = true
		_clear_events()
		_num_from = float(v)
		_settled_level = float(v)
		_update_low(true)
		_refresh()
		return
	if v == old:
		return
	var reduced := UIStyle.reduce_motion
	_num_from = number
	_num_t0 = -INF if reduced else t
	if v < old:
		var top := maxf(level, trail_top_at(t))
		_heal_t0 = -INF
		_dmg_old = maxf(top, float(v))
		_dmg_new = float(v)
		var amount := old - v
		if reduced:
			_dmg_t0 = -INF
			_start_fade("trail", float(v), _dmg_old, t)
		else:
			_dmg_t0 = t
			_embers_total = ember_count(amount)
			_embers_left = _embers_total
			_punch(PUNCH_DMG, t)
			_shake(t)
		_tint = Color(UIStyle.BAD, 1.0)
		_tint_t0 = -INF if reduced else t
		damaged.emit(amount)
		if amount >= BIG_HIT:
			big_hit.emit(amount)
	else:
		var amount := v - old
		_dmg_t0 = -INF
		_heal_from = minf(level, float(v))
		_heal_to = float(v)
		if reduced:
			_heal_t0 = -INF
			_start_fade("heal", _heal_from, _heal_to, t)
		else:
			_heal_t0 = t
			_punch(PUNCH_HEAL, t)
			_spawn_sparkles(amount)
		_tint = Color(UIStyle.GOOD, 1.0)
		_tint_t0 = -INF if reduced else t
		healed.emit(amount)
	_settled_level = float(v)
	_update_low(false)
	_wake()
	_refresh()


## Sets the value and the scale together (`snap` as in set_hp).
func set_value(v: int, p_max: int, snap: bool = false) -> void:
	max_hp = p_max
	if snap:
		_max_t0 = -INF   # no stretch
	set_hp(v, snap)


## Animated damage of `amount` HP.
func damage(amount: int) -> void:
	set_hp(hp - maxi(0, amount))


## Animated heal of `amount` HP.
func heal(amount: int) -> void:
	set_hp(hp + maxi(0, amount))


## Lethal blow: the glass cracks (150 ms), the liquid drains to 0 and 8-12 shards fall. Under
## reduce motion the vial just empties with a static crack.
func shatter() -> void:
	var t := _now()
	_shatter_from = liquid_level(t)
	hp = 0
	_settled_level = 0.0
	_clear_events()
	_num_from = shown_number(t)
	_num_t0 = t
	_shatter_t0 = t
	if not UIStyle.reduce_motion:
		_shake(t)
		var n := 8 + rng.randi_range(0, 4)
		for i in n:
			var p := Particle.new()
			p.kind = "shard"
			var r := _well_rect()
			p.pos = Vector2(r.position.x + rng.randf() * r.size.x, r.position.y + rng.randf() * r.size.y)
			p.vel = Vector2(rng.randf_range(-30, 30), rng.randf_range(-40, -10))
			p.life = UIStyle.dur(SHARD_LIFE) * rng.randf_range(0.8, 1.1)
			p.size = rng.randf_range(2.5, 5.0)
			p.spin = rng.randf_range(-9, 9)
			p.angle = rng.randf() * TAU
			p.col = Color(1, 0.92, 0.88, 0.85)
			_add_particle(p, true)
	_update_low(false)
	_wake()
	_refresh()


## True while HP is at or under 25% of the scale.
func low() -> bool:
	return _low


## True while HP is at or under 10% of the scale.
func critical() -> bool:
	return _has_value and is_critical(hp, max_hp)


## The scale currently drawn (tweens towards max_hp after a change).
func shown_max(t: float = NAN) -> float:
	if is_nan(t):
		t = _now()
	if _max_t0 == -INF:
		return float(max_hp)
	var k := quart_out(t - _max_t0, UIStyle.dur(MAX_STRETCH_T))
	return lerpf(_max_from, float(max_hp), k)


## The liquid level (HP) drawn at clock time `t`.
func liquid_level(t: float = NAN) -> float:
	if is_nan(t):
		t = _now()
	if _shatter_t0 != -INF:
		var k := clampf((t - _shatter_t0 - UIStyle.dur(SHATTER_CRACK)) / UIStyle.dur(SHATTER_DRAIN), 0.0, 1.0)
		return lerpf(_shatter_from, 0.0, k * k)
	if _dmg_t0 != -INF:
		var k := clampf((t - _dmg_t0) / UIStyle.dur(DMG_DROP), 0.0, 1.0)
		return lerpf(_dmg_old, _dmg_new, k)
	if _heal_t0 != -INF:
		return lerpf(_heal_from, _heal_to, quart_out(t - _heal_t0, UIStyle.dur(HEAL_POUR)))
	return _settled_level


## The top of the amber damage trail (HP) at `t`; equal to the liquid level when there is none.
func trail_top_at(t: float = NAN) -> float:
	if is_nan(t):
		t = _now()
	if _dmg_t0 == -INF:
		return liquid_level(t)
	return trail_top(t - _dmg_t0, _dmg_old, _dmg_new, UIStyle.dur(DMG_FLASH + DMG_HOLD), UIStyle.dur(DMG_DRAIN))


## The number shown at `t` (counts to hp over COUNT_T, QUART OUT).
func shown_number(t: float = NAN) -> float:
	if is_nan(t):
		t = _now()
	if _num_t0 == -INF:
		return float(hp)
	return lerpf(_num_from, float(hp), quart_out(t - _num_t0, UIStyle.dur(COUNT_T)))


## True while a timed animation is still running at `t`.
func animating(t: float = NAN) -> bool:
	if is_nan(t):
		t = _now()
	var busy := false
	if _dmg_t0 != -INF:
		busy = busy or t - _dmg_t0 < UIStyle.dur(DMG_FLASH + DMG_HOLD + DMG_DRAIN)
	if _heal_t0 != -INF:
		busy = busy or t - _heal_t0 < UIStyle.dur(maxf(HEAL_POUR + HEAL_GLOW_FADE, HEAL_SHIMMER))
	if _num_t0 != -INF:
		busy = busy or t - _num_t0 < UIStyle.dur(COUNT_T)
	if _tint_t0 != -INF:
		busy = busy or t - _tint_t0 < UIStyle.dur(TINT_T)
	if _punch_t0 != -INF:
		busy = busy or t - _punch_t0 < UIStyle.dur(PUNCH_T)
	if _shake_t0 != -INF:
		busy = busy or t - _shake_t0 < UIStyle.dur(SHAKE_T)
	if _max_t0 != -INF:
		busy = busy or t - _max_t0 < UIStyle.dur(MAX_STRETCH_T)
	if _fade_t0 != -INF:
		busy = busy or t - _fade_t0 < UIStyle.dur(REDUCED_FADE)
	if _shatter_t0 != -INF:
		busy = busy or t - _shatter_t0 < UIStyle.dur(SHATTER_CRACK + SHATTER_DRAIN)
	return busy or not _parts.is_empty()


## Dev / screenshots: freezes the shader's clock (drift, glint, low-HP pulse) at `t` s; -1 resumes.
func freeze_shader_time(t: float) -> void:
	_mat.set_shader_parameter("frozen_time", t)
	_mat.set_shader_parameter("time_offset", 0.0 if t >= 0.0 else float(get_instance_id() % 997) * 0.37)


## Live particles (dev / tests).
func particle_count() -> int:
	return _parts.size()


## Advances the animation to the clock's current time (called every frame while active; tests and
## the gallery call it after moving a fake clock).
func step() -> void:
	var t := _now()
	var dt := 0.0 if _last_t < 0.0 else clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	_step_particles(t, dt)
	_step_low(t, dt)
	_step_shake(t)
	if not animating(t):
		_finish_events()
	_refresh()
	if not animating(t) and not _needs_loop():
		set_process(false)
		_last_t = -1.0


# ---------------------------------------------------------------- internals

func _now() -> float:
	return float(clock.call())


func _animating_allowed() -> bool:
	return is_inside_tree() and not UIStyle.reduce_motion and _has_value


func _wake() -> void:
	if is_inside_tree():
		set_process(true)


func _process(_d: float) -> void:
	step()


func _needs_loop() -> bool:
	# Low state keeps ticking for the heartbeat schedule; critical spawns motes.
	return _low and (is_local and my_turn or (critical() and not UIStyle.reduce_motion))


func _clear_events() -> void:
	_dmg_t0 = -INF
	_heal_t0 = -INF
	_num_t0 = -INF
	_punch_t0 = -INF
	_tint_t0 = -INF
	_fade_t0 = -INF
	_shatter_t0 = -INF
	_embers_left = 0


func _finish_events() -> void:
	_dmg_t0 = -INF
	_heal_t0 = -INF
	_fade_t0 = -INF
	_max_t0 = -INF


func _start_fade(kind: String, a: float, b: float, t: float) -> void:
	_fade_kind = kind
	_fade_a = a
	_fade_b = b
	_fade_t0 = t


func _punch(scale: float, t: float) -> void:
	_punch_scale = scale
	_punch_t0 = t


func _shake(t: float) -> void:
	if UIStyle.reduce_motion:
		return
	if _shake_t0 == -INF or t - _shake_t0 >= UIStyle.dur(SHAKE_T):
		_shake_base = Vector2.ZERO
		if shake_target != null and is_instance_valid(shake_target):
			_shake_target_base = shake_target.position
	_shake_t0 = t


func _step_shake(t: float) -> void:
	if _shake_t0 == -INF:
		return
	var e := t - _shake_t0
	var d := UIStyle.dur(SHAKE_T)
	var off := Vector2.ZERO
	if e < d:
		var decay := 1.0 - e / d
		off = Vector2(sin(e * 95.0), cos(e * 71.0) * 0.5) * SHAKE_PX * decay * decay
	else:
		_shake_t0 = -INF
	# A shake target that contains the vial already carries it: the vial's own layers stay put then,
	# so the glass never moves twice as far as its plate.
	var carried := shake_target != null and is_instance_valid(shake_target) and shake_target.is_ancestor_of(self)
	_body.position = Vector2.ZERO if carried else off
	_over.position = Vector2.ZERO if carried else off
	if shake_target != null and is_instance_valid(shake_target):
		shake_target.position = _shake_target_base + off


func _update_low(snap: bool) -> void:
	var now_low := _has_value and is_low(hp, max_hp)
	if now_low == _low:
		return
	_low = now_low
	_low_t0 = -INF if snap else _now()
	low_hp_changed.emit(_low)
	if _low:
		_beat()
		_next_beat = _now() + HEARTBEAT_PERIOD
	else:
		_next_beat = INF
	_wake()


func _beat() -> void:
	if not is_local:
		return
	heartbeat.emit()
	Sfx.play(HEARTBEAT_SFX, HEARTBEAT_DB, 0.0)


func _step_low(t: float, dt: float) -> void:
	if not _low:
		return
	if t >= _next_beat:
		if is_local and my_turn:
			_beat()
		_next_beat = t + HEARTBEAT_PERIOD
	if critical() and not UIStyle.reduce_motion and dt > 0.0:
		_mote_acc += dt * MOTE_RATE
		while _mote_acc >= 1.0:
			_mote_acc -= 1.0
			var r := _well_rect()
			var lvl := fraction(liquid_level(t), shown_max(t))
			var p := Particle.new()
			p.kind = "mote"
			p.pos = Vector2(r.position.x + rng.randf() * maxf(4.0, r.size.x * lvl), r.position.y + r.size.y * rng.randf_range(0.2, 0.8))
			p.vel = Vector2(rng.randf_range(-3, 3), -rng.randf_range(10, 16))
			p.life = MOTE_LIFE
			p.size = rng.randf_range(1.2, 2.0)
			p.col = Color("ff8a4a")
			_add_particle(p)


func _spawn_sparkles(amount: int) -> void:
	var r := _well_rect()
	var m := shown_max()
	var x0 := r.position.x + r.size.x * fraction(_heal_from, m)
	var x1 := r.position.x + r.size.x * fraction(_heal_to, m)
	for i in sparkle_count(amount):
		var p := Particle.new()
		p.kind = "sparkle"
		p.pos = Vector2(lerpf(x0, maxf(x1, x0 + 8.0), rng.randf()), r.position.y + rng.randf_range(2, r.size.y - 2))
		p.vel = Vector2(rng.randf_range(-4, 4), -rng.randf_range(22, 34))
		p.life = UIStyle.dur(SPARKLE_LIFE) * rng.randf_range(0.8, 1.0)
		p.age = -rng.randf_range(0.0, 0.12)
		p.size = rng.randf_range(2.0, 3.4)
		p.col = Color("cfffb8") if i % 2 == 0 else UIStyle.GOLD_HI
		_add_particle(p)


func _add_particle(p: Particle, force: bool = false) -> void:
	p.origin = p.pos
	p.born = _now() - p.age
	p.age = minf(p.age, 0.0)
	if _parts.size() >= MAX_PARTICLES:
		if not force:
			return
		_parts.remove_at(0)
	_parts.append(p)


func _step_particles(t: float, _dt: float) -> void:
	# Embers leave the draining edge of the trail.
	if _dmg_t0 != -INF and _embers_left > 0:
		var hold_end := UIStyle.dur(DMG_FLASH + DMG_HOLD)
		var e := t - _dmg_t0 - hold_end
		var due := 0 if e < 0.0 else clampi(int(ceil(e / UIStyle.dur(DMG_DRAIN) * float(_embers_total))), 1, _embers_total)
		while _embers_total - _embers_left < due:
			# Each ember is born at its own moment of the drain, at the trail edge of that moment;
			# one already past its life (a late step) is skipped.
			var k := _embers_total - _embers_left
			_embers_left -= 1
			var born := _dmg_t0 + hold_end + UIStyle.dur(DMG_DRAIN) * float(k) / float(_embers_total)
			if t - born >= UIStyle.dur(EMBER_LIFE):
				continue
			var r := _well_rect()
			var x := r.position.x + r.size.x * fraction(trail_top_at(born), shown_max(born))
			var p := Particle.new()
			p.kind = "ember"
			p.pos = Vector2(x + rng.randf_range(-3, 3), r.position.y + rng.randf_range(r.size.y * 0.3, r.size.y * 0.9))
			p.vel = Vector2(rng.randf_range(-6, 6), EMBER_FALL / EMBER_LIFE)
			p.life = UIStyle.dur(EMBER_LIFE)
			p.size = rng.randf_range(1.4, 2.4)
			p.col = Color("ffb08a") if rng.randf() < 0.5 else Color("ff7a3a")
			p.age = t - born
			_add_particle(p)
	# Motion is a function of age (not integrated per frame), so any clock jump lands exactly.
	var keep: Array[Particle] = []
	for p in _parts:
		p.age = t - p.born
		if p.age < 0.0:
			keep.append(p)
			continue
		var a := p.age
		match p.kind:
			"shard":
				p.pos = p.origin + p.vel * a + Vector2(0, 0.5 * SHARD_GRAVITY * a * a)
			"sparkle":
				# Velocity decays to SPARKLE_DRAG of itself per second: distance = v (1 - d^a) / -ln d.
				p.pos = p.origin + p.vel * (1.0 - pow(SPARKLE_DRAG, a)) / -log(SPARKLE_DRAG)
			_:
				p.pos = p.origin + p.vel * a
		if p.age < p.life:
			keep.append(p)
	_parts = keep


func _well_rect() -> Rect2:
	return Rect2(Vector2(5, 5), size - Vector2(10, 10))


func _on_resized() -> void:
	if _body == null:
		return
	_body.size = size
	_over.size = size
	_mat.set_shader_parameter("vial_size", size)
	_refresh()


func _over_redraw() -> void:
	if _over != null:
		_over.queue_redraw()


## Pushes the current frame's state to the shader and redraws the overlay.
func _refresh() -> void:
	if _body == null:
		return
	var t := _now()
	var m := shown_max(t)
	var lvl := liquid_level(t)
	_mat.set_shader_parameter("fill", fraction(lvl, m))
	_mat.set_shader_parameter("tick_step", float(TICK_HP) / maxf(1.0, m))
	_mat.set_shader_parameter("motion", 0.0 if UIStyle.reduce_motion else 1.0)
	var low_k := 1.0 if _low else 0.0
	if _low and _low_t0 != -INF and not UIStyle.reduce_motion:
		low_k = clampf((t - _low_t0) / 0.3, 0.0, 1.0)
	_mat.set_shader_parameter("low_hp", low_k)
	# Damage trail.
	var tr_a := 0.0
	var tr_from := 0.0
	var tr_to := 0.0
	var tr_flash := 0.0
	if _dmg_t0 != -INF:
		var e := t - _dmg_t0
		var top := trail_top(e, _dmg_old, _dmg_new, UIStyle.dur(DMG_FLASH + DMG_HOLD), UIStyle.dur(DMG_DRAIN))
		tr_from = fraction(_dmg_new, m)
		tr_to = fraction(top, m)
		tr_a = 1.0 if top > _dmg_new + 0.01 else 0.0
		tr_flash = flash_at(e, UIStyle.dur(DMG_FLASH))
	elif _fade_t0 != -INF and _fade_kind == "trail":
		tr_from = fraction(_fade_a, m)
		tr_to = fraction(_fade_b, m)
		tr_a = 1.0 - clampf((t - _fade_t0) / UIStyle.dur(REDUCED_FADE), 0.0, 1.0)
	_mat.set_shader_parameter("trail_from", tr_from)
	_mat.set_shader_parameter("trail_to", tr_to)
	_mat.set_shader_parameter("trail_alpha", tr_a)
	_mat.set_shader_parameter("trail_flash", tr_flash)
	# Heal glow and shimmer.
	var hg := 0.0
	var h_from := 0.0
	var h_to := 0.0
	var shim := -10000.0
	if _heal_t0 != -INF:
		var e := t - _heal_t0
		h_from = fraction(_heal_from, m)
		h_to = fraction(_heal_to, m)
		var pour := UIStyle.dur(HEAL_POUR)
		hg = 1.0 if e < pour else 1.0 - clampf((e - pour) / UIStyle.dur(HEAL_GLOW_FADE), 0.0, 1.0)
		var sk := e / UIStyle.dur(HEAL_SHIMMER)
		if sk < 1.0:
			var ws := size.x - 10.0
			shim = lerpf(-14.0, ws * h_to + 14.0, sk)
	elif _fade_t0 != -INF and _fade_kind == "heal":
		h_from = fraction(_fade_a, m)
		h_to = fraction(_fade_b, m)
		hg = 1.0 - clampf((t - _fade_t0) / UIStyle.dur(REDUCED_FADE), 0.0, 1.0)
	_mat.set_shader_parameter("heal_from", h_from)
	_mat.set_shader_parameter("heal_to", h_to)
	_mat.set_shader_parameter("heal_glow", hg)
	_mat.set_shader_parameter("shimmer_x", shim)
	_over_redraw()


# ---------------------------------------------------------------- overlay drawing

func _draw_overlay(ci: Control) -> void:
	var t := _now()
	var r := Rect2(Vector2.ZERO, size)
	var well := _well_rect()
	if flash > 0.001:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, flash * 0.35)
		sb.set_corner_radius_all(5)
		ci.draw_style_box(sb, well)
	_draw_crack(ci, well, t)
	_draw_stud(ci, Vector2(1.0, r.size.y / 2.0))
	_draw_stud(ci, Vector2(r.size.x - 1.0, r.size.y / 2.0))
	_draw_number(ci, t)
	_draw_particles(ci)


## The faceted end-cap stud: a 6 px gold diamond with a dark rim and a white glint.
func _draw_stud(ci: Control, c: Vector2) -> void:
	var h := 4.6
	var w := 3.8
	var top := c + Vector2(0, -h)
	var right := c + Vector2(w, 0)
	var bottom := c + Vector2(0, h)
	var left := c + Vector2(-w, 0)
	var rim := PackedVector2Array([top + Vector2(0, -1), right + Vector2(1, 0), bottom + Vector2(0, 1), left + Vector2(-1, 0)])
	ci.draw_colored_polygon(rim, Color("1a1006"))
	ci.draw_colored_polygon(PackedVector2Array([top, right, c, left]), UIStyle.GOLD_HI)
	ci.draw_colored_polygon(PackedVector2Array([left, c, right, bottom]), UIStyle.BRONZE.lerp(UIStyle.GOLD, 0.45))
	ci.draw_colored_polygon(PackedVector2Array([top, c, left]), Color("fff1c4"))
	ci.draw_line(top + Vector2(-0.6, 1.2), top + Vector2(-1.6, 2.6), Color(1, 1, 1, 0.95), 1.0, true)


## Hairline crack across the glass in the low state (and while shattering).
func _draw_crack(ci: Control, well: Rect2, t: float) -> void:
	var a := 0.0
	if _low:
		a = 1.0 if _low_t0 == -INF or UIStyle.reduce_motion else clampf((t - _low_t0) / 0.3, 0.0, 1.0)
	if _shatter_t0 != -INF:
		a = maxf(a, clampf((t - _shatter_t0) / UIStyle.dur(SHATTER_CRACK), 0.0, 1.0) * 1.6)
	if a <= 0.0:
		return
	var o := well.position
	var s := well.size
	# A glass fracture: long straight facets from an impact point, with two shorter branches.
	var hit := o + Vector2(s.x * 0.62, s.y * 0.42)
	var main := PackedVector2Array([o + Vector2(s.x * 0.555, 0), o + Vector2(s.x * 0.585, s.y * 0.2), hit,
		o + Vector2(s.x * 0.655, s.y * 0.7), o + Vector2(s.x * 0.67, s.y)])
	var branch := PackedVector2Array([hit, o + Vector2(s.x * 0.69, s.y * 0.3), o + Vector2(s.x * 0.76, s.y * 0.26)])
	var branch2 := PackedVector2Array([hit, o + Vector2(s.x * 0.575, s.y * 0.62), o + Vector2(s.x * 0.545, s.y * 0.8)])
	var dark := Color(0, 0, 0, minf(1.0, 0.2 * a))
	var lite := Color(1, 1, 1, minf(1.0, 0.30 * a))
	for line in [main, branch, branch2]:
		var shifted := PackedVector2Array()
		for q in line:
			shifted.append(q + Vector2(0.8, 0.8))
		ci.draw_polyline(shifted, dark, 1.0, true)
		ci.draw_polyline(line, lite, 1.0, true)


func _draw_number(ci: Control, t: float) -> void:
	var font := UIStyle.font_display(700)
	var small := UIStyle.font_bold()
	var shown := shown_number(t)
	var txt := "%d" % roundi(shown)
	var tint_a := 0.0
	if _tint_t0 != -INF:
		tint_a = 1.0 - clampf((t - _tint_t0) / UIStyle.dur(TINT_T), 0.0, 1.0)
	var col := UIStyle.TEXT.lerp(Color(_tint, 1.0).lightened(0.2), tint_a * 0.9)
	var base_y := size.y / 2.0 + (font.get_ascent(NUMBER_SIZE) - font.get_descent(NUMBER_SIZE)) / 2.0 - 1.0
	var pos := Vector2(NUMBER_X, base_y)
	var sc := 1.0
	if _punch_t0 != -INF and not UIStyle.reduce_motion:
		var e := (t - _punch_t0) / UIStyle.dur(PUNCH_T)
		if e < 1.0:
			# Up fast, settle with a BACK OUT overshoot below 1 and back.
			var up := clampf(e / 0.3, 0.0, 1.0)
			var down := clampf((e - 0.3) / 0.7, 0.0, 1.0)
			var c1 := 1.70158
			var back := 1.0 + (c1 + 1.0) * pow(down - 1.0, 3.0) + c1 * pow(down - 1.0, 2.0)
			sc = lerpf(1.0, _punch_scale, up) if e < 0.3 else lerpf(_punch_scale, 1.0, back)
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE)
	var pivot := pos + Vector2(sz.x / 2.0, -font.get_ascent(NUMBER_SIZE) * 0.35)
	ci.draw_set_transform(pivot - pivot * sc, 0.0, Vector2(sc, sc))
	# Shadow (0 2 0 #000 80%), outline (2 px #2a0806), fill.
	ci.draw_string_outline(font, pos + Vector2(0, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, 4, Color(0, 0, 0, 0.8))
	ci.draw_string(font, pos + Vector2(0, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, Color(0, 0, 0, 0.8))
	ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, 4, Color("2a0806"))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hp_pos := Vector2(NUMBER_X + sz.x + 5.0, base_y - 1.0)
	ci.draw_string_outline(small, hp_pos, "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, 3, Color(0, 0, 0, 0.55))
	ci.draw_string(small, hp_pos, "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(UIStyle.TEXT, 0.7))
	if size.x >= SCALE_LABEL_MIN_W:
		var scale_txt := "/ %d" % max_hp
		var sw := small.get_string_size(scale_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
		var sp := Vector2(size.x - 12.0 - sw, base_y - 1.0)
		ci.draw_string_outline(small, sp, scale_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, 3, Color(0, 0, 0, 0.45))
		ci.draw_string(small, sp, scale_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(UIStyle.TEXT, 0.5))


func _draw_particles(ci: Control) -> void:
	for p in _parts:
		if p.age < 0.0:
			continue
		var k := clampf(p.age / maxf(p.life, 0.001), 0.0, 1.0)
		var fade := 1.0 - k
		match p.kind:
			"ember", "mote":
				ci.draw_circle(p.pos, p.size * 2.4, Color(p.col, 0.18 * fade), true, -1.0, true)
				ci.draw_circle(p.pos, p.size, Color(p.col.lightened(0.25), 0.95 * fade), true, -1.0, true)
			"sparkle":
				var s := p.size * (0.6 + 0.6 * sin(k * PI))
				var c := Color(p.col, fade)
				ci.draw_circle(p.pos, s * 1.6, Color(p.col, 0.16 * fade), true, -1.0, true)
				ci.draw_colored_polygon(PackedVector2Array([p.pos + Vector2(0, -s * 1.6), p.pos + Vector2(s * 0.35, 0),
					p.pos + Vector2(0, s * 1.6), p.pos + Vector2(-s * 0.35, 0)]), c)
				ci.draw_colored_polygon(PackedVector2Array([p.pos + Vector2(-s * 1.6, 0), p.pos + Vector2(0, -s * 0.35),
					p.pos + Vector2(s * 1.6, 0), p.pos + Vector2(0, s * 0.35)]), c)
			"shard":
				var pts := PackedVector2Array()
				var rot := p.angle + p.spin * p.age
				for j in 3:
					var a := rot + float(j) * TAU / 3.0 + (0.5 if j == 1 else 0.0)
					pts.append(p.pos + Vector2(cos(a), sin(a)) * p.size * (1.0 if j != 2 else 0.6))
				ci.draw_colored_polygon(pts, Color(p.col, p.col.a * fade))
				ci.draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(1, 1, 1, 0.9 * fade), 1.0, true)
