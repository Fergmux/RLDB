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
var _sbw: float = SIDEBAR_W        # effective sidebar width in screen units
var _side_k: float = 1.0           # sidebar scale on wide windows
var _overlay_sig: int = 0
var _prompt_sig: int = 0
var _details_sig: String = ""
var _series_sig: int = 0
var _overlay_want: Vector2 = Vector2(900, 600)
var _deck_open: Dictionary = {}    # tile id -> full list expanded
var _src_uid_cache: int = -1
var _hover_opt: int = -1           # prompt option under the sidebar mouse
var _kb_uid: int = -1              # keyboard-focused card
var _kb_idx: int = 0               # keyboard-focused action in its row

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
var overlay_dim: ColorRect
var arrow: ArrowLayer
var state_chip: PanelContainer
var state_label: Label
var brow: HBoxContainer
var details_panel: PanelContainer
var details_scroll: ScrollContainer
var scroll_cue: ScrollCue
var log_panel: PanelContainer
var series_panel: PanelContainer
var series_box: VBoxContainer
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
		# Plain centre line (no ornament) and a soft gradient under the active half (no hard gold line).
		draw_line(Vector2(x0, mid_y), Vector2(x1, mid_y), Color(UIStyle.TABLE_INLAY.lightened(0.2), 0.9), 2.0)
		if glow_side >= 0:
			var y := top_edge if glow_side == 0 else bottom_edge
			var dir := -1.0 if glow_side == 0 else 1.0
			var gc := Color(UIStyle.GOLD, 0.0)
			var gs := Color(UIStyle.GOLD, 0.2)
			draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + dir * 22.0), Vector2(x0, y + dir * 22.0)]), PackedColorArray([gs, gs, gc, gc]))


## Dashed gold arrow from the acting card to the hovered target while choosing a target.
class ArrowLayer extends Control:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var on: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 55

	func _draw() -> void:
		if not on:
			return
		var d := b - a
		var length := d.length()
		if length < 24.0:
			return
		var dir := d / length
		var col := UIStyle.TARGET
		var head := 16.0
		var seg := 16.0
		var gap := 9.0
		var phase := 0.0 if UIStyle.reduce_motion else fposmod(float(Time.get_ticks_msec()) / 1000.0 * 50.0, seg + gap)
		var p := -phase
		var end := length - head * 0.8
		while p < end:
			var s0 := maxf(p, 0.0)
			var e0 := minf(p + seg, end)
			if e0 > s0:
				draw_line(a + dir * s0, a + dir * e0, Color(0, 0, 0, 0.55), 8.0)
				draw_line(a + dir * s0, a + dir * e0, col, 4.0)
			p += seg + gap
		var tip := b - dir * 4.0
		var n := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([tip, tip - dir * head + n * head * 0.55, tip - dir * head - n * head * 0.55])
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_colored_polygon(pts, col)
		draw_polyline(outline, Color(0, 0, 0, 0.7), 2.0)
		draw_circle(a, 6.0, Color(0, 0, 0, 0.6))
		draw_circle(a, 4.0, col)


## Cue shown under the details text while it continues below the fold.
class ScrollCue extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var font := UIStyle.font_bold()
		var txt := "Scroll for more"
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var cx := size.x / 2.0
		draw_rect(Rect2(0, 0, size.x, size.y), Color(UIStyle.GOLD, 0.12))
		draw_string(font, Vector2(cx - sz.x / 2.0, size.y / 2.0 + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD_HI)
		for dx in [-sz.x / 2.0 - 14.0, sz.x / 2.0 + 14.0]:
			var c := Vector2(cx + dx, size.y / 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]), UIStyle.GOLD_HI)


## Deck crest: heater shield in the deck's dominant Type colour(s) with the Type initial.
class DeckCrest extends Control:
	var types: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(56, 68)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _shield(r: Rect2) -> PackedVector2Array:
		var x := r.position.x
		var y := r.position.y
		var w := r.size.x
		var h := r.size.y
		return PackedVector2Array([Vector2(x + 0.08 * w, y), Vector2(x + 0.92 * w, y), Vector2(x + w, y + 0.12 * h), Vector2(x + w, y + 0.56 * h),
			Vector2(x + 0.5 * w, y + h), Vector2(x, y + 0.56 * h), Vector2(x, y + 0.12 * h)])

	func _draw() -> void:
		var outer := Rect2(2, 2, size.x - 4, size.y - 4)
		draw_colored_polygon(_shield(outer), UIStyle.GOLD)
		var inner := Rect2(outer.position + Vector2(3, 3), outer.size - Vector2(6, 6))
		var ip := _shield(inner)
		var c0 := UIStyle.type_color(types[0] if types.size() > 0 else "")
		draw_colored_polygon(ip, c0.darkened(0.15))
		if types.size() > 1:
			var half := Geometry2D.intersect_polygons(ip, PackedVector2Array([Vector2(size.x / 2.0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x / 2.0, size.y)]))
			for poly in half:
				draw_colored_polygon(poly, UIStyle.type_color(types[1]).darkened(0.15))
		var letter := String(types[0]).substr(0, 1) if types.size() > 0 and String(types[0]) != "" else "?"
		var font := UIStyle.font_display(700)
		var sz := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		var pos := Vector2((size.x - sz.x) / 2.0, size.y * 0.5 + 9.0)
		draw_string_outline(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4, Color(0, 0, 0, 0.8))
		draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)


## Remaining reward picks as filled / empty gems.
class PickPips extends Control:
	var left: int = 0
	var total: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var amber: Color = UIStyle.COST_COLORS["ap"]
		for i in total:
			var c := Vector2(14.0 + i * 28.0, size.y / 2.0)
			if i < left:
				draw_circle(c, 11.0, amber.darkened(0.65))
				draw_circle(c, 9.0, amber)
				draw_circle(c + Vector2(-3, -3.5), 3.5, Color(1, 1, 1, 0.35))
			else:
				draw_circle(c, 11.0, Color(0.1, 0.08, 0.06))
				draw_arc(c, 9.5, 0.0, TAU, 24, Color(amber, 0.4), 2.0)


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
	arrow = ArrowLayer.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(arrow)
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


