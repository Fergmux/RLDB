class_name PlayerPlate
extends PanelContainer
## Player info plate (match-board.md section 4): name with turn marker, HP bar with number,
## AP gems and pile chips. Pile chips for the local player are clickable (inspection only).

## HP bar scale floor: the bar is never scaled to less than this maximum.
const DEFAULT_MAX_HP := 60


## Animated HP bar with the HP number.
class HpBar extends Control:
	## `hp` is the real value; `shown` is what is drawn and tweens towards it (number counts up/down).
	## Damage leaves a pale ghost segment that drains after a beat; healing shows the gained segment in
	## green that the fill grows into. `tint` flashes the number red (damage) or green (heal).
	var hp: int = 0
	var max_hp: int = DEFAULT_MAX_HP
	var flash: float = 0.0: set = _set_flash
	var shown: float = 0.0: set = _set_shown
	var ghost: float = 0.0: set = _set_ghost
	var tint: Color = Color(1, 1, 1, 0): set = _set_tint
	var _tw: Tween
	var _heal: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _set_flash(v: float) -> void:
		flash = v
		queue_redraw()

	func _set_shown(v: float) -> void:
		shown = v
		queue_redraw()

	func _set_ghost(v: float) -> void:
		ghost = v
		queue_redraw()

	func _set_tint(v: Color) -> void:
		tint = v
		queue_redraw()

	## Sets the real HP and animates the bar and number to it (~0.4 s). `snap` = no animation
	## (first update, a different player on this plate, reduce motion, not in the tree).
	func set_hp(v: int, snap: bool = false) -> void:
		var old := shown
		hp = v
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if snap or not is_inside_tree() or UIStyle.reduce_motion or is_equal_approx(old, float(v)):
			shown = float(v)
			ghost = float(v)
			tint = Color(1, 1, 1, 0)
			return
		var dmg := float(v) < old
		_heal = not dmg
		var col := Color("ff5a48") if dmg else UIStyle.GOOD
		tint = Color(col, 1.0)
		ghost = maxf(ghost, old) if dmg else float(v)
		_tw = create_tween().set_parallel(true)
		_tw.tween_property(self, "shown", float(v), UIStyle.dur(0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "tint", Color(col, 0.0), UIStyle.dur(0.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if dmg:
			_tw.tween_property(self, "ghost", float(v), UIStyle.dur(0.35)).set_delay(UIStyle.dur(0.35)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	## Rounded segment of the bar `r` between HP values `a` and `b` (skipped when under half a pixel).
	func _seg(r: Rect2, a: float, b: float, col: Color) -> void:
		var m := float(maxi(1, max_hp))
		var x0 := r.position.x + r.size.x * clampf(minf(a, b) / m, 0.0, 1.0)
		var x1 := r.position.x + r.size.x * clampf(maxf(a, b) / m, 0.0, 1.0)
		if x1 - x0 < 0.5:
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(mini(5, int((x1 - r.position.x) / 2.0)))
		draw_style_box(sb, Rect2(x0, r.position.y, x1 - x0, r.size.y))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := UIStyle.flat(Color("120c0b"), Color(UIStyle.BRONZE, 0.8), 1, 6)
		draw_style_box(sb, r)
		var frac := clampf(shown / float(maxi(1, max_hp)), 0.0, 1.0)
		var fill := r.grow(-2.0)
		var inner := fill
		fill.size.x *= frac
		# Ghost segment: damage drains pale red behind the fill; a heal shows the gain in green ahead of it.
		if ghost > shown + 0.01:
			_seg(inner, shown, ghost, Color(UIStyle.GOOD, 0.55) if _heal else Color("ffb08a", 0.75))
		if fill.size.x > 1.0:
			var rad := mini(5, int(fill.size.x / 2.0))
			var fb := StyleBoxFlat.new()
			fb.bg_color = Color("a8372d") if frac > 0.25 else Color("d4412f")
			fb.set_corner_radius_all(rad)
			draw_style_box(fb, fill)
			var hi := StyleBoxFlat.new()
			hi.bg_color = Color(1, 1, 1, 0.12)
			hi.corner_radius_top_left = rad
			hi.corner_radius_top_right = rad
			draw_style_box(hi, Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.45)))
		if flash > 0.001:
			draw_style_box(UIStyle.flat(Color(1, 1, 1, flash * 0.5), Color.TRANSPARENT, 0, 6), r)
		if tint.a > 0.001:
			draw_style_box(UIStyle.flat(Color(tint, tint.a * 0.18), Color(tint, tint.a * 0.7), 1, 6), r)
		var col := UIStyle.TEXT if frac > 0.25 else UIStyle.BAD
		col = col.lerp(Color(tint, 1.0).lightened(0.25), tint.a * 0.85)
		var font := UIStyle.font_display(700)
		var fs := 22
		var txt := "%d" % roundi(shown)
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(8, size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.7))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var small := UIStyle.font_bold()
		draw_string(small, Vector2(8 + sz.x + 5, pos.y - 1), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIStyle.TEXT, 0.7))


