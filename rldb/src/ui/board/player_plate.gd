class_name PlayerPlate
extends PanelContainer
## Player info plate (match-board.md section 4): name with turn marker, HP bar with number,
## AP gems and pile chips. Pile chips for the local player are clickable (inspection only).

signal pile_pressed(zone: String)

const CHIP_ZONES := [["hand", "Hand"], ["draw", "Deck"], ["spent", "Spent"], ["exhaust", "Exh"], ["extra", "Extra"]]
const CHIP_TIPS := {"hand": "Hand", "draw": "Draw pile (Deck)", "spent": "Spent pile", "exhaust": "Exhaust pile", "extra": "Extra Deck"}


class HpBar extends Control:
	var hp: int = 0
	var max_hp: int = 60
	var flash: float = 0.0: set = _set_flash

	func _init() -> void:
		custom_minimum_size = Vector2(0, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _set_flash(v: float) -> void:
		flash = v
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := UIStyle.flat(Color("120c0b"), Color(UIStyle.BRONZE, 0.8), 1, 6)
		draw_style_box(sb, r)
		var frac := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
		var fill := r.grow(-2.0)
		fill.size.x *= frac
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
		var col := UIStyle.TEXT if frac > 0.25 else UIStyle.BAD
		var font := UIStyle.font_display(700)
		var fs := 22
		var txt := "%d" % hp
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(8, size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.7))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var small := UIStyle.font_bold()
		draw_string(small, Vector2(8 + sz.x + 5, pos.y - 1), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIStyle.TEXT, 0.7))


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

	func _init() -> void:
		custom_minimum_size = Vector2(0, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func capacity_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return maxi(0, maxi(p_ap, maxi(p_start, p_peak)))

	static func filled_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return clampi(p_ap, 0, capacity_for(p_ap, p_start, p_peak))

	static func spent_for(p_ap: int, p_start: int, p_peak: int) -> int:
		return capacity_for(p_ap, p_start, p_peak) - filled_for(p_ap, p_start, p_peak)

	func capacity() -> int:
		return capacity_for(ap, ap_start, ap_peak)

	func filled() -> int:
		return filled_for(ap, ap_start, ap_peak)

	func spent() -> int:
		return spent_for(ap, ap_start, ap_peak)

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
				draw_circle(c, rad, amber.darkened(0.65))
				draw_circle(c, rad * 0.8, amber)
				draw_circle(c + Vector2(-0.25, -0.3) * rad, rad * 0.32, Color(1, 1, 1, 0.35))
			else:
				# Spent: dark socket, thin outline and a crack so it never reads as "unfilled".
				draw_circle(c, rad, Color(0.07, 0.05, 0.04))
				draw_arc(c, rad - 0.5, 0.0, TAU, 20, Color(amber, 0.4), 1.2)
				if rad >= 4.5:
					draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.7) * rad, c + Vector2(0.15, -0.1) * rad,
						c + Vector2(-0.2, 0.25) * rad, c + Vector2(0.1, 0.75) * rad]), Color(amber, 0.55), 1.0)
			x += pitch
		var font := UIStyle.font_display(700)
		var txt := ap_text()
		var tp := Vector2(x + 8.0, size.y / 2.0 + 6)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0, 0, 0, 0.7))
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, amber)


class TurnMark extends Control:
	var on: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(14, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if on:
			draw_colored_polygon(PackedVector2Array([Vector2(2, 4), Vector2(12, 10), Vector2(2, 16)]), UIStyle.GOLD)


var name_label: Label
var next_label: Label
var hp_bar: HpBar
var ap_gems: ApGems
var turn_mark: TurnMark
var chips: Dictionary = {}
var _max_hp: int = 60
var _active: bool = false
var _tween: Tween


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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	for z in CHIP_ZONES:
		var b := UIStyle.button("%s 0" % z[1], 13)
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UIStyle.flat(UIStyle.PANEL_LIGHT, Color(UIStyle.BRONZE, 0.7), 1, 11))
		b.add_theme_stylebox_override("hover", UIStyle.flat(UIStyle.PANEL_LIGHT.lightened(0.1), UIStyle.GOLD, 1, 11))
		b.add_theme_stylebox_override("disabled", UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.7), Color(UIStyle.BRONZE, 0.6), 1, 11))
		for s in ["normal", "hover", "disabled"]:
			(b.get_theme_stylebox(s) as StyleBoxFlat).content_margin_left = 4
			(b.get_theme_stylebox(s) as StyleBoxFlat).content_margin_right = 4
			(b.get_theme_stylebox(s) as StyleBoxFlat).content_margin_top = 1
			(b.get_theme_stylebox(s) as StyleBoxFlat).content_margin_bottom = 1
		b.add_theme_color_override("font_disabled_color", UIStyle.TEXT)
		b.tooltip_text = CHIP_TIPS[z[0]]
		var zone: String = z[0]
		b.pressed.connect(func(): pile_pressed.emit(zone))
		row.add_child(b)
		chips[zone] = b


## Refreshes the plate from a player view. `mine` enables pile inspection.
func update_from(pv: Dictionary, active: bool, mine: bool, label_suffix: String, next_text: String) -> void:
	name_label.text = String(pv["name"]) + label_suffix
	name_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if active else UIStyle.TEXT)
	turn_mark.on = active
	turn_mark.queue_redraw()
	_max_hp = maxi(_max_hp, maxi(int(pv["hp"]), 60))
	hp_bar.hp = pv["hp"]
	hp_bar.max_hp = _max_hp
	hp_bar.queue_redraw()
	ap_gems.ap = int(pv["ap"])
	ap_gems.ap_start = int(pv.get("ap_start", ap_gems.ap))
	ap_gems.ap_peak = int(pv.get("ap_peak", ap_gems.ap))
	ap_gems.queue_redraw()
	next_label.text = next_text
	var counts: Dictionary = pv["counts"]
	for z in CHIP_ZONES:
		var b: Button = chips[z[0]]
		b.text = "%s %d" % [z[1], counts[z[0]]]
		var inspectable: bool = mine and z[0] != "hand"
		b.disabled = not inspectable
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if inspectable else Control.CURSOR_ARROW
		b.tooltip_text = CHIP_TIPS[z[0]] + ("" if mine else " (count only)")
	if active != _active:
		_active = active
		pulse()


func reset_hp_max() -> void:
	_max_hp = 60


## Brief highlight (turn change / damage).
func pulse() -> void:
	if UIStyle.reduce_motion:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hp_bar, "flash", 0.6, UIStyle.dur(0.08))
	_tween.tween_property(hp_bar, "flash", 0.0, UIStyle.dur(0.3))


func hp_anchor() -> Vector2:
	# Over the right end of the HP bar: never over the player name at the top-left of the plate.
	var r := hp_bar.get_global_rect()
	return Vector2(r.end.x - 56.0, r.get_center().y)


func ap_anchor() -> Vector2:
	return ap_gems.get_global_rect().get_center() + Vector2(60, 0)


func deck_anchor() -> Vector2:
	return (chips["draw"] as Control).get_global_rect().get_center()


func portrait_center() -> Vector2:
	return get_global_rect().get_center()
