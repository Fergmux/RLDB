class_name GameScreen
extends Control
## Match UI for one seat (design/ux/match-board.md). Renders the redacted series view from a
## SeatClient and sends commands; it never computes rules itself. All legality, costs,
## damage and statuses come from the authority's view. Effects (FxPlayer) are presentation
## only: the board is always rendered in its final state first.

signal back_to_menu

const SIDEBAR_W := 360.0
const TOP_H := 44.0
const HAND_H := 190.0
const U := 128.0
const G := 8.0
const MID := 16.0
const PW := 85.0
const TH := 85.0
const PGAP := 24.0
const BOARD_H := 730.0
const HAND_SCALE := 1.25
const FIELD_SCALE := 1.08
const MAX_FX_ENTRIES := 25
const ZONE_KEY := {"unit": "units", "backrow": "backrow", "power": "powers"}
const ZONE_KIND := {"unit": "board", "backrow": "trap", "power": "power"}
const PHASE_ORDER := [["main1", "Main 1"], ["battle", "Battle"], ["main2", "Main 2"], ["end", "End"]]

var client: SeatClient
var view: Dictionary = {}
var mv: Dictionary = {}          # match view (may be the finished game between games)
var prev_mv: Dictionary = {}
var selected_uid: int = -1       # pinned in the details panel
var multi: Array = []            # selected option indices for a multi-select prompt
var fx: FxPlayer
var fx_layer: Control
var banner_layer: Control

var _log_seq_shown: int = 0
var _log_game: int = -1
var _fx_seq: int = -1
var _fx_game: int = -99
var _draws_me: int = 0
var _overlay_hidden_by_user: bool = false
var _last_stage: String = ""
var _error_text: String = ""
var _laid_size: Vector2 = Vector2.ZERO
var _area: Rect2 = Rect2()
var _y0: float = 0.0
var _ux: float = 0.0
var _peek_uid: int = -1

# Layers / nodes
var table: ColorRect
var deco: BoardDeco
var board_layer: Control
var hand_layer: Control
var hover_layer: Control
var side_root: Control
var top_strip: Control
var pause_dim: Control
var pause_panel: PanelContainer
var pause_box: VBoxContainer
var turn_title: Label
var turn_note: Label
var pips: PhasePips
var phase_btn: Button
var concede_btn: Button
var details_box: VBoxContainer
var prompt_panel: PanelContainer
var prompt_box: VBoxContainer
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_box: VBoxContainer
var pile_popup: PanelContainer
var pile_box: VBoxContainer
var settings_popup: PanelContainer
var toast: Label
var seat_label: Label
var conn_label: Label
var empty_hand_label: Label
var opp_hand_box: Control
var opp_hand_n: int = -1
var opp_hand_count_label: Label

var _plates: Array = []            # [top plate, bottom plate]
var _slots: Dictionary = {}        # "side:zone:slot" -> {holder, widget, hash, pidx}
var _hand_items: Dictionary = {}   # uid -> {holder, widget, hash}
var _hand_order: Array = []
var _gone_hand: Dictionary = {}    # uid -> global centre of a hand card removed by the last render
var _prompt_tween: Tween
var _prompt_style: StyleBoxFlat

# Hover state
var _hv: Dictionary = {}
var _hv_forced: bool = false
var _close_at: float = -1.0
var _peek_at: float = -1.0
var _stack: Control
var _stack_sig: String = ""


## Table decoration: centre line with ornament and the active player's underglow.
class BoardDeco extends Control:
	var mid_y: float = 0.0
	var x0: float = 0.0
	var x1: float = 0.0
	var glow_side: int = -1
	var top_edge: float = 0.0
	var bottom_edge: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_line(Vector2(x0, mid_y), Vector2(x1, mid_y), Color(UIStyle.TABLE_INLAY.lightened(0.15), 0.9), 2.0)
		var c := Vector2((x0 + x1) / 2.0, mid_y)
		var pts := PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)])
		draw_colored_polygon(pts, Color(UIStyle.GOLD, 0.85))
		pts.append(pts[0])
		draw_polyline(pts, Color(UIStyle.GOLD_HI, 0.9), 1.0)
		if glow_side >= 0:
			var y := top_edge if glow_side == 0 else bottom_edge
			var dir := -1.0 if glow_side == 0 else 1.0
			var gc := Color(UIStyle.GOLD, 0.0)
			var gs := Color(UIStyle.GOLD, 0.28)
			draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + dir * 16.0), Vector2(x0, y + dir * 16.0)]), PackedColorArray([gs, gs, gc, gc]))
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(UIStyle.GOLD, 0.9), 2.0)


## Phase pips for the turn bar.
class PhasePips extends Control:
	var phase: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := GameScreen.PHASE_ORDER.size()
		var w := (size.x - 6.0 * (n - 1)) / n
		var font := UIStyle.font_bold()
		for i in n:
			var r := Rect2(i * (w + 6.0), 0, w, size.y)
			var on: bool = GameScreen.PHASE_ORDER[i][0] == phase
			var sb := UIStyle.flat(UIStyle.GOLD if on else UIStyle.PANEL_INK, UIStyle.GOLD_HI if on else Color(UIStyle.BRONZE, 0.6), 1, 10)
			draw_style_box(sb, r)
			var txt: String = GameScreen.PHASE_ORDER[i][1]
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(font, Vector2(r.position.x + (w - sz.x) / 2.0, size.y / 2.0 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.ON_GOLD if on else UIStyle.MUTED)


func _ready() -> void:
	UIStyle.load_settings()
	theme = UIStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_table()
	_build_board()
	_build_hand_layer()
	_build_side()
	_build_top_strip()
	hover_layer = _passive_layer()
	hover_layer.z_index = 100
	fx_layer = _passive_layer()
	fx_layer.z_index = 60
	_build_pause()
	_build_overlays()
	banner_layer = _passive_layer()
	fx = FxPlayer.new()
	fx.screen = self
	add_child(fx)
	resized.connect(_relayout)
	_relayout()


func attach(c: SeatClient) -> void:
	if client != null and client.view_changed.is_connected(_on_view):
		client.view_changed.disconnect(_on_view)
		client.status_changed.disconnect(_on_status)
	client = c
	client.view_changed.connect(_on_view)
	client.status_changed.connect(_on_status)
	selected_uid = -1
	_peek_uid = -1
	multi = []
	_log_seq_shown = 0
	_log_game = -1
	_fx_seq = -1
	_fx_game = -99
	prev_mv = {}
	mv = {}
	fx.finish_all()
	_clear_hover()
	for uid in _hand_items.keys():
		(_hand_items[uid]["holder"] as Node).queue_free()
	_hand_items.clear()
	_hand_order.clear()
	opp_hand_n = -1
	log_label.clear()
	for pl in _plates:
		(pl as PlayerPlate).reset_hp_max()
	if not c.last_view.is_empty():
		_on_view(c.last_view)


func _passive_layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# ---------------------------------------------------------------- build

func _build_table() -> void:
	table = ColorRect.new()
	table.color = UIStyle.TABLE_WOOD
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/table.gdshader")
	table.material = mat
	add_child(table)


func _build_board() -> void:
	deco = BoardDeco.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(deco)
	board_layer = _passive_layer()
	for side in 2:
		for slot in 6:
			_make_slot(side, "unit", slot)
		for slot in 3:
			_make_slot(side, "backrow", slot)
		for slot in 4:
			_make_slot(side, "power", slot)
	for side in 2:
		var pl := PlayerPlate.new()
		board_layer.add_child(pl)
		var s := side
		pl.pile_pressed.connect(func(z): if s == 1: _show_pile(z))
		_plates.append(pl)
	opp_hand_box = Control.new()
	opp_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_layer.add_child(opp_hand_box)
	opp_hand_count_label = UIStyle.label("", 12, UIStyle.TEXT, false, true)
	board_layer.add_child(opp_hand_count_label)


func _make_slot(side: int, zone: String, slot: int) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := CardWidget.new()
	w.auto_hover = false
	w.show_tooltip = false
	var label := ""
	match zone:
		"unit": label = "%s %d" % ["Front" if slot < 3 else "Back", slot % 3 + 1]
		"backrow": label = "Trap / Spell %d" % (slot + 1)
		"power": label = "Power %d" % (slot + 1)
	w.setup(null, ZONE_KIND[zone], label)
	w.pressed.connect(_on_widget_pressed)
	w.right_pressed.connect(_on_widget_right)
	holder.add_child(w)
	board_layer.add_child(holder)
	_slots[_key(side, zone, slot)] = {"holder": holder, "widget": w, "hash": -1, "pidx": -1, "label": label}


func _key(side: int, zone: String, slot: int) -> String:
	return "%d:%s:%d" % [side, zone, slot]


func _build_hand_layer() -> void:
	hand_layer = _passive_layer()
	empty_hand_label = UIStyle.label("Your hand is empty.", 15, UIStyle.MUTED)
	empty_hand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_layer.add_child(empty_hand_label)


func _side_panel(color: Color = Color(UIStyle.PANEL, 0.96)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel_style(color))
	return p


func _header(text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIStyle.label(text, 15, UIStyle.GOLD, false, true))
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	return v


func _build_side() -> void:
	side_root = Control.new()
	side_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_root)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 4
	col.offset_right = -8
	col.offset_top = 8
	col.offset_bottom = -8
	col.add_theme_constant_override("separation", 8)
	side_root.add_child(col)
	# Turn bar
	var tp := _side_panel()
	col.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tp.add_child(tv)
	turn_title = UIStyle.label("", 18, UIStyle.TEXT, false, true)
	turn_title.clip_text = true
	tv.add_child(turn_title)
	pips = PhasePips.new()
	tv.add_child(pips)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	tv.add_child(brow)
	phase_btn = UIStyle.primary_button("", 16)
	phase_btn.custom_minimum_size = Vector2(0, 44)
	phase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_btn.pressed.connect(func(): _send({"t": "next_phase"}))
	brow.add_child(phase_btn)
	concede_btn = UIStyle.button("Concede", 12)
	concede_btn.custom_minimum_size = Vector2(76, 44)
	concede_btn.pressed.connect(_confirm_concede)
	brow.add_child(concede_btn)
	turn_note = UIStyle.label("", 12, Color("ff9ff3"), true)
	turn_note.visible = false
	tv.add_child(turn_note)
	# Prompt
	prompt_panel = _side_panel()
	_prompt_style = prompt_panel.get_theme_stylebox("panel") as StyleBoxFlat
	col.add_child(prompt_panel)
	prompt_box = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 4)
	prompt_panel.add_child(prompt_box)
	# Details
	var dp := _side_panel()
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dp.size_flags_stretch_ratio = 1.15
	col.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	dp.add_child(dv)
	dv.add_child(_header("Card details"))
	var ds := ScrollContainer.new()
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(ds)
	details_box = VBoxContainer.new()
	details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_box.add_theme_constant_override("separation", 4)
	ds.add_child(details_box)
	# Log
	var lp := _side_panel()
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 0.95
	col.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	lp.add_child(lv)
	lv.add_child(_header("Game log"))
	var lbg := PanelContainer.new()
	lbg.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(UIStyle.BRONZE, 0.4), 1, 6))
	lbg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lbg)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.selection_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 13)
	lbg.add_child(log_label)


