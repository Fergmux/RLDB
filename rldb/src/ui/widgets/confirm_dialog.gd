class_name ConfirmDialog
extends Control
## Small centred confirmation over a dimmed screen: title, message and its choices. Clicking the
## dim or the cancel choice closes it; any other choice closes it, then runs its action.
## The one dialog used across the game (in-game menu, concede, menu screens).
##
## Two choices (`open`) sit side by side: confirm, then cancel. Three or more (`open_choices`,
## G01: Save and quit / Forfeit and quit / Keep playing) stack as one column of equal buttons in
## the order given, so long labels never crowd the plate.

const PANEL_W := 420.0
## Dim over everything behind the dialog: strong enough that a gold-rimmed modal underneath (a
## series window) recedes instead of competing with the dialog (playtest feedback 08).
const DIM_ALPHA := 0.7
## Width of each stacked button in a dialog with three or more choices.
const STACK_W := 280.0

## The choices as built: [{text, style, action}] (dev drivers and tests read it).
var choices: Array = []


## Opens a dialog as a full-rect child of `parent` (above its other content) and returns it.
## `tag` is the header strip title of the house plate (F06-01).
static func open(parent: Node, title: String, text: String, confirm: String, on_yes: Callable,
		cancel: String = "Keep playing", tag: String = "Confirm") -> ConfirmDialog:
	return open_choices(parent, title, text, [choice(confirm, on_yes, "primary"), choice(cancel)], tag)


## Opens a dialog with any number of `choices` (made with `choice`). A choice without an action
## only closes the dialog; clicking the dim does the same.
static func open_choices(parent: Node, title: String, text: String, list: Array, tag: String = "Confirm") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d._build(title, text, list, tag)
	parent.add_child(d)
	d._appear()
	return d


## One dialog choice. `style`: "primary" (gold), "danger" (red rim) or "" (plain). An empty
## `action` closes the dialog and does nothing else (the cancel choice).
static func choice(text: String, action: Callable = Callable(), style: String = "") -> Dictionary:
	return {"text": text, "action": action, "style": style}


## Closes the dialog without running any action.
func close() -> void:
	if not is_queued_for_deletion():
		queue_free()


## Presses choice `text` as a click would (dev drivers); returns false when there is none.
func press(text: String) -> bool:
	for b in find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).pressed.emit()
			return true
	return false


var _panel: HousePanel


func _build(title: String, text: String, list: Array, tag: String) -> void:
	choices = list
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = UiLayers.CONFIRM_DIALOG
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_panel = HousePanel.new(tag, "", Vector2(26, 22), 12)
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	_panel.add_headline(title, 26, true, 12.0)
	var m := UIStyle.label(text, 16, UIStyle.TEXT, true)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var stacked := list.size() > 2
	var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10 if stacked else 12)
	if stacked:
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 2)
		v.add_child(gap)
	v.add_child(row)
	for c in list:
		var b := _button(c, stacked)
		row.add_child(b)


func _button(c: Dictionary, stacked: bool) -> Button:
	var style := String(c.get("style", ""))
	var b := UIStyle.primary_button(String(c["text"]), 15) if style == "primary" else UIStyle.button(String(c["text"]), 15)
	if style == "danger":
		# The theme's plain styles resolve once the button is in the tree.
		b.ready.connect(func(): _danger(b), CONNECT_ONE_SHOT)
	b.custom_minimum_size = Vector2(STACK_W, 42) if stacked else Vector2(170 if style == "primary" else 150, 40)
	var act: Callable = c.get("action", Callable())
	b.pressed.connect(func():
		close()
		if act.is_valid():
			act.call())
	return b


## Plain button restyled with a red rim and text: a choice that cannot be undone (forfeiting).
static func _danger(b: Button) -> void:
	for st in ["normal", "hover", "pressed"]:
		var rim := UIStyle.BAD if st != "normal" else Color(UIStyle.BAD, 0.75)
		b.add_theme_stylebox_override(st, UiSurface.restyled(b.get_theme_stylebox(st), func(d: StyleBoxFlat): d.border_color = rim))
	b.add_theme_color_override("font_color", UIStyle.BAD.lightened(0.35))
	b.add_theme_color_override("font_hover_color", UIStyle.BAD.lightened(0.5))


func _appear() -> void:
	_panel.appear()
