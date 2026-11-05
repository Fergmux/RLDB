class_name GameMenu
extends RefCounted
## Top strip of the match screen (connection state + Menu button), the in-game menu (Settings,
## Return to menu, Concede game, Quit to desktop), the interface settings popup and the
## confirmation dialogs for leaving or conceding.

const SETTINGS_W := 400.0
## Menu button (design review #15): the standard small height that fits the 44 px top strip (the
## review's 40 px at 16 px from the top needs a taller strip, GameScreen.TOP_H), 96 px wide with
## the ☰ glyph; Chat beside it takes the same size.
const MENU_BUTTON := Vector2(96, 36)
## Veil behind the in-game settings (design review #13: the standard modal veil).
const SETTINGS_VEIL := Color(0, 0, 0, 0.55)
## In-game menu opening (design review #14): it grows out of the Menu button corner.
const MENU_OPEN_SCALE := 0.94
const MENU_OPEN_DROP := 8.0
## In-game menu items that end the game (Danger family, design review #14).
const DANGER_ITEMS := ["concede", "quit"]
## Gap between the Menu button strip and the popups under it.
const POPUP_GAP := 8.0

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
## The in-game menu's buttons by key (settings, spectators, concede, return, stop, quit).
var items: Dictionary = {}
## The Menu button in the top strip.
var menu_button: Button
## L26: the compact series scoreboard in the middle of the top strip.
var scoreboard: SeriesScoreboard
## The veil behind the in-game settings (shown with it).
var settings_veil: ColorRect
## The shared settings form inside the settings popup.
var settings_form: SettingsForm
## L13: the full-window click catcher under the open in-game menu (a click on it closes the menu).
var outside_catcher: Control
var _dialog_root: ConfirmDialog
## L13: true while the in-game menu plays its closing motion; its tween.
var _closing: bool = false
var _close_tw: Tween
var _menu_rest: Vector2


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the top strip: connection label and the Menu button.
func build_top_strip() -> void:
	top_strip = Control.new()
	top_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_strip.z_index = UiLayers.TOP_STRIP     # UI review F12: the Menu button is never under a burst
	gs.add_child(top_strip)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UIStyle.sp("md")
	row.offset_right = -UIStyle.sp("lg")
	row.offset_top = (GameScreen.TOP_H - MENU_BUTTON.y) / 2.0
	row.offset_bottom = -(GameScreen.TOP_H - MENU_BUTTON.y) / 2.0
	row.add_theme_constant_override("separation", UIStyle.sp("md"))
	top_strip.add_child(row)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	conn_label = UIStyle.label("", 14, UIStyle.MUTED)
	conn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(conn_label)
	var menu_b := UIStyle.secondary_button("☰  Menu", 15)
	menu_b.name = "MenuButton"
	menu_b.custom_minimum_size = MENU_BUTTON
	menu_b.tooltip_text = "Menu"
	menu_b.pressed.connect(toggle)
	row.add_child(menu_b)
	menu_button = menu_b
	# L26 (owner, 5 Nov): the series at a glance, centred in the strip over the board (hidden in a
	# single game); GameSidebar.update_scoreboard keeps it current and pops each new point in.
	scoreboard = SeriesScoreboard.new()
	top_strip.add_child(scoreboard)
	# A1 / A2: Chat sits right before Menu; the spectator badge (and Watch button) before Chat.
	gs.chat.build(row, menu_b)
	if gs.chat.button != null:
		gs.chat.button.custom_minimum_size = MENU_BUTTON   # review #15: Chat matches Menu, 12 px apart
		gs.chat.button.add_theme_font_size_override("font_size", 15)
	gs.spectate.build(row, gs.chat.button)


## J15 (owner, 22 Oct): while the series modal is up the top strip (Menu, Chat, spectator badge) draws
## above its full-window dim, where it is; `false` returns it to its in-game layer.
func raise_top_strip(on: bool) -> void:
	if top_strip != null:
		top_strip.z_index = UiLayers.SERIES_TOP_STRIP if on else UiLayers.TOP_STRIP