func _build_top_strip() -> void:
	top_strip = Control.new()
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_strip)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	top_strip.add_child(row)
	seat_label = UIStyle.label("", 14, UIStyle.MUTED)
	seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(seat_label)
	conn_label = UIStyle.label("", 13, UIStyle.MUTED)
	conn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(conn_label)
	var gear := UIStyle.button("Settings", 12)
	gear.custom_minimum_size = Vector2(0, 28)
	gear.pressed.connect(func(): settings_popup.visible = not settings_popup.visible)
	row.add_child(gear)
	var menu_b := UIStyle.button("Menu", 12)
	menu_b.custom_minimum_size = Vector2(60, 28)
	menu_b.pressed.connect(func(): back_to_menu.emit())
	row.add_child(menu_b)


func _build_pause() -> void:
	pause_dim = ColorRect.new()
	(pause_dim as ColorRect).color = Color(0, 0, 0, 0.6)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_dim.visible = false
	add_child(pause_dim)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(UIStyle.PANEL, 0.98), UIStyle.GOLD))
	pause_panel.custom_minimum_size = Vector2(440, 0)
	pause_dim.add_child(pause_panel)
	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pause_box)


func _build_overlays() -> void:
	overlay = PanelContainer.new()
	overlay.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.06, 0.055, 0.05, 0.97), UIStyle.GOLD, 12))
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 20
	overlay.offset_right = -(SIDEBAR_W + 12.0)
	overlay.offset_top = 40
	overlay.offset_bottom = -40
	overlay.visible = false
	add_child(overlay)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(sc)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 8)
	sc.add_child(overlay_box)
	pile_popup = PanelContainer.new()
	pile_popup.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.07, 0.065, 0.06, 0.98), UIStyle.SELECT, 12))
	pile_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pile_popup.offset_left = 40
	pile_popup.offset_right = -(SIDEBAR_W + 40.0)
	pile_popup.offset_top = 70
	pile_popup.offset_bottom = -(HAND_H + 10.0)
	pile_popup.visible = false
	add_child(pile_popup)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile_popup.add_child(ps)
	pile_box = VBoxContainer.new()
	pile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_box.add_theme_constant_override("separation", 6)
	ps.add_child(pile_box)
	# Settings
	settings_popup = PanelContainer.new()
	settings_popup.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.07, 0.065, 0.06, 0.99), UIStyle.GOLD, 10))
	settings_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_popup.visible = false
	add_child(settings_popup)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	settings_popup.add_child(sv)
	sv.add_child(_header("Interface settings"))
	var rm := CheckBox.new()
	rm.text = "Reduced motion (no travel, shake or particles)"
	rm.button_pressed = UIStyle.reduce_motion
	rm.toggled.connect(func(on): UIStyle.set_reduce_motion(on); fx.finish_all(); _render_all())
	sv.add_child(rm)
	var fa := CheckBox.new()
	fa.text = "Fast animations (half duration)"
	fa.button_pressed = UIStyle.fast_anim
	fa.toggled.connect(func(on): UIStyle.set_fast_anim(on))
	sv.add_child(fa)
	var cl := UIStyle.button("Close", 13)
	cl.pressed.connect(func(): settings_popup.visible = false)
	sv.add_child(cl)
	toast = UIStyle.label("", 15, UIStyle.BAD, true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 4)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)


# ---------------------------------------------------------------- layout

func _slot_rect(side: int, zone: String, slot: int) -> Rect2:
	var col := slot % 3
	match zone:
		"unit":
			var front := slot < 3
			var ry := 0.0
			if side == 0:
				ry = 229.0 if front else 93.0
			else:
				ry = 373.0 if front else 509.0
			return Rect2(_ux + col * (U + G), _y0 + ry, U, U)
		"backrow":
			return Rect2(_ux + slot * (U + G), _y0 + (0.0 if side == 0 else 645.0), U, TH)
	var bx := _ux - PGAP - (2.0 * PW + G) if side == 0 else _ux + 3.0 * U + 2.0 * G + PGAP
	var by := _y0 + (93.0 if side == 0 else 373.0)
	return Rect2(bx + (slot % 2) * (PW + G), by + int(slot / 2) * (U + G), PW, U)


func _relayout() -> void:
	if size.x < 200.0 or size.y < 200.0:
		return
	_laid_size = size
	var w := size.x
	var h := size.y
	_area = Rect2(0, TOP_H, w - SIDEBAR_W, h - TOP_H - HAND_H)
	_y0 = _area.position.y + maxf(0.0, (_area.size.y - BOARD_H) / 2.0)
	_ux = _area.position.x + (_area.size.x - (3.0 * U + 2.0 * G)) / 2.0
	for key in _slots.keys():
		var parts: PackedStringArray = (key as String).split(":")
		var r := _slot_rect(int(parts[0]), parts[1], int(parts[2]))
		var it: Dictionary = _slots[key]
		(it["holder"] as Control).position = r.position
		(it["holder"] as Control).size = r.size
		(it["widget"] as Control).size = r.size
	var pw := 300.0
	(_plates[0] as Control).position = Vector2(_area.end.x - pw - 14.0, _y0 - 6.0)
	(_plates[0] as Control).size = Vector2(pw, 0)
	(_plates[1] as Control).position = Vector2(14.0, _y0 + BOARD_H - 112.0 + 6.0)
	(_plates[1] as Control).size = Vector2(pw, 0)
	opp_hand_box.position = Vector2(14.0, TOP_H + 8.0)
	opp_hand_count_label.position = Vector2(14.0, TOP_H + 8.0 + 92.0)
	deco.mid_y = _y0 + 365.0
	deco.x0 = _ux - 30.0
	deco.x1 = _ux + 3.0 * U + 2.0 * G + 30.0
	deco.top_edge = _y0 - 8.0
	deco.bottom_edge = _y0 + BOARD_H + 8.0
	deco.queue_redraw()
	side_root.position = Vector2(w - SIDEBAR_W, 0)
	side_root.size = Vector2(SIDEBAR_W, h)
	top_strip.position = Vector2.ZERO
	top_strip.size = Vector2(w - SIDEBAR_W, TOP_H)
	pause_dim.position = Vector2(0, TOP_H)
	pause_dim.size = Vector2(w - SIDEBAR_W, h - TOP_H)
	pause_panel.position = (pause_dim.size - Vector2(440, 160)) / 2.0
	settings_popup.position = Vector2(w - SIDEBAR_W - 400.0, TOP_H + 4.0)
	toast.position = Vector2(60, TOP_H + 4.0)
	toast.size = Vector2(_area.size.x - 120.0, 24)
	_layout_hand([], true)
	_place_opp_hand()


