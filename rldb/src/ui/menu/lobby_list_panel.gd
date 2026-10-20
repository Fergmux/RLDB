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
var _dots: Control
## The SCREEN-tier headline (D3).
var headline: TitleText


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
	_panel = HousePanel.new("Play · online", "Steam", Vector2(28, 24), UIStyle.sp("md"))
	_panel.arm = 18.0
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	cc.add_child(_panel)
	var v := _panel.body
	headline = TitleText.apply(_panel.add_headline("Public RLDB lobbies", 26, true, 12.0), TitleText.Tier.SCREEN, 26)
	# Status line: animated dots while searching (WaitingDots), then the result.
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	UIStyle.pad(srow, "sm")
	v.add_child(srow)
	_status = UIStyle.label("", 16, UIStyle.MUTED, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.visible = false
	srow.add_child(_status)
	_dots = WaitingDots.new("Searching for lobbies", 16, UIStyle.MUTED)
	srow.add_child(_dots)
	_list = VBoxContainer.new()
	UIStyle.pad(_list, "sm")
	v.add_child(_list)
	var back := UIStyle.size_button(UIStyle.secondary_button("Back", 15), "standard")
	back.custom_minimum_size.x = 160
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	v.add_child(back)


func _ready() -> void:
	_panel.appear()
	headline.play_sweep()
	get_tree().create_timer(SEARCH_TIMEOUT).timeout.connect(func():
		if is_instance_valid(self) and not _done:
			_dots.visible = false
			_status.visible = true
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
	_dots.visible = false
	_status.visible = true
	for c in _list.get_children():
		c.queue_free()
	if lobbies.is_empty():
		_status.text = "No public lobbies found. The host must tick \"List my lobby publicly\"; friends-only lobbies are joined through Steam invites."
		return
	_status.text = "%d public %s found." % [lobbies.size(), "lobby" if lobbies.size() == 1 else "lobbies"]
	for l in lobbies:
		_list.add_child(_row(l))


## One lobby (design review WP-8 lobby-list check): an F2-style row with the host's name, the
## table's state and a Join / Watch button; the row lights its rim on hover (ui_hover). The button
## text is lobby_label(), its tooltip explains spectating.
func _row(l: Dictionary) -> Control:
	var host := String(l["host"]) if String(l["host"]) != "" else "Unknown"
	var members := int(l["members"])
	var full := members >= 2
	var pc := PanelContainer.new()
	pc.name = "LobbyRow"
	var n := UIStyle.flat(Color(0.06, 0.05, 0.04, 0.92), Color(UIStyle.BRONZE, 0.75), 1, 8)
	UIStyle.pad(n, "lg", "md")
	UIStyle.lift(n, UIStyle.DEPTH_PLATE)
	var h := n.duplicate() as StyleBoxFlat
	h.border_color = Color(UIStyle.GOLD, 0.95)
	h.bg_color = Color(0.1, 0.08, 0.055, 0.95)
	UIStyle.lift_style(h, Color(UIStyle.GOLD, 0.3), 10, 0)
	pc.add_theme_stylebox_override("panel", UiSurface.box(n, UiSurface.LEATHER, UIStyle.PANEL_GRAIN * 0.5))
	var hover := UiSurface.box(h, UiSurface.LEATHER, UIStyle.PANEL_GRAIN * 0.5)
	var rest: StyleBox = pc.get_theme_stylebox("panel")
	pc.mouse_entered.connect(func(): pc.add_theme_stylebox_override("panel", hover); Sfx.hover_at(Time.get_ticks_msec()))
	pc.mouse_exited.connect(func(): pc.add_theme_stylebox_override("panel", rest))
	var row := HBoxContainer.new()
	UIStyle.pad(row, "md")
	pc.add_child(row)
	var dot := WaitPlate.StatusDot.new(full)   # an open seat pulses; a full table rests
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var nm := UIStyle.label(host, 17, UIStyle.GOLD_HI)
	nm.add_theme_font_override("font", UIStyle.font_display(600))
	nm.clip_text = true
	col.add_child(nm)
	var watching := maxi(members - 2, 0)
	var state := ("Open seat · %d/2 players" % maxi(members, 1)) if not full else ("Table full · %s" % ("%d watching" % watching if watching > 0 else "no spectators yet"))
	col.add_child(UIStyle.label(state, 13, UIStyle.MUTED))
	var b := UIStyle.size_button(UIStyle.secondary_button("Join" if not full else "Watch", 15), "small")
	b.name = "LobbyButton"
	b.custom_minimum_size.x = 110
	b.tooltip_text = lobby_label(host, members) + ("\nBoth seats are taken: you join as a spectator and can chat." if full else "")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var id: int = l["id"]
	b.pressed.connect(func(): queue_free(); join_chosen.emit(id))
	row.add_child(b)
	return pc


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