## Row of AP gems and sockets with the "AP x/y" label.
class ApGems extends Control:
	## AP slot display policy (F02-06). The row shows the player's real AP capacity, not a fixed
	## number of sockets:
	##   capacity = max(ap_start, ap_peak, ap)  (never negative)
	## where ap_start is this turn's effective starting allowance (after reset / modifiers such as
	## Marked by the Abyss) and ap_peak the most AP held this turn. An ordinary 2-AP turn therefore
	## shows exactly 2 slots; AP gained above the allowance expands the row (no UI cap); spent AP
	## stays visible as a cracked, dark "spent" socket (capacity - ap) so usage reads at a glance.
	## Before the first turn (everything 0) no slots are drawn, only "AP 0". Above 10 slots the
	## gems shrink to stay inside the plate. The next turn recomputes from its own allowance.
	var ap: int = 0
	var ap_start: int = 0
	var ap_peak: int = 0

	const MAX_ROW_W := 190.0   # width budget for the gem row on a 300 px plate
	const GAIN_T := 0.32       # gem pop when AP is gained (s, before UIStyle.dur)
	const SPEND_T := 0.3       # gem dims and shrinks into its socket when spent
	const STAGGER := 0.06      # delay between gems changing in one update

	## Presentation only: per-gem animations, index -> seconds remaining (delay + duration), and the
	## AP number shown in the label, which counts towards `ap`.
	var _gain: Dictionary = {}
	var _spend: Dictionary = {}
	var _shown_ap: float = 0.0
	var _txt_pop: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_process(not _gain.is_empty() or not _spend.is_empty())

	## Sets the AP fields and animates the change: gained gems pop in, spent gems dim with a small
	## shrink, the "AP x/y" number counts. `snap` (or reduce motion / not in tree) = no animation.
	func set_values(p_ap: int, p_start: int, p_peak: int, snap: bool = false) -> void:
		var old_filled := filled()
		var old_ap := ap
		ap = p_ap
		ap_start = p_start
		ap_peak = p_peak
		var new_filled := filled()
		if snap or not is_inside_tree() or UIStyle.reduce_motion:
			_gain.clear()
			_spend.clear()
			_shown_ap = float(ap)
			_txt_pop = 0.0
			set_process(false)
			queue_redraw()
			return
		var k := 0
		for i in range(old_filled, new_filled):
			_spend.erase(i)
			_gain[i] = UIStyle.dur(GAIN_T + STAGGER * k)
			k += 1
		k = 0
		for i in range(old_filled - 1, new_filled - 1, -1):
			_gain.erase(i)
			_spend[i] = UIStyle.dur(SPEND_T + STAGGER * k)
			k += 1
		if ap != old_ap:
			_txt_pop = 1.0
		set_process(true)
		queue_redraw()

	func _process(d: float) -> void:
		for dict in [_gain, _spend]:
			for i in dict.keys():
				dict[i] -= d
				if dict[i] <= 0.0:
					dict.erase(i)
		var step := d * maxf(6.0, absf(float(ap) - _shown_ap) * 4.0) / UIStyle.dur(1.0)
		_shown_ap = move_toward(_shown_ap, float(ap), step)
		_txt_pop = maxf(0.0, _txt_pop - d / UIStyle.dur(0.3))
		if _gain.is_empty() and _spend.is_empty() and is_equal_approx(_shown_ap, float(ap)) and _txt_pop <= 0.0:
			set_process(false)
		queue_redraw()

	## 0 -> 1 progress of a gem animation (0 while still waiting for its stagger delay).
	func _prog(rem: float, total: float) -> float:
		return clampf(1.0 - rem / UIStyle.dur(total), 0.0, 1.0)

	## Slots shown: max(ap_start, ap_peak, ap), never negative.
	static func capacity_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return maxi(0, maxi(p_ap, maxi(p_start, p_peak)))

	## Filled (unspent) slots: ap clamped to the capacity.
	static func filled_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return clampi(p_ap, 0, capacity_for(p_ap, p_start, p_peak))

	## Spent (cracked socket) slots: capacity - filled.
	static func spent_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return capacity_for(p_ap, p_start, p_peak) - filled_for(p_ap, p_start, p_peak)

	## capacity_for() of the current values.
	func capacity() -> int:
		return capacity_for(ap, ap_start, ap_peak)

	## filled_for() of the current values.
	func filled() -> int:
		return filled_for(ap, ap_start, ap_peak)

	## Label text: "AP 1/2" (or just "AP 0" when there are no slots yet).
	func ap_text() -> String:
		return "AP %d/%d" % [ap, capacity()] if capacity() > 0 else "AP %d" % ap

	func _draw() -> void:
		var amber: Color = UIStyle.COST_COLORS["ap"]
		var cap := capacity()
		var n := filled()
		var pitch := clampf(MAX_ROW_W / float(maxi(cap, 1)), 4.0, 20.0)
		var rad := minf(8.0, pitch * 0.42)
		var x := 10.0
		for i in cap:
			var c := Vector2(x + pitch / 2.0, size.y / 2.0)
			if i < n:
				var g := _prog(_gain[i], GAIN_T) if _gain.has(i) else 1.0
				if g < 1.0:
					_socket(c, rad, amber)
				if g > 0.0:
					# Pop: overshoots to ~1.35x, then settles; a bright ring expands and fades.
					var sc := 1.0 + 0.35 * sin(g * PI) if g < 1.0 else 1.0
					_gem(c, rad * sc * minf(1.0, g * 2.5), amber, minf(1.0, g * 3.0))
					if g < 1.0:
						draw_arc(c, rad * (1.0 + 0.9 * g), 0.0, TAU, 24, Color(UIStyle.GOLD_HI, 0.8 * (1.0 - g)), 1.6, true)
			else:
				_socket(c, rad, amber)
				if _spend.has(i):
					# Spent this update: the gem dims and shrinks into the socket.
					var k := _prog(_spend[i], SPEND_T)
					_gem(c, rad * lerpf(1.0, 0.45, k), amber.lerp(amber.darkened(0.6), k), 1.0 - k)
			x += pitch
		var font := UIStyle.font_display(700)
		var shown := roundi(_shown_ap)
		var txt := "AP %d/%d" % [shown, cap] if cap > 0 else "AP %d" % shown
		var fs := 16
		var tp := Vector2(x + 8.0, size.y / 2.0 + 6)
		if _txt_pop > 0.0:
			var sc2 := 1.0 + 0.18 * sin(_txt_pop * PI)
			draw_set_transform(tp, 0.0, Vector2(sc2, sc2))
			tp = Vector2.ZERO
		var tcol := amber.lerp(UIStyle.GOLD_HI.lightened(0.3), _txt_pop * 0.8)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.7))
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## One AP gem of radius `r` at alpha `a` (skipped when invisible).
	func _gem(c: Vector2, r: float, amber: Color, a: float) -> void:
		if r <= 0.2 or a <= 0.0:
			return
		draw_circle(c, r, Color(amber.darkened(0.65), a), true, -1.0, true)
		draw_circle(c, r * 0.8, Color(amber, a), true, -1.0, true)
		draw_circle(c + Vector2(-0.25, -0.3) * r, r * 0.32, Color(1, 1, 1, 0.35 * a), true, -1.0, true)

	## Spent: dark socket, thin outline and a crack so it never reads as "unfilled".
	func _socket(c: Vector2, rad: float, amber: Color) -> void:
		draw_circle(c, rad, Color(0.07, 0.05, 0.04), true, -1.0, true)
		draw_arc(c, rad - 0.5, 0.0, TAU, 20, Color(amber, 0.4), 1.2, true)
		if rad >= 4.5:
			draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.7) * rad, c + Vector2(0.15, -0.1) * rad,
				c + Vector2(-0.2, 0.25) * rad, c + Vector2(0.1, 0.75) * rad]), Color(amber, 0.55), 1.0, true)