func _place_opp_hand() -> void:
	for ch in opp_hand_box.get_children():
		ch.queue_free()
	var n := maxi(opp_hand_n, 0)
	var shown := mini(n, 10)
	var step := 0.0
	if shown > 1:
		step = minf(40.0, (200.0 - 64.0) / float(shown - 1))
	for i in shown:
		var b := CardWidget.new().setup({"hidden": true, "zone": "hand"}, "back")
		b.show_tooltip = false
		b.auto_hover = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.position = Vector2(i * step, 0)
		opp_hand_box.add_child(b)
	opp_hand_count_label.text = "Opponent hand: %d" % n if n >= 0 else ""


func _layout_hand(new_ids: Array, instant: bool) -> void:
	var n := _hand_order.size()
	empty_hand_label.visible = n == 0 and not mv.is_empty()
	empty_hand_label.position = Vector2(_area.size.x / 2.0 - 70.0, size.y - HAND_H / 2.0 - 10.0)
	if n == 0:
		return
	var cw := 128.0
	var step := cw + 8.0
	var span_max := 1000.0
	if n * cw + (n - 1) * 8.0 > span_max:
		step = (span_max - cw) / float(n - 1)
	var span := step * (n - 1) + cw
	var x0 := _area.size.x / 2.0 - span / 2.0
	var top := size.y - HAND_H + 6.0
	var fan := n >= 5 and not UIStyle.reduce_motion
	var deck := (_plates[1] as PlayerPlate).deck_anchor() if not _plates.is_empty() else Vector2(100, size.y)
	var new_i := 0
	for i in n:
		var uid: int = _hand_order[i]
		var it: Dictionary = _hand_items[uid]
		var holder: Control = it["holder"]
		var t := 0.0
		if n > 1:
			t = (float(i) - float(n - 1) / 2.0) / (float(n - 1) / 2.0)
		var pos := Vector2(x0 + i * step, top + (t * t * 6.0 if fan else 0.0))
		var rot := deg_to_rad(t * 2.0) if fan else 0.0
		holder.set_meta("rest_rot", rot)
		holder.set_meta("rest_pos", pos)
		var is_hv: bool = not _hv.is_empty() and _hv.get("uid", -9) == uid and _hv.get("kind", "") == "hand"
		if uid in new_ids and not instant and not UIStyle.reduce_motion:
			holder.position = pos
			holder.rotation = rot
			var w: CardWidget = it["widget"]
			w.position = deck - (pos + holder.size / 2.0)
			w.scale = Vector2(0.5, 0.5)
			w.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(UIStyle.dur(0.07) * new_i)
			tw.tween_property(w, "modulate:a", 1.0, UIStyle.dur(0.06))
			tw.parallel().tween_property(w, "position", Vector2.ZERO, UIStyle.dur(0.28)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(w, "scale", Vector2.ONE, UIStyle.dur(0.28)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			new_i += 1
			continue
		if instant or UIStyle.reduce_motion or not it.get("placed", false):
			holder.position = pos
			if not is_hv:
				holder.rotation = rot
		else:
			var tw2 := create_tween()
			tw2.tween_property(holder, "position", pos, UIStyle.dur(0.15)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			if not is_hv:
				tw2.parallel().tween_property(holder, "rotation", rot, UIStyle.dur(0.15))
		it["placed"] = true
		if not is_hv:
			hand_layer.move_child(holder, i + 1)   # keep the empty-hand label at index 0


# ---------------------------------------------------------------- view handling

func _on_status(text: String) -> void:
	_error_text = text
	toast.text = text
	var t := get_tree().create_timer(4.0)
	t.timeout.connect(func():
		if toast.text == text:
			toast.text = "")


func _on_view(v: Dictionary) -> void:
	prev_mv = mv
	view = v
	mv = v.get("match", {})
	if v["stage"] != _last_stage:
		_overlay_hidden_by_user = false
		_last_stage = v["stage"]
	if not mv.is_empty() and mv.get("pending", {}).is_empty():
		multi = []
	seat_label.text = "You are %s  ·  Series %d-%d (best of %d)" % [v["names"][v["you"]], v["scores"][0], v["scores"][1], v["best_of"]]
	var events := _collect_fx()
	_draws_me = 0
	for e in events:
		if e["k"] == "draw" and int(e["p"]) == me():
			_draws_me += int(e["n"])
	if _laid_size != size:
		_relayout()
	_render_all()
	if not events.is_empty():
		fx.play(events, prev_mv)


## New presentation events since the last view; empty (skip animations) on first load,
## game switch or a burst of many entries (reconnect).
func _collect_fx() -> Array:
	if mv.is_empty():
		return []
	var entries: Array = mv.get("log", [])
	var maxseq := 0
	var fresh := []
	for e in entries:
		maxseq = maxi(maxseq, int(e["seq"]))
		if int(e["seq"]) > _fx_seq:
			fresh.append(e)
	var game_no: int = view.get("game_no", 0)
	var skip := _fx_seq < 0 or game_no != _fx_game or fresh.size() > MAX_FX_ENTRIES
	_fx_seq = maxseq
	_fx_game = game_no
	if skip:
		return []
	var out := []
	for e in fresh:
		out.append_array(e.get("fx", []))
	return out


func _render_all() -> void:
	_render_board()
	_render_turnbar()
	_render_prompt()
	_render_details()
	_render_log()
	_render_overlay()
	_render_pause()
	_refresh_stack()


func me() -> int:
	return view.get("you", 0)


func _pv(p: int) -> Dictionary:
	return mv["players"][p]


func _side_of(p: int) -> int:
	return 1 if p == me() else 0


# FxPlayer host contract ------------------------------------------------

func fx_slot_item(p: int, zone: String, slot: int) -> Dictionary:
	return _slots.get(_key(_side_of(p), zone, slot), {})


func fx_slot_global_rect(p: int, zone: String, slot: int) -> Rect2:
	var it: Dictionary = fx_slot_item(p, zone, slot)
	if it.is_empty():
		return Rect2()
	return (it["holder"] as Control).get_global_rect()


func plate_of(p: int) -> PlayerPlate:
	return _plates[_side_of(p)]


func hand_anchor(p: int) -> Vector2:
	if p == me():
		return get_global_transform() * Vector2(_area.size.x / 2.0, size.y - HAND_H / 2.0)
	return opp_hand_box.get_global_rect().get_center() + Vector2(60, 40)


func board_global_rect() -> Rect2:
	return get_global_transform() * _area


# ---------------------------------------------------------------- board

func _clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _board_targeting() -> bool:
	var pd := _pending()
	if pd.is_empty() or not pd["mine"]:
		return false
	for o in pd["options"]:
		if o.has("ref") or (o.has("slot") and not o.has("card")):
			return true
	return false


func _render_board() -> void:
	var have := not mv.is_empty()
	var p := me()
	var o := 1 - p
	var targeting := _board_targeting()
	for side in 2:
		var pidx := p if side == 1 else o
		for zone in ["unit", "backrow", "power"]:
			var n := 6 if zone == "unit" else (3 if zone == "backrow" else 4)
			for slot in n:
				_set_slot(side, zone, slot, pidx, have, targeting)
		var pl: PlayerPlate = _plates[side]
		pl.visible = have
		if have:
			var pv := _pv(pidx)
			var active: bool = mv["active"] == pidx and mv["winner"] == -1
			var nxt := ""
			if pidx == p and not pv.get("ap_next", []).is_empty():
				var parts := []
				for m in pv["ap_next"]:
					parts.append("%+d" % m["n"])
				nxt = "next turn %s AP" % " ".join(parts)
			pl.update_from(pv, active, pidx == p, "  (you)" if pidx == p else "", nxt)
	deco.glow_side = -1
	if have and mv["winner"] == -1:
		deco.glow_side = _side_of(mv["active"])
	deco.queue_redraw()
	_render_hand(targeting)
	var on: int = _pv(o)["counts"]["hand"] if have else -1
	if on != opp_hand_n:
		opp_hand_n = on
		_place_opp_hand()


func _set_slot(side: int, zone: String, slot: int, pidx: int, have: bool, targeting: bool) -> void:
	var it: Dictionary = _slots[_key(side, zone, slot)]
	var w: CardWidget = it["widget"]
	var cv = null
	if have:
		cv = _pv(pidx)[ZONE_KEY[zone]][slot]
	var hsh := hash(cv) if cv != null else 0
	if it["hash"] != hsh or it["pidx"] != pidx:
		w.setup(cv, ZONE_KIND[zone], it["label"])
		it["hash"] = hsh
		it["pidx"] = pidx
	w.show_label = have and bool(mv.get("first_turn", false))
	var opt := _option_for_ref(pidx, zone, slot)
	var vis: bool = cv != null and not cv.get("hidden", false)
	var is_sel: bool = vis and cv.get("uid", -2) == selected_uid
	w.set_marks(opt != -1, is_sel or (opt != -1 and opt in multi), targeting and opt == -1)


func _render_hand(targeting: bool) -> void:
	var cards: Array = []
	if not mv.is_empty():
		cards = _pv(me()).get("hand", [])
	var seen := {}
	var new_ids := []
	var order := []
	var my_turn: bool = not mv.is_empty() and mv["active"] == me() and mv["winner"] == -1 and mv.get("pending", {}).is_empty()
	for c in cards:
		var uid: int = c["uid"]
		seen[uid] = true
		order.append(uid)
		var it: Dictionary = _hand_items.get(uid, {})
		if it.is_empty():
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.size = CardWidget.SIZES["hand"]
			holder.pivot_offset = holder.size / 2.0
			var w := CardWidget.new()
			w.auto_hover = false
			w.show_tooltip = false
			w.pressed.connect(_on_widget_pressed)
			w.right_pressed.connect(_on_widget_right)
			holder.add_child(w)
			hand_layer.add_child(holder)
			it = {"holder": holder, "widget": w, "hash": -1, "placed": false}
			_hand_items[uid] = it
			new_ids.append(uid)
		var wd: CardWidget = it["widget"]
		var hsh := hash(c)
		if it["hash"] != hsh:
			wd.setup(c, "hand")
			it["hash"] = hsh
		var opt := _option_for_uid(uid)
		var playable := false
		if my_turn:
			for a in mv.get("actions", []):
				if a.get("uid", -1) == uid and a["ok"]:
					playable = true
					break
		var dim := (targeting and opt == -1) or (not playable and opt == -1)
		wd.set_marks(opt != -1, uid == selected_uid or (opt != -1 and opt in multi), dim)
	for uid in _hand_items.keys():
		if not seen.has(uid):
			var h: Control = _hand_items[uid]["holder"]
			_gone_hand[uid] = h.get_global_rect().get_center()
			if not _hv.is_empty() and _hv.get("uid", -9) == uid:
				_clear_hover()
			h.queue_free()
			_hand_items.erase(uid)
	_hand_order = order
	var anim := new_ids if _draws_me > 0 else []
	if anim.size() > _draws_me:
		anim = anim.slice(anim.size() - _draws_me)
	_layout_hand(anim, false)


# ---------------------------------------------------------------- turn bar

func _render_turnbar() -> void:
	if mv.is_empty():
		turn_title.text = "No game in progress"
		pips.phase = ""
		pips.queue_redraw()
		phase_btn.text = "—"
		phase_btn.disabled = true
		concede_btn.disabled = true
		turn_note.visible = false
		return
	var owner_name: String = _pv(mv["active"])["name"]
	turn_title.text = "Turn %d · %s" % [mv["turn"], owner_name]
	pips.phase = mv["phase"]
	pips.queue_redraw()
	var pd := _pending()
	var label := ""
	var ok := false
	var tip := ""
	for a in mv.get("actions", []):
		if a["t"] == "next_phase":
			label = a["label"]
			ok = a["ok"]
			tip = a["reason"]
	if mv["winner"] != -1:
		label = "Game over"
		ok = false
	elif mv["active"] != me():
		label = "Opponent is acting…" if pd.is_empty() or not pd["mine"] else "Choose an option"
		ok = false
	elif not pd.is_empty():
		label = "Choose an option" if pd["mine"] else "Waiting for opponent"
		ok = false
	elif mv["resolving"]:
		label = "Resolving…"
		ok = false
	if mv["active"] == me() and mv["first_turn"] and ok:
		tip = "No Battle Phase on the first turn."
	phase_btn.text = label
	phase_btn.disabled = not ok
	phase_btn.tooltip_text = tip
	concede_btn.disabled = mv["winner"] != -1
	var note := ""
	if mv["reversal"]:
		note = "SNEAKY SNUNDAY: card-effect gains/losses reversed"
	turn_note.text = note
	turn_note.visible = note != ""
	var net: Dictionary = view.get("net", {})
	if net.is_empty():
		conn_label.text = "Local match"
	elif net.get("paused", false):
		conn_label.text = "● Paused"
	elif not net.get("opponent_connected", true):
		conn_label.text = "● Opponent not connected"
	else:
		conn_label.text = "● Connected (%s)" % net.get("transport", "net")
	conn_label.add_theme_color_override("font_color", UIStyle.BAD if (net.get("paused", false) or not net.get("opponent_connected", true)) and not net.is_empty() else UIStyle.MUTED)


func _confirm_concede() -> void:
	_show_message("Concede this game?", [["Concede", func(): _send({"t": "concede"}); pile_popup.visible = false], ["Keep playing", func(): pile_popup.visible = false]])


# ---------------------------------------------------------------- selection & prompts

func _pending() -> Dictionary:
	if mv.is_empty():
		return {}
	return mv.get("pending", {})


func _option_for_ref(p: int, zone: String, slot: int) -> int:
	var pd := _pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == p and o["ref"]["zone"] == zone and o["ref"]["slot"] == slot:
			return o["i"]
		if o.has("slot") and p == me() and not o.has("ref"):
			var oz: String = o.get("zone", "")
			var mapped := "unit" if oz in ["unit", "adjacent", "column", "orig"] else oz
			if mapped == zone and o["slot"] == slot and pd["kind"] == "slot":
				return o["i"]
	return -1


func _option_for_uid(uid: int) -> int:
	var pd := _pending()
	if pd.is_empty() or not pd["mine"]:
		return -1
	for o in pd["options"]:
		if o.has("card") and o["card"].get("uid", -1) == uid:
			return o["i"]
	return -1


func _on_widget_pressed(w: CardWidget) -> void:
	fx.finish_all()
	var opt := -1
	var idx := -1
	for k in _slots.keys():
		if _slots[k]["widget"] == w:
			var parts: PackedStringArray = (k as String).split(":")
			var pidx := me() if int(parts[0]) == 1 else 1 - me()
			opt = _option_for_ref(pidx, parts[1], int(parts[2]))
			idx = 1
			break
	if opt == -1 and not w.view.is_empty():
		opt = _option_for_uid(w.view.get("uid", -2))
	if opt != -1:
		_pick_option(opt)
		return
	_pin(w)


func _on_widget_right(w: CardWidget) -> void:
	fx.finish_all()
	_pin(w)


func _pin(w: CardWidget) -> void:
	if not w.view.is_empty() and not w.view.get("hidden", false) and w.view.has("uid"):
		selected_uid = w.view["uid"]
		_peek_uid = -1
		_render_board()
		_render_details()


func _pick_option(i: int) -> void:
	var pd := _pending()
	if pd["max"] > 1:
		if i in multi:
			multi.erase(i)
		else:
			multi.append(i)
		_render_all()
		return
	_send({"t": "choose", "id": pd["id"], "indices": [i]})


func _send(cmd: Dictionary) -> void:
	toast.text = ""
	if client != null:
		client.send(cmd)


func _unhandled_input(event: InputEvent) -> void:
	var cancel := false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel = true
	if not cancel:
		return
	if pile_popup.visible:
		pile_popup.visible = false
		return
	if settings_popup.visible:
		settings_popup.visible = false
		return
	var pd := _pending()
	if not pd.is_empty() and pd["mine"] and pd["cancellable"]:
		multi = []
		_send({"t": "cancel", "id": pd["id"]})
	elif selected_uid != -1:
		selected_uid = -1
		_peek_uid = -1
		_render_board()
		_render_details()
	_clear_hover()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]):
		if fx != null and fx.busy():
			fx.finish_all()


# ---------------------------------------------------------------- hover + on-card actions

func _locked() -> bool:
	if mv.is_empty() or view.get("stage", "") != "game" or mv["winner"] != -1:
		return true
	if not mv.get("pending", {}).is_empty() or mv.get("resolving", false):
		return true
	var net: Dictionary = view.get("net", {})
	return net.get("paused", false)


func _hover_blocked() -> bool:
	return overlay.visible or pile_popup.visible or settings_popup.visible or pause_dim.visible or mv.is_empty()


func _process(_d: float) -> void:
	if not is_visible_in_tree():
		return
	if _hv_forced:
		return
	_update_hover(get_global_mouse_position())


func _hover_items_under(m: Vector2, exclude_key: String) -> Dictionary:
	# Hand cards: topmost (last) first.
	for i in range(_hand_order.size() - 1, -1, -1):
		var uid: int = _hand_order[i]
		var it: Dictionary = _hand_items[uid]
		var h: Control = it["holder"]
		if "h:%d" % uid != exclude_key and h.get_global_rect().has_point(m):
			return {"key": "h:%d" % uid, "w": it["widget"], "holder": h, "uid": uid, "kind": "hand", "own": true}
	for k in _slots.keys():
		var sl: Dictionary = _slots[k]
		var w: CardWidget = sl["widget"]
		if k == exclude_key or w.view.is_empty() or w.view.get("hidden", false):
			continue
		var h2: Control = sl["holder"]
		if h2.get_global_rect().has_point(m):
			var parts: PackedStringArray = (k as String).split(":")
			var zone: String = parts[1]
			return {"key": k, "w": w, "holder": h2, "uid": w.view.get("uid", -1), "kind": ZONE_KIND[zone], "own": int(parts[0]) == 1}
	return {}


func _update_hover(m: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _hover_blocked():
		if not _hv.is_empty():
			_clear_hover()
		return
	if not _hv.is_empty():
		if not is_instance_valid(_hv["w"]) or not (_hv["w"] as Node).is_inside_tree():
			_clear_hover()
			return
		var tr := _target_rect(_hv)
		var in_stack := _stack != null and _stack.get_global_rect().grow(3.0).has_point(m)
		if tr.has_point(m) or in_stack:
			_close_at = -1.0
		else:
			var cand := _hover_items_under(m, _hv["key"])
			if not cand.is_empty():
				_set_hover(cand)
			else:
				var region := tr.grow(10.0).merge((_hv["holder"] as Control).get_global_rect())
				if _stack != null:
					region = region.merge(_stack.get_global_rect())
				if region.has_point(m):
					_close_at = -1.0
				elif _close_at < 0.0:
					_close_at = now + 0.15
				elif now >= _close_at:
					_clear_hover()
	else:
		var cand2 := _hover_items_under(m, "")
		if not cand2.is_empty():
			_set_hover(cand2)
	if _peek_at >= 0.0 and now >= _peek_at and not _hv.is_empty():
		_peek_at = -1.0
		if _hv["uid"] != _peek_uid and _hv["uid"] != -1:
			_peek_uid = _hv["uid"]
			_render_details()


func _lift_params(kind: String) -> Array:
	var hand := kind == "hand"
	var sc := HAND_SCALE if hand else FIELD_SCALE
	var lift := Vector2(0, -48) if hand else Vector2.ZERO
	if UIStyle.reduce_motion:
		sc = minf(sc, 1.05)
		lift = Vector2(0, -16) if hand else Vector2.ZERO
	return [sc, lift]


func _target_rect(it: Dictionary) -> Rect2:
	var hr: Rect2 = (it["holder"] as Control).get_global_rect()
	var lp := _lift_params(it["kind"])
	var c := hr.get_center() + (lp[1] as Vector2)
	return Rect2(c - hr.size * float(lp[0]) / 2.0, hr.size * float(lp[0]))


func _set_hover(it: Dictionary) -> void:
	if not _hv.is_empty():
		_unlift(_hv)
	_hv = it
	_close_at = -1.0
	_peek_at = Time.get_ticks_msec() / 1000.0 + 0.25
	var w: CardWidget = it["w"]
	var holder: Control = it["holder"]
	w.hovered = true
	holder.z_index = 40
	if it["kind"] == "hand":
		hand_layer.move_child(holder, -1)
	var lp := _lift_params(it["kind"])
	_kill_hv_tween(w)
	var tw := create_tween()
	w.set_meta("hv_tw", tw)
	tw.set_parallel(true)
	var d := UIStyle.dur(0.12 if it["kind"] == "hand" else 0.1)
	if UIStyle.reduce_motion:
		d = 0.05
	tw.tween_property(w, "position", lp[1], d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "scale", Vector2(lp[0], lp[0]), d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if it["kind"] == "hand":
		tw.tween_property(holder, "rotation", 0.0, d)
	_rebuild_stack()


func _kill_hv_tween(w: CardWidget) -> void:
	if w.has_meta("hv_tw"):
		var t: Tween = w.get_meta("hv_tw")
		if t != null and t.is_valid():
			t.kill()


func _unlift(it: Dictionary) -> void:
	var w: CardWidget = it["w"]
	if not is_instance_valid(w):
		return
	var holder: Control = it["holder"]
	w.hovered = false
	_kill_hv_tween(w)
	var tw := create_tween()
	w.set_meta("hv_tw", tw)
	tw.set_parallel(true)
	var d := UIStyle.dur(0.09)
	tw.tween_property(w, "position", Vector2.ZERO, d)
	tw.tween_property(w, "scale", Vector2.ONE, d)
	if it["kind"] == "hand" and holder.has_meta("rest_rot"):
		tw.tween_property(holder, "rotation", float(holder.get_meta("rest_rot")), d)
	tw.chain().tween_callback(func():
		if is_instance_valid(holder):
			holder.z_index = 0)
	if it["kind"] == "hand":
		for i in _hand_order.size():
			var h: Control = _hand_items[_hand_order[i]]["holder"]
			hand_layer.move_child(h, i + 1)


func _clear_hover() -> void:
	if not _hv.is_empty():
		_unlift(_hv)
	_hv = {}
	_hv_forced = false
	_close_at = -1.0
	_peek_at = -1.0
	_clear_stack()
	if selected_uid != -1 and _peek_uid != -1:
		_peek_uid = -1
		_render_details()


func _clear_stack() -> void:
	if _stack != null and is_instance_valid(_stack):
		_stack.queue_free()
	_stack = null
	_stack_sig = ""


## Legal actions of a card: enabled ones, or one greyed explanation when nothing is legal.
func _actions_for_card(uid: int) -> Array:
	if _locked():
		return []
	var oks := []
	var bad := []
	for a in mv.get("actions", []):
		if a.get("uid", -1) != uid:
			continue
		if a["ok"]:
			oks.append(a)
		elif a.get("reason", "") != "":
			bad.append(a)
	if not oks.is_empty():
		return oks
	if not bad.is_empty():
		return [bad[0]]
	return []


func _act_sig(acts: Array) -> String:
	var parts := []
	for a in acts:
		parts.append("%s/%s/%s/%s" % [a["t"], a.get("idx", ""), a["ok"], a.get("reason", "")])
	return "|".join(parts)


func _refresh_stack() -> void:
	if _hv.is_empty():
		return
	if not _hv["own"] or _locked():
		if _stack != null:
			_clear_stack()
		return
	var sig := _act_sig(_actions_for_card(_hv["uid"]))
	if sig != _stack_sig:
		_rebuild_stack()


func _rebuild_stack() -> void:
	_clear_stack()
	if _hv.is_empty() or not _hv["own"]:
		return
	var uid: int = _hv["uid"]
	var acts := _actions_for_card(uid)
	_stack_sig = _act_sig(acts)
	if acts.is_empty():
		return
	var tr := _target_rect(_hv)
	var kind: String = _hv["kind"]
	var n := acts.size()
	var bh := 28.0
	var gap := 6.0
	var total := n * bh + (n - 1) * gap
	var base_w := 128.0 if kind in ["hand", "board", "trap"] else 85.0
	var k := tr.size.x / base_w
	var x := tr.position.x + 8.0
	var w := tr.size.x - 16.0
	var top := 0.0
	if kind in ["trap", "power"]:
		var cy := tr.position.y + tr.size.y * 0.46
		top = cy - total / 2.0
		var lim := tr.end.y - 6.0
		if top + total > lim:
			top = lim - total
	else:
		var frac := 0.278 if kind == "hand" else 0.297
		top = tr.position.y + tr.size.y * frac - total / 2.0
		var reserved := tr.end.y - 38.0 * k
		if top + total > reserved:
			top = reserved - total
		var gem_bottom := tr.position.y + 30.0 * k
		if top < gem_bottom:
			x = tr.position.x + 34.0 * k
			w = tr.size.x - 8.0 - 34.0 * k
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size = Vector2(w, total)
	box.position = hover_layer.get_global_transform().affine_inverse() * Vector2(x, top)
	for i in n:
		var a: Dictionary = acts[i]
		var b := UIStyle.button(a["label"] if a["ok"] else String(a["reason"]), 13)
		b.custom_minimum_size = Vector2(w, bh)
		b.size = Vector2(w, bh)
		b.position = Vector2(0, i * (bh + gap))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if a["ok"] else Control.CURSOR_ARROW
		var primary: bool = i == 0 and a["ok"]
		var nrm := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.97), UIStyle.GOLD if primary else UIStyle.BRONZE, 2 if primary else 1, 6)
		var hov := UIStyle.flat(Color(UIStyle.PANEL_LIGHT.lightened(0.12), 0.99), UIStyle.GOLD_HI, 2, 6)
		var dis := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.92), Color(UIStyle.BRONZE, 0.35), 1, 6)
		for st in [nrm, hov, dis]:
			st.content_margin_top = 2
			st.content_margin_bottom = 2
			st.content_margin_left = 4
			st.content_margin_right = 4
		b.add_theme_stylebox_override("normal", nrm)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("disabled", dis)
		b.add_theme_color_override("font_disabled_color", UIStyle.DISABLED)
		if a["ok"]:
			b.pressed.connect(_run_action.bind(uid, a))
		else:
			b.disabled = true
			b.tooltip_text = String(a["reason"])
		box.add_child(b)
	hover_layer.add_child(box)
	_stack = box
	if not UIStyle.reduce_motion:
		box.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(UIStyle.dur(0.06))
		tw.tween_property(box, "modulate:a", 1.0, UIStyle.dur(0.1))
	box.set_meta("rect_global", Rect2(Vector2(x, top), Vector2(w, total)))


