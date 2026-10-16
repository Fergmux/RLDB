class_name ConfirmDialog
extends Control
## Small centred confirmation over a dimmed screen: title, message, a confirm button and a
## cancel button. Clicking the dim or cancel closes it; confirm closes it, then runs `on_yes`.
## The one dialog used across the game (in-game menu, concede, menu screens).

const PANEL_W := 420.0


## Opens a dialog as a full-rect child of `parent` (above its other content) and returns it.
static func open(parent: Node, title: String, text: String, confirm: String, on_yes: Callable,
		cancel: String = "Keep playing") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d._build(title, text, confirm, on_yes, cancel)
	parent.add_child(d)
	d._appear()
	return d


## Closes the dialog without running the confirm action.
func close() -> void:
	if not is_queued_for_deletion():
		queue_free()


var _panel: PanelContainer


func _build(title: String, text: String, confirm: String, on_yes: Callable, cancel: String) -> void:
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
	_panel = PanelContainer.new()
	var sb := UIStyle.panel_style(Color(0.05, 0.045, 0.04, 0.99), UIStyle.GOLD, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 22)
	sb.shadow_size = 20
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var t := UIStyle.label(title, 26, UIStyle.GOLD, false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var m := UIStyle.label(text, 16, UIStyle.TEXT, true)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var yes := UIStyle.primary_button(confirm, 15)
	yes.custom_minimum_size = Vector2(170, 40)
	yes.pressed.connect(func(): close(); on_yes.call())
	row.add_child(yes)
	var no := UIStyle.button(cancel, 15)
	no.custom_minimum_size = Vector2(150, 40)
	no.pressed.connect(close)
	row.add_child(no)


func _appear() -> void:
	if UIStyle.reduce_motion:
		return
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = Vector2(PANEL_W / 2.0, 70)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
