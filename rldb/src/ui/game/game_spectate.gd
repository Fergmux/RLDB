class_name GameSpectate
extends RefCounted
## A2 spectating on the match screen, and the J22 lobby list.
##   Everyone online: a "View lobby" button in the top strip (always there, with an eye chip
##   counting the spectators) opens the Lobby list in two sections. Players: both seats, the
##   viewer marked "You"; the others only offer Mute (J21). Spectators: each with Mute and, for a
##   player viewing, the eye toggle. Closed eye = default view, tooltip "Allow this player to see
##   your cards"; open eye = allowed, tooltip "Stop this player seeing your cards". While anyone is
##   allowed, the player's cursor is sent (throttled, normalised board space) for the allowed
##   spectators to follow.
##   Spectators: a "Spectating" badge naming whose side they watch (and whether they see that
##   player's cards), a button to watch the other player, and the watched player's live cursor.
## Mute is local to this viewer (GameChat.muted): it hides that person's chat lines and alerts.

const ALLOW_TIP := "Allow this player to see your cards"
const STOP_TIP := "Stop this player seeing your cards"
const LIST_W := 400.0
const BADGE_GOLD := Color("e9c46a")
## Lobby button: its label and size (it matches Chat and Menu, review #15).
const LOBBY_TEXT := "View lobby"
const LOBBY_SIZE := Vector2(132, 36)

## The host screen this component works on.
var gs: GameScreen
## Spectator only: the top-strip "Spectating" badge (players: hidden; J22 the lobby button replaced it).
var badge: Button
## J22: the always-present View lobby button (online, players and spectators).
var lobby_button: Button
## Spectator only: watch the other player.
var flip_button: Button
## The Lobby list popover.
var panel: HousePanel
## J20 / J22: the list's round close button.
var close_button: RoundCloseButton
var _list: VBoxContainer
var _badge_eye: EyeGlyph
var _badge_label: Label
var _chip: CountChip
var _cursor: SpectatorCursor
var _last_send := 0
var _last_pos := Vector2(INF, INF)
var _sig := 0
var _session: NetSession


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the badge, flip and lobby buttons (into the top strip, before `before`) and the hidden list.
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
	badge.add_theme_stylebox_override("hover", n)
	badge.add_theme_stylebox_override("pressed", n)
	badge.add_theme_stylebox_override("disabled", n)
	badge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	badge.mouse_default_cursor_shape = Control.CURSOR_ARROW
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
	row.add_child(badge)
	row.move_child(badge, before.get_index())
	flip_button = UIStyle.button("", 15)
	flip_button.name = "WatchOther"
	flip_button.custom_minimum_size = Vector2(0, LOBBY_SIZE.y)   # the strip's buttons share one height
	flip_button.visible = false
	flip_button.pressed.connect(_flip)
	row.add_child(flip_button)
	row.move_child(flip_button, before.get_index())
	lobby_button = UIStyle.button(LOBBY_TEXT, 15)
	lobby_button.name = "LobbyButton"
	lobby_button.custom_minimum_size = LOBBY_SIZE
	lobby_button.visible = false
	lobby_button.pressed.connect(toggle_list)
	row.add_child(lobby_button)
	row.move_child(lobby_button, before.get_index())
	_chip = CountChip.new()
	_chip.name = "LobbyChip"
	# L12 (owner, 5 Nov): View lobby lives only in the in-game menu, so the button stays hidden and
	# the spectator count rides on the Menu button instead (the menu item names it too).
	var host_btn: Control = gs.menu.menu_button if gs.menu.menu_button != null else lobby_button
	host_btn.add_child(_chip)
	# Pinned to the button's top-right corner (like the Chat button's unread badge).
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.offset_left = -CountChip.W + 10.0
	_chip.offset_right = 10.0
	_chip.offset_top = -5.0
	_chip.offset_bottom = -5.0 + CountChip.H
	panel = HousePanel.new("Lobby", "", Vector2(UIStyle.sp("lg"), UIStyle.sp("lg")), UIStyle.sp("sm"))   # D5: 16 px popover padding
	panel.name = "LobbyPanel"
	panel.visible = false
	panel.z_index = UiLayers.GAME_MENU
	gs.add_child(panel)
	close_button = GameChat.add_close(panel, close_list)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	panel.body.add_child(_list)
	_cursor = SpectatorCursor.new()
	_cursor.z_index = UiLayers.HOVER + 1
	_cursor.visible = false
	gs.add_child(_cursor)
	gs.chat.mute_changed.connect(func(_k, _on): if panel.visible: _render_list())


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


