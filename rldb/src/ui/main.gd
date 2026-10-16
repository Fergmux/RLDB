extends Control
## Entry scene: main menu, mode setup, and screen switching. Hosts the local
## hot-seat harness, LAN (ENet) dev sessions and Steam lobbies through the same
## SeatClient interface.

var menu: Control
var screen: GameScreen
var local_host: LocalHost
var net: NetSession
var privacy_overlay: PanelContainer
var _shown_seat: int = 0
var _privacy: bool = true
var opts := {"best_of": 3, "deck_mode": "starter", "names": ["Player 1", "Player 2"]}
var status_label: Label


func _ready() -> void:
	theme = UIStyle.make_theme()
	# Saved window mode (scripted runs keep their own window size).
	if not OS.get_cmdline_user_args().any(func(a): return String(a).contains("shots")):
		UIStyle.apply_window_mode()
	Music.start()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not ("--no-steam" in OS.get_cmdline_user_args()):
		var cfg := Series.load_mode_config()
		SteamBridge.init(int(cfg.get("steam_app_id", 480)))
		if SteamBridge.available():
			SteamBridge.steam().join_requested.connect(_on_steam_join_requested)
	_parse_cmdline()
	var launch_lobby := SteamBridge.launch_lobby()
	if launch_lobby != 0 and SteamBridge.available():
		_auto_started = true
		call_deferred("join_steam_lobby", launch_lobby)
	if not _auto_started:
		_show_menu()


## A friend's invite was accepted in the Steam overlay while the game is running.
func _on_steam_join_requested(lobby: int, _friend: int) -> void:
	if net != null and is_instance_valid(net) and net.is_active():
		if net.lobby_id == lobby:
			return
		_confirm_leave("Accepting this invite will leave your current series. Continue?", func(): join_steam_lobby(lobby))
		return
	join_steam_lobby(lobby)


func _confirm_leave(text: String, on_yes: Callable) -> void:
	var p := UIStyle.panel(Color(0.06, 0.07, 0.09, 0.97))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(520, 160)
	p.position = Vector2(540, 380)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UIStyle.label(text, 16, UIStyle.ACCENT, true))
	var row := HBoxContainer.new()
	v.add_child(row)
	var yes := UIStyle.button("Leave and continue", 14)
	yes.pressed.connect(func(): p.queue_free(); on_yes.call())
	row.add_child(yes)
	var no := UIStyle.button("Stay", 14)
	no.pressed.connect(func(): p.queue_free())
	row.add_child(no)


var _auto_started := false


## Command-line hooks for automated runs and screenshots:
##   -- --local [--seed=N] [--draft] [--bo=5]
##   -- --host=PORT / --join=HOST:PORT   (LAN dev transport)
func _parse_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var cfg := opts.duplicate(true)
	for a in args:
		if a.begins_with("--seed="):
			cfg["seed"] = int(a.split("=")[1])
		elif a == "--draft":
			cfg["deck_mode"] = "draft"
		elif a.begins_with("--bo="):
			cfg["best_of"] = int(a.split("=")[1])
		elif a == "--no-privacy":
			_privacy = false
		if a.ends_with("shots") or a.contains("shots="):
			# Scripted screenshot runs must never create or show the player's real saves.
			SeriesStore.DIR = "user://dev_saves"
	for a in args:
		if a.begins_with("--net-shots="):
			_auto_started = true
			var nd: Node = load("res://src/dev/net_shot_driver.gd").new()
			add_child(nd)
			nd.call_deferred("run", self, a.split("=")[1])
			return
		if a.begins_with("--deckbuilder-shots="):
			_auto_started = true
			call_deferred("_run_deckbuilder_shots", a.split("=", true, 1)[1])
			return
		if a.begins_with("--bot-shots="):
			_auto_started = true
			var bd: Node = load("res://src/dev/bot_driver.gd").new()
			add_child(bd)
			bd.call_deferred("run", self, a.split("=", true, 1)[1])
			return
		if a.begins_with("--f02-shots="):
			_auto_started = true
			var f2: Node = load("res://src/dev/f02_driver.gd").new()
			add_child(f2)
			f2.call_deferred("run", self, a.split("=", true, 1)[1])
			return
		if a.begins_with("--shots="):
			_auto_started = true
			var driver: Node = load("res://src/dev/shot_driver.gd").new()
			add_child(driver)
			driver.call_deferred("run", self, a.split("=")[1])
			return
		if a == "--local":
			_auto_started = true
			call_deferred("_start_local", cfg)
		elif a == "--bot":
			_auto_started = true
			call_deferred("_start_bot", cfg)
		elif a.begins_with("--host="):
			_auto_started = true
			call_deferred("_start_lan_host", int(a.split("=")[1]), cfg)
		elif a.begins_with("--join="):
			_auto_started = true
			var hp := a.split("=")[1].split(":")
			call_deferred("_start_lan_join", hp[0], int(hp[1]))