func _run_action(uid: int, a: Dictionary) -> void:
	# Ignore a stale click: the action must still be legal for this card instance.
	var still := false
	for b in mv.get("actions", []):
		if b.get("uid", -1) == uid and b["t"] == a["t"] and b.get("idx", -1) == a.get("idx", -1) and b["ok"]:
			still = true
	if not still or _locked():
		return
	var cmd := {"t": a["t"], "uid": uid}
	if a.has("idx"):
		cmd["idx"] = a["idx"]
	selected_uid = uid
	_clear_hover()
	_send(cmd)


## Dev/test API: force the hover state on a hand card (index) or a field slot.
func debug_hover_hand(index: int) -> void:
	if index < 0 or index >= _hand_order.size():
		return
	var uid: int = _hand_order[index]
	var it: Dictionary = _hand_items[uid]
	_hv_forced = false
	_set_hover({"key": "h:%d" % uid, "w": it["widget"], "holder": it["holder"], "uid": uid, "kind": "hand", "own": true})
	_hv_forced = true
	_peek_uid = uid
	_render_details()


func debug_hover_slot(p: int, zone: String, slot: int) -> void:
	var it: Dictionary = fx_slot_item(p, zone, slot)
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	_hv_forced = false
	_set_hover({"key": _key(_side_of(p), zone, slot), "w": w, "holder": it["holder"], "uid": w.view.get("uid", -1), "kind": ZONE_KIND[zone], "own": p == me()})
	_hv_forced = true
	_peek_uid = w.view.get("uid", -1)
	_render_details()


