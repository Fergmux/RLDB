class_name GameChat
extends RefCounted
## A1: the in-game chat of an online series (players and spectators share it). A Chat button sits
## next to Menu in the top strip, with an unread badge that pulses softly (and a chime) when a
## message arrives while the box is closed. The box is a house popover: a scrolling history with
## timestamps and sender names tinted per seat (spectators marked), an input line (Enter sends,
## Esc closes) and a Send button.
##
## Online only: the button is hidden for bot, hot-seat and tutorial games (their seat client is
## not a NetSeat). Messages go through NetSession.send_chat; the history is the session's memory
## (nothing is written anywhere). Text is rendered with add_text, never parsed as markup.

const W := 400.0
const H := 470.0
## Name colours: seat 0, seat 1, spectators; system lines and notices.
const SEAT_COLORS := [Color("f0b75e"), Color("79c2f2")]
const SPECTATOR_COLOR := Color("c7aef2")
const SYSTEM_COLOR := Color("a79c88")
const NOTICE_COLOR := Color("ef8a7a")
## The character counter appears from this length on.
const COUNTER_FROM := 150

## The host screen this component works on.
var gs: GameScreen
## Chat button in the top strip (hidden offline).
var button: Button
## Unread messages badge on the button.
var badge: UnreadBadge
## The chat popover.
var panel: HousePanel
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
var _send_b: Button
var _counter: Label
var _rendered := 0


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the Chat button (into the top strip row, before Menu) and the hidden popover.
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
	button.add_child(badge)
	badge.position = Vector2(76 - 12, -7)
	panel = HousePanel.new("Chat", "Players and spectators", Vector2(16, 14), 8)
	panel.name = "ChatPanel"
	panel.visible = false
	panel.z_index = UiLayers.GAME_MENU
	panel.custom_minimum_size = Vector2(W, H)
	gs.add_child(panel)
	var close := UIStyle.button("✕", 12)
	close.tooltip_text = "Close (Esc)"
	close.custom_minimum_size = Vector2(26, 22)
	close.mouse_filter = Control.MOUSE_FILTER_STOP
	close.pressed.connect(close_box)
	panel.head_row.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.head_row.add_child(close)
	panel.head_row.move_child(close, panel.head_row.get_child_count() - 2)
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
	_send_b.tooltip_text = "Send (Enter)"
	_send_b.pressed.connect(send)
	row2.add_child(_send_b)
	var foot := HBoxContainer.new()
	panel.body.add_child(foot)
	var hint := UIStyle.label("Enter sends · Esc closes", 12, Color(UIStyle.TEXT_DIM, 0.85))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	_counter = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	foot.add_child(_counter)
	_on_typed("")


## Binds the chat to the screen's seat client (a NetSeat's session; offline: hidden).
func attach(c: SeatClient) -> void:
	if session != null and is_instance_valid(session) and session.chat_received.is_connected(_on_entry):
		session.chat_received.disconnect(_on_entry)
	session = (c as NetSeat).session if c is NetSeat else null
	button.visible = session != null
	if session == null:
		panel.visible = false
		return
	session.chat_received.connect(_on_entry)
	history.clear()
	_rendered = 0
	for e in session.chat_log:
		_append(e)
	_refresh_empty()


## Places the popover under the top strip, against the sidebar.
func layout(w: float) -> void:
	panel.size = Vector2(W, H)
	panel.position = Vector2(w - gs.sidebar_w - W - 10.0, GameScreen.TOP_H + 4.0)


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
	panel.appear()
	unread = 0
	badge.set_count(0)
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


func _on_typed(t: String) -> void:
	var n := t.length()
	_counter.text = "%d / %d" % [n, NetChat.MAX_LEN] if n >= COUNTER_FROM else ""
	_counter.add_theme_color_override("font_color", NOTICE_COLOR if n >= NetChat.MAX_LEN else UIStyle.TEXT_DIM)
	_send_b.disabled = NetChat.sanitize(t) == ""


func _on_entry(e: Dictionary) -> void:
	_append(e)
	_refresh_empty()
	var role := String(e.get("role", ""))
	if not panel.visible and role in ["player", "spectator"]:
		unread += 1
		badge.set_count(unread)
		Sfx.play("chat")


func _refresh_empty() -> void:
	empty_label.visible = _rendered == 0


## Appends one entry: "12:41  Name  SPECTATOR  message", or an italic system / notice line.
func _append(e: Dictionary) -> void:
	var role := String(e.get("role", ""))
	var text := String(e.get("text", ""))
	if text == "":
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
	var seat := int(e.get("seat", -1))
	var col: Color = SPECTATOR_COLOR if role == "spectator" else SEAT_COLORS[clampi(seat, 0, 1)]
	history.push_bold()
	history.push_color(col)
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


## Unread count on the Chat button: a gold medallion that pulses softly while it shows a number.
class UnreadBadge:
	extends Control
	var count := 0
	var _tw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		size = Vector2(20, 20)
		pivot_offset = Vector2(10, 10)
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
			return
		_tw = create_tween()
		if n > was:
			scale = Vector2(1.45, 1.45)
			_tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_callback(func():
			if not is_instance_valid(self):
				return
			var loop := create_tween().set_loops()
			_tw = loop
			loop.tween_property(self, "scale", Vector2(1.12, 1.12), 0.8).set_trans(Tween.TRANS_SINE)
			loop.tween_property(self, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE))

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c + Vector2(0, 1.5), 10.5, Color(0, 0, 0, 0.45))
		draw_circle(c, 10.0, UIStyle.GOLD.darkened(0.35))
		draw_circle(c, 8.6, UIStyle.GOLD)
		draw_circle(c + Vector2(-2, -3), 4.0, Color(UIStyle.GOLD_HI, 0.55))
		var txt := str(count) if count < 10 else "9+"
		var f := UIStyle.font_bold()
		var fs := 12
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - tw / 2.0, c.y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.ON_GOLD)