## J22: everyone watching, as this viewer may see them: [{"id", "name", "allowed"?}] (a player
## gets the permissions of their seat; a spectator only names).
func watchers() -> Array:
	if gs.is_spectator():
		return gs.view.get("net", {}).get("people", [])
	return spectators()


## J22: the two seats for the lobby list: [{"seat", "name"}].
func players() -> Array:
	var names: Array = gs.view.get("names", ["", ""])
	var out := []
	for s in 2:
		out.append({"seat": s, "name": String(names[s]) if s < names.size() else "Player %d" % (s + 1)})
	return out


## Refreshes the badge, the flip and lobby buttons and the open list from the view.
func render() -> void:
	var net: Dictionary = gs.view.get("net", {})
	var names: Array = gs.view.get("names", ["", ""])
	var sig := hash([net.get("spectators", []), net.get("people", []), net.get("spectator", false), net.get("follow", -1), net.get("allowed", false),
		names, net.get("spectator_count", 0), net.get("opponent_connected", true), gs.is_network(),
		gs.view.get("scores"), gs.view.get("history"), gs.view.get("stage")])   # L26: the series section
	if sig == _sig:
		return
	_sig = sig
	var list := watchers()
	lobby_button.visible = false   # L12: View lobby is in the in-game menu only
	var count := int(net.get("spectator_count", list.size())) if gs.is_spectator() else list.size()
	_chip.set_count(count)
	lobby_button.tooltip_text = "See who is at this table: both players and %s" % (("%d spectator%s" % [count, "" if count == 1 else "s"]) if count > 0 else "no spectators yet")
	if gs.menu.menu_button != null:
		gs.menu.menu_button.tooltip_text = "Menu" if count <= 0 else "Menu · %d watching: View lobby is in the menu" % count
	if gs.is_spectator():
		var follow := int(net.get("follow", 0))
		var who := String(names[follow]) if follow < names.size() else ""
		_badge_eye.open = bool(net.get("allowed", false))
		_badge_eye.col = BADGE_GOLD if _badge_eye.open else UIStyle.MUTED
		_badge_label.text = ("SPECTATING · %s's cards" if _badge_eye.open else "SPECTATING · %s's side") % who
		badge.tooltip_text = ("%s lets you see their cards. You only watch: nothing you click affects the game." % who) if _badge_eye.open else "You are watching. Neither player's hand or face-down cards are shown unless a player allows you."
		badge.visible = true
		var other := 1 - follow
		flip_button.text = "Watch %s" % String(names[other]) if other < names.size() else "Watch other side"
		flip_button.tooltip_text = "Turn the board to %s's side" % String(names[other]) if other < names.size() else ""
		flip_button.visible = gs.view.get("stage", "") == "game"
		_fit_badge()
	else:
		badge.visible = false
		flip_button.visible = false
	if panel.visible:
		_render_list()


## The badge is a Button drawn around a free-standing row, so it is sized to that row here.
func _fit_badge() -> void:
	badge.custom_minimum_size.x = 8.0 + _badge_eye.custom_minimum_size.x + 6.0 + _badge_label.get_minimum_size().x + 12.0


## Opens or closes the Lobby list.
func toggle_list() -> void:
	if panel.visible:
		close_list()
		return
	gs.menu.close_popups()
	Sfx.play("select")
	_render_list()
	panel.visible = true
	GameChat.raise_for_input(panel)
	panel.appear()
	gs.hover.clear()


## Closes the Lobby list.
func close_list() -> void:
	if not panel.visible:
		return
	panel.visible = false
	Sfx.play("back")