## Binds this screen to a seat. Safe to call before the node entered the tree: it waits for _ready.
func attach(c: SeatClient) -> void:
	if not is_node_ready():
		await ready
	if client != null and client.view_changed.is_connected(_on_view):
		client.view_changed.disconnect(_on_view)
		client.status_changed.disconnect(_on_status)
	client = c
	client.view_changed.connect(_on_view)
	client.status_changed.connect(_on_status)
	selected_uid = -1
	_peek_uid = -1
	_kb_uid = -1
	_overlay_sig = 0
	_prompt_sig = 0
	_details_sig = ""
	_series_sig = 0
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
	opp_hand_count_label = UIStyle.label("", 13, UIStyle.MUTED, false, true)
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
	empty_hand_label = UIStyle.label("Your hand is empty.", 14, UIStyle.MUTED)
	empty_hand_label.modulate.a = 0.6
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
	turn_title = UIStyle.label("", 19, UIStyle.TEXT, false, true)
	turn_title.clip_text = true
	tv.add_child(turn_title)
	pips = PhasePips.new()
	tv.add_child(pips)
	brow = HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	tv.add_child(brow)
	phase_btn = UIStyle.primary_button("", 16)
	phase_btn.custom_minimum_size = Vector2(0, 44)
	phase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_btn.pressed.connect(func(): _send({"t": "next_phase"}))
	brow.add_child(phase_btn)
	# Status chip (NOT a button): shown instead of the phase button while a choice is pending.
	state_chip = PanelContainer.new()
	var cs := UIStyle.flat(Color(UIStyle.GOLD, 0.1), Color(UIStyle.GOLD, 0.55), 1, 6)
	cs.border_width_left = 6
	cs.content_margin_left = 10
	cs.content_margin_right = 8
	state_chip.add_theme_stylebox_override("panel", cs)
	state_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_chip.custom_minimum_size = Vector2(0, 44)
	state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_chip.visible = false
	state_label = UIStyle.label("", 17, UIStyle.GOLD_HI, true, true)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_chip.add_child(state_label)
	brow.add_child(state_chip)
	concede_btn = UIStyle.button("Concede", 13)
	concede_btn.custom_minimum_size = Vector2(80, 44)
	concede_btn.pressed.connect(_confirm_concede)
	brow.add_child(concede_btn)
	turn_note = UIStyle.label("", 13, Color("ff9ff3"), true)
	turn_note.visible = false
	tv.add_child(turn_note)
	# Prompt
	prompt_panel = _side_panel()
	_prompt_style = prompt_panel.get_theme_stylebox("panel") as StyleBoxFlat
	col.add_child(prompt_panel)
	prompt_box = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 4)
	prompt_panel.add_child(prompt_box)
	# Series summary (deck selection, rewards, between games, series over)
	series_panel = _side_panel()
	series_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(series_panel)
	series_box = VBoxContainer.new()
	series_box.add_theme_constant_override("separation", 6)
	series_panel.add_child(series_box)
	# Details
	details_panel = _side_panel()
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 1.15
	col.add_child(details_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	details_panel.add_child(dv)
	dv.add_child(_header("Card details"))
	details_scroll = ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(details_scroll)
	details_box = VBoxContainer.new()
	details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_box.add_theme_constant_override("separation", 4)
	details_scroll.add_child(details_box)
	scroll_cue = ScrollCue.new()
	dv.add_child(scroll_cue)
	var vb := details_scroll.get_v_scroll_bar()
	vb.changed.connect(_update_scroll_cue)
	vb.value_changed.connect(func(_v): _update_scroll_cue())
	# Log
	log_panel = _side_panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 0.95
	col.add_child(log_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	log_panel.add_child(lv)
	lv.add_child(_header("Game log"))
	var lbg := PanelContainer.new()
	lbg.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_INK, 0.85), Color(UIStyle.BRONZE, 0.4), 1, 6))
	lbg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(lbg)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.meta_clicked.connect(_on_log_meta)
	log_label.scroll_following = true
	log_label.selection_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_label.add_theme_font_size_override("bold_font_size", 14)
	lbg.add_child(log_label)


func _update_scroll_cue() -> void:
	if details_scroll == null or scroll_cue == null:
		return
	var vb := details_scroll.get_v_scroll_bar()
	var more := vb.max_value - vb.page > 3.0 and vb.value + vb.page < vb.max_value - 3.0
	if scroll_cue.visible != more:
		scroll_cue.visible = more
	scroll_cue.queue_redraw()


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
	seat_label = UIStyle.label("", 15, UIStyle.MUTED)
	seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(seat_label)
	conn_label = UIStyle.label("", 14, UIStyle.MUTED)
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
	overlay_dim = ColorRect.new()
	overlay_dim.color = Color(0, 0, 0, 0.6)
	overlay_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_dim.visible = false
	add_child(overlay_dim)
	overlay = PanelContainer.new()
	overlay.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.075, 0.065, 0.058, 0.99), UIStyle.GOLD, 12))
	overlay.visible = false
	add_child(overlay)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(sc)
	overlay_box = VBoxContainer.new()
	overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_theme_constant_override("separation", 10)
	sc.add_child(overlay_box)
	pile_popup = PanelContainer.new()
	pile_popup.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.07, 0.065, 0.06, 0.98), UIStyle.SELECT, 12))
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
	# Wide windows: the sidebar (and its text) grows a little instead of floating in empty space.
	_side_k = clampf(w / 1600.0, 1.0, 1.2)
	_sbw = SIDEBAR_W * _side_k
	_area = Rect2(0, TOP_H, w - _sbw, h - TOP_H - HAND_H)
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
	opp_hand_count_label.position = Vector2(14.0, TOP_H + 8.0 + 96.0)
	deco.mid_y = _y0 + 365.0
	deco.x0 = _ux - 30.0
	deco.x1 = _ux + 3.0 * U + 2.0 * G + 30.0
	deco.top_edge = _y0 - 8.0
	deco.bottom_edge = _y0 + BOARD_H + 8.0
	deco.queue_redraw()
	side_root.scale = Vector2(_side_k, _side_k)
	side_root.position = Vector2(w - _sbw, 0)
	side_root.size = Vector2(SIDEBAR_W, h / _side_k)
	top_strip.position = Vector2.ZERO
	top_strip.size = Vector2(w - _sbw, TOP_H)
	pause_dim.position = Vector2(0, TOP_H)
	pause_dim.size = Vector2(w - _sbw, h - TOP_H)
	pause_panel.position = (pause_dim.size - Vector2(440, 160)) / 2.0
	settings_popup.position = Vector2(w - _sbw - 400.0, TOP_H + 4.0)
	toast.position = Vector2(60, TOP_H + 4.0)
	toast.size = Vector2(_area.size.x - 120.0, 24)
	_layout_hand([], true)
	_place_opp_hand()
	_place_modals()


## Centres the stage modal (and the pile popup) in the left-hand play area.
func _place_modals() -> void:
	var region := Rect2(0, TOP_H, size.x - _sbw, size.y - TOP_H)
	overlay_dim.position = region.position
	overlay_dim.size = region.size
	var sz := Vector2(minf(_overlay_want.x, region.size.x - 40.0), minf(_overlay_want.y, region.size.y - 24.0))
	overlay.size = sz
	overlay.position = region.position + (region.size - sz) / 2.0
	pile_popup.position = Vector2(40, TOP_H + 26.0)
	pile_popup.size = Vector2(maxf(200.0, size.x - _sbw - 80.0), maxf(160.0, size.y - TOP_H - HAND_H - 40.0))