## True when global point `at` is over one of the top strip's visible buttons (Menu, Chat, Watch...).
func over_top_button(at: Vector2) -> bool:
	if top_strip == null or not top_strip.is_visible_in_tree():
		return false
	for b in top_strip.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree() and (b as Control).get_global_rect().has_point(at):
			return true
	return false


## Builds the in-game menu and the settings popup (hidden).
func build_popups() -> void:
	# In-game menu (Menu button / Esc): Settings, Return to menu, then the destructive group.
	# Design review #14: 16 px inset, 12 px between items, a divider before the destructive group,
	# which uses the Danger family (Concede game, Quit to desktop). J13 (owner, 22 Oct): Concede game
	# comes below Return to menu.
	var menu_plate := HousePanel.new("Menu", "", Vector2(UIStyle.sp("lg"), UIStyle.sp("lg")), UIStyle.sp("md"))
	game_menu = menu_plate
	game_menu.visible = false
	game_menu.z_index = UiLayers.GAME_MENU
	gs.add_child(game_menu)
	var gmv := menu_plate.body
	# A2: "Spectators" for online players, "Stop watching" instead of conceding / returning for a
	# spectator (refresh_items shows the right set for the current view).
	for it in [["settings", "Settings", func(): game_menu.visible = false; _show_popup(settings_popup)],
			["spectators", "Spectators", func(): game_menu.visible = false; gs.spectate.toggle_list()],
			["return", "Return to menu", func(): confirm_forfeit(false)],
			["stop", "Stop watching", func(): confirm_forfeit(false)],
			["concede", "Concede game", func(): game_menu.visible = false; _confirm_concede()],
			["quit", "Quit to desktop", func(): confirm_forfeit(true)]]:
		var key := String(it[0])
		if key == "concede":
			var rule := Ornate.Rule.new(Color(UIStyle.GOLD, 0.45), true, 10.0)
			rule.name = "DestructiveDivider"
			gmv.add_child(rule)
		var gb := UIStyle.danger_button(it[1], 16) if key in DANGER_ITEMS else UIStyle.secondary_button(it[1], 16)
		gb.name = "Menu_" + key
		gb.custom_minimum_size = Vector2(230, 42)
		gb.pressed.connect(it[2])
		gmv.add_child(gb)
		items[it[0]] = gb
	refresh_items()
	# L13 (owner, 5 Nov): a click anywhere off the open menu closes it (with its close cue and
	# motion). A transparent catcher under the menu takes that click, so it never reaches the board.
	outside_catcher = Control.new()
	outside_catcher.name = "MenuOutsideCatcher"
	outside_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	outside_catcher.z_index = UiLayers.GAME_MENU - 1
	outside_catcher.visible = false
	outside_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outside_catcher.gui_input.connect(_on_outside_input)
	gs.add_child(outside_catcher)
	game_menu.visibility_changed.connect(func(): outside_catcher.visible = game_menu.visible and not _closing)
	# Settings (design review #12, #13): the shared SettingsForm (the same builder as the main
	# menu's Settings), centred on the board over the standard veil, with a 44 px Close.
	settings_veil = ColorRect.new()
	settings_veil.name = "SettingsVeil"
	settings_veil.color = SETTINGS_VEIL
	settings_veil.visible = false
	settings_veil.z_index = UiLayers.GAME_MENU
	settings_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_veil.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close_settings())
	gs.add_child(settings_veil)
	var set_plate := HousePanel.new("Settings", "In game", Vector2(28, 24), UIStyle.sp("md"))
	set_plate.arm = 18.0
	settings_popup = set_plate
	settings_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_popup.visible = false
	settings_popup.z_index = UiLayers.GAME_MENU
	gs.add_child(settings_popup)
	settings_popup.visibility_changed.connect(func(): settings_veil.visible = settings_popup.visible)
	var sv := set_plate.body
	var head := set_plate.add_headline("Settings", 28, false, 10.0, false)
	set_plate.set_meta(&"headline", TitleText.apply(head, TitleText.Tier.SCREEN, 28))
	settings_form = SettingsForm.new(func(_on): gs.fx.finish_all(); gs.render_all())
	sv.add_child(settings_form)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cl := UIStyle.size_button(UIStyle.secondary_button("Close", 15), "standard")
	cl.name = "Close"
	cl.custom_minimum_size.x = 160
	cl.pressed.connect(close_settings)
	row.add_child(cl)
	sv.add_child(row)


