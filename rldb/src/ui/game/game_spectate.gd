class_name GameSpectate
extends RefCounted
## A2 spectating on the match screen.
##   Players: an eye badge in the top strip with the number of spectators (it opens the list), and
##   the Spectators list (from the game menu or the badge): each spectator's name with an eye
##   toggle. Closed eye = default view, tooltip "Allow this player to see your cards"; open eye =
##   allowed, tooltip "Stop this player seeing your cards". While anyone is allowed, the player's
##   cursor is sent (throttled, normalised board space) for the allowed spectators to follow.
##   Spectators: a "Spectating" badge naming whose side they watch (and whether they see that
##   player's cards), a button to watch the other player, and the watched player's live cursor.

const ALLOW_TIP := "Allow this player to see your cards"
const STOP_TIP := "Stop this player seeing your cards"
const LIST_W := 380.0
const BADGE_GOLD := Color("e9c46a")

## The host screen this component works on.
var gs: GameScreen
## Top-strip badge (players: eye + count; spectators: Spectating + name).
var badge: Button
## Spectator only: watch the other player.
var flip_button: Button
## The Spectators list popover.
var panel: HousePanel
var _list: VBoxContainer
var _badge_eye: EyeGlyph
var _badge_label: Label
var _cursor: SpectatorCursor
var _last_send := 0
var _last_pos := Vector2(INF, INF)
var _sig := 0
var _session: NetSession


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the badge and flip button (into the top strip, before `before`) and the hidden list.
func build(row: HBoxContainer, before: Control) -> void:
	badge = Button.new()
	badge.name = "SpectatorBadge"
	badge.focus_mode = Control.FOCUS_NONE
	badge.flat = false
	badge.visible = false
	badge.custom_minimum_size = Vector2(0, 30)
	var n := UIStyle.flat(Color(0.08, 0.06, 0.03, 0.88), Color(UIStyle.GOLD, 0.65), 1, 15)
	var h := UIStyle.flat(Color(0.14, 0.1, 0.05, 0.95), UIStyle.GOLD_HI, 1, 15)
	for s in [n, h]:
		s.content_margin_left = 10
		s.content_margin_right = 14
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = 3
	badge.add_theme_stylebox_override("normal", n)
	badge.add_theme_stylebox_override("hover", h)
	badge.add_theme_stylebox_override("pressed", h)
	badge.add_theme_stylebox_override("disabled", n)
	badge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8
	hb.offset_right = -10
	badge.add_child(hb)
	_badge_eye = EyeGlyph.new(true, BADGE_GOLD, 16.0)
	_badge_eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_badge_eye)
	_badge_label = UIStyle.label("", 13, UIStyle.GOLD_HI, false, true)
	_badge_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_badge_label)
	badge.pressed.connect(func(): if not gs.is_spectator(): toggle_list())
	row.add_child(badge)
	row.move_child(badge, before.get_index())
	flip_button = UIStyle.button("", 13)
	flip_button.name = "WatchOther"
	flip_button.custom_minimum_size = Vector2(0, 30)
	flip_button.visible = false
	flip_button.pressed.connect(_flip)
	row.add_child(flip_button)
	row.move_child(flip_button, before.get_index())
	panel = HousePanel.new("Spectators", "", Vector2(16, 14), 8)
	panel.name = "SpectatorsPanel"
	panel.visible = false
	panel.z_index = UiLayers.GAME_MENU
	gs.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	panel.body.add_child(_list)
	var close := UIStyle.button("Close", 13)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): panel.visible = false; Sfx.play("back"))
	panel.body.add_child(close)
	_cursor = SpectatorCursor.new()
	_cursor.z_index = UiLayers.HOVER + 1
	_cursor.visible = false
	gs.add_child(_cursor)


## Binds to the seat client (cursor events of a spectator's session).
func attach(c: SeatClient) -> void:
	if _session != null and is_instance_valid(_session) and _session.cursor_received.is_connected(_on_cursor):
		_session.cursor_received.disconnect(_on_cursor)
	_session = (c as NetSeat).session if c is NetSeat else null
	if _session != null:
		_session.cursor_received.connect(_on_cursor)
	_cursor.track.clear()
	_sig = 0