## Shrinks the modal to its content once the layout has settled (two frames).
func _fit_overlay() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not overlay.visible:
		return
	var need := overlay_box.get_combined_minimum_size().y + 40.0
	_overlay_want.y = minf(need, _overlay_want.y)
	_place_modals()


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
	# Hidden at 0: an empty stack needs no label.
	opp_hand_count_label.text = "Opponent hand: %d" % n if n > 0 else ""


func _layout_hand(new_ids: Array, instant: bool) -> void:
	var n := _hand_order.size()
	empty_hand_label.visible = n == 0 and not mv.is_empty()
	empty_hand_label.position = Vector2(_area.size.x / 2.0 - 60.0, size.y - HAND_H / 2.0 - 10.0)
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
			if holder.position.distance_to(pos) > 0.5 or (not is_hv and absf(holder.rotation - rot) > 0.001):
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
	_render_series()
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
	_src_uid_cache = _source_uid() if targeting else -1
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
	deco.glow_side = -1   # active player is shown by the plate's turn marker, not a table band
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
	w.set_marks(opt != -1, is_sel or (opt != -1 and opt in multi), targeting and opt == -1 and not (vis and cv.get("uid", -2) == _src_uid_cache))


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
		var strong := targeting and opt == -1 and uid != _src_uid_cache
		var soft := not strong and not playable and opt == -1
		wd.set_marks(opt != -1, uid == selected_uid or (opt != -1 and opt in multi), strong, soft)
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
	var stage: String = view.get("stage", "")
	var in_game := not mv.is_empty() and stage == "game"
	pips.visible = in_game
	brow.visible = in_game
	details_panel.visible = in_game
	log_panel.visible = not mv.is_empty()
	series_panel.visible = not in_game
	_update_conn()
	if not in_game:
		# Between games / before the first game nothing of the finished game's turn state is shown.
		turn_title.text = _stage_title(stage) if stage != "" else "Series"
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
	var chip := ""
	var chip_mine := false
	if mv["winner"] != -1:
		chip = "Game over"
	elif not pd.is_empty():
		var resp: bool = pd["kind"] == "trap_response"
		if pd["mine"]:
			chip_mine = true
			chip = "Your response" if resp else ("Choose a target" if _board_targeting() else "Your choice")
		else:
			chip = "Opponent is responding…" if resp else "Opponent is choosing…"
	elif mv["active"] != me():
		chip = "Opponent's turn"
	elif mv["resolving"]:
		chip = "Resolving…"
	elif label == "":
		chip = "Please wait…"
	if mv["active"] == me() and mv["first_turn"] and ok:
		tip = "No Battle Phase on the first turn."
	state_chip.visible = chip != ""
	phase_btn.visible = chip == ""
	state_label.text = chip
	state_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if chip_mine else UIStyle.MUTED)
	phase_btn.text = label
	phase_btn.disabled = not ok
	phase_btn.tooltip_text = tip
	concede_btn.disabled = mv["winner"] != -1
	var note := ""
	if mv["reversal"]:
		note = "SNEAKY SNUNDAY: card-effect gains/losses reversed"
	turn_note.text = note
	turn_note.visible = note != ""


func _update_conn() -> void:
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
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if _handle_key(ke):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel()


## Esc / right-click: close popups, cancel a cancellable prompt, otherwise unpin and clear hover.
func _cancel() -> void:
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


func _digit_of(k: int) -> int:
	if k >= KEY_1 and k <= KEY_9:
		return k - KEY_1 + 1
	if k >= KEY_KP_1 and k <= KEY_KP_9:
		return k - KEY_KP_1 + 1
	return 0


## Keyboard fallback. 1-9 pick prompt options, Enter confirms a multi-select or ends the phase,
## Esc cancels, Tab / Shift+Tab walk your actionable cards (opening the card's action row) and
## the arrow keys + Enter choose an action. Returns true when the key was used.
func _handle_key(e: InputEventKey) -> bool:
	var k: int = e.keycode
	if k == KEY_ESCAPE:
		_cancel()
		return true
	if pile_popup.visible or settings_popup.visible or pause_dim.visible or view.is_empty():
		return false
	var num := _digit_of(k)
	var is_enter: bool = k == KEY_ENTER or k == KEY_KP_ENTER
	var stage: String = view.get("stage", "")
	if stage != "game":
		if not overlay.visible:
			return false
		if stage == "decks" and view.has("starters") and num > 0 and num <= view["starters"].size() and not view["deck_ready"][me()]:
			_send({"t": "pick_starter", "index": num - 1})
			return true
		if stage == "first_player" and view.get("last_loser", -1) == me() and (num == 1 or num == 2):
			_send({"t": "first_player", "who": me() if num == 1 else 1 - me()})
			return true
		return false
	if mv.is_empty() or mv["winner"] != -1:
		return false
	var pd := _pending()
	if not pd.is_empty():
		if not pd["mine"]:
			return false
		if num > 0 and num <= pd["options"].size():
			_pick_option(pd["options"][num - 1]["i"])
			return true
		if is_enter and pd["max"] > 1 and multi.size() >= pd["min"]:
			_send({"t": "choose", "id": pd["id"], "indices": multi.duplicate()})
			return true
		return false
	if _hover_blocked() or mv.get("resolving", false):
		return false
	if k == KEY_TAB:
		_kb_cycle(-1 if e.shift_pressed else 1)
		return true
	if _kb_uid != -1 and _stack != null and not _hv.is_empty():
		var acts := _actions_for_card(_kb_uid)
		if k == KEY_UP or k == KEY_LEFT or k == KEY_DOWN or k == KEY_RIGHT:
			var step := -1 if (k == KEY_UP or k == KEY_LEFT) else 1
			_kb_idx = clampi(_kb_idx + step, 0, maxi(acts.size() - 1, 0))
			_rebuild_stack()
			return true
		if is_enter or k == KEY_SPACE:
			if _kb_idx < acts.size() and acts[_kb_idx]["ok"]:
				_run_action(_kb_uid, acts[_kb_idx])
			return true
	if is_enter and mv["active"] == me():
		for a in mv.get("actions", []):
			if a["t"] == "next_phase" and a["ok"]:
				_send({"t": "next_phase"})
				return true
	return false


## Cards of yours that currently have at least one legal action (hand first, then the field).
func _kb_cards() -> Array:
	var out := []
	if _locked():
		return out
	for uid in _hand_order:
		if _has_ok_action(uid):
			var it: Dictionary = _hand_items[uid]
			out.append({"key": "h:%d" % uid, "w": it["widget"], "holder": it["holder"], "uid": uid, "kind": "hand", "own": true})
	for zone in ["unit", "backrow", "power"]:
		var n := 6 if zone == "unit" else (3 if zone == "backrow" else 4)
		for slot in n:
			var key := _key(1, zone, slot)
			var sl: Dictionary = _slots[key]
			var wd: CardWidget = sl["widget"]
			if wd.view.is_empty() or wd.view.get("hidden", false):
				continue
			var uid2: int = wd.view.get("uid", -1)
			if uid2 != -1 and _has_ok_action(uid2):
				out.append({"key": key, "w": wd, "holder": sl["holder"], "uid": uid2, "kind": ZONE_KIND[zone], "own": true})
	return out