func _clear_screens() -> void:
	for n in [menu, screen, local_host, privacy_overlay, net]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	menu = null
	screen = null
	local_host = null
	privacy_overlay = null
	net = null


var _fading := false


## Fades to black, runs `fn` (which builds the next screen) and fades back in (user feedback:
## menu -> game, game -> menu and the collection screens). Input is blocked while black.
func _go(fn: Callable) -> void:
	if _fading:
		return
	if _auto_started and menu == null and screen == null:
		fn.call()
		return
	_fading = true
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.z_index = 300
	add_child(black)
	var out_s := 0.2 if UIStyle.reduce_motion else 0.35
	var in_s := 0.25 if UIStyle.reduce_motion else 0.55
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, out_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		fn.call()
		move_child(black, -1))
	tw.tween_interval(0.12)
	tw.tween_property(black, "color:a", 0.0, in_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		black.queue_free()
		_fading = false)


# ---------------------------------------------------------------- menu

const FONT_TITLE := preload("res://assets/fonts/Cinzel-Variable.ttf")
const M_WOOD := Color("2a211a")
const M_DEEP := Color("0e0d0c")
const M_SLATE := Color("1f1c1a")
const M_BRONZE := Color("7a5a30")
const M_GOLD := Color("d4a64a")
const M_PARCH := Color("ece4d2")
const M_DIM := Color("a79c88")


func _title_label(text: String, size: int, color: Color = M_GOLD) -> Label:
	var l := UIStyle.label(text, size, color)
	l.add_theme_font_override("font", FONT_TITLE)
	return l


## A bronze-trimmed slate plate with a heading; returns the VBox to fill.
func _section(parent: Control, heading: String, note: String = "") -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(M_SLATE, M_BRONZE, 1, 6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_title_label(heading, 20, M_GOLD))
	if note != "":
		v.add_child(UIStyle.label(note, 14, M_DIM, true))
	return v