## Places the top strip over the play field and the popups under it, against the sidebar.
func layout(w: float) -> void:
	top_strip.position = Vector2.ZERO
	top_strip.size = Vector2(w - gs.sidebar_w, GameScreen.TOP_H)


## Places the settings popup and the menu (called after the banner and pause are placed).
func layout_popups(w: float) -> void:
	settings_popup.reset_size()
	var ss := settings_popup.get_combined_minimum_size()
	var sw := maxf(SETTINGS_W, ss.x)
	var board_w := w - gs.sidebar_w
	var h := gs.size.y
	settings_popup.size = Vector2(sw, ss.y)
	settings_popup.position = Vector2(floorf((board_w - sw) / 2.0), maxf(GameScreen.TOP_H, floorf((h - ss.y) / 2.0)))
	settings_veil.position = Vector2.ZERO
	settings_veil.size = Vector2(w, h)
	game_menu.reset_size()
	game_menu.position = Vector2(w - gs.sidebar_w - game_menu.get_combined_minimum_size().x - 10.0, GameScreen.TOP_H + POPUP_GAP)


## Connection state in the top strip (network games only). A1 (owner feedback 20 Oct): a healthy
## connection shows nothing (no "Connected (steam)"); only a pause or a missing opponent is named.
func update_conn() -> void:
	var net: Dictionary = gs.view.get("net", {})
	if net.is_empty():
		conn_label.text = ""
	elif net.get("paused", false):
		conn_label.text = "● Paused"
	elif not net.get("opponent_connected", true) and not gs.is_spectator():
		conn_label.text = "● Opponent not connected"
	else:
		conn_label.text = ""
	conn_label.visible = conn_label.text != ""
	conn_label.add_theme_color_override("font_color", UIStyle.BAD)
	refresh_items()


## Shows the in-game menu buttons that fit this screen: a spectator gets Settings, Stop watching and
## Quit; everyone online also gets View lobby (J22, with the spectator count). Concede game shows only while a game
## is being played (between duels there is nothing to concede; the host would refuse it).
func refresh_items() -> void:
	if items.is_empty():
		return
	var spec := gs.is_spectator()
	var n: int = gs.spectate.watchers().size()
	(items["spectators"] as Button).visible = gs.is_network()
	(items["spectators"] as Button).text = "View lobby (%d watching)" % n if n > 0 else "View lobby"
	(items["concede"] as Button).visible = (not spec and String(gs.view.get("stage", "")) == "game"
			and not gs.mv.is_empty() and int(gs.mv.get("winner", -1)) == -1)
	(items["return"] as Button).visible = not spec
	(items["stop"] as Button).visible = spec


## Final review (2026-11-05): closes the in-game Settings popup with the panel_close cue and the
## closing motion, as the in-game menu (L13) and the other popovers; false when it was not open.
## The Close button, a click on the veil and Esc all come here.
func close_settings() -> bool:
	var hp := settings_popup as HousePanel
	if not hp.is_open():
		return false
	hp.dismiss()
	return true


## Hides every top-strip popover (menu, settings, chat, spectators) before another opens.
func close_popups() -> void:
	game_menu.visible = false
	settings_popup.visible = false
	if gs.chat.panel != null:
		gs.chat.panel.visible = false
	if gs.spectate.panel != null:
		gs.spectate.panel.visible = false


## Opens or closes the in-game menu (closes the settings popup).
func toggle() -> void:
	Sfx.play("select")
	settings_popup.visible = false
	if gs.chat.panel != null:
		gs.chat.panel.visible = false
	if gs.spectate.panel != null:
		gs.spectate.panel.visible = false
	if game_menu.visible and not _closing:
		close_menu()
	else:
		_stop_closing()
		refresh_items()
		_show_popup(game_menu)
		outside_catcher.visible = true   # L13 (a menu reopened mid-close never stopped being visible)
		gs.hover.clear()