func _has_ok_action(uid: int) -> bool:
	for a in mv.get("actions", []):
		if a.get("uid", -1) == uid and a["ok"]:
			return true
	return false


func _kb_cycle(dir: int) -> void:
	var list := _kb_cards()
	if list.is_empty():
		return
	var cur := -1
	for i in list.size():
		if list[i]["uid"] == _kb_uid:
			cur = i
	var nxt := 0
	if cur == -1:
		nxt = 0 if dir > 0 else list.size() - 1
	else:
		nxt = wrapi(cur + dir, 0, list.size())
	var item: Dictionary = list[nxt]
	_kb_uid = item["uid"]
	_kb_idx = 0
	_hv_forced = false
	_set_hover(item)
	_hv_forced = true
	_peek_uid = _kb_uid
	_render_details()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _kb_uid != -1 and (event as InputEventMouseMotion).relative.length() > 3.0:
		_kb_uid = -1
		_hv_forced = false
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
	_update_arrow()
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
	_kb_uid = -1
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
	var uid: int = _hv["uid"]
	var sig := _stack_sig_for(uid, _actions_for_card(uid))
	if sig != _stack_sig:
		_rebuild_stack()


func _stack_sig_for(uid: int, acts: Array) -> String:
	return _act_sig(acts) + "#%d" % (_kb_idx if uid == _kb_uid else -1)


## Action row for a hovered own card. It sits OUTSIDE the card body: above a lifted hand card,
## just below a field card, so the name plate, ATK/DEF and status chips are never covered.
func _rebuild_stack() -> void:
	_clear_stack()
	if _hv.is_empty() or not _hv["own"]:
		return
	var uid: int = _hv["uid"]
	var acts := _actions_for_card(uid)
	_stack_sig = _stack_sig_for(uid, acts)
	if acts.is_empty():
		return
	var tr := _target_rect(_hv)
	var kind: String = _hv["kind"]
	var n := acts.size()
	var hand := kind == "hand"
	var bh := 28.0 if hand else 26.0
	var gap := 3.0
	var cols := 1 if (hand or n <= 2) else 2
	var rows := int(ceil(float(n) / float(cols)))
	var w := maxf(tr.size.x, 136.0)
	var bw := (w - gap * float(cols - 1)) / float(cols)
	var total := rows * bh + (rows - 1) * gap
	var x := tr.get_center().x - w / 2.0
	var top := 0.0
	if hand:
		top = tr.position.y - total - 4.0
	else:
		top = tr.end.y + 3.0
		if top + total > size.y - 6.0:
			top = tr.position.y - total - 3.0
	x = clampf(x, 4.0, maxf(4.0, _area.end.x - w - 4.0))
	top = maxf(top, TOP_H + 2.0)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size = Vector2(w, total)
	box.position = hover_layer.get_global_transform().affine_inverse() * Vector2(x, top)
	for i in n:
		var a: Dictionary = acts[i]
		var full: String = a["label"] if a["ok"] else String(a["reason"])
		var b := UIStyle.button(full, 13)
		b.size = Vector2(bw, bh)
		b.custom_minimum_size = Vector2(bw, bh)
		b.position = Vector2(float(i % cols) * (bw + gap), float(int(i / cols)) * (bh + gap))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = full
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if a["ok"] else Control.CURSOR_ARROW
		var primary: bool = i == 0 and a["ok"]
		var kbf: bool = uid == _kb_uid and i == _kb_idx
		var nrm := UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.98), UIStyle.SELECT if kbf else (UIStyle.GOLD if primary else UIStyle.BRONZE), 3 if kbf else (2 if primary else 1), 6)
		var hov := UIStyle.flat(Color(UIStyle.PANEL_LIGHT.lightened(0.12), 0.99), UIStyle.GOLD_HI, 2, 6)
		var dis := UIStyle.flat(Color(UIStyle.PANEL_INK, 0.95), Color(UIStyle.BRONZE, 0.5), 1, 6)
		for st in [nrm, hov, dis]:
			st.content_margin_top = 1
			st.content_margin_bottom = 1
			st.content_margin_left = 4
			st.content_margin_right = 4
		b.add_theme_stylebox_override("normal", nrm)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("disabled", dis)
		b.add_theme_color_override("font_disabled_color", UIStyle.MUTED)
		if a["ok"]:
			b.pressed.connect(_run_action.bind(uid, a))
		else:
			b.disabled = true
		box.add_child(b)
	hover_layer.add_child(box)
	_stack = box
	if not UIStyle.reduce_motion:
		box.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(UIStyle.dur(0.05))
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
	var pd := _pending()
	var sig := hash([view.get("stage", ""), view.get("net", {}), pd, mv.get("active", -1), mv.get("winner", -1), mv.get("resolving", false),
		multi, _overlay_hidden_by_user, view.get("deck_ready", []), view.get("you", 0)])
	if sig == _prompt_sig:
		return
	_prompt_sig = sig
	_clear(prompt_box)
	_hover_opt = -1
	var decision := false
	if _render_net_banner():
		prompt_box.add_child(UIStyle.label("Match paused. Nothing can happen until both players are connected.", 14, UIStyle.MUTED, true))
		_prompt_pulse(false)
		return
	if view.get("stage", "") != "game" or mv.is_empty():
		if _overlay_hidden_by_user and view.get("stage", "") != "game":
			var back := UIStyle.button("Return to %s" % _stage_title(view.get("stage", "")), 15)
			back.pressed.connect(func(): _overlay_hidden_by_user = false; _render_all())
			prompt_box.add_child(back)
		else:
			prompt_box.add_child(UIStyle.label(_stage_hint(), 15, UIStyle.MUTED, true))
		_prompt_pulse(false)
		return
	if mv["winner"] != -1:
		prompt_box.add_child(UIStyle.label("Game over: %s wins." % _pv(mv["winner"])["name"], 17, UIStyle.ACCENT, true, true))
	elif pd.is_empty():
		var txt := "Your turn. Hover a card (or press Tab) to see what it can do." if mv["active"] == me() else "Opponent's turn."
		if mv["resolving"]:
			txt = "Resolving…"
		prompt_box.add_child(UIStyle.label(txt, 15, UIStyle.TEXT if mv["active"] == me() else UIStyle.MUTED, true))
	elif not pd["mine"]:
		prompt_box.add_child(UIStyle.label(pd["prompt"], 15, UIStyle.ACCENT, true))
		prompt_box.add_child(UIStyle.label("You cannot act until this choice is made.", 13, UIStyle.MUTED, true))
	else:
		decision = true
		_render_choice(pd)
	_prompt_pulse(decision)