func debug_clear_hover() -> void:
	_hv_forced = false
	_clear_hover()


# ---------------------------------------------------------------- prompt

func _render_net_banner() -> bool:
	var net: Dictionary = view.get("net", {})
	if net.is_empty():
		return false
	if net.get("paused", false):
		return true
	elif not net.get("opponent_connected", true) and net.get("is_host", false):
		prompt_box.add_child(UIStyle.label(net.get("message", "Waiting for an opponent…"), 14, UIStyle.ACCENT, true))
		if net.get("transport", "") == "steam":
			var inv := UIStyle.button("Invite a Steam friend", 14)
			inv.pressed.connect(func(): get_tree().call_group("net_session", "invite_friend"))
			prompt_box.add_child(inv)
	return false


func _render_pause() -> void:
	var net: Dictionary = view.get("net", {})
	var paused: bool = not net.is_empty() and net.get("paused", false)
	pause_dim.visible = paused
	_clear(pause_box)
	if not paused:
		return
	pause_box.add_child(UIStyle.label("MATCH PAUSED", 26, UIStyle.BAD, false, true))
	pause_box.add_child(UIStyle.label(net["message"] if net.get("message", "") != "" else "Waiting for the connection to be restored. Nothing can happen until both players are connected.", 14, UIStyle.TEXT, true))
	if net.get("is_host", false) and view.get("stage", "") == "game" and net.get("claim_in", -1) >= 0:
		var wait: int = net["claim_in"]
		var claim := UIStyle.primary_button("Claim this game (opponent absent)" if wait == 0 else "Claim this game available in %d s" % wait, 14)
		claim.disabled = wait > 0
		claim.tooltip_text = "Wins the current game only; the series continues."
		claim.pressed.connect(func(): _send({"t": "claim_game"}))
		pause_box.add_child(claim)
	pause_box.add_child(UIStyle.label("You can still use Menu or inspect the log.", 12, UIStyle.MUTED, true))
	pause_panel.set_deferred("size", Vector2(440, 0))


