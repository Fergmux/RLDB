class_name GameMenu
extends RefCounted
## Top strip of the match screen (connection state + Menu button), the in-game menu (Settings,
## Concede, Return to menu, Quit to desktop), the interface settings popup and the
## confirmation dialogs for leaving or conceding.

const SETTINGS_W := 400.0

## The host screen this component works on.
var gs: GameScreen
## Strip along the top edge (menu button, connection state).
var top_strip: Control
## Connection state text.
var conn_label: Label
## The in-game menu popup.
var game_menu: PanelContainer
## The settings popup.
var settings_popup: PanelContainer
var _dialog_root: ConfirmDialog


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the top strip: connection label and the Menu button.
func build_top_strip() -> void:
	top_strip = Control.new()
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gs.add_child(top_strip)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	top_strip.add_child(row)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	conn_label = UIStyle.label("", 14, UIStyle.MUTED)
	conn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(conn_label)
	var menu_b := UIStyle.button("Menu", 13)
	menu_b.custom_minimum_size = Vector2(76, 30)
	menu_b.pressed.connect(toggle)
	row.add_child(menu_b)


## Builds the in-game menu and the settings popup (hidden).
func build_popups() -> void:
	# In-game menu (Menu button / Esc): Settings, Concede, Return to menu, Quit to desktop.
	game_menu = PanelContainer.new()
	var gms := UIStyle.panel_style(Color(0.05, 0.045, 0.04, 0.98), UIStyle.GOLD, 10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		gms.set_content_margin(side, 14)
	gms.shadow_size = 14
	gms.shadow_color = Color(0, 0, 0, 0.6)
	game_menu.add_theme_stylebox_override("panel", gms)
	game_menu.visible = false
	game_menu.z_index = UiLayers.GAME_MENU
	gs.add_child(game_menu)
	var gmv := VBoxContainer.new()
	gmv.add_theme_constant_override("separation", 8)
	game_menu.add_child(gmv)
	for it in [["Settings", func(): game_menu.visible = false; settings_popup.visible = true],
			["Concede game", func(): game_menu.visible = false; _confirm_concede()],
			["Return to menu", func(): confirm_forfeit(false)],
			["Quit to desktop", func(): confirm_forfeit(true)]]:
		var gb := UIStyle.button(it[0], 16)
		gb.custom_minimum_size = Vector2(230, 42)
		gb.pressed.connect(it[1])
		gmv.add_child(gb)
	# Settings
	settings_popup = PanelContainer.new()
	settings_popup.add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.07, 0.065, 0.06, 0.99), UIStyle.GOLD, 10))
	settings_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_popup.visible = false
	gs.add_child(settings_popup)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	settings_popup.add_child(sv)
	sv.add_child(GameUi.header("Interface settings"))
	var rm := CheckBox.new()
	rm.text = "Reduced motion (no travel, shake or particles)"
	rm.button_pressed = UIStyle.reduce_motion
	rm.toggled.connect(func(on): UIStyle.set_reduce_motion(on); gs.fx.finish_all(); gs.render_all())
	sv.add_child(rm)
	var fa := CheckBox.new()
	fa.text = "Fast animations (half duration)"
	fa.button_pressed = UIStyle.fast_anim
	fa.toggled.connect(func(on): UIStyle.set_fast_anim(on))
	sv.add_child(fa)
	sv.add_child(UIStyle.display_controls(14))
	sv.add_child(audio_controls(14))
	var cl := UIStyle.button("Close", 13)
	cl.pressed.connect(func(): settings_popup.visible = false)
	sv.add_child(cl)


## Places the top strip over the play field and the popups under it, against the sidebar.
func layout(w: float) -> void:
	top_strip.position = Vector2.ZERO
	top_strip.size = Vector2(w - gs.sidebar_w, GameScreen.TOP_H)


## Places the settings popup and the menu (called after the banner and pause are placed).
func layout_popups(w: float) -> void:
	settings_popup.position = Vector2(w - gs.sidebar_w - SETTINGS_W, GameScreen.TOP_H + 4.0)
	game_menu.reset_size()
	game_menu.position = Vector2(w - gs.sidebar_w - game_menu.get_combined_minimum_size().x - 10.0, GameScreen.TOP_H + 4.0)


## Connection state in the top strip (network games only).
func update_conn() -> void:
	var net: Dictionary = gs.view.get("net", {})
	if net.is_empty():
		conn_label.text = ""
	elif net.get("paused", false):
		conn_label.text = "● Paused"
	elif not net.get("opponent_connected", true):
		conn_label.text = "● Opponent not connected"
	else:
		conn_label.text = "● Connected (%s)" % net.get("transport", "net")
	conn_label.add_theme_color_override("font_color", UIStyle.BAD if (net.get("paused", false) or not net.get("opponent_connected", true)) and not net.is_empty() else UIStyle.MUTED)


## Opens or closes the in-game menu (closes the settings popup).
func toggle() -> void:
	Sfx.play("select")
	settings_popup.visible = false
	game_menu.visible = not game_menu.visible
	if game_menu.visible:
		gs.hover.clear()


## Return to menu / Quit to desktop: an unfinished series is forfeited (after a warning).
func confirm_forfeit(quit: bool) -> void:
	game_menu.visible = false
	var live := gs.has_live_series()
	var go := func():
		if live:
			gs.send({"t": "forfeit_series"})
		if quit:
			# A couple of frames so a network forfeit is flushed before the peer closes.
			await gs.get_tree().process_frame
			await gs.get_tree().process_frame
			gs.get_tree().quit()
		else:
			gs.leave_to_menu.emit()
	if not live:
		go.call()
		return
	_dialog("Are you sure?", "Quitting will forfeit the match.", "Forfeit and %s" % ("quit" if quit else "leave"), go)


## Opens the shared confirmation dialog over the screen (one at a time).
func _dialog(title: String, text: String, confirm: String, on_yes: Callable) -> void:
	close_dialog()
	_dialog_root = ConfirmDialog.open(gs, title, text, confirm, on_yes)
	gs.hover.clear()


## Closes the open confirmation dialog; returns true when there was one.
func close_dialog() -> bool:
	if _dialog_root != null and is_instance_valid(_dialog_root) and not _dialog_root.is_queued_for_deletion():
		_dialog_root.close()
		_dialog_root = null
		return true
	_dialog_root = null
	return false


func _confirm_concede() -> void:
	_dialog("Concede this game?", "Your opponent wins this game; the series continues.", "Concede", func(): gs.send({"t": "concede"}))


## Music and sound-effect volume sliders with mute boxes (game settings and main menu).
static func audio_controls(fs: int) -> Control:
	Sfx.load_settings()
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	for row in [["Music volume", Music.get_volume(), Music.is_muted(), Music.set_volume, Music.set_muted],
			["Sound effects", Sfx.get_volume(), Sfx.is_muted(), Sfx.set_volume, Sfx.set_muted]]:
		g.add_child(UIStyle.label(row[0], fs, UIStyle.TEXT))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = row[1]
		sl.custom_minimum_size = Vector2(170, 24)
		sl.value_changed.connect(row[3])
		if row[0] == "Sound effects":
			sl.drag_ended.connect(func(_c): Sfx.play("select"))
		g.add_child(sl)
		var mb := CheckBox.new()
		mb.text = "Mute"
		mb.button_pressed = row[2]
		mb.toggled.connect(row[4])
		g.add_child(mb)
	return g