## L13: closes the in-game menu with the panel_close cue and the reverse of its opening motion (it
## shrinks back into the Menu button corner, rising 8 px as it fades; a plain hide under reduce
## motion). Returns false when the menu was not open.
func close_menu() -> bool:
	if not game_menu.visible or _closing:
		return false
	Sfx.play("panel_close")
	if UIStyle.reduce_motion or not game_menu.is_inside_tree():
		game_menu.visible = false
		return true
	_closing = true
	outside_catcher.visible = false
	game_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE   # no clicks on a closing menu
	var rest := game_menu.position
	_menu_rest = rest
	game_menu.pivot_offset = Vector2(game_menu.size.x, 0)
	_close_tw = game_menu.create_tween().set_parallel(true)
	UIStyle.tween_token(_close_tw, game_menu, "modulate:a", 0.0, "panel_out")
	UIStyle.tween_token(_close_tw, game_menu, "scale", Vector2.ONE * MENU_OPEN_SCALE, "panel_out")
	UIStyle.tween_token(_close_tw, game_menu, "position", rest - Vector2(0, MENU_OPEN_DROP), "panel_out")
	_close_tw.chain().tween_callback(func():
		_stop_closing()
		game_menu.visible = false)
	return true


## L13: ends a closing motion at once and leaves the menu at rest (still visible).
func _stop_closing() -> void:
	if _close_tw != null and _close_tw.is_valid():
		_close_tw.kill()
	_close_tw = null
	if _closing:
		_closing = false
		game_menu.modulate.a = 1.0
		game_menu.scale = Vector2.ONE
		game_menu.position = _menu_rest
		game_menu.pivot_offset = game_menu.size / 2.0
		game_menu.mouse_filter = Control.MOUSE_FILTER_STOP


## L13: a press anywhere off the open menu closes it (and goes no further).
func _on_outside_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		outside_catcher.accept_event()
		close_menu()


## Shows a house popover with its opening animation. The in-game menu grows out of the Menu
## button (review #14: from its top-right corner, 8 px of drop, panel_in with the panel_open cue);
## the settings pop in the middle of the board with their title's sweep.
func _show_popup(p: Control) -> void:
	p.visible = true
	p.reset_size()
	if p == settings_popup:
		layout_popups(gs.size.x)
	var hp := p as HousePanel
	hp.appear()
	if p == game_menu:
		_grow_from_button()
	var tt: TitleText = p.get_meta(&"headline") if p.has_meta(&"headline") else null
	if tt != null:
		tt.play_sweep()


## The in-game menu's open motion: scale 0.94 -> 1 pivoting on its top-right corner (under the
## Menu button) while it drops 8 px into place; a plain fade under reduce motion (appear's).
func _grow_from_button() -> void:
	if UIStyle.reduce_motion or not game_menu.is_inside_tree():
		return
	var rest := game_menu.position
	game_menu.pivot_offset = Vector2(game_menu.size.x, 0)
	game_menu.scale = Vector2.ONE * MENU_OPEN_SCALE
	game_menu.position = rest - Vector2(0, MENU_OPEN_DROP)
	var tw := game_menu.create_tween().set_parallel(true)
	UIStyle.tween_token(tw, game_menu, "scale", Vector2.ONE, "panel_in")
	UIStyle.tween_token(tw, game_menu, "position", rest, "panel_in")
	tw.chain().tween_callback(func(): game_menu.pivot_offset = game_menu.size / 2.0)


