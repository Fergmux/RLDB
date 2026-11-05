class_name GameChat
extends RefCounted
## A1: the in-game chat of an online series (players and spectators share it). A Chat button sits
## next to Menu in the top strip. J17: a message that arrives while the box is closed pops a
## speech-bubble preview out under the button (sender and message, for a few seconds; a click opens
## the chat), raises the unread badge with a ripple and plays the chat_pop cue. The box is a house
## popover: a scrolling history with timestamps and sender names tinted per seat (spectators
## marked), an input line and a Send button. Enter sends and Esc closes (J19: no hint line; the
## tooltips name the keys). J20: a round close medallion in the header.
##
## J21: anyone at the table can be muted by this viewer (from the lobby list, GameSpectate): their
## lines leave the history and they raise no badge, preview or sound. Mute is local to this screen
## and never sent anywhere.
##
## Online only: the button is hidden for bot, hot-seat and tutorial games (their seat client is
## not a NetSeat). Messages go through NetSession.send_chat; the history is the session's memory
## (nothing is written anywhere). Text is rendered with add_text, never parsed as markup.

## Emitted when this viewer mutes or unmutes someone (sender key, see sender_key).
signal mute_changed(key: String, on: bool)

const W := 400.0
const H := 470.0
## Name colours: seat 0, seat 1, spectators; system lines and notices.
const SEAT_COLORS := [Color("f0b75e"), Color("79c2f2")]
const SPECTATOR_COLOR := Color("c7aef2")
const SYSTEM_COLOR := Color("a79c88")
const NOTICE_COLOR := Color("ef8a7a")
## The character counter appears from this length on.
const COUNTER_FROM := 150
## J17: the new-message cue and how long the preview stays (s) before it fades.
const NEW_SOUND := "chat_pop"
const PEEK_HOLD := 4.2
## Diameter of the round close button (J20).
const CLOSE_D := 30.0