## Places the list popover under the top strip, against the sidebar.
func layout(w: float) -> void:
	panel.reset_size()
	panel.size = Vector2(LIST_W, 0)
	panel.position = Vector2(w - gs.sidebar_w - LIST_W - 10.0, GameScreen.TOP_H + 4.0)
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The spectators of my seat ([{"id", "name", "allowed"}]; empty offline or for spectators).
func spectators() -> Array:
	if gs.is_spectator():
		return []
	return gs.view.get("net", {}).get("spectators", [])


## Refreshes the badge, the flip button and the open list from the view.
func render() -> void:
	var net: Dictionary = gs.view.get("net", {})
	var names: Array = gs.view.get("names", ["", ""])
	var sig := hash([net.get("spectators", []), net.get("spectator", false), net.get("follow", -1), net.get("allowed", false), names, net.get("spectator_count", 0)])
	if sig == _sig:
		return
	_sig = sig
	if gs.is_spectator():
		var follow := int(net.get("follow", 0))
		var who := String(names[follow]) if follow < names.size() else ""
		_badge_eye.open = bool(net.get("allowed", false))
		_badge_eye.col = BADGE_GOLD if _badge_eye.open else UIStyle.MUTED
		_badge_label.text = ("SPECTATING · %s's cards" if _badge_eye.open else "SPECTATING · %s's side") % who
		badge.tooltip_text = ("%s lets you see their cards. You only watch: nothing you click affects the game." % who) if _badge_eye.open else "You are watching. Neither player's hand or face-down cards are shown unless a player allows you."
		badge.mouse_default_cursor_shape = Control.CURSOR_ARROW
		badge.visible = true
		var other := 1 - follow
		flip_button.text = "Watch %s" % String(names[other]) if other < names.size() else "Watch other side"
		flip_button.tooltip_text = "Turn the board to %s's side" % String(names[other]) if other < names.size() else ""
		flip_button.visible = gs.view.get("stage", "") == "game"
		panel.visible = false
		_fit_badge()
		return
	flip_button.visible = false
	var list := spectators()
	badge.visible = gs.is_network() and not list.is_empty()
	var allowed := list.filter(func(s): return s.get("allowed", false)).size()
	_badge_eye.open = true
	_badge_eye.col = BADGE_GOLD
	_badge_label.text = "%d watching" % list.size()
	badge.tooltip_text = "Spectators: %s%s" % [", ".join(list.map(func(s): return String(s["name"]))),
		(". %d can see your cards." % allowed) if allowed > 0 else ". None can see your cards."]
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fit_badge()
	if panel.visible:
		_render_list()


## The badge is a Button drawn around a free-standing row, so it is sized to that row here.
func _fit_badge() -> void:
	badge.custom_minimum_size.x = 8.0 + _badge_eye.custom_minimum_size.x + 6.0 + _badge_label.get_minimum_size().x + 12.0


## Opens or closes the Spectators list.
func toggle_list() -> void:
	if panel.visible:
		panel.visible = false
		Sfx.play("back")
		return
	gs.menu.close_popups()
	Sfx.play("select")
	_render_list()
	panel.visible = true
	panel.appear()
	gs.hover.clear()


func _render_list() -> void:
	GameUi.clear(_list)
	var list := spectators()
	panel.set_tag("%d watching" % list.size() if not list.is_empty() else "")
	if list.is_empty():
		var l := UIStyle.label("No one is watching this game.", 15, UIStyle.TEXT_DIM, true)
		l.add_theme_font_override("font", UIStyle.font_italic())
		_list.add_child(l)
	else:
		var intro := UIStyle.label("Spectators see neither player's hand or face-down cards unless you let them see yours.", 13, UIStyle.TEXT_DIM, true)
		intro.custom_minimum_size.x = LIST_W - 50.0
		_list.add_child(intro)
		_list.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.4), false, 8.0))
	for s in list:
		_list.add_child(_row(s))
	panel.reset_size()
	panel.size = Vector2(LIST_W, 0)