func _prompt_pulse(on: bool) -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_style.border_color = UIStyle.BRONZE
	if not on:
		return
	if UIStyle.reduce_motion:
		_prompt_style.border_color = UIStyle.GOLD
		return
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt_style, "border_color", UIStyle.GOLD_HI, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(_prompt_style, "border_color", UIStyle.BRONZE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _render_prompt() -> void:
	_clear(prompt_box)
	var decision := false
	var pd := _pending()
	if _render_net_banner():
		prompt_box.add_child(UIStyle.label("Match paused. Nothing can happen until both players are connected.", 13, UIStyle.MUTED, true))
		_prompt_pulse(false)
		return
	if view.get("stage", "") != "game" or mv.is_empty():
		prompt_box.add_child(UIStyle.label(_stage_hint(), 14, UIStyle.MUTED, true))
		_prompt_pulse(false)
		return
	if mv["winner"] != -1:
		prompt_box.add_child(UIStyle.label("Game over: %s wins." % _pv(mv["winner"])["name"], 16, UIStyle.ACCENT, true, true))
	elif pd.is_empty():
		var txt := "Your turn. Hover a card to see what it can do." if mv["active"] == me() else "Opponent's turn."
		if mv["resolving"]:
			txt = "Resolving…"
		prompt_box.add_child(UIStyle.label(txt, 14, UIStyle.TEXT if mv["active"] == me() else UIStyle.MUTED, true))
	elif not pd["mine"]:
		prompt_box.add_child(UIStyle.label(pd["prompt"], 14, UIStyle.ACCENT, true))
		prompt_box.add_child(UIStyle.label("You cannot act until this choice is made.", 12, UIStyle.MUTED, true))
	else:
		decision = true
		_render_choice(pd)
	_prompt_pulse(decision)


func _render_choice(pd: Dictionary) -> void:
	prompt_box.add_child(UIStyle.label(pd["prompt"], 15, UIStyle.TARGET, true))
	if _board_targeting():
		prompt_box.add_child(UIStyle.label("Click a highlighted card or zone on the board, or pick below.", 12, UIStyle.MUTED, true))
	if pd["kind"] == "trap_response":
		prompt_box.add_child(UIStyle.label("Your opponent is waiting. Activate a Trap or pass.", 12, UIStyle.MUTED, true))
	# Cards shown only for this selection (e.g. a hidden pile) get previews; everything
	# else (zones, field cards, yes/no) is a full-width text button.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	prompt_box.add_child(flow)
	prompt_box.add_child(list)
	for o in pd["options"]:
		var chosen: bool = o["i"] in multi
		if o.has("card") and not o.has("ref"):
			var cell := VBoxContainer.new()
			var w := CardWidget.new().setup(o["card"], "mini")
			w.show_tooltip = false
			w.set_marks(true, chosen)
			var idx: int = o["i"]
			w.pressed.connect(func(_w): _pick_option(idx))
			cell.add_child(w)
			var b := UIStyle.button(("✓ " if chosen else "") + "Choose", 11)
			b.pressed.connect(_pick_option.bind(o["i"]))
			cell.add_child(b)
			flow.add_child(cell)
		else:
			var b2 := UIStyle.button(("✓ " if chosen else "") + o["label"], 13)
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.tooltip_text = o["label"]
			b2.pressed.connect(_pick_option.bind(o["i"]))
			list.add_child(b2)
	if pd["max"] > 1:
		var total_txt := ""
		if pd.get("min_total", 0) > 0:
			var total := 0
			for i in multi:
				total += maxi(pd["options"][i].get("card", {}).get("cost", 0), 0)
			total_txt = "  ·  cost total %d / %d" % [total, pd["min_total"]]
		prompt_box.add_child(UIStyle.label("Selected %d (choose %d–%d)%s" % [multi.size(), pd["min"], pd["max"], total_txt], 12, UIStyle.MUTED))
		var confirm := UIStyle.primary_button("Confirm selection", 14)
		confirm.disabled = multi.size() < pd["min"]
		confirm.pressed.connect(func(): _send({"t": "choose", "id": pd["id"], "indices": multi.duplicate()}))
		prompt_box.add_child(confirm)
	if pd["cancellable"]:
		var cancel := UIStyle.button("Cancel", 13)
		cancel.pressed.connect(func(): multi = []; _send({"t": "cancel", "id": pd["id"]}))
		prompt_box.add_child(cancel)


func _stage_hint() -> String:
	match view.get("stage", ""):
		"decks": return "Choose a deck."
		"rewards": return "Choose your rewards."
		"first_player": return "Choosing who goes first."
		"over": return "The series is over."
	return ""


# ---------------------------------------------------------------- details (inspection only)

func _find_card(uid: int) -> Dictionary:
	if mv.is_empty() or uid == -1:
		return {}
	for p in 2:
		var pv: Dictionary = mv["players"][p]
		for z in ["units", "backrow", "powers", "hand", "spent", "exhaust", "extra", "draw_inspect"]:
			for c in pv.get(z, []):
				if c != null and not c.get("hidden", false) and c.get("uid", -1) == uid:
					return c
	return {}


func _details_uid() -> int:
	return _peek_uid if _peek_uid != -1 else selected_uid


func _render_details() -> void:
	_clear(details_box)
	var duid := _details_uid()
	var c := _find_card(duid)
	if c.is_empty():
		details_box.add_child(UIStyle.label("Hover a card to read it, or click it to pin it here. Right-click or Esc to clear.", 13, UIStyle.MUTED, true))
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	details_box.add_child(top)
	var cw := CardWidget.new()
	cw.show_tooltip = false
	cw.auto_hover = false
	cw.setup(c, "big")
	cw.custom_minimum_size = Vector2(150, 210)
	cw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cw)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	top.add_child(info)
	_card_details(info, c)
	for part in c.get("stat_parts", []):
		details_box.add_child(UIStyle.label("• " + part, 12, UIStyle.MUTED, true))
	var any_status := false
	if c.get("runes", 0) > 0:
		details_box.add_child(UIStyle.label("Rune ×%d — %s" % [c["runes"], CardDB.STATUS_HELP["rune"]], 13, Color("8fc1ff"), true))
		any_status = true
	for s in CardDB.STATUS_ORDER:
		var n: int = c.get("statuses", {}).get(s, 0)
		if n > 0:
			any_status = true
			details_box.add_child(UIStyle.label("%s ×%d — %s" % [s.capitalize(), n, CardDB.STATUS_HELP[s]], 13, Color("9be7b7") if CardDB.is_buff(s) else Color("ff9d9d"), true))
	if not any_status and c.has("race"):
		details_box.add_child(UIStyle.label("No statuses.", 12, UIStyle.MUTED))
	var text: String = c.get("text", "")
	details_box.add_child(UIStyle.label(text if text != "" else "No effect text.", 14, UIStyle.TEXT, true))
	var sup: String = c.get("support", "full")
	if sup != "full":
		details_box.add_child(UIStyle.label("Implementation: %s" % sup, 12, UIStyle.BAD, true))
	# Legality notes (why something cannot be done) — information only, no buttons.
	for a in mv.get("actions", []):
		if a.get("uid", -1) == duid and not a["ok"] and a.get("reason", "") != "":
			details_box.add_child(UIStyle.label("Cannot %s: %s" % [String(a["label"]).to_lower(), a["reason"]], 12, UIStyle.MUTED, true))