## The host screen this component works on.
var gs: GameScreen
## Chat button in the top strip (hidden offline).
var button: Button
## Unread messages badge on the button.
var badge: UnreadBadge
## J17: the new-message preview under the button.
var peek: ChatPeek
## The chat popover.
var panel: HousePanel
## J20: the round close button in the popover's header.
var close_button: RoundCloseButton
## Message history.
var history: RichTextLabel
## The input line.
var input: LineEdit
## Shown while the history is empty.
var empty_label: Label
## The session whose chat this shows (null offline).
var session: NetSession
## Messages received while the box was closed.
var unread: int = 0
## J21: sender keys this viewer has muted (key -> true). Local to this screen.
var muted: Dictionary = {}
var _send_b: Button
var _counter: Label
var _foot: Control
var _rendered := 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the Chat button (into the top strip row, before Menu), its badge and preview, and the
## hidden popover.
func build(row: HBoxContainer, before: Control) -> void:
	button = UIStyle.button("Chat", 13)
	button.name = "ChatButton"
	button.custom_minimum_size = Vector2(76, 30)
	button.tooltip_text = "Talk to everyone at this table"
	button.visible = false
	button.pressed.connect(toggle)
	row.add_child(button)
	row.move_child(button, before.get_index())
	badge = UnreadBadge.new()
	badge.name = "ChatBadge"
	button.add_child(badge)
	button.resized.connect(_place_badge)
	_place_badge()
	peek = ChatPeek.new()
	peek.name = "ChatPeek"
	peek.z_index = UiLayers.TOAST
	peek.clicked.connect(open_box)
	gs.add_child(peek)
	panel = HousePanel.new("Chat", "Players and spectators", Vector2(UIStyle.sp("lg"), UIStyle.sp("lg")), UIStyle.sp("sm"))   # D5: 16 px popover padding
	panel.name = "ChatPanel"
	panel.visible = false
	panel.z_index = UiLayers.GAME_MENU
	panel.custom_minimum_size = Vector2(W, H)
	gs.add_child(panel)
	close_button = add_close(panel, close_box)
	# History: an inset well of dark parchment with the house scroll bar.
	var well := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.04, 0.03, 0.02, 0.78), Color(UIStyle.BRONZE, 0.55), 1, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	well.add_theme_stylebox_override("panel", UiSurface.box(sb, UiSurface.LEATHER, 0.22))
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.body.add_child(well)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_child(stack)
	history = RichTextLabel.new()
	history.name = "ChatHistory"
	history.bbcode_enabled = false
	history.scroll_active = true
	history.scroll_following = true
	history.selection_enabled = true
	history.context_menu_enabled = false
	history.focus_mode = Control.FOCUS_NONE
	history.theme = Ornate.scroll_theme()
	history.add_theme_font_override("normal_font", UIStyle.font_body())
	history.add_theme_font_override("bold_font", UIStyle.font_bold())
	history.add_theme_font_override("italics_font", UIStyle.font_italic())
	history.add_theme_font_size_override("normal_font_size", 15)
	history.add_theme_font_size_override("bold_font_size", 15)
	history.add_theme_font_size_override("italics_font_size", 14)
	history.add_theme_color_override("default_color", UIStyle.TEXT)
	history.add_theme_constant_override("line_separation", 5)
	history.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(history)
	empty_label = UIStyle.label("No messages yet.\nSay hello to the table.", 15, Color(UIStyle.TEXT_DIM, 0.9), true)
	empty_label.add_theme_font_override("font", UIStyle.font_italic())
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(empty_label)
	# Input row.
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	panel.body.add_child(row2)
	input = LineEdit.new()
	input.name = "ChatInput"
	input.placeholder_text = "Write a message…"
	input.max_length = NetChat.MAX_LEN
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 36)
	input.context_menu_enabled = false
	input.add_theme_font_override("font", UIStyle.font_body())
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", UIStyle.TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UIStyle.TEXT_DIM, 0.75))
	input.add_theme_color_override("caret_color", UIStyle.GOLD_HI)
	input.add_theme_color_override("selection_color", Color(UIStyle.GOLD, 0.35))
	var n := UIStyle.flat(Color(0.05, 0.04, 0.03, 0.92), Color(UIStyle.BRONZE, 0.8), 1, 7)
	var f := UIStyle.flat(Color(0.07, 0.055, 0.035, 0.96), UIStyle.GOLD, 2, 7)
	for s in [n, f]:
		s.content_margin_left = 10
		s.content_margin_right = 10
	f.shadow_color = Color(UIStyle.GOLD, 0.22)
	f.shadow_size = 6
	input.add_theme_stylebox_override("normal", n)
	input.add_theme_stylebox_override("focus", f)
	input.text_submitted.connect(func(_t): send())
	input.text_changed.connect(_on_typed)
	row2.add_child(input)
	_send_b = UIStyle.primary_button("Send", 14)
	_send_b.custom_minimum_size = Vector2(72, 36)
	_send_b.tooltip_text = "Send"
	_send_b.pressed.connect(send)
	row2.add_child(_send_b)
	# J19: no key hint under the input; the character counter shows only near the limit.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	_foot = foot
	panel.body.add_child(foot)
	_counter = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	foot.add_child(_counter)
	_on_typed("")


## J20: adds the round close button at the right of `p`'s header strip, calling `on_close`.
static func add_close(p: HousePanel, on_close: Callable) -> RoundCloseButton:
	var close := RoundCloseButton.new(CLOSE_D)
	close.name = "CloseButton"
	close.tooltip_text = "Close"
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	p.head_row.mouse_filter = Control.MOUSE_FILTER_PASS
	p.head_row.add_child(close)
	p.head_row.move_child(close, p.head_row.get_child_count() - 2)
	return close


## J20: GUI picking in Godot follows the tree order, not z_index, so a popover built before the
## series modal (its full-field dim, the pause veil) drew above it but lost every click to it.
## This moves `c` after its siblings, and then every sibling drawn above it (a higher z_index)
## after it again, so input order matches draw order. Draw order among equal z is unchanged
## except that `c` now comes last of its layer.
static func raise_for_input(c: Control) -> void:
	var parent := c.get_parent()
	if parent == null:
		return
	parent.move_child(c, -1)
	for ch in parent.get_children():
		if ch != c and ch is CanvasItem and (ch as CanvasItem).z_index > c.z_index:
			parent.move_child(ch, -1)