## One entry of the left-hand menu: large Cinzel text, left-aligned. Hover slides it a touch
## right, turns it gold and draws a gold rule with a diamond marker; the item whose content is
## shown stays marked. `slide` is animated when a menu level appears.
class MenuItem extends Button:
	const MENU_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
	var label_text := ""
	var fs := 30
	var muted := false
	var active := false: set = _set_active
	var slide := 0.0: set = _set_slide
	var hl := 0.0: set = _set_hl
	var _tw: Tween

	func _init(t: String, size_px: int = 30, is_muted: bool = false) -> void:
		label_text = t
		fs = size_px
		muted = is_muted
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, fs * 1.75)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(func(): _to_hl(1.0); Sfx.play("select", 0.0, 0.03))
		mouse_exited.connect(func(): _to_hl(0.0))

	func _set_active(v: bool) -> void:
		active = v
		queue_redraw()

	func _set_slide(v: float) -> void:
		slide = v
		queue_redraw()

	func _set_hl(v: float) -> void:
		hl = v
		queue_redraw()

	func _to_hl(v: float) -> void:
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UIStyle.reduce_motion:
			hl = v
			return
		_tw = create_tween()
		_tw.tween_property(self, "hl", v, 0.14).set_trans(Tween.TRANS_SINE)

	func _draw() -> void:
		var font: Font = MENU_FONT
		var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mark := maxf(hl, 1.0 if active else 0.0)
		var x := 30.0 + 8.0 * hl + slide
		var base := size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		var col := (Color("a79c88") if muted else Color("ece4d2")).lerp(UIStyle.GOLD_HI, maxf(hl, 0.85 if active else 0.0))
		draw_string(font, Vector2(x + 2, base + 2), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55 * modulate.a))
		draw_string(font, Vector2(x, base), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if mark > 0.01:
			var y := base + 8.0
			draw_line(Vector2(x - 4.0, y), Vector2(x + tw, y), Color(UIStyle.GOLD, 0.55 * mark), 1.5, true)
			var c := Vector2(12.0 + slide, size.y / 2.0)
			var r := 5.0 + 1.5 * mark
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), Color(UIStyle.GOLD_HI, mark))


## Menu tree: level -> items [label, target]. A target starting with "@" opens a sub-level;
## anything else is a leaf shown in the centre (or an action).
const MENU := {
	"root": [["Resume", "resume"], ["Play", "@play"], ["Decks", "@decks"], ["Settings", "settings"], ["Quit", "quit"]],
	"play": [["Play online", "@online"], ["Play local", "@local"]],
	"online": [["Host game", "host_online"], ["Join game", "join_online"]],
	"local": [["Play vs Bot", "bot"], ["Hot-seat", "hotseat"], ["Host LAN", "host_lan"], ["Join LAN", "join_lan"]],
	"decks": [["Deck builder", "builder"], ["Card list", "cards"]],
}
const MENU_TITLES := {"root": "", "play": "Play", "online": "Play · Online", "local": "Play · Local", "decks": "Decks"}
const BAND_W := 520.0

var _menu_path: Array = ["root"]
var _menu_list: VBoxContainer
var _menu_crumb: Label
var _menu_center: CenterContainer
var _menu_leaf: String = ""
var _lan_addr: String = "127.0.0.1:24680"