func _card_details(box: VBoxContainer, c: Dictionary) -> void:
	box.add_child(UIStyle.label(c["name"], 18, UIStyle.GOLD_HI, true, true))
	box.add_child(UIStyle.label("%s  ·  Cost: %s" % [UIStyle.CATEGORY_NAMES[c["category"]], c["cost_text"]], 13, UIStyle.TEXT, true))
	if c.has("race"):
		box.add_child(UIStyle.label("Race: %s\nType: %s" % [c["race"] if c["race"] != "" else "None", c["type"] if c["type"] != "" else "None"], 13, UIStyle.MUTED, true))
		var pa = c.get("printed_atk")
		var pd = c.get("printed_def")
		box.add_child(UIStyle.label("ATK %s   DEF %s" % [str(c.get("atk", "?")), str(c.get("def", "?"))], 15, UIStyle.TEXT))
		box.add_child(UIStyle.label("printed %s / %s" % ["?" if pa == null else str(pa), "?" if pd == null else str(pd)], 12, UIStyle.MUTED))
		if c.get("zone", "") == "unit":
			var flags := []
			flags.append("Attack stance" if c["stance"] == "atk" else "Defense stance")
			if c.get("protected", false):
				flags.append("Protected")
			if c.get("new", false):
				flags.append("Summoned this turn")
			if c.get("attacked", false):
				flags.append("Attacked this turn")
			box.add_child(UIStyle.label(" · ".join(flags), 12, UIStyle.MUTED, true))


# ---------------------------------------------------------------- log

func _render_log() -> void:
	if mv.is_empty():
		return
	var game_no: int = view.get("game_no", 0)
	if game_no != _log_game:
		log_label.clear()
		_log_seq_shown = 0
		_log_game = game_no
		log_label.append_text("[color=#f2b544][b]Game %d[/b][/color]\n" % game_no)
	for e in mv.get("log", []):
		if e["seq"] <= _log_seq_shown:
			continue
		_log_seq_shown = e["seq"]
		var t: String = e["text"]
		if t == "":
			continue
		var col := "#e8e0cc"
		var bold := false
		if t.begins_with("—"):
			col = "#f0cf7a"
			bold = true
		elif t.contains("loses") and t.contains("HP"):
			col = "#ff8a8a"
		elif t.contains("gains") and t.contains("HP"):
			col = "#8fe3a8"
		elif t.begins_with("Battle:"):
			col = "#ffd84a"
		elif t.begins_with("GAME OVER"):
			col = "#ff9ff3"
			bold = true
		var body := t.replace("[", "(").replace("]", ")")
		if bold:
			body = "[b]%s[/b]" % body
		log_label.append_text("[color=%s]%s[/color]\n" % [col, body])


# ---------------------------------------------------------------- piles

