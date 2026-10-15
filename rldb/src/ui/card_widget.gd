class_name CardWidget
extends PanelContainer
## Renders one card view: artwork (or placeholder) underneath live overlays for
## cost, ATK/DEF, stance, statuses and Runes. Runtime stats are never baked into art.

signal pressed(widget: CardWidget)

const SIZES := {"board": Vector2(140, 118), "hand": Vector2(136, 172), "mini": Vector2(116, 80), "big": Vector2(220, 300)}
const ART_DIR := "res://art/cards/"

var view: Dictionary = {}
var size_kind: String = "board"
var highlighted: bool = false
var selected: bool = false
var dimmed: bool = false
var empty_text: String = ""


func setup(v, kind: String = "board", empty_label: String = "") -> CardWidget:
	view = v if v != null else {}
	size_kind = kind
	empty_text = empty_label
	custom_minimum_size = SIZES[kind]
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()
	return self


func set_marks(is_target: bool, is_selected: bool, is_dimmed: bool = false) -> void:
	highlighted = is_target
	selected = is_selected
	dimmed = is_dimmed
	_apply_frame()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _apply_frame() -> void:
	var border := Color("3a3f4c")
	var width := 1
	var bg := UIStyle.PANEL_LIGHT
	if view.is_empty():
		bg = Color("1d2029")
	elif view.get("hidden", false):
		bg = Color("2b2440")
	else:
		border = UIStyle.CATEGORY_COLORS.get(view.get("category", "unit"), border)
		width = 2
	if selected:
		border = UIStyle.SELECT
		width = 3
	if highlighted:
		border = UIStyle.TARGET
		width = 3
	add_theme_stylebox_override("panel", UIStyle.flat(bg, border, width, 7))
	modulate = Color(1, 1, 1, 0.55) if dimmed else Color.WHITE


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	_apply_frame()
	var small := size_kind in ["board", "mini"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	if view.is_empty():
		var l := UIStyle.label(empty_text, 11, UIStyle.MUTED, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(l)
		return
	if view.get("hidden", false):
		var l2 := UIStyle.label("Face-down" if view.get("zone", "") == "backrow" else "Hidden", 12, Color("b9a7e6"))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(l2)
		return
	var fs := 11 if small else 12
	# Header: cost badge + name.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 3)
	box.add_child(head)
	var cost := UIStyle.label(_cost_badge(), fs, Color("111111"))
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", UIStyle.flat(UIStyle.COST_COLORS.get(view["cost_kind"], UIStyle.ACCENT), Color.TRANSPARENT, 0, 4))
	cost_panel.add_child(cost)
	cost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.tooltip_text = view["cost_text"]
	head.add_child(cost_panel)
	var name_l := UIStyle.label(view["name"], fs, UIStyle.TEXT, true)
	# Autowrap labels report no width inside a box container; give it the card's width.
	name_l.custom_minimum_size = Vector2(SIZES[size_kind].x - 40, 0)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.max_lines_visible = 2
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_l)
	# Art (or placeholder) with type/race caption. Mini cards skip the art strip.
	var art_h: int = {"board": 14, "mini": 0, "hand": 40, "big": 130}[size_kind]
	if art_h > 0:
		box.add_child(_art_rect(art_h))
	var cat: String = view["category"]
	var is_unit := cat in ["basic_unit", "unit", "fusion", "ritual", "arcane"]
	var sub := ""
	if is_unit:
		sub = "%s · %s" % [view["race"] if view["race"] != "" else "No race", view["type"] if view["type"] != "" else "No type"]
	else:
		sub = UIStyle.CATEGORY_NAMES[cat]
	box.add_child(UIStyle.label(sub, 10, UIStyle.MUTED))
	if is_unit:
		var stats := HBoxContainer.new()
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(stats)
		stats.add_child(_stat_label("ATK", view.get("atk"), view.get("printed_atk"), small))
		stats.add_child(_stat_label("DEF", view.get("def"), view.get("printed_def"), small))
		if view.get("zone", "") == "unit":
			var st := UIStyle.label("ATK" if view["stance"] == "atk" else "DEF", 10, Color("111111"))
			var stp := PanelContainer.new()
			stp.add_theme_stylebox_override("panel", UIStyle.flat(Color("ff9f43") if view["stance"] == "atk" else Color("54a0ff"), Color.TRANSPARENT, 0, 3))
			stp.add_child(st)
			stp.tooltip_text = "Attack stance" if view["stance"] == "atk" else "Defense stance"
			stats.add_child(stp)
	if view.get("zone", "") == "backrow" and not view.get("face_up", true):
		box.add_child(UIStyle.label("Set (face-down)", 10, Color("b9a7e6")))
	# Status chips.
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 2)
	chips.add_theme_constant_override("v_separation", 1)
	box.add_child(chips)
	if view.get("runes", 0) > 0:
		chips.add_child(_chip("RUNE %d" % view["runes"], Color("5aa2ff"), "Rune counters: %d" % view["runes"]))
	for s in CardDB.STATUS_ORDER:
		var n: int = view.get("statuses", {}).get(s, 0)
		if n > 0:
			var col := Color("4cc38a") if CardDB.is_buff(s) else Color("e0605e")
			chips.add_child(_chip("%s %d" % [UIStyle.STATUS_SHORT[s], n], col, CardDB.STATUS_HELP[s]))
	if view.get("support", "full") == "unimplemented":
		box.add_child(UIStyle.label("Effect not implemented", 10, UIStyle.BAD))
	if size_kind == "big":
		var t := UIStyle.label(view.get("text", ""), 11, UIStyle.TEXT, true)
		t.custom_minimum_size = Vector2(SIZES["big"].x - 12, 0)
		box.add_child(t)
	tooltip_text = "%s\n%s" % [view["name"], view.get("text", "")]


func _cost_badge() -> String:
	match view["cost_kind"]:
		"fusion": return "F"
		"ritual": return ("?" if view.get("printed_cost") == null else str(view["printed_cost"])) + "R"
		"arcane": return str(view["printed_cost"]) + "A"
	return str(view["cost"])


func _art_rect(h: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = ART_DIR + String(view.get("art", {}).get("image", ""))
	if view.get("art", {}).get("image", "") != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
		return holder
	var c := ColorRect.new()
	var base: Color = UIStyle.type_color(view.get("type", "")) if view.has("type") else UIStyle.CATEGORY_COLORS[view["category"]]
	c.color = base.darkened(0.35)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(c)
	var glyph := UIStyle.label(_glyph(), 8 if h < 20 else (12 if h < 60 else 22), base.lightened(0.45))
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(glyph)
	return holder


func _glyph() -> String:
	var cat: String = view["category"]
	if cat in ["spell", "trap", "power"]:
		return UIStyle.CATEGORY_NAMES[cat].to_upper()
	var t: String = view.get("type", "")
	var r: String = view.get("race", "")
	return ("%s %s" % [t if t != "" else "—", r if r != "" else ""]).strip_edges().to_upper()


func _stat_label(name: String, value, printed, small: bool) -> Label:
	var text := "%s %s" % [name, "?" if value == null else str(value)]
	var col := UIStyle.TEXT
	if value != null and printed != null and view.get("zone", "") == "unit":
		if value > printed:
			col = UIStyle.GOOD
		elif value < printed:
			col = UIStyle.BAD
	var l := UIStyle.label(text, 12 if small else 13, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _chip(text: String, col: Color, tip: String) -> Control:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(col.darkened(0.45), col, 1, 3)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(UIStyle.label(text, 9, col.lightened(0.4)))
	return p