func _show_menu() -> void:
	_clear_screens()
	_menu_path = ["root"]
	_menu_leaf = ""
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.add_child(UIStyle.background(0.05, UIStyle.MENU_BACKGROUND))
	# Darkened band on the left, fading out toward the right edge.
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.018, 0.025, 0.9))
	g.set_color(1, Color(0.02, 0.018, 0.025, 0.0))
	g.add_point(0.68, Color(0.02, 0.018, 0.025, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var band := TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_bottom = 1.0
	band.offset_right = BAND_W + 160.0
	menu.add_child(band)
	# Menu column (left-aligned, user feedback).
	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = 56.0
	col.offset_right = BAND_W - 60.0
	col.offset_top = 80.0
	col.offset_bottom = -40.0
	col.add_theme_constant_override("separation", 4)
	menu.add_child(col)
	var title := _title_label("RLDB", 88, M_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)
	var sub := _title_label("A TWO-PLAYER ROGUELIKE DECK BATTLER", 14, M_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 54)
	col.add_child(gap)
	_menu_crumb = _title_label("", 16, M_BRONZE.lightened(0.3))
	_menu_crumb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_crumb.custom_minimum_size = Vector2(0, 24)
	col.add_child(_menu_crumb)
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 2)
	col.add_child(_menu_list)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	status_label = UIStyle.label(SteamBridge.describe(), 13, M_DIM, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(status_label)
	# Content panels sit in the centre of the whole screen.
	_menu_center = CenterContainer.new()
	_menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(_menu_center)
	_build_menu_level(false)


## Builds the items of the current menu level; `animate` slides them in one after another.
func _build_menu_level(animate: bool = true) -> void:
	for ch in _menu_list.get_children():
		_menu_list.remove_child(ch)
		ch.queue_free()
	var level: String = _menu_path[-1]
	_menu_crumb.text = ""   # no breadcrumb above the options (user feedback); the spacer keeps the layout
	var items: Array = MENU[level].duplicate()
	if level == "root" and SeriesStore.list().is_empty():
		items = items.filter(func(it): return it[1] != "resume")
	var i := 0
	for it in items:
		var mi := MenuItem.new(it[0], 34 if level == "root" else 30)
		mi.active = it[1] == _menu_leaf
		var target: String = it[1]
		mi.pressed.connect(func(): _menu_pick(target))
		_menu_list.add_child(mi)
		_slide_in(mi, i, animate)
		i += 1
	if level != "root":
		var back := MenuItem.new("Back", 22, true)
		back.pressed.connect(_menu_back)
		_menu_list.add_child(back)
		_slide_in(back, i, animate)


func _slide_in(mi: MenuItem, i: int, animate: bool) -> void:
	if not animate or UIStyle.reduce_motion:
		return
	mi.modulate.a = 0.0
	mi.slide = -60.0
	var tw := mi.create_tween()
	tw.tween_interval(0.045 * i)
	tw.set_parallel(true)
	tw.tween_property(mi, "modulate:a", 1.0, 0.22)
	tw.tween_property(mi, "slide", 0.0, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _menu_pick(target: String) -> void:
	Sfx.play("confirm")
	if target.begins_with("@"):
		_menu_path.append(target.substr(1))
		_menu_leaf = ""
		_set_center(null)
		_build_menu_level()
		return
	match target:
		"quit":
			get_tree().quit()
		"builder":
			_go(_show_deck_builder)
		"cards":
			_go(_show_card_list)
		_:
			_menu_leaf = target
			for mi in _menu_list.get_children():
				if mi is MenuItem:
					(mi as MenuItem).active = false
			_build_menu_level(false)
			_set_center(_leaf_panel(target))


func _menu_back() -> void:
	Sfx.play("cancel")
	if _menu_path.size() > 1:
		_menu_path.pop_back()
	_menu_leaf = ""
	_set_center(null)
	_build_menu_level()


func _unhandled_input(event: InputEvent) -> void:
	if menu == null or not is_instance_valid(menu) or _menu_list == null or not is_instance_valid(_menu_list):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		if _menu_leaf != "":
			_menu_leaf = ""
			_set_center(null)
			_build_menu_level(false)
		elif _menu_path.size() > 1:
			_menu_back()
		get_viewport().set_input_as_handled()


## Shows `panel` in the centre area with a short fade/rise (or clears it when null).
func _set_center(panel: Control) -> void:
	for ch in _menu_center.get_children():
		_menu_center.remove_child(ch)
		ch.queue_free()
	if panel == null:
		return
	_menu_center.add_child(panel)
	if UIStyle.reduce_motion:
		return
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)


## A dark panel for centre content: returns [panel, content VBox].
func _center_panel(title: String, note: String = "") -> Array:
	var p := PanelContainer.new()
	var sb := UIStyle.flat(Color(0.035, 0.03, 0.04, 0.9), Color(UIStyle.GOLD, 0.5), 1, 12)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 24)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_title_label(title, 30, M_GOLD))
	if note != "":
		v.add_child(UIStyle.label(note, 15, M_DIM, true))
	return [p, v]