func _place_badge() -> void:
	badge.position = Vector2(button.size.x - badge.size.x * 0.7, -3.0)


## Binds the chat to the screen's seat client (a NetSeat's session; offline: hidden).
func attach(c: SeatClient) -> void:
	if session != null and is_instance_valid(session) and session.chat_received.is_connected(_on_entry):
		session.chat_received.disconnect(_on_entry)
	var was := session
	session = (c as NetSeat).session if c is NetSeat else null
	if session != was:
		muted.clear()   # keys belong to one table: another session starts with nobody muted
		unread = 0
		badge.set_count(0)
	button.visible = session != null
	peek.dismiss(true)
	if session == null:
		panel.visible = false
		return
	session.chat_received.connect(_on_entry)
	rebuild_history()


## Re-renders the history from the session's memory (muted senders left out).
func rebuild_history() -> void:
	history.clear()
	_rendered = 0
	if session != null:
		for e in session.chat_log:
			_append(e)
	_refresh_empty()


## Places the popover under the top strip, against the sidebar, and the preview under the button.
func layout(w: float) -> void:
	panel.size = Vector2(W, H)
	panel.position = Vector2(w - gs.sidebar_w - W - 10.0, GameScreen.TOP_H + 4.0)
	_place_peek()


func _place_peek() -> void:
	if peek == null or button == null or not button.is_inside_tree():
		return
	var tip_x := button.get_global_rect().get_center().x - gs.get_global_rect().position.x
	var right := gs.size.x - gs.sidebar_w - 10.0
	peek.place(tip_x, right, GameScreen.TOP_H + 2.0)


## True while the box is open.
func is_open() -> bool:
	return panel.visible


## True while the input line has the keyboard (game shortcuts must not fire).
func typing() -> bool:
	return panel.visible and input.has_focus()


## Opens or closes the box.
func toggle() -> void:
	if panel.visible:
		close_box()
	else:
		open_box()


## Opens the box, clears the unread count and focuses the input.
func open_box() -> void:
	gs.menu.close_popups()
	Sfx.play("select")
	panel.visible = true
	raise_for_input(panel)
	panel.appear()
	unread = 0
	badge.set_count(0)
	peek.dismiss(true)
	gs.hover.clear()
	input.call_deferred("grab_focus")


## Closes the box (the draft in the input line is kept).
func close_box() -> void:
	if not panel.visible:
		return
	panel.visible = false
	input.release_focus()
	Sfx.play("back")


## Sends the input line. Empty or refused text stays for editing (a refusal shows as a notice).
func send() -> void:
	if session == null:
		return
	var text := input.text
	if NetChat.sanitize(text) == "":
		input.text = ""
		_on_typed("")
		return
	var err := session.send_chat(text)
	if err == "":
		input.text = ""
		_on_typed("")
	input.grab_focus()


# ---------------------------------------------------------------- J21 mute

## The sender key of a chat entry: "p<seat>" for a player, "s<id>" for a spectator, "" for system
## lines and notices (never muted).
static func sender_key(e: Dictionary) -> String:
	match String(e.get("role", "")):
		"player":
			return "p%d" % int(e.get("seat", -1))
		"spectator":
			return "s%d" % int(e.get("sid", -1))
	return ""


## This viewer's own sender key ("p<seat>", or "s<id>" for a spectator).
func my_key() -> String:
	var net: Dictionary = gs.view.get("net", {})
	if gs.is_spectator():
		return "s%d" % int(net.get("spec_id", -1))
	return "p%d" % gs.me()


## True when `key` is muted by this viewer.
func is_muted(key: String) -> bool:
	return muted.has(key)


## Mutes (`on`) or unmutes `key`: the history is re-rendered without (or with) their lines.
func set_muted(key: String, on: bool) -> void:
	if key == "" or key == my_key() or on == is_muted(key):
		return
	if on:
		muted[key] = true
	else:
		muted.erase(key)
	rebuild_history()
	if on and peek.key == key:
		peek.dismiss(false)
	mute_changed.emit(key, on)


