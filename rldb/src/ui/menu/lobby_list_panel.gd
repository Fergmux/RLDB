class_name LobbyListPanel
extends Control
## "Browse public lobbies": a centred dialog over the dimmed menu. Shows "Searching…" until
## `show_lobbies` gives the results, then a Join button per lobby. Back (or clicking the dim)
## closes it and leaves the menu as it was. Frees itself before emitting either choice.

## Emitted when a lobby is chosen.
signal join_chosen(lobby_id: int)
## Emitted when Back is chosen (or the dim is clicked).
signal back_chosen

const PANEL_W := 520.0
## Seconds without an answer from Steam before the search is reported as failed.
const SEARCH_TIMEOUT := 12.0

var _list: VBoxContainer
var _status: Label
var _done := false
var _panel: HousePanel


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = UiLayers.CONFIRM_DIALOG
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _back())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_panel = HousePanel.new("Join game", "Steam", Vector2(26, 22), 12)
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	_panel.add_headline("Public RLDB lobbies", 26, true, 12.0)
	_status = UIStyle.label("Searching…", 16, UIStyle.TEXT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	var back := UIStyle.button("Back", 15)
	back.custom_minimum_size = Vector2(150, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	v.add_child(back)


func _ready() -> void:
	_panel.appear()
	get_tree().create_timer(SEARCH_TIMEOUT).timeout.connect(func():
		if is_instance_valid(self) and not _done:
			_status.text = "Steam did not answer the search. Check that Steam is online and try again.")


## A2: the button text for a lobby of `members` (host included): an open seat is joined, a full
## table is watched ("Watch <host>'s game · N watching").
static func lobby_label(host: String, members: int) -> String:
	if members < 2:
		return "Join %s's lobby (%d/2 players)" % [host, maxi(members, 1)]
	var watching := members - 2
	return "Watch %s's game · %s" % [host, "%d watching" % watching if watching > 0 else "no spectators yet"]


## Lists `lobbies` (dicts with id, host, members); an empty list says none were found.
func show_lobbies(lobbies: Array) -> void:
	_done = true
	for c in _list.get_children():
		c.queue_free()
	if lobbies.is_empty():
		_status.text = "No public lobbies found. The host must tick \"List my lobby publicly\"; friends-only lobbies are joined through Steam invites."
		return
	_status.text = "Found %d lobby(s)." % lobbies.size()
	for l in lobbies:
		var host := String(l["host"]) if String(l["host"]) != "" else "Unknown"
		var b := UIStyle.primary_button(lobby_label(host, int(l["members"])), 15)
		if int(l["members"]) >= 2:
			b.tooltip_text = "Both seats are taken: you join as a spectator and can chat."
		b.custom_minimum_size = Vector2(0, 40)
		var id: int = l["id"]
		b.pressed.connect(func(): queue_free(); join_chosen.emit(id))
		_list.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	if is_queued_for_deletion():
		return
	Sfx.play("back")   # F22: Back button and Esc alike (one sound: coalesced with the button's)
	queue_free()
	back_chosen.emit()