func _labelled(v: VBoxContainer, text: String, ctl: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UIStyle.label(text, 17, M_PARCH)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(ctl)
	v.add_child(row)


## Best-of / deck mode pickers shared by every "start a series" panel.
func _series_options(v: VBoxContainer) -> void:
	var bo := OptionButton.new()
	for n in [1, 3, 5, 7]:
		bo.add_item(str(n), n)
	bo.select([1, 3, 5, 7].find(opts["best_of"]))
	bo.item_selected.connect(func(i): opts["best_of"] = bo.get_item_id(i))
	_labelled(v, "Best of", bo)
	var dm := OptionButton.new()
	dm.add_item("Starter decks")
	dm.add_item("Draft")
	dm.select(0 if opts["deck_mode"] == "starter" else 1)
	dm.item_selected.connect(func(i): opts["deck_mode"] = "starter" if i == 0 else "draft")
	_labelled(v, "Decks", dm)


func _start_button(v: VBoxContainer, text: String, fn: Callable) -> void:
	var b := UIStyle.primary_button(text, 19)
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(fn)
	v.add_child(b)


## Centre content for a leaf of the menu tree.
func _leaf_panel(target: String) -> Control:
	var pv: Array
	match target:
		"bot":
			pv = _center_panel("Play vs Bot", "A series against the computer. The bot picks a random starter deck.")
			_series_options(pv[1])
			_start_button(pv[1], "Start series", func(): _go(func(): _start_bot(opts.duplicate(true))))
		"hotseat":
			pv = _center_panel("Hot-seat", "Two players take turns on this screen.")
			_series_options(pv[1])
			var priv := CheckBox.new()
			priv.text = "Privacy screen between turns"
			priv.button_pressed = _privacy
			priv.toggled.connect(func(on): _privacy = on)
			pv[1].add_child(priv)
			_start_button(pv[1], "Start series", func(): _go(func(): _start_local(opts.duplicate(true))))
		"host_lan":
			pv = _center_panel("Host LAN", "Your friend joins with your computer's local IP address and this port.")
			_series_options(pv[1])
			var port := LineEdit.new()
			port.text = _lan_addr.split(":")[-1]
			port.custom_minimum_size = Vector2(160, 0)
			_labelled(pv[1], "Port", port)
			_start_button(pv[1], "Host series", func(): _go(func(): _start_lan_host(int(port.text), opts.duplicate(true))))
		"join_lan":
			pv = _center_panel("Join LAN", "Enter the host's address and port (for example 192.168.1.20:24680).")
			var addr := LineEdit.new()
			addr.text = _lan_addr
			addr.custom_minimum_size = Vector2(260, 0)
			_labelled(pv[1], "Address", addr)
			_start_button(pv[1], "Join", func():
				_lan_addr = addr.text
				var hp := addr.text.split(":")
				_go(func(): _start_lan_join(hp[0], int(hp[1]) if hp.size() > 1 else 24680)))
		"host_online":
			pv = _center_panel("Host game", "Creates a Steam lobby and opens the invite dialog.")
			_series_options(pv[1])
			var pub := CheckBox.new()
			pub.text = "List my lobby publicly"
			pub.tooltip_text = "Off: friends-only, joined by invite. On: also visible under Join game."
			pub.button_pressed = opts.get("public_lobby", false)
			pub.toggled.connect(func(on): opts["public_lobby"] = on)
			pv[1].add_child(pub)
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, M_DIM, true))
			_start_button(pv[1], "Host and invite", func(): _go(func(): _start_steam_host()))
		"join_online":
			pv = _center_panel("Join game", "Accept a friend's invite in the Steam overlay, or browse public lobbies.")
			pv[1].add_child(UIStyle.label(SteamBridge.describe(), 14, M_DIM, true))
			_start_button(pv[1], "Browse public lobbies", func(): _go(_start_steam_browse))
		"resume":
			pv = _center_panel("Resume", "Pick up a series where you left it.")
			_add_saved_series(pv[1], SeriesStore.list())
		"settings":
			pv = _center_panel("Settings")
			pv[1].add_child(UIStyle.display_controls(16))
			pv[1].add_child(GameScreen.audio_controls(16))
			var rm := CheckBox.new()
			rm.text = "Reduced motion (no travel, shake or particles)"
			rm.button_pressed = UIStyle.reduce_motion
			rm.toggled.connect(func(on): UIStyle.set_reduce_motion(on))
			pv[1].add_child(rm)
			var fa := CheckBox.new()
			fa.text = "Fast animations (half duration)"
			fa.button_pressed = UIStyle.fast_anim
			fa.toggled.connect(func(on): UIStyle.set_fast_anim(on))
			pv[1].add_child(fa)
			var priv2 := CheckBox.new()
			priv2.text = "Privacy screen between turns (hot-seat)"
			priv2.button_pressed = _privacy
			priv2.toggled.connect(func(on): _privacy = on)
			pv[1].add_child(priv2)
		_:
			return null
	return pv[0]