## Return to menu / Quit to desktop (and the window's close button). G01: between duels (rewards,
## who goes first) the series is saved, so the dialog offers Save and quit / Forfeit and quit /
## Keep playing ("leave" instead of "quit" for Return to menu). During a duel there is no save
## point, so leaving forfeits; during the deck choice nothing has been played, so it abandons.
func confirm_forfeit(quit: bool) -> void:
	game_menu.visible = false
	var verb := "quit" if quit else "leave"
	var net: Dictionary = gs.view.get("net", {})
	if gs.is_spectator():
		_leave(quit, "")     # A2: a spectator leaves freely; nothing is sent, nothing forfeited
		return
	if not gs.has_live_series() or net.get("host_gone", false):
		_leave(quit, "")     # nothing to keep or forfeit (or the host is gone: nobody to tell)
		return
	var stage := String(gs.view.get("stage", ""))
	if stage == "decks":   # no game played yet (deck choice / draft)
		_choices("Abandon game?", "Are you sure you want to abandon your game?", [
			ConfirmDialog.choice("Abandon and %s" % verb, func(): _leave(quit, "forfeit_series"), "danger"),
			ConfirmDialog.choice("Keep playing")])
	elif bool(gs.view.get("at_checkpoint", false)):
		_choices("Leave the series?", save_text(), [
			ConfirmDialog.choice("Save and %s" % verb, func(): _save_and_leave(quit), "primary"),
			ConfirmDialog.choice("Forfeit and %s" % verb, func(): _leave(quit, "forfeit_series"), "danger"),
			ConfirmDialog.choice("Keep playing")])
	else:
		_choices("Forfeit the series?", "Series are saved between duels, not during one, so leaving now forfeits the whole series. To resume later, leave from the rewards screen after this duel.", [
			ConfirmDialog.choice("Forfeit and %s" % verb, func(): _leave(quit, "forfeit_series"), "danger"),
			ConfirmDialog.choice("Keep playing")])


## The Save and quit explanation for this kind of series (G01).
func save_text() -> String:
	var tail := " Forfeiting ends the series now as a loss."
	if not gs.is_network():
		return "The series is saved here, so you can resume it later from Resume on the main menu." + tail
	if gs.view.get("net", {}).get("is_host", false):
		return "The series is saved on this computer. Resume it later from Resume on the main menu, and your opponent can join again to continue." + tail
	return "The series is saved on the host's computer. When %s resumes it, join their game again to continue." % String(gs.view["names"][0]) + tail


## Save and quit / leave. Online the other player can start the next duel while this dialog is
## open; a series is only saved between duels, so if that happened the choice is asked again
## (now forfeit-only) instead of leaving without a save.
func _save_and_leave(quit: bool) -> void:
	if bool(gs.view.get("at_checkpoint", false)):
		_leave(quit, "suspend")
	else:
		confirm_forfeit(quit)


## Leaves the screen after sending `cmd` ("suspend": saved, "forfeit_series", or "" for nothing).
func _leave(quit: bool, cmd: String) -> void:
	if cmd != "":
		gs.send({"t": cmd})
	if quit or gs.is_network():
		# A couple of frames so a network command is flushed before the connection closes.
		var tree := gs.get_tree()
		await tree.process_frame
		await tree.process_frame
		if not is_instance_valid(gs):
			# The screen closed meanwhile (for example a dropped connection took it down).
			if quit:
				tree.quit()
			return
	if quit:
		gs.get_tree().quit()
	else:
		gs.leave_to_menu.emit()


## Opens the shared dialog with `list` choices (one at a time).
func _choices(title: String, text: String, list: Array, tag: String = "Leave game") -> void:
	close_dialog()
	_dialog_root = ConfirmDialog.open_choices(gs, title, text, list, tag)
	gs.hover.clear()


## The open confirmation dialog, or null.
func dialog() -> ConfirmDialog:
	if _dialog_root != null and is_instance_valid(_dialog_root) and not _dialog_root.is_queued_for_deletion():
		return _dialog_root
	return null


## Opens the shared confirmation dialog over the screen (one at a time). `style` is the confirm's
## button family ("danger" for a step that cannot be undone: Keep playing then holds the focus).
func _dialog(title: String, text: String, confirm: String, on_yes: Callable, tag: String = "Leave game", style: String = "primary") -> void:
	close_dialog()
	_dialog_root = ConfirmDialog.open(gs, title, text, confirm, on_yes, "Keep playing", tag, style)
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
	_dialog("Concede this game?", "Your opponent wins this game; the series continues.", "Concede", func(): gs.send({"t": "concede"}), "Concede", "danger")


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
		sl.value_changed.connect(func(_v: float): Sfx.slider_tick())   # L1: a bead click per step
		if row[0] == "Sound effects":
			sl.drag_ended.connect(func(_c): Sfx.play("select"))
		g.add_child(sl)
		var mb := CheckBox.new()
		mb.text = "Mute"
		mb.button_pressed = row[2]
		mb.toggled.connect(row[4])
		g.add_child(mb)
	return g