func _show_pile(zone: String) -> void:
	_clear(pile_box)
	var pv := _pv(me())
	var key := "draw_inspect" if zone == "draw" else zone
	var head := HBoxContainer.new()
	pile_box.add_child(head)
	var title := "Your %s (%d)" % [zone.capitalize() if zone != "extra" else "Extra Deck", pv.get(key, []).size()]
	if zone == "draw":
		title += " — shown in a random order; the real Draw order is unchanged"
	var tl := UIStyle.label(title, 16, UIStyle.GOLD, true, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := UIStyle.button("Close", 13)
	close.pressed.connect(func(): pile_popup.visible = false)
	head.add_child(close)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	pile_box.add_child(flow)
	for c in pv.get(key, []):
		var w := CardWidget.new().setup(c, "hand")
		w.pressed.connect(func(_w):
			selected_uid = c["uid"]
			_peek_uid = -1
			_render_details())
		flow.add_child(w)
	if pv.get(key, []).is_empty():
		pile_box.add_child(UIStyle.label("Empty.", 13, UIStyle.MUTED))
	pile_popup.visible = true
	_clear_hover()


func _show_message(text: String, buttons: Array) -> void:
	_clear(pile_box)
	pile_box.add_child(UIStyle.label(text, 16, UIStyle.GOLD, true, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pile_box.add_child(row)
	for pair in buttons:
		var b := UIStyle.button(pair[0], 14)
		b.pressed.connect(pair[1])
		row.add_child(b)
	pile_popup.visible = true
	_clear_hover()


# ---------------------------------------------------------------- series stages (overlay)

func _render_overlay() -> void:
	_clear(overlay_box)
	var stage: String = view.get("stage", "")
	if stage == "game" or _overlay_hidden_by_user:
		overlay.visible = false
		if _overlay_hidden_by_user and stage != "game":
			var back := UIStyle.button("Return to %s" % _stage_title(stage), 14)
			back.pressed.connect(func(): _overlay_hidden_by_user = false; _render_overlay())
			_clear(prompt_box)
			prompt_box.add_child(back)
		return
	overlay.visible = true
	overlay_box.add_child(UIStyle.label(_stage_title(stage), 28, UIStyle.GOLD, false, true))
	overlay_box.add_child(UIStyle.label("Score %d – %d  ·  best of %d" % [view["scores"][0], view["scores"][1], view["best_of"]], 15, UIStyle.MUTED))
	match stage:
		"decks": _render_decks()
		"rewards": _render_rewards()
		"first_player": _render_first()
		"over": _render_over()
	if not mv.is_empty() and stage != "decks":
		var see := UIStyle.button("View the final board and log of game %d" % view["game_no"], 13)
		see.pressed.connect(func(): _overlay_hidden_by_user = true; _render_all())
		overlay_box.add_child(see)


func _stage_title(stage: String) -> String:
	match stage:
		"decks": return "Choose your deck" if view.get("deck_mode", "starter") == "starter" else "Draft your deck"
		"rewards": return "Game %d complete — rewards" % view["game_no"]
		"first_player": return "Next game"
		"over": return "Series over"
	return ""


func _game_result_line() -> String:
	if view.get("history", []).is_empty():
		return ""
	var h: Dictionary = view["history"][-1]
	return "%s won game %d (turn %d, HP %d–%d)." % [view["names"][h["winner"]], h["game"], h["turns"], h["hp"][0], h["hp"][1]]


func _render_decks() -> void:
	var p := me()
	if view["deck_ready"][p]:
		overlay_box.add_child(UIStyle.label("Deck locked in: %s. Waiting for your opponent…" % view["deck_name"], 16, UIStyle.TEXT, true))
		return
	if view.has("starters"):
		for i in view["starters"].size():
			var s: Dictionary = view["starters"][i]
			var row := HBoxContainer.new()
			overlay_box.add_child(row)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			col.add_child(UIStyle.label(s["name"], 18, UIStyle.TEXT, false, true))
			col.add_child(UIStyle.label(s["theme"], 13, UIStyle.MUTED))
			var names_txt := ", ".join(s["main"].map(func(c): return c["name"]))
			col.add_child(UIStyle.label("Main (%d): %s" % [s["main"].size(), names_txt], 11, UIStyle.MUTED, true))
			col.add_child(UIStyle.label("Extra Deck: %s" % ", ".join(s["extra"].map(func(c): return c["name"])), 11, UIStyle.MUTED, true))
			var b := UIStyle.primary_button("Choose %s" % s["name"], 14)
			b.pressed.connect(func(): _send({"t": "pick_starter", "index": i}))
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		_render_custom_decks()
		return
	var dr: Dictionary = view["draft"]
	overlay_box.add_child(UIStyle.label("Pick %d of %d — %s" % [dr["step"] + 1, dr["total"], String(dr["category"]).capitalize()], 18, UIStyle.TEXT))
	var flow := HFlowContainer.new()
	overlay_box.add_child(flow)
	for i in dr["offer"].size():
		var c: Dictionary = dr["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_child(CardWidget.new().setup(_summary_view(c), "big"))
		var b2 := UIStyle.primary_button("Pick", 14)
		b2.pressed.connect(func(): _send({"t": "draft_pick", "index": i}))
		cell.add_child(b2)
		flow.add_child(cell)
	overlay_box.add_child(UIStyle.label("Picked: " + ", ".join(dr["picked"].map(func(c): return c["name"])), 12, UIStyle.MUTED, true))


## Saved custom decks (not offered in draft mode).
func _render_custom_decks() -> void:
	if view.get("deck_mode", "starter") == "draft":
		return
	var decks := DeckStore.list()
	if decks.is_empty():
		return
	var rule := ColorRect.new()
	rule.color = Color(UIStyle.GOLD, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	overlay_box.add_child(rule)
	overlay_box.add_child(UIStyle.label("Your saved decks", 20, UIStyle.GOLD, false, true))
	for d in decks:
		var row := HBoxContainer.new()
		overlay_box.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var counts := DeckStore.split_counts(d["cards"])
		col.add_child(UIStyle.label(d["name"], 17, UIStyle.TEXT, false, true))
		col.add_child(UIStyle.label("Main %d · Extra Deck %d · %d cards" % [counts["main"], counts["extra"], d["cards"].size()], 12, UIStyle.MUTED))
		var b := UIStyle.primary_button("Use this deck", 14)
		var deck: Dictionary = d
		b.pressed.connect(func(): _send({"t": "custom_deck", "cards": deck["cards"], "name": deck["name"]}))
		row.add_child(b)


func _summary_view(c: Dictionary) -> Dictionary:
	var kind := "ap"
	var printed = null
	match c["category"]:
		"fusion": kind = "fusion"
		"ritual": kind = "ritual"
		"arcane": kind = "arcane"
	var d := CardDB.get_def(c["id"])
	printed = d["cost"]
	return {"uid": -1000 - c["id"], "id": c["id"], "name": c["name"], "category": c["category"], "cost_kind": kind,
		"cost_text": c["cost_text"], "cost": printed if printed != null else 0, "printed_cost": printed,
		"race": c["race"], "type": c["type"], "atk": c["atk"], "def": c["def"], "printed_atk": c["atk"], "printed_def": c["def"],
		"text": c["text"], "support": c["support"], "art": d["art"], "statuses": {}, "runes": 0, "zone": "pile"}


func _render_rewards() -> void:
	overlay_box.add_child(UIStyle.label(_game_result_line(), 16, UIStyle.TEXT, true))
	var r: Dictionary = view["rewards"]
	if r["done"]:
		overlay_box.add_child(UIStyle.label("You have finished choosing rewards. Waiting for your opponent…" if not r["opponent_done"] else "Starting soon…", 15, UIStyle.TEXT, true))
		for t in r["taken"]:
			overlay_box.add_child(UIStyle.label("• " + t, 13, UIStyle.MUTED))
		return
	overlay_box.add_child(UIStyle.label("Rewards left to choose: %d — any combination of adding a card, removing a card or changing a basic unit's Type." % r["left"], 15, UIStyle.ACCENT, true))
	if r["opponent_done"]:
		overlay_box.add_child(UIStyle.label("Your opponent has finished.", 12, UIStyle.MUTED))
	for t in r["taken"]:
		overlay_box.add_child(UIStyle.label("✓ " + t, 13, UIStyle.GOOD))
	overlay_box.add_child(UIStyle.label("Add a card (pick one of these):", 15, UIStyle.TEXT))
	var flow := HFlowContainer.new()
	overlay_box.add_child(flow)
	for i in r["offer"].size():
		var c: Dictionary = r["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_child(CardWidget.new().setup(_summary_view(c), "big"))
		var b := UIStyle.button("Add %s" % c["name"], 12)
		b.pressed.connect(func(): _send({"t": "reward_add", "index": i}))
		cell.add_child(b)
		flow.add_child(cell)
	overlay_box.add_child(UIStyle.label("Remove a card from your deck:", 15, UIStyle.TEXT))
	var deck_flow := HFlowContainer.new()
	overlay_box.add_child(deck_flow)
	var counts := {}
	var order := []
	for c in view["deck"]:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	for c in order:
		var b2 := UIStyle.button("− %s%s" % [c["name"], " ×%d" % counts[c["id"]] if counts[c["id"]] > 1 else ""], 12)
		b2.tooltip_text = c["text"]
		b2.pressed.connect(func(): _send({"t": "reward_remove", "card_id": c["id"]}))
		deck_flow.add_child(b2)
	overlay_box.add_child(UIStyle.label("Change a basic unit's Type (all copies):", 15, UIStyle.TEXT))
	for c in order:
		if c["category"] != "basic_unit":
			continue
		var row := HBoxContainer.new()
		overlay_box.add_child(row)
		row.add_child(UIStyle.label("%s ×%d →" % [c["name"], counts[c["id"]]], 13))
		for t in r["basic_types"]:
			if t == c["type"]:
				continue
			var tb := UIStyle.button(t, 12)
			tb.add_theme_color_override("font_color", UIStyle.type_color(t).lightened(0.3))
			tb.pressed.connect(func(): _send({"t": "reward_basic", "from_id": c["id"], "to_type": t}))
			row.add_child(tb)
	var fin := UIStyle.primary_button("Skip remaining rewards", 13)
	fin.pressed.connect(func(): _send({"t": "reward_finish"}))
	overlay_box.add_child(fin)


func _render_first() -> void:
	overlay_box.add_child(UIStyle.label(_game_result_line(), 16, UIStyle.TEXT, true))
	if view["last_loser"] == me():
		overlay_box.add_child(UIStyle.label("You lost the last game, so you choose who goes first in game %d." % (view["game_no"] + 1), 16, UIStyle.ACCENT, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		overlay_box.add_child(row)
		var b1 := UIStyle.primary_button("I go first", 15)
		b1.pressed.connect(func(): _send({"t": "first_player", "who": me()}))
		row.add_child(b1)
		var b2 := UIStyle.button("My opponent goes first", 15)
		b2.pressed.connect(func(): _send({"t": "first_player", "who": 1 - me()}))
		row.add_child(b2)
	else:
		overlay_box.add_child(UIStyle.label("Your opponent lost the last game and is choosing who goes first…", 15, UIStyle.TEXT, true))


func _render_over() -> void:
	var w := 0 if view["scores"][0] > view["scores"][1] else 1
	if view.get("forfeit_by", -1) != -1:
		w = 1 - view["forfeit_by"]
		overlay_box.add_child(UIStyle.label("%s left and forfeited the series." % view["names"][view["forfeit_by"]], 16, UIStyle.BAD))
	overlay_box.add_child(UIStyle.label("%s wins the series (games %d–%d)." % [view["names"][w], view["scores"][0], view["scores"][1]], 22, UIStyle.TEXT, false, true))
	for h in view["history"]:
		overlay_box.add_child(UIStyle.label("Game %d: %s (turn %d, HP %d–%d)" % [h["game"], view["names"][h["winner"]], h["turns"], h["hp"][0], h["hp"][1]], 13, UIStyle.MUTED))
	var b := UIStyle.primary_button("Back to main menu", 15)
	b.pressed.connect(func(): back_to_menu.emit())
	overlay_box.add_child(b)