func _new_screen() -> GameScreen:
	screen = GameScreen.new()
	add_child(screen)
	screen.back_to_menu.connect(_on_menu_requested)
	screen.leave_to_menu.connect(func(): _go(_show_menu))
	return screen


# ---------------------------------------------------------------- local hot-seat

func _start_local(cfg: Dictionary) -> void:
	_clear_screens()
	cfg["mode"] = "local"
	local_host = LocalHost.new()
	add_child(local_host)
	local_host.start(cfg)
	_new_screen()
	_shown_seat = 0
	screen.attach(local_host.seats[0])
	for s in local_host.seats:
		s.view_changed.connect(func(_v): call_deferred("_check_hotseat"))


## Series against the bot: you are seat 0, the BotPlayer drives seat 1 (random starter deck).
## The screen never switches seats.
func _start_bot(cfg: Dictionary) -> void:
	_clear_screens()
	cfg["names"] = ["Player", "Bot"]
	cfg["mode"] = "bot"
	local_host = LocalHost.new()
	add_child(local_host)
	local_host.start(cfg)
	_new_screen()
	_shown_seat = 0
	screen.attach(local_host.seats[0])
	var bot := BotPlayer.new()
	local_host.add_child(bot)
	bot.start(local_host, 1, screen)


## Hot-seat: when the other seat must act, hand the screen over (optionally behind
## a privacy screen so the next player does not see the previous player's hand).
func _check_hotseat() -> void:
	if local_host == null or screen == null:
		return
	var want := local_host.acting_seat()
	if want == _shown_seat:
		return
	# Let the current seat's end-of-turn animation finish before handing the screen over.
	var wait_ms: int = screen.fx_hold_until - Time.get_ticks_msec()
	if wait_ms > 0:
		get_tree().create_timer(float(wait_ms) / 1000.0).timeout.connect(_check_hotseat, CONNECT_ONE_SHOT)
		return
	if _privacy:
		_show_privacy(want)
	else:
		_switch_seat(want)


func _switch_seat(seat: int) -> void:
	_shown_seat = seat
	screen.attach(local_host.seats[seat])


func _show_privacy(seat: int) -> void:
	if privacy_overlay != null and is_instance_valid(privacy_overlay):
		privacy_overlay.queue_free()
	privacy_overlay = UIStyle.panel(Color(0.05, 0.05, 0.07, 1.0))
	privacy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(privacy_overlay)
	var c := CenterContainer.new()
	privacy_overlay.add_child(c)
	var v := VBoxContainer.new()
	c.add_child(v)
	v.add_child(UIStyle.label("Pass to %s" % local_host.series.names[seat], 36, UIStyle.ACCENT))
	v.add_child(UIStyle.label("Hidden information is protected between seats.", 14, UIStyle.MUTED))
	var b := UIStyle.button("I am %s — continue" % local_host.series.names[seat], 18)
	b.pressed.connect(func():
		privacy_overlay.queue_free()
		privacy_overlay = null
		_switch_seat(seat))
	v.add_child(b)


# ---------------------------------------------------------------- network sessions

func _start_lan_host(port: int, cfg: Dictionary) -> void:
	_clear_screens()
	cfg["mode"] = "lan"
	net = NetSession.new()
	add_child(net)
	var err := net.host_enet(port, cfg)
	_new_screen()
	screen.attach(net.local_seat)
	if err != "":
		net.local_seat.status_changed.emit(err)