func _render_list() -> void:
	GameUi.clear(_list)
	var list := watchers()
	var spec := gs.is_spectator()
	panel.set_tag("%d watching" % list.size() if not list.is_empty() else "")
	# L26 (owner, 5 Nov): the series results in full at the top of the list (more than one game).
	if SeriesResults.shows_for(gs.view):
		_list.add_child(_section("Series", "Best of %d" % int(gs.view.get("best_of", 3))))
		var sr := SeriesResults.new().setup(SeriesResults.model(gs.view, gs.me()))
		sr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_list.add_child(sr)
		_list.add_child(_gap(6))
	_list.add_child(_section("Players", "2"))
	for p in players():
		_list.add_child(_player_row(p))
	_list.add_child(_gap(6))
	_list.add_child(_section("Spectators", str(list.size())))
	if list.is_empty():
		var l := UIStyle.label("No one is watching this game.", 15, UIStyle.TEXT_DIM, true)
		l.add_theme_font_override("font", UIStyle.font_italic())
		l.custom_minimum_size.x = LIST_W - 50.0
		_list.add_child(l)
	elif not spec:
		var intro := UIStyle.label("Spectators see neither player's hand or face-down cards unless you let them see yours.", 13, UIStyle.TEXT_DIM, true)
		intro.custom_minimum_size.x = LIST_W - 50.0
		_list.add_child(intro)
	for s in list:
		_list.add_child(_row(s))
	var foot := UIStyle.label("Mute hides someone's chat and alerts on this screen only.", 12, Color(UIStyle.TEXT_DIM, 0.85), true)
	foot.custom_minimum_size.x = LIST_W - 50.0
	_list.add_child(_gap(2))
	_list.add_child(foot)
	panel.reset_size()
	panel.size = Vector2(LIST_W, 0)


func _gap(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A section heading: small gold caps with a count, over a fading rule.
func _section(title: String, count: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var t := UIStyle.label(title.to_upper(), 13, UIStyle.GOLD_HI, false, true)
	t.name = "Section_" + title
	h.add_child(t)
	var c := UIStyle.label(count, 12, Color(UIStyle.GOLD, 0.75), false, true)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	v.add_child(Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), false, 6.0))
	return v


## Row frame: dark plate (warm gold while `lit`), dimmed while `muted`.
func _plate(lit: bool, muted: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.2, 0.15, 0.06, 0.9) if lit else Color(0.1, 0.075, 0.04, 0.85),
		Color(UIStyle.GOLD, 0.7) if lit else Color(UIStyle.BRONZE, 0.55), 1, 8)
	UIStyle.pad(sb, "md")   # D5: list-row padding, 12 px on every side
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	if muted:
		p.modulate = Color(1, 1, 1, 0.72)
	return p