func _on_typed(t: String) -> void:
	var n := t.length()
	_counter.text = "%d / %d" % [n, NetChat.MAX_LEN] if n >= COUNTER_FROM else ""
	_counter.add_theme_color_override("font_color", NOTICE_COLOR if n >= NetChat.MAX_LEN else UIStyle.TEXT_DIM)
	_foot.visible = _counter.text != ""
	_send_b.disabled = NetChat.sanitize(t) == ""


func _on_entry(e: Dictionary) -> void:
	var key := sender_key(e)
	if is_muted(key):
		return
	_append(e)
	_refresh_empty()
	var role := String(e.get("role", ""))
	if not panel.visible and role in ["player", "spectator"] and key != my_key():
		unread += 1
		badge.set_count(unread)
		_place_peek()
		raise_for_input(peek)
		peek.show_entry(e, key, unread, _name_color(e))
		Sfx.play(NEW_SOUND)


func _refresh_empty() -> void:
	empty_label.visible = _rendered == 0


static func _name_color(e: Dictionary) -> Color:
	if String(e.get("role", "")) == "spectator":
		return SPECTATOR_COLOR
	return SEAT_COLORS[clampi(int(e.get("seat", 0)), 0, 1)]


## Appends one entry: "12:41  Name  SPECTATOR  message", or an italic system / notice line.
func _append(e: Dictionary) -> void:
	var role := String(e.get("role", ""))
	var text := String(e.get("text", ""))
	if text == "" or is_muted(sender_key(e)):
		return
	if _rendered > 0:
		history.newline()
	_rendered += 1
	history.push_color(Color(UIStyle.TEXT_DIM, 0.8))
	history.push_font_size(12)
	history.add_text(time_text(int(e.get("at", 0))) + "   ")
	history.pop()
	history.pop()
	if role == "system" or role == "notice":
		history.push_italics()
		history.push_color(SYSTEM_COLOR if role == "system" else NOTICE_COLOR)
		history.add_text(text)
		history.pop()
		history.pop()
		return
	history.push_bold()
	history.push_color(_name_color(e))
	history.add_text(String(e.get("from", "Player")))
	history.pop()
	history.pop()
	if role == "spectator":
		history.push_color(Color(SPECTATOR_COLOR, 0.75))
		history.push_font_size(11)
		history.add_text("  SPECTATOR")
		history.pop()
		history.pop()
	history.push_color(Color(UIStyle.TEXT_DIM, 0.7))
	history.add_text("  ·  ")
	history.pop()
	history.add_text(text)