func _start_lan_join(host: String, port: int) -> void:
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	var err := net.join_enet(host, port)
	_new_screen()
	screen.attach(net.local_seat)
	if err != "":
		net.local_seat.status_changed.emit(err)


func _start_steam_host(cfg: Dictionary = {}) -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	var hc: Dictionary = cfg if not cfg.is_empty() else opts.duplicate(true)
	hc["mode"] = "steam"
	net.host_steam(hc)
	_new_screen()
	screen.attach(net.local_seat)


func _start_steam_browse() -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	_new_screen()
	screen.attach(net.local_seat)
	net.lobbies_found.connect(_show_lobbies)
	net.browse_steam()


func _show_lobbies(lobbies: Array) -> void:
	var panel := UIStyle.panel(Color(0.06, 0.07, 0.09, 0.97))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 300)
	panel.position = Vector2(540, 300)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UIStyle.label("RLDB lobbies", 20, UIStyle.ACCENT))
	if lobbies.is_empty():
		v.add_child(UIStyle.label("No lobbies found. Ask a friend to host and invite you through Steam.", 14, UIStyle.MUTED, true))
	for l in lobbies:
		var b := UIStyle.button("Join %s's lobby (%d/2)" % [l["host"], l["members"]], 14)
		b.pressed.connect(func(): panel.queue_free(); join_steam_lobby(l["id"]))
		v.add_child(b)
	var back := UIStyle.button("Back to menu", 13)
	back.pressed.connect(func(): panel.queue_free(); _show_menu())
	v.add_child(back)


func join_steam_lobby(lobby_id: int) -> void:
	_clear_screens()
	net = NetSession.new()
	add_child(net)
	_new_screen()
	screen.attach(net.local_seat)
	net.join_steam(lobby_id)


# ---------------------------------------------------------------- card list

func _show_card_list() -> void:
	_clear_screens()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	menu.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var counts := {}
	for d in CardDB.all():
		var s := CardScripts.support_status(d["id"])
		counts[s] = counts.get(s, 0) + 1
	var t := UIStyle.label("All %d cards · support: %s" % [CardDB.all().size(), str(counts)], 18, UIStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := UIStyle.button("Back", 14)
	back.pressed.connect(func(): _go(_show_menu))
	head.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	sc.add_child(flow)
	var gs := GameScreen.new()
	for d in CardDB.all():
		var summary := Series._card_summary(d["id"])
		var w := CardWidget.new().setup(gs._summary_view(summary), "big")
		flow.add_child(w)
	gs.free()


func _on_menu_requested() -> void:
	if net != null and is_instance_valid(net) and net.is_active():
		_confirm_leave("Leave this online series? Your opponent will be left waiting.", func(): _go(_show_menu))
		return
	_go(_show_menu)



# ---------------------------------------------------------------- saved series (P-02)

const MODE_NAMES := {"bot": "Against the bot", "local": "Hot-seat", "lan": "LAN (you host)", "steam": "Steam (you host)"}


## Unfinished series saved between games, newest first: one tile each with the players, the
## score, how it was played and when, a Resume button (reopens it the same way) and Delete.
func _add_saved_series(box: VBoxContainer, saves: Array) -> void:
	if saves.is_empty():
		box.add_child(UIStyle.label("No saved series.", 15, M_DIM))
	for sv in saves.slice(0, 5):
		var tile := PanelContainer.new()
		var sb := UIStyle.flat(Color(1, 1, 1, 0.035), Color(UIStyle.BRONZE, 0.7), 1, 10)
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			sb.set_content_margin(side, 16)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			sb.set_content_margin(side, 12)
		tile.add_theme_stylebox_override("panel", sb)
		box.add_child(tile)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		tile.add_child(row)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_title_label("%s  vs  %s" % [sv["names"][0], sv["names"][1]], 20, M_PARCH))
		var when := String(sv["saved_at"]).replace("T", "  ")
		info.add_child(UIStyle.label("%s  ·  best of %d  ·  next: game %d" % [MODE_NAMES.get(sv.get("mode", "local"), "Hot-seat"), int(sv["best_of"]), int(sv.get("game_no", 0)) + 1], 14, M_DIM))
		info.add_child(UIStyle.label("Saved %s" % when.substr(0, 17), 13, M_DIM))
		var score := _title_label("%d – %d" % [int(sv["scores"][0]), int(sv["scores"][1])], 30, M_GOLD)
		score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(score)
		var btns := VBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btns)
		var id: String = sv["id"]
		var mode: String = String(sv.get("mode", "local"))
		var res := UIStyle.primary_button("Resume", 16)
		res.custom_minimum_size = Vector2(130, 40)
		res.disabled = mode == "steam" and not SteamBridge.available()
		if res.disabled:
			res.tooltip_text = SteamBridge.describe()
		res.pressed.connect(func(): _resume(id, mode))
		btns.add_child(res)
		var del := UIStyle.button("Delete", 13)
		del.custom_minimum_size = Vector2(130, 30)
		del.pressed.connect(func(): _confirm_leave("Delete this saved series?", func():
			SeriesStore.delete(id)
			_show_menu()))
		btns.add_child(del)