## Name and note column of a row; the name in `col` with a seat-colour pip.
func _name_col(nm_text: String, note: String, col: Color, note_col: Color, pip: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	v.add_child(top)
	var dot := SeatPip.new(pip)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(dot)
	var nm := UIStyle.label(nm_text, 16, col, false, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	v.add_child(UIStyle.label(note, 12, note_col))
	return v


## J22: one seat: name, a note ("You", away, lets you see their cards) and, for someone else, Mute.
func _player_row(p: Dictionary) -> Control:
	var seat := int(p["seat"])
	var key := "p%d" % seat
	var me := not gs.is_spectator() and seat == gs.me()
	var muted := gs.chat.is_muted(key)
	var net: Dictionary = gs.view.get("net", {})
	var note := "Host" if seat == 0 else "Player"
	if me:
		note = "You"
	elif muted:
		note = "Muted · chat hidden"
	elif not gs.is_spectator() and not bool(net.get("opponent_connected", true)):
		note = "Away · reconnecting"
	elif gs.is_spectator() and bool((net.get("allowed_by", [false, false]) as Array)[seat]):
		note = "Lets you see their cards"
	var plate := _plate(me, muted)
	plate.name = "Player_%d" % seat
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	plate.add_child(h)
	h.add_child(_name_col(String(p["name"]), note, UIStyle.GOLD_HI if me else UIStyle.TEXT,
		GameChat.NOTICE_COLOR if muted else UIStyle.TEXT_DIM, GameChat.SEAT_COLORS[seat]))
	if not me:
		h.add_child(_mute_toggle(key, String(p["name"])))
	return plate


## One spectator: name (and a note while allowed or muted) with Mute and, for a player, the eye.
func _row(s: Dictionary) -> Control:
	var id := int(s["id"])
	var key := "s%d" % id
	var me := gs.is_spectator() and id == int(gs.view.get("net", {}).get("spec_id", -1))
	var allowed: bool = s.get("allowed", false)
	var muted := gs.chat.is_muted(key)
	var note := "You" if me else ("Muted · chat hidden" if muted else ("Can see your cards" if allowed else ("Default view: no hidden cards" if not gs.is_spectator() else "Spectator")))
	var p := _plate(allowed or me, muted)
	p.name = "Spectator_%d" % id
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var note_col: Color = GameChat.NOTICE_COLOR if muted else (GameChat.SPECTATOR_COLOR if allowed else UIStyle.TEXT_DIM)
	h.add_child(_name_col(String(s["name"]), note, UIStyle.GOLD_HI if allowed or me else UIStyle.TEXT, note_col, GameChat.SPECTATOR_COLOR))
	if not me:
		h.add_child(_mute_toggle(key, String(s["name"])))
	if not gs.is_spectator():
		var t := eye_toggle(allowed)
		t.name = "EyeToggle%d" % id
		t.pressed.connect(func():
			Sfx.play("confirm" if not allowed else "cancel")
			gs.send({"t": "spectator_revoke" if allowed else "spectator_allow", "id": id}))
		h.add_child(t)
	return p


## J21: the Mute toggle of `key` (a speech bubble; struck through in red while muted).
func _mute_toggle(key: String, who: String) -> Button:
	var on := gs.chat.is_muted(key)
	var b := mute_toggle(on, who)
	b.name = "Mute_" + key
	b.pressed.connect(func():
		Sfx.play("toggle_off" if not on else "toggle_on")
		gs.chat.set_muted(key, not on))
	return b


## J21: a mute toggle button for `who`: a gold speech bubble (chat shown) or a dim one struck in
## red (muted), with its tooltip.
static func mute_toggle(on: bool, who: String) -> Button:
	var b := JuicyButton.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(46, 40)
	b.tooltip_text = ("Unmute %s: show their chat again" if on else "Mute %s: hide their chat messages and alerts") % who
	var n := UIStyle.flat(Color(0.14, 0.05, 0.035, 0.95) if on else Color(0.06, 0.045, 0.025, 0.95),
		Color("c4513f") if on else Color(UIStyle.BRONZE, 0.9), 2 if on else 1, 8)
	var hv := UIStyle.flat(Color(0.16, 0.12, 0.06, 0.98), UIStyle.GOLD_HI, 1, 8)
	hv.shadow_color = Color(UIStyle.GOLD_HI, 0.35)
	hv.shadow_size = 7
	for s in [n, hv]:
		s.content_margin_left = 6
		s.content_margin_right = 6
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var g := GameChat.ChatGlyph.new(24.0)
	g.name = "Glyph"
	g.col = UIStyle.MUTED if on else UIStyle.GOLD
	g.struck = on
	b.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.set_meta("muted", on)
	return b


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


## A small seat-colour jewel before a name in the lobby list.
class SeatPip:
	extends Control
	var col: Color

	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(10, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c + Vector2(0, 1), 4.6, Color(0, 0, 0, 0.5))
		draw_circle(c, 4.4, col.darkened(0.45))
		draw_circle(c, 3.4, col)
		draw_circle(c + Vector2(-1.1, -1.2), 1.3, Color(1, 1, 1, 0.55))


## J22: the spectator count on the View lobby button: a dark pill with a gold eye and the number
## (hidden at 0).
class CountChip:
	extends Control
	const W := 38.0
	const H := 20.0
	var count := 0
	var _eye: EyeGlyph

	func _init() -> void:
		size = Vector2(W, H)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		_eye = EyeGlyph.new(true, Color("e9c46a"), 10.0)
		_eye.position = Vector2(5, 5)
		_eye.size = Vector2(15, 10)
		add_child(_eye)

	## Shows `n` spectators (0 hides the chip).
	func set_count(n: int) -> void:
		count = n
		visible = n > 0
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sh := UIStyle.flat(Color(0.06, 0.045, 0.025, 0.96), Color(UIStyle.GOLD, 0.85), 1, 10)
		sh.shadow_color = Color(0, 0, 0, 0.5)
		sh.shadow_size = 3
		draw_style_box(sh, r)
		var f := UIStyle.font_bold()
		var txt := str(count) if count < 10 else "9+"
		draw_string(f, Vector2(23, 15), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GOLD_HI)
