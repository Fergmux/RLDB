class_name ConfirmDialog
extends Control
## Small centred confirmation over a dimmed screen: title, message and its choices. Clicking the
## dim or the cancel choice closes it; any other choice closes it, then runs its action.
## The one dialog used across the game (in-game menu, concede, menu screens).
##
## Two choices (`open`) sit side by side: confirm, then cancel. Three or more (`open_choices`,
## G01: Save and quit / Forfeit and quit / Keep playing) stack as one column of equal buttons in
## the order given, so long labels never crowd the plate.
##
## Button hierarchy (design review 1.4.4, #69-#71): a "primary" choice is the gold family, a
## "danger" choice (Concede, Delete, Forfeit: cannot be undone) the ember family, and every other
## choice (Cancel, Keep playing) the iron secondary. When a danger choice is offered, the cancel
## choice holds the keyboard focus, so Enter keeps the player safe; otherwise the confirm does.
## Spacing: 20 px from the message to the buttons, 24 px under them, 44 px buttons, 160 px wide.

const PANEL_W := 420.0
## Dim over everything behind the dialog: strong enough that a gold-rimmed modal underneath (a
## series window) recedes instead of competing with the dialog (playtest feedback 08).
const DIM_ALPHA := 0.7
## Width of each stacked button in a dialog with three or more choices.
const STACK_W := 280.0
## Side-by-side buttons: minimum width and height (design review #71).
const BUTTON_W := 160.0
const BUTTON_H := 44.0
## Message-to-buttons gap and the padding under the button row.
const TEXT_TO_BUTTONS := 20
const BOTTOM_PAD := 24

## The choices as built: [{text, style, action}] (dev drivers and tests read it).
var choices: Array = []


## Opens a dialog as a full-rect child of `parent` (above its other content) and returns it.
## `tag` is the header strip title of the house plate (F06-01). `style` is the confirm's family:
## "primary", or "danger" for a step that cannot be undone (the cancel then holds the focus).
static func open(parent: Node, title: String, text: String, confirm: String, on_yes: Callable,
		cancel: String = "Keep playing", tag: String = "Confirm", style: String = "primary") -> ConfirmDialog:
	return open_choices(parent, title, text, [choice(confirm, on_yes, style), choice(cancel)], tag)


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


## Closes the dialog without running any action. `cue` plays panel_close (a dismissal: the dim or a
## cancel choice); a choice with an action closes silently and keeps its own click.
func close(cue: bool = true) -> void:
	if not is_queued_for_deletion():
		if cue:
			Sfx.play("panel_close")
		queue_free()


## Presses choice `text` as a click would (dev drivers); returns false when there is none.
func press(text: String) -> bool:
	for b in find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).pressed.emit()
			return true
	return false


var _panel: HousePanel
var _focus_button: Button
## The SCREEN-tier headline (D3); it sweeps once when the dialog opens.
var _headline: TitleText


## The button holding the default keyboard focus (the cancel when a danger choice is offered).
func focus_button() -> Button:
	return _focus_button


## The button of choice `text`, or null.
func button_for(text: String) -> Button:
	for b in find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


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
	_panel = HousePanel.new(tag, "", Vector2(26, BOTTOM_PAD), 12)
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	_headline = TitleText.apply(_panel.add_headline(title, 26, true, 12.0), TitleText.Tier.SCREEN, 26)
	var m := UIStyle.label(text, 16, UIStyle.TEXT, true)
	m.add_theme_constant_override("line_spacing", 5)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var stacked := list.size() > 2
	var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10 if stacked else 12)
	if stacked:
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The body separation (12) plus this spacer is the 20 px message-to-buttons gap.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, TEXT_TO_BUTTONS - 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	v.add_child(row)
	var has_danger := list.any(func(c): return String(c.get("style", "")) == "danger")
	var first_confirm: Button = null
	for c in list:
		var b := _button(c, stacked)
		row.add_child(b)
		var is_cancel := not (c.get("action", Callable()) as Callable).is_valid()
		if has_danger and is_cancel and _focus_button == null:
			_focus_button = b
		if not has_danger and not is_cancel and first_confirm == null:
			first_confirm = b
	if _focus_button == null:
		_focus_button = first_confirm


func _ready() -> void:
	if _focus_button != null:
		_focus_button.grab_focus()


func _button(c: Dictionary, stacked: bool) -> Button:
	var style := String(c.get("style", ""))
	var b: Button
	match style:
		"primary":
			b = UIStyle.primary_button(String(c["text"]), 15)
		"danger":
			b = UIStyle.danger_button(String(c["text"]), 15)
		_:
			b = UIStyle.secondary_button(String(c["text"]), 15)
	b.focus_mode = Control.FOCUS_ALL   # keyboard: Tab / arrows move, Enter presses (cancel by default)
	b.custom_minimum_size = Vector2(STACK_W, BUTTON_H) if stacked else Vector2(BUTTON_W, BUTTON_H)
	var act: Callable = c.get("action", Callable())
	b.pressed.connect(func():
		close(not act.is_valid())
		if act.is_valid():
			act.call())
	return b


func _appear() -> void:
	_panel.appear()
	if _headline != null:
		_headline.play_sweep()