## Gold triangle shown beside the name of the player whose turn it is.
class TurnMark extends Control:
	var on: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(14, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if on:
			draw_colored_polygon(PackedVector2Array([Vector2(2, 4), Vector2(12, 10), Vector2(2, 16)]), UIStyle.GOLD)
			draw_polyline(PackedVector2Array([Vector2(2, 4), Vector2(12, 10), Vector2(2, 16), Vector2(2, 4)]), UIStyle.GOLD, 1.0, true)


var name_label: Label
var next_label: Label
var hp_bar: HpBar
var ap_gems: ApGems
var turn_mark: TurnMark
var _max_hp: int = DEFAULT_MAX_HP
var _active: bool = false
var _tween: Tween
## Player shown on this plate at the last update; a different one (seat switch) snaps instead of animating.
var _who: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(300, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIStyle.panel_style(Color(UIStyle.PANEL, 0.94), UIStyle.BRONZE, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	v.add_child(head)
	turn_mark = TurnMark.new()
	head.add_child(turn_mark)
	name_label = UIStyle.label("", 20, UIStyle.TEXT, false, true)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	next_label = UIStyle.label("", 13, UIStyle.MUTED)
	head.add_child(next_label)
	hp_bar = HpBar.new()
	v.add_child(hp_bar)
	ap_gems = ApGems.new()
	v.add_child(ap_gems)


## Refreshes the plate from a player view. `mine` enables pile inspection.
func update_from(pv: Dictionary, active: bool, mine: bool, label_suffix: String, next_text: String) -> void:
	name_label.text = String(pv["name"]) + label_suffix
	name_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if active else UIStyle.TEXT)
	turn_mark.on = active
	turn_mark.queue_redraw()
	# HP and AP animate from the previous values (HpBar.set_hp / ApGems.set_values); a different
	# player on this plate (hot-seat seat switch, new match) snaps instead.
	var who := String(pv["name"])
	var snap := who != _who
	_who = who
	_max_hp = maxi(_max_hp, maxi(int(pv["hp"]), DEFAULT_MAX_HP))
	hp_bar.max_hp = _max_hp
	hp_bar.set_hp(int(pv["hp"]), snap)
	hp_bar.queue_redraw()
	var ap := int(pv["ap"])
	ap_gems.set_values(ap, int(pv.get("ap_start", ap)), int(pv.get("ap_peak", ap)), snap)
	next_label.text = next_text
	if active != _active:
		_active = active
		pulse()


## Resets the HP bar scale to the default (new match).
func reset_hp_max() -> void:
	_max_hp = DEFAULT_MAX_HP


## Brief highlight (turn change / damage).
func pulse() -> void:
	if UIStyle.reduce_motion:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hp_bar, "flash", 0.6, UIStyle.dur(0.08))
	_tween.tween_property(hp_bar, "flash", 0.0, UIStyle.dur(0.3))


## Global point for HP change popups: over the right end of the HP bar, never over the player
## name at the top-left of the plate.
func hp_anchor() -> Vector2:
	var r := hp_bar.get_global_rect()
	return Vector2(r.end.x - 56.0, r.get_center().y)


## Global point for AP change popups (right of the gem row's centre).
func ap_anchor() -> Vector2:
	return ap_gems.get_global_rect().get_center() + Vector2(60, 0)