## Reopens a saved series the way it was being played (bot, hot-seat, LAN host, Steam host).
func _resume(id: String, how: String) -> void:
	var s := SeriesStore.load_series(id)
	if s == null:
		status_label.text = "That save could not be read."
		return
	var cfg := {"resume": s}
	match how:
		"bot": _go(func(): _start_bot(cfg))
		"lan": _go(func(): _start_lan_host(24680, cfg))
		"steam": _go(func(): _start_steam_host(cfg))
		_: _go(func(): _start_local(cfg))


func _show_deck_builder() -> void:
	_clear_screens()
	var db: Control = load("res://src/ui/deck_builder.gd").new()
	menu = db
	add_child(db)
	db.connect("closed", func(): _go(_show_menu))


# ---------------------------------------------------------------- dev: deck builder screenshots

func _shot_to(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## `-- --deckbuilder-shots=<dir>`: drives the builder, saves a deck, captures, quits.
func _run_deckbuilder_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 5:
		await get_tree().process_frame
	_show_menu()
	for i in 4:
		await get_tree().process_frame
	await _shot_to(dir, "01_main_menu")
	_show_deck_builder()
	for i in 4:
		await get_tree().process_frame
	var db: DeckBuilder = menu as DeckBuilder
	await _shot_to(dir, "02_builder_empty")
	db.set_filters("dragon")
	db.deck_name_edit.text = "Screenshot Deck"
	var added := 0
	for d in CardDB.all():
		if added >= 10:
			break
		if DeckBuilder.matches(d, "dragon", "", "", "", ""):
			db.add_card(int(d["id"]), 2 if added < 2 else 1)
			added += 1
	for cost in ["kind:fusion", "kind:ritual", "kind:arcane"]:
		for d in CardDB.all():
			if DeckBuilder.matches(d, "", "", "", "", cost):
				db.add_card(int(d["id"]))
				break
	for d in CardDB.all():
		if d["category"] in ["spell", "trap", "power"]:
			db.add_card(int(d["id"]))
			if db.counts.size() > 18:
				break
	for d in CardDB.all():
		if d["category"] == "fusion":
			db.show_preview(int(d["id"]))
			break
	for i in 3:
		await get_tree().process_frame
	await _shot_to(dir, "03_builder_search_dragon")
	db.set_filters("")
	db._cat_opt.select(db._cat_opt.item_count - 1)
	db._refresh_catalogue()
	db.save()
	for i in 3:
		await get_tree().process_frame
	await _shot_to(dir, "04_builder_saved_filter_arcane")
	DeckStore.delete_deck("Screenshot Deck")  # leave the player's decks untouched
	get_tree().quit()