## Local wall-clock "HH:MM" of unix time `at` (the moment the message reached this screen).
static func time_text(at: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(at + bias * 60)
	return "%02d:%02d" % [int(d["hour"]), int(d["minute"])]


## Unread count on the Chat button: a gold medallion that pops in with a ripple ring (J17) and
## then pulses softly while it shows a number.
class UnreadBadge:
	extends Control
	const D := 22.0
	var count := 0
	## 0..1 progress of the ripple ring that spreads from the badge on a new message.
	var ripple := 1.0:
		set(v):
			ripple = v
			queue_redraw()
	var _tw: Tween
	var _rtw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(D, D)
		size = Vector2(D, D)
		pivot_offset = Vector2(D, D) / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	## Shows `n` (0 hides the badge).
	func set_count(n: int) -> void:
		var was := count
		count = n
		visible = n > 0
		queue_redraw()
		if _tw != null and _tw.is_valid():
			_tw.kill()
		scale = Vector2.ONE
		if n <= 0 or UIStyle.reduce_motion or not is_inside_tree():
			ripple = 1.0
			return
		_tw = create_tween()
		if n > was:
			scale = Vector2(0.2, 0.2) if was == 0 else Vector2(1.5, 1.5)
			_tw.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if _rtw != null and _rtw.is_valid():
				_rtw.kill()
			ripple = 0.0
			_rtw = create_tween()
			_rtw.tween_property(self, "ripple", 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.tween_callback(func():
			if not is_instance_valid(self):
				return
			var loop := create_tween().set_loops()
			_tw = loop
			loop.tween_property(self, "scale", Vector2(1.12, 1.12), 0.8).set_trans(Tween.TRANS_SINE)
			loop.tween_property(self, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE))

	func _draw() -> void:
		var c := size / 2.0
		var r := D / 2.0
		if ripple < 1.0:
			draw_arc(c, r + 2.0 + ripple * 16.0, 0.0, TAU, 40, Color(UIStyle.GOLD_HI, 0.7 * (1.0 - ripple)), 2.0 * (1.0 - ripple) + 0.5, true)
		draw_circle(c + Vector2(0, 1.5), r + 0.8, Color(0, 0, 0, 0.5))
		draw_circle(c, r, UIStyle.GOLD.darkened(0.4))
		draw_circle(c, r - 1.4, UIStyle.GOLD)
		draw_circle(c + Vector2(-2, -3), r * 0.45, Color(UIStyle.GOLD_HI, 0.55))
		var txt := str(count) if count < 10 else "9+"
		var f := UIStyle.font_bold()
		var fs := 13
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - tw / 2.0, c.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.ON_GOLD)


## J17: the new-message preview. A small house speech bubble that pops out under the Chat button
## (its tail points at the button): a chat glyph, the sender in their seat colour with a "+n" tag
## while several are unread, and the message on one line. It stays PEEK_HOLD seconds (held while
## the mouse is on it), then fades and rises away. A click opens the chat. Static (no pop or rise)
## under reduced motion.
class ChatPeek:
	extends Control
	signal clicked
	const PW := 320.0
	const PH := 66.0
	const TAIL := 9.0
	const RADIUS := 10.0
	## Sender key of the message shown ("" while hidden).
	var key := ""
	var _name: Label
	var _more: Label
	var _text: Label
	var _tip_x := PW - 40.0
	var _tw: Tween
	var _over := false

	func _init() -> void:
		size = Vector2(PW, PH + TAIL)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Open the chat"
		visible = false
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(14, TAIL + 9)
		row.size = Vector2(PW - 28, PH - 18)
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		var icon := ChatGlyph.new()
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 8)
		col.add_child(top)
		_name = UIStyle.label("", 16, UIStyle.GOLD_HI)
		_name.add_theme_font_override("font", UIStyle.font_bold())
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(_name)
		_more = UIStyle.label("", 11, Color(UIStyle.GOLD, 0.9), false, true)
		_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(_more)
		_text = UIStyle.label("", 15, UIStyle.TEXT)
		_text.clip_text = true
		_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_text)
		mouse_entered.connect(func(): _over = true; _hold())
		mouse_exited.connect(func(): _over = false; _hold())

	## Positions the bubble: its tail at `tip_x`, its right edge at most `right`, its top at `top`.
	func place(tip_x: float, right: float, top: float) -> void:
		var x := minf(tip_x + 40.0, right) - PW
		position = Vector2(x, top)
		_tip_x = clampf(tip_x - x, RADIUS + TAIL, PW - RADIUS - TAIL)
		pivot_offset = Vector2(_tip_x, 0)
		queue_redraw()

	## Shows message `e` from `who` (`unread` messages are waiting) with its pop-in.
	func show_entry(e: Dictionary, who: String, unread: int, name_col: Color) -> void:
		key = who
		_name.text = String(e.get("from", "Player"))
		_name.add_theme_color_override("font_color", name_col)
		_more.text = "+%d MORE" % (unread - 1) if unread > 1 else ("SPECTATOR" if String(e.get("role", "")) == "spectator" else "NEW MESSAGE")
		_text.text = String(e.get("text", ""))
		var fresh := not visible
		visible = true
		_kill()
		if UIStyle.reduce_motion or not is_inside_tree():
			modulate.a = 1.0
			scale = Vector2.ONE
			_hold()
			return
		_tw = create_tween().set_parallel(true)
		if fresh:
			modulate.a = 0.0
			scale = Vector2(0.55, 0.55)
			_tw.tween_property(self, "modulate:a", 1.0, 0.16)
			_tw.tween_property(self, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			modulate.a = 1.0
			scale = Vector2(1.06, 1.06)
			_tw.tween_property(self, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.chain().tween_callback(_hold)

	## Hides the bubble (`now`: at once, else with its fade).
	func dismiss(now: bool) -> void:
		_kill()
		if now or UIStyle.reduce_motion or not is_inside_tree() or not visible:
			visible = false
			key = ""
			return
		_fade(0.0)

	func _hold() -> void:
		if not visible:
			return
		_kill()
		modulate.a = 1.0
		if _over:
			return
		_fade(PEEK_HOLD)

	func _fade(delay: float) -> void:
		_kill()
		var y0 := position.y
		_tw = create_tween()
		if delay > 0.0:
			_tw.tween_interval(delay)
		_tw.tween_property(self, "modulate:a", 0.0, 0.35)
		if not UIStyle.reduce_motion:
			_tw.parallel().tween_property(self, "position:y", y0 - 6.0, 0.35)
		_tw.tween_callback(func():
			visible = false
			key = ""
			position.y = y0)

	func _kill() -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		_tw = null

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _draw() -> void:
		var body := Rect2(Vector2(0, TAIL), Vector2(PW, PH))
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0)
		sh.shadow_color = Color(0, 0, 0, 0.55)
		sh.shadow_size = 10
		sh.shadow_offset = Vector2(0, 3)
		sh.set_corner_radius_all(int(RADIUS))
		draw_style_box(sh, body)
		var sb := UIStyle.flat(Color(0.13, 0.095, 0.05, 0.97), UIStyle.GOLD_HI, 2, int(RADIUS))
		sb.shadow_color = Color(UIStyle.GOLD, 0.3)
		sb.shadow_size = 6
		draw_style_box(sb, body)
		# A warm sheen across the top and a gold accent down the left, inside the rim.
		Ornate.rounded_gradient(self, Rect2(body.position + Vector2(2, 2), Vector2(PW - 4, 16)), RADIUS - 2.0, 0.0,
			Color(1, 0.9, 0.6, 0.12), Color(1, 0.9, 0.6, 0.0))
		Ornate.vgradient(self, Rect2(2, TAIL + RADIUS, 3, PH - RADIUS * 2.0), Color(UIStyle.GOLD_HI, 0.95), Color(UIStyle.GOLD.darkened(0.3), 0.8))
		# The tail, pointing up at the Chat button (drawn over the rim so it joins the bubble).
		var t := PackedVector2Array([Vector2(_tip_x - TAIL, TAIL + 2.0), Vector2(_tip_x, 0.5), Vector2(_tip_x + TAIL, TAIL + 2.0)])
		draw_colored_polygon(t, Color(0.13, 0.095, 0.05, 0.97))
		draw_polyline(t, UIStyle.GOLD_HI, 2.0, true)


## A drawn speech bubble with three dots (the chat glyph of the preview and the mute toggle).
class ChatGlyph:
	extends Control
	## Main colour of the bubble outline and dots.
	var col: Color = UIStyle.GOLD_HI:
		set(v):
			col = v
			queue_redraw()
	## Draws the red strike of a muted chat.
	var struck := false:
		set(v):
			struck = v
			queue_redraw()

	func _init(px: float = 30.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var r := Rect2(o + Vector2(s * 0.06, s * 0.12), Vector2(s * 0.88, s * 0.62))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.darkened(0.7), 0.95)
		sb.border_color = col
		sb.set_border_width_all(maxi(1, int(round(s / 15.0))))
		sb.set_corner_radius_all(int(s * 0.22))
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var tail := PackedVector2Array([o + Vector2(s * 0.26, s * 0.72), o + Vector2(s * 0.2, s * 0.92), o + Vector2(s * 0.46, s * 0.72)])
		draw_colored_polygon(tail, Color(col.darkened(0.7), 0.95))
		draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), col, maxf(1.0, s / 15.0), true)
		for i in 3:
			draw_circle(o + Vector2(s * (0.3 + 0.2 * i), s * 0.43), s * 0.055, col)
		if struck:
			var a := o + Vector2(s * 0.1, s * 0.9)
			var b := o + Vector2(s * 0.9, s * 0.1)
			draw_line(a, b, Color(0.08, 0.02, 0.01, 0.9), s / 6.0, true)
			draw_line(a, b, Color("e0604f"), s / 10.0, true)
