class_name StatsDialog
extends Control
## The player's statistics (Decks > Statistics): a house plate over a dimmed screen listing a few
## facts from PlayerStats (record, streaks, favourite cards and decks). Kept on this computer only.
## Clicking the dim, Close or Esc closes it.

const PANEL_W := 560.0
## The list scrolls inside the plate above this share of the window height.
const LIST_MAX_SHARE := 0.6
const ROW_H := 42.0


## Opens the dialog as a full-rect child of `parent` and returns it. `facts` (empty) means the
## stored record (PlayerStats.facts()).
static func open(parent: Node, facts: Array = []) -> StatsDialog:
	var d := StatsDialog.new()
	d._build(facts if not facts.is_empty() else PlayerStats.facts())
	parent.add_child(d)
	d._panel.appear()
	return d


func close() -> void:
	if not is_queued_for_deletion():
		queue_free()


var _panel: HousePanel


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		Sfx.play("back")
		close()
		get_viewport().set_input_as_handled()


func _build(facts: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = UiLayers.CONFIRM_DIALOG
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_panel = HousePanel.new("Statistics", "This computer", Vector2(26, 22), 12)
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	_panel.add_headline("Your statistics", 26, true, 12.0)
	if facts.is_empty():
		var e := UIStyle.label("Finish a duel and your record, favourite cards and best streaks will appear here.", 16, UIStyle.TEXT_DIM, true)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.custom_minimum_size = Vector2(PANEL_W - 80, 0)
		v.add_child(e)
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		for i in facts.size():
			list.add_child(_row(facts[i], i % 2 == 1))
		var max_h := maxf(260.0, parent_height() * LIST_MAX_SHARE)
		if facts.size() * ROW_H > max_h:
			var sa := ScrollArea.new()
			sa.custom_minimum_size = Vector2(0, max_h)
			sa.set_content(list)
			v.add_child(sa)
		else:
			v.add_child(list)
	var foot := UIStyle.label("Kept on this computer only.", 12, UIStyle.TEXT_DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	var close_btn := UIStyle.primary_button("Close", 15)
	close_btn.custom_minimum_size = Vector2(170, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	v.add_child(close_btn)


## Height available to the dialog (the window, before it is in the tree).
func parent_height() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_visible_rect().size.y if tree != null and tree.root != null else 900.0


## One fact: label (and its detail underneath) on the left, the value in gold on the right.
func _row(f: Dictionary, shaded: bool) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035) if shaded else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	pc.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	left.add_child(UIStyle.label(String(f["label"]), 15, UIStyle.TEXT))
	if String(f.get("detail", "")) != "":
		var d := UIStyle.label(String(f["detail"]), 12, UIStyle.TEXT_DIM)
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.custom_minimum_size = Vector2(120, 0)
		left.add_child(d)
	var val := UIStyle.label(String(f["value"]), 17, UIStyle.GOLD_HI)
	val.add_theme_font_override("font", UIStyle.font_bold())
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(val)
	return pc