func _render_choice(pd: Dictionary) -> void:
	prompt_box.add_child(UIStyle.label(pd["prompt"], 16, UIStyle.TARGET, true))
	if _board_targeting():
		prompt_box.add_child(UIStyle.label("Click a highlighted card or zone, or pick below (keys 1-9).", 13, UIStyle.MUTED, true))
	if pd["kind"] == "trap_response":
		prompt_box.add_child(UIStyle.label("Your opponent is waiting. Activate a Trap or pass.", 13, UIStyle.MUTED, true))
	# Cards shown only for this selection (e.g. a hidden pile) get previews; everything
	# else (zones, field cards, yes/no) is a full-width text button.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	prompt_box.add_child(flow)
	prompt_box.add_child(list)
	var shown := 0
	for o in pd["options"]:
		var chosen: bool = o["i"] in multi
		var idx: int = o["i"]
		shown += 1
		if o.has("card") and not o.has("ref"):
			var cell := VBoxContainer.new()
			var w := CardWidget.new().setup(o["card"], "mini")
			w.show_tooltip = false
			w.set_marks(true, chosen)
			w.pressed.connect(func(_w): _pick_option(idx))
			cell.add_child(w)
			var b := UIStyle.button(("✓ " if chosen else "") + ("%d  " % shown if shown <= 9 else "") + "Choose", 13)
			b.pressed.connect(_pick_option.bind(idx))
			cell.add_child(b)
			flow.add_child(cell)
		else:
			var b2 := UIStyle.button(("✓ " if chosen else "") + ("%d · " % shown if shown <= 9 else "") + o["label"], 14)
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b2.tooltip_text = o["label"]
			b2.pressed.connect(_pick_option.bind(idx))
			b2.mouse_entered.connect(func(): _hover_opt = idx)
			b2.mouse_exited.connect(func(): if _hover_opt == idx: _hover_opt = -1)
			list.add_child(b2)
	if pd["max"] > 1:
		var total_txt := ""
		if pd.get("min_total", 0) > 0:
			var total := 0
			for i in multi:
				total += maxi(pd["options"][i].get("card", {}).get("cost", 0), 0)
			total_txt = "  ·  cost total %d / %d" % [total, pd["min_total"]]
		prompt_box.add_child(UIStyle.label("Selected %d (choose %d–%d)%s" % [multi.size(), pd["min"], pd["max"], total_txt], 13, UIStyle.MUTED))
		var confirm := UIStyle.primary_button("Confirm selection  (Enter)", 15)
		confirm.disabled = multi.size() < pd["min"]
		confirm.pressed.connect(func(): _send({"t": "choose", "id": pd["id"], "indices": multi.duplicate()}))
		prompt_box.add_child(confirm)
	if pd["cancellable"]:
		var cancel := UIStyle.button("Cancel  (Esc)", 14)
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
	var duid := _details_uid()
	var c := _find_card(duid)
	var notes := []
	if not c.is_empty():
		for a in mv.get("actions", []):
			if a.get("uid", -1) == duid and not a["ok"] and a.get("reason", "") != "":
				notes.append("Cannot %s: %s" % [String(a["label"]).to_lower(), a["reason"]])
	var uid_key := duid if not c.is_empty() else -1
	var sig := "%d|%d|%d" % [uid_key, hash(c), hash(notes)]
	if sig == _details_sig:
		return
	var same_card: bool = _details_sig.begins_with("%d|" % uid_key)
	_details_sig = sig
	var keep: int = details_scroll.scroll_vertical if same_card else 0
	_clear(details_box)
	_build_details(c, notes)
	details_scroll.set_deferred("scroll_vertical", keep)
	_update_scroll_cue.call_deferred()


func _build_details(c: Dictionary, notes: Array) -> void:
	if c.is_empty():
		details_box.add_child(UIStyle.label("Hover a card to read it, or click it to pin it here. Right-click or Esc to clear.", 14, UIStyle.MUTED, true))
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
		details_box.add_child(UIStyle.label("• " + part, 13, UIStyle.MUTED, true))
	var any_status := false
	if c.get("runes", 0) > 0:
		details_box.add_child(UIStyle.label("Rune ×%d — %s" % [c["runes"], CardDB.STATUS_HELP["rune"]], 14, Color("8fc1ff"), true))
		any_status = true
	for s in CardDB.STATUS_ORDER:
		var n: int = c.get("statuses", {}).get(s, 0)
		if n > 0:
			any_status = true
			var buff := CardDB.is_buff(s)
			details_box.add_child(UIStyle.label("%s %s ×%d — %s" % ["Buff:" if buff else "Debuff:", s.capitalize(), n, CardDB.STATUS_HELP[s]], 14, Color("9be7b7") if buff else Color("ff9d9d"), true))
	if not any_status and c.has("race"):
		details_box.add_child(UIStyle.label("No statuses.", 13, UIStyle.MUTED))
	var text: String = c.get("text", "")
	details_box.add_child(UIStyle.label(text if text != "" else "No effect text.", 15, UIStyle.TEXT, true))
	var sup: String = c.get("support", "full")
	if sup != "full":
		details_box.add_child(UIStyle.label("Implementation: %s" % sup, 13, UIStyle.BAD, true))
	for n in notes:
		details_box.add_child(UIStyle.label(n, 13, UIStyle.MUTED, true))


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

const LOG_BACKFILL := 100   # entries shown when (re)attaching; the full history is one click away
var _log_full := false


## Re-renders the whole game log on request (the history must stay reviewable).
func _on_log_meta(meta) -> void:
	if str(meta) == "show_all":
		_log_full = true
		_log_game = -1
		_render_log()