## One spectator: name (and a note while allowed) with the eye toggle at the right.
func _row(s: Dictionary) -> Control:
	var allowed: bool = s.get("allowed", false)
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.1, 0.075, 0.04, 0.85) if not allowed else Color(0.2, 0.15, 0.06, 0.9),
		Color(UIStyle.GOLD, 0.7) if allowed else Color(UIStyle.BRONZE, 0.55), 1, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var nm := UIStyle.label(String(s["name"]), 16, UIStyle.TEXT if not allowed else UIStyle.GOLD_HI, false, true)
	nm.clip_text = true
	col.add_child(nm)
	col.add_child(UIStyle.label("Can see your cards" if allowed else "Default view: no hidden cards", 12, GameChat.SPECTATOR_COLOR if allowed else UIStyle.TEXT_DIM))
	var t := eye_toggle(allowed)
	t.name = "EyeToggle%d" % int(s["id"])
	var id := int(s["id"])
	t.pressed.connect(func():
		Sfx.play("confirm" if not allowed else "cancel")
		gs.send({"t": "spectator_revoke" if allowed else "spectator_allow", "id": id}))
	h.add_child(t)
	return p


## The eye toggle button: closed eye with ALLOW_TIP, or an open, glowing eye with STOP_TIP.
static func eye_toggle(allowed: bool) -> Button:
	var b := JuicyButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 40)
	b.tooltip_text = STOP_TIP if allowed else ALLOW_TIP
	var n := UIStyle.flat(Color(0.06, 0.045, 0.025, 0.95) if not allowed else Color(0.3, 0.22, 0.08, 0.95),
		Color(UIStyle.BRONZE, 0.9) if not allowed else UIStyle.GOLD_HI, 1, 8)
	var hv := UIStyle.flat(Color(0.16, 0.12, 0.06, 0.98), UIStyle.GOLD_HI, 1, 8)
	hv.shadow_color = Color(UIStyle.GOLD_HI, 0.35)
	hv.shadow_size = 7
	if allowed:
		n.shadow_color = Color(UIStyle.GOLD_HI, 0.3)
		n.shadow_size = 6
	for s in [n, hv]:
		s.content_margin_left = 6
		s.content_margin_right = 6
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var eye := EyeGlyph.new(allowed, UIStyle.GOLD if allowed else UIStyle.MUTED, 22.0)
	eye.name = "Eye"
	eye.glow = 1.0 if allowed else 0.0
	b.add_child(eye)
	eye.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # the glyph draws centred in its rect
	b.set_meta("allowed", allowed)
	return b


func _flip() -> void:
	var follow := int(gs.view.get("net", {}).get("follow", 0))
	Sfx.play("select")
	gs.send({"t": "spectate_follow", "who": 1 - follow})
	_cursor.track.clear()


func _on_cursor(seat: int, pos: Vector2) -> void:
	if not gs.is_spectator() or seat != int(gs.view.get("net", {}).get("follow", -1)):
		return
	_cursor.track.push(pos, Time.get_ticks_msec())


## Per frame: players send their cursor while a spectator may follow it; spectators draw theirs.
func process() -> void:
	if _session == null:
		_cursor.visible = false
		return
	if gs.is_spectator():
		var net: Dictionary = gs.view.get("net", {})
		var on: bool = bool(net.get("allowed", false)) and gs.view.get("stage", "") == "game"
		var now := Time.get_ticks_msec()
		_cursor.visible = on and _cursor.track.visible_at(now)
		if _cursor.visible:
			_cursor.label = String(gs.view.get("names", ["", ""])[int(net.get("follow", 0))])
			_cursor.at = gs.board.norm_to_local(_cursor.track.sample(now))
			_cursor.queue_redraw()
		return
	_cursor.visible = false
	if gs.view.get("stage", "") != "game" or not _session.cursor_wanted():
		return
	var now2 := Time.get_ticks_msec()
	if now2 - _last_send < int(1000.0 / CursorTrack.SEND_HZ):
		return
	var p := gs.board.local_to_norm(gs.get_local_mouse_position())
	if p.distance_to(_last_pos) < 0.001:
		return
	_last_send = now2
	_last_pos = p
	_session.send_cursor(p)