func _render_log() -> void:
	if mv.is_empty():
		return
	var game_no: int = view.get("game_no", 0)
	var entries: Array = mv.get("log", [])
	var fresh_game := game_no != _log_game
	if fresh_game:
		log_label.clear()
		_log_seq_shown = 0
		_log_game = game_no
		log_label.append_text("[color=#f2b544][b]Game %d[/b][/color]
" % game_no)
		# Re-attaching (hot-seat seat swap, reconnect) must not re-parse the whole history.
		if entries.size() > LOG_BACKFILL and not _log_full:
			_log_seq_shown = int(entries[entries.size() - LOG_BACKFILL - 1]["seq"])
			log_label.append_text("[color=#d4a64a][url=show_all](%d earlier entries — click to show the full history)[/url][/color]
" % (entries.size() - LOG_BACKFILL))
		_log_full = false
	# Only walk the new tail of the log, not the whole array every view.
	var start := entries.size()
	while start > 0 and int(entries[start - 1]["seq"]) > _log_seq_shown:
		start -= 1
	for i in range(start, entries.size()):
		var e: Dictionary = entries[i]
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
		log_label.append_text("[color=%s]%s[/color]
" % [col, body])


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
	var stage: String = view.get("stage", "")
	var sig := 1
	if stage != "game":
		var vv := view.duplicate()
		vv.erase("match")
		sig = hash([vv, _overlay_hidden_by_user, _deck_open])
	if sig == _overlay_sig:
		return
	_overlay_sig = sig
	_clear(overlay_box)
	if stage == "game" or stage == "" or _overlay_hidden_by_user:
		overlay.visible = false
		overlay_dim.visible = false
		return
	overlay.visible = true
	overlay_dim.visible = true
	_clear_hover()
	var want := Vector2(1000, 800)
	match stage:
		"decks": want = Vector2(1180, 860)
		"rewards": want = Vector2(1040, 900)
		"first_player": want = Vector2(620, 420)
		"over": want = Vector2(660, 760)
	_overlay_want = want
	overlay_box.custom_minimum_size = Vector2(want.x - 56.0, 0)
	if stage != "over":
		var head := VBoxContainer.new()
		head.add_theme_constant_override("separation", 2)
		overlay_box.add_child(head)
		head.add_child(UIStyle.label(_stage_title(stage), 30, UIStyle.GOLD, false, true))
		head.add_child(UIStyle.label("Score %d – %d  ·  best of %d" % [view["scores"][0], view["scores"][1], view["best_of"]], 16, UIStyle.MUTED))
	match stage:
		"decks": _render_decks()
		"rewards": _render_rewards()
		"first_player": _render_first()
		"over": _render_over()
	if not mv.is_empty() and stage != "decks":
		var see := UIStyle.button("View the final board and log of game %d" % view["game_no"], 14)
		see.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		see.pressed.connect(func(): _overlay_hidden_by_user = true; _render_all())
		overlay_box.add_child(see)
	_place_modals()
	_fit_overlay()


# ---------------------------------------------------------------- target arrow

## Dashed arrow from the acting card to the hovered legal target (board or sidebar list).
func _update_arrow() -> void:
	var on := false
	if arrow != null and not mv.is_empty() and not overlay.visible and _board_targeting():
		var src := _source_rect()
		var dst := _hovered_target_rect()
		if src.size != Vector2.ZERO and dst.size != Vector2.ZERO:
			var inv := arrow.get_global_transform().affine_inverse()
			arrow.a = inv * src.get_center()
			arrow.b = inv * dst.get_center()
			on = true
	if on or arrow.on:
		arrow.on = on
		arrow.queue_redraw()


func _source_rect() -> Rect2:
	var uid := _source_uid()
	if uid == -1:
		return Rect2()
	for k in _slots.keys():
		if (k as String).begins_with("1:"):
			var sl: Dictionary = _slots[k]
			if (sl["widget"] as CardWidget).view.get("uid", -9) == uid:
				return (sl["holder"] as Control).get_global_rect()
	if _hand_items.has(uid):
		return (_hand_items[uid]["holder"] as Control).get_global_rect()
	return Rect2()


func _source_uid() -> int:
	var pd := _pending()
	var re := RegEx.new()
	re.compile("for (.+?)[.?:]?$")
	var m := re.search(String(pd.get("prompt", "")))
	if m != null:
		var nm := m.get_string(1)
		for c in _pv(me())["units"]:
			if c != null and not c.get("hidden", false) and c.get("name", "") == nm:
				return c["uid"]
	if selected_uid != -1 and _is_mine_card(selected_uid):
		return selected_uid
	return -1


func _is_mine_card(uid: int) -> bool:
	var pv := _pv(me())
	for z in ["units", "backrow", "powers", "hand"]:
		for c in pv.get(z, []):
			if c != null and c.get("uid", -9) == uid:
				return true
	return false


func _hovered_target_rect() -> Rect2:
	if _hover_opt != -1:
		return _option_rect(_hover_opt)
	var m := get_global_mouse_position()
	for k in _slots.keys():
		var parts: PackedStringArray = (k as String).split(":")
		var pidx := me() if int(parts[0]) == 1 else 1 - me()
		if _option_for_ref(pidx, parts[1], int(parts[2])) != -1:
			var r: Rect2 = (_slots[k]["holder"] as Control).get_global_rect()
			if r.has_point(m):
				return r
	return Rect2()


func _option_rect(i: int) -> Rect2:
	var pd := _pending()
	for o in pd.get("options", []):
		if o["i"] != i:
			continue
		if o.has("ref"):
			return fx_slot_global_rect(o["ref"]["p"], o["ref"]["zone"], o["ref"]["slot"])
		if o.has("slot"):
			var oz: String = o.get("zone", "")
			var mapped := "unit" if oz in ["unit", "adjacent", "column", "orig"] else oz
			return fx_slot_global_rect(me(), mapped, o["slot"])
		if o.has("card") and _hand_items.has(o["card"].get("uid", -1)):
			return (_hand_items[o["card"]["uid"]]["holder"] as Control).get_global_rect()
	return Rect2()


## Sidebar summary shown instead of the turn/log panels while no game is being played.
func _render_series() -> void:
	if view.is_empty() or view.get("stage", "") == "game":
		return
	var stage: String = view.get("stage", "")
	var sig := hash([stage, view.get("scores"), view.get("history"), view.get("deck_ready"), view.get("names"), view.get("best_of"), view.get("you"), view.get("game_no")])
	if sig == _series_sig:
		return
	_series_sig = sig
	_clear(series_box)
	series_box.add_child(_header("Series"))
	var names: Array = view["names"]
	for p in 2:
		var row := HBoxContainer.new()
		series_box.add_child(row)
		var nm := UIStyle.label(String(names[p]) + ("  (you)" if p == me() else ""), 17, UIStyle.TEXT, false, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		row.add_child(UIStyle.label(str(view["scores"][p]), 24, UIStyle.GOLD, false, true))
		if stage == "decks":
			series_box.add_child(UIStyle.label("Deck ready" if view["deck_ready"][p] else "Choosing a deck…", 14, UIStyle.GOOD if view["deck_ready"][p] else UIStyle.MUTED))
	series_box.add_child(UIStyle.label("Best of %d" % view["best_of"], 14, UIStyle.MUTED))
	for h in view.get("history", []):
		series_box.add_child(UIStyle.label("Game %d: %s won (turn %d)" % [h["game"], names[h["winner"]], h["turns"]], 14, UIStyle.TEXT, true))


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
		overlay_box.add_child(UIStyle.label("Deck locked in: %s. Waiting for your opponent…" % view["deck_name"], 18, UIStyle.TEXT, true))
		return
	if view.has("starters"):
		overlay_box.add_child(UIStyle.label("Pick a starter deck (keys 1-%d)" % view["starters"].size(), 15, UIStyle.MUTED))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		overlay_box.add_child(grid)
		for i in view["starters"].size():
			var s: Dictionary = view["starters"][i]
			var idx: int = i
			grid.add_child(_deck_tile("s%d" % i, s["name"], s["theme"], s["main"], s["extra"], "Choose %s" % s["name"], func(): _send({"t": "pick_starter", "index": idx})))
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
	overlay_box.add_child(UIStyle.label("Picked: " + ", ".join(dr["picked"].map(func(c): return c["name"])), 13, UIStyle.MUTED, true))


## Saved custom decks (not offered in draft mode), as tiles like the starters.
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
	overlay_box.add_child(UIStyle.label("Your saved decks", 22, UIStyle.GOLD, false, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_box.add_child(grid)
	var n := 0
	for d in decks:
		var main := []
		var extra := []
		for id in d["cards"]:
			var def := CardDB.get_def(int(id))
			if def.is_empty():
				continue
			var sm := Series._card_summary(int(id))
			if CardDB.is_extra_category(def["category"]):
				extra.append(sm)
			else:
				main.append(sm)
		var deck: Dictionary = d
		grid.add_child(_deck_tile("c%d" % n, d["name"], "Custom deck", main, extra, "Use this deck", func(): _send({"t": "custom_deck", "cards": deck["cards"], "name": deck["name"]})))
		n += 1


func _dominant_types(cards: Array) -> Array:
	var counts := {}
	for c in cards:
		var t: String = c.get("type", "")
		if t != "" and c.get("atk") != null:
			counts[t] = counts.get(t, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var out := []
	for k in keys:
		if out.is_empty() or (out.size() < 2 and counts[k] * 3 >= counts[keys[0]]):
			out.append(k)
	return out


func _key_cards(main: Array, extra: Array) -> Array:
	var out := []
	var seen := {}
	for c in extra:
		if out.size() < 2 and not seen.has(c["id"]):
			seen[c["id"]] = true
			out.append(c)
	var units := main.filter(func(c): return c["category"] != "basic_unit" and c.get("atk") != null)
	units.sort_custom(func(a, b): return int(a["atk"]) + int(a["def"]) > int(b["atk"]) + int(b["def"]))
	for c in units:
		if out.size() < 5 and not seen.has(c["id"]):
			seen[c["id"]] = true
			out.append(c)
	for c in main:
		if out.size() < 5 and not seen.has(c["id"]) and c["category"] != "basic_unit":
			seen[c["id"]] = true
			out.append(c)
	return out


func _grouped_names(cards: Array) -> String:
	var order := []
	var n := {}
	for c in cards:
		if not n.has(c["id"]):
			order.append(c)
		n[c["id"]] = n.get(c["id"], 0) + 1
	return ", ".join(order.map(func(c): return c["name"] + (" ×%d" % n[c["id"]] if n[c["id"]] > 1 else "")))


func _pill(text: String, col: Color, fs: int = 13) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(col.darkened(0.7), 0.95), col, 1, 10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(UIStyle.label(text, fs, col.lightened(0.55)))
	return p


## One deck tile: crest, name, theme blurb, Main/Extra counts, key cards and a full-list toggle.
func _deck_tile(id: String, title: String, theme: String, main: Array, extra: Array, btn_text: String, on_pick: Callable) -> Control:
	var tile := PanelContainer.new()
	var sb := UIStyle.panel_style(Color(UIStyle.PANEL_LIGHT, 0.98), UIStyle.BRONZE, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	tile.add_theme_stylebox_override("panel", sb)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tile.add_child(row)
	var types := _dominant_types(main)
	var crest := DeckCrest.new()
	crest.types = types
	crest.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(crest)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UIStyle.label(title, 22, UIStyle.TEXT, true, true))
	col.add_child(UIStyle.label(theme, 15, UIStyle.MUTED, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	col.add_child(chips)
	chips.add_child(_pill("Main %d" % main.size(), UIStyle.GOLD))
	chips.add_child(_pill("Extra %d" % extra.size(), Color("9d7ae8")))
	for t in types:
		chips.add_child(_pill(String(t), UIStyle.type_color(t)))
	var keys := _key_cards(main, extra)
	if not keys.is_empty():
		col.add_child(UIStyle.label("Key cards", 13, UIStyle.GOLD))
		var kf := HFlowContainer.new()
		kf.add_theme_constant_override("h_separation", 5)
		kf.add_theme_constant_override("v_separation", 4)
		col.add_child(kf)
		for c in keys:
			var pill := _pill(c["name"], UIStyle.CATEGORY_COLORS.get(c["category"], UIStyle.BRONZE), 13)
			pill.tooltip_text = "%s (%s)\n%s" % [c["name"], UIStyle.CATEGORY_NAMES.get(c["category"], ""), c["text"]]
			kf.add_child(pill)
	var open: bool = _deck_open.get(id, false)
	if open:
		col.add_child(UIStyle.label("Main deck (%d)" % main.size(), 13, UIStyle.GOLD))
		col.add_child(UIStyle.label(_grouped_names(main), 14, UIStyle.TEXT, true))
		col.add_child(UIStyle.label("Extra Deck (%d)" % extra.size(), 13, UIStyle.GOLD))
		col.add_child(UIStyle.label(_grouped_names(extra) if not extra.is_empty() else "None", 14, UIStyle.TEXT, true))
	var brow2 := HBoxContainer.new()
	brow2.add_theme_constant_override("separation", 8)
	col.add_child(brow2)
	var tog := UIStyle.button("Hide full list" if open else "View full list", 13)
	tog.pressed.connect(func(): _deck_open[id] = not _deck_open.get(id, false); _overlay_sig = 0; _render_overlay())
	brow2.add_child(tog)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow2.add_child(sp)
	var pick := UIStyle.primary_button(btn_text, 15)
	pick.pressed.connect(on_pick)
	brow2.add_child(pick)
	return tile


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


func _resize_card(w: CardWidget, sz: Vector2) -> void:
	w.custom_minimum_size = sz
	w.size = sz
	w.pivot_offset = sz / 2.0


func _render_rewards() -> void:
	var line := _game_result_line()
	if line != "":
		overlay_box.add_child(UIStyle.label(line, 16, UIStyle.TEXT, true))
	var r: Dictionary = view["rewards"]
	if r["done"]:
		overlay_box.add_child(UIStyle.label("You have finished choosing rewards. Waiting for your opponent…" if not r["opponent_done"] else "Starting soon…", 17, UIStyle.TEXT, true))
		for t in r["taken"]:
			overlay_box.add_child(UIStyle.label("• " + t, 14, UIStyle.MUTED))
		return
	# Picks remaining
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 12)
	overlay_box.add_child(pr)
	var total: int = r["left"] + r["taken"].size()
	var pips_c := PickPips.new()
	pips_c.left = r["left"]
	pips_c.total = maxi(total, r["left"])
	pips_c.custom_minimum_size = Vector2(maxf(28.0, pips_c.total * 28.0 + 4.0), 28)
	pr.add_child(pips_c)
	pr.add_child(UIStyle.label("%d pick%s remaining" % [r["left"], "" if r["left"] == 1 else "s"], 20, UIStyle.ACCENT, false, true))
	overlay_box.add_child(UIStyle.label("Each pick is one of: add a card, remove a card, or change a basic unit's Type.", 14, UIStyle.MUTED, true))
	if r["opponent_done"]:
		overlay_box.add_child(UIStyle.label("Your opponent has finished.", 13, UIStyle.MUTED))
	for t in r["taken"]:
		overlay_box.add_child(UIStyle.label("✓ " + t, 14, UIStyle.GOOD))
	# Add a card
	overlay_box.add_child(UIStyle.label("Add a card — pick one", 18, UIStyle.GOLD, false, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 10)
	overlay_box.add_child(flow)
	for i in r["offer"].size():
		var c: Dictionary = r["offer"][i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var cw := CardWidget.new().setup(_summary_view(c), "big")
		cw.show_tooltip = false
		_resize_card(cw, Vector2(180, 252))
		var idx: int = i
		cw.pressed.connect(func(_w): _send({"t": "reward_add", "index": idx}))
		cell.add_child(cw)
		var b := UIStyle.primary_button("Add %s" % c["name"], 13)
		b.clip_text = true
		b.custom_minimum_size = Vector2(180, 0)
		b.pressed.connect(func(): _send({"t": "reward_add", "index": idx}))
		cell.add_child(b)
		flow.add_child(cell)
	var counts := {}
	var order := []
	for c in view["deck"]:
		if not counts.has(c["id"]):
			order.append(c)
		counts[c["id"]] = counts.get(c["id"], 0) + 1
	# Remove a card (list + preview) and change a basic type, side by side
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	overlay_box.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(UIStyle.label("Remove a card from your deck", 18, UIStyle.GOLD, false, true))
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 10)
	left.add_child(lr)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.custom_minimum_size = Vector2(0, 260)
	lsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(lsc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 3)
	lsc.add_child(lv)
	var prev_panel := PanelContainer.new()
	prev_panel.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_INK, 0.9), Color(UIStyle.BRONZE, 0.6), 1, 8))
	lr.add_child(prev_panel)
	var prev := CardWidget.new()
	prev.show_tooltip = false
	prev.auto_hover = false
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.setup(_summary_view(order[0]) if not order.is_empty() else null, "big")
	_resize_card(prev, Vector2(180, 252))
	prev_panel.add_child(prev)
	for c in order:
		var b2 := UIStyle.button("− %s%s" % [c["name"], " ×%d" % counts[c["id"]] if counts[c["id"]] > 1 else ""], 16)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.clip_text = true
		var cc: Dictionary = c
		b2.mouse_entered.connect(func():
			prev.setup(_summary_view(cc), "big")
			_resize_card(prev, Vector2(180, 252)))
		b2.pressed.connect(func(): _send({"t": "reward_remove", "card_id": cc["id"]}))
		lv.add_child(b2)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(UIStyle.label("Change a basic unit's Type", 18, UIStyle.GOLD, false, true))
	right.add_child(UIStyle.label("Applies to all copies.", 14, UIStyle.MUTED))
	for c in order:
		if c["category"] != "basic_unit":
			continue
		right.add_child(UIStyle.label("%s ×%d  (now %s)" % [c["name"], counts[c["id"]], c["type"] if c["type"] != "" else "None"], 15, UIStyle.TEXT))
		var tf := HFlowContainer.new()
		tf.add_theme_constant_override("h_separation", 4)
		tf.add_theme_constant_override("v_separation", 4)
		right.add_child(tf)
		for t in r["basic_types"]:
			if t == c["type"]:
				continue
			var tb := UIStyle.button(t, 14)
			tb.add_theme_color_override("font_color", UIStyle.type_color(t).lightened(0.35))
			var cid: int = c["id"]
			tb.pressed.connect(func(): _send({"t": "reward_basic", "from_id": cid, "to_type": t}))
			tf.add_child(tb)
	var fin := UIStyle.primary_button("Finish rewards" if not r["taken"].is_empty() else "Skip remaining rewards", 16)
	fin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fin.pressed.connect(func(): _send({"t": "reward_finish"}))
	overlay_box.add_child(fin)


func _render_first() -> void:
	var line := _game_result_line()
	if line != "":
		overlay_box.add_child(UIStyle.label(line, 17, UIStyle.TEXT, true))
	if view["last_loser"] == me():
		overlay_box.add_child(UIStyle.label("You lost the last game, so you choose who goes first in game %d." % (view["game_no"] + 1), 18, UIStyle.ACCENT, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		overlay_box.add_child(row)
		var b1 := UIStyle.primary_button("I go first  (1)", 17)
		b1.pressed.connect(func(): _send({"t": "first_player", "who": me()}))
		row.add_child(b1)
		var b2 := UIStyle.button("My opponent goes first  (2)", 17)
		b2.pressed.connect(func(): _send({"t": "first_player", "who": 1 - me()}))
		row.add_child(b2)
	else:
		overlay_box.add_child(UIStyle.label("Your opponent lost the last game and is choosing who goes first…", 17, UIStyle.TEXT, true))


func _render_over() -> void:
	var w := 0 if view["scores"][0] > view["scores"][1] else 1
	var forfeit: int = view.get("forfeit_by", -1)
	if forfeit != -1:
		w = 1 - forfeit
	var won: bool = w == me()
	var res := UIStyle.label("VICTORY" if won else "DEFEAT", 64, UIStyle.GOLD_HI if won else UIStyle.BAD, false, true)
	res.add_theme_font_override("font", UIStyle.font_display(700))
	res.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	res.add_theme_constant_override("outline_size", 6)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(res)
	var sub := UIStyle.label("%s wins the series" % view["names"][w], 20, UIStyle.TEXT, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	if forfeit != -1:
		var ff := UIStyle.label("%s left and forfeited the series." % view["names"][forfeit], 16, UIStyle.BAD, true)
		ff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(ff)
	var score := HBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_CENTER
	score.add_theme_constant_override("separation", 18)
	overlay_box.add_child(score)
	score.add_child(UIStyle.label(view["names"][0], 20, UIStyle.TEXT, false, true))
	score.add_child(UIStyle.label("%d – %d" % [view["scores"][0], view["scores"][1]], 40, UIStyle.GOLD, false, true))
	score.add_child(UIStyle.label(view["names"][1], 20, UIStyle.TEXT, false, true))
	overlay_box.add_child(UIStyle.label("Game history", 16, UIStyle.GOLD, false, true))
	for h in view["history"]:
		var hw: bool = h["winner"] == me()
		var rowp := PanelContainer.new()
		rowp.add_theme_stylebox_override("panel", UIStyle.flat(Color(UIStyle.PANEL_LIGHT, 0.9), Color(UIStyle.GOOD if hw else UIStyle.BAD, 0.7), 1, 6))
		overlay_box.add_child(rowp)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		rowp.add_child(hb)
		hb.add_child(_pill("WIN" if hw else "LOSS", UIStyle.GOOD if hw else UIStyle.BAD))
		var t := UIStyle.label("Game %d — %s won" % [h["game"], view["names"][h["winner"]]], 16, UIStyle.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(t)
		hb.add_child(UIStyle.label("Turn %d · HP %d–%d" % [h["turns"], h["hp"][0], h["hp"][1]], 14, UIStyle.MUTED))
	var b := UIStyle.primary_button("Back to main menu", 17)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): back_to_menu.emit())
	overlay_box.add_child(b)


