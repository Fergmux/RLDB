extends Control
## Entry scene (res://main.tscn): coordinates the screens. Shows the MainMenu, the deck builder
## and the card list, starts play sessions through the SessionLauncher (hot-seat, bot, LAN, Steam
## lobbies, all through the same SeatClient interface), fades between screens, and handles the
## command line, Steam invites and the window's close button.
##
## Dev drivers (src/dev) and tests reach in through the members kept here: `screen`,
## `local_host`, `menu`, `opts`, `_privacy`, `_shown_seat`, `_start_local`, `_show_menu`, ...

const DEV_SAVES_DIR := "user://dev_saves"
const DECKBUILDER_SHOT_DRIVER := "res://src/dev/deck_builder_shot_driver.gd"

## Current non-game screen: the MainMenu, DeckBuilder or CardListScreen (null during a game).
var menu: Control
## Steam status line of the main menu (null while no menu is shown).
var status_label: Label
## Choices for the next series, shared with the menu and the session launcher.
var options := SessionOptions.new()

var _sessions: SessionLauncher
var _fader := ScreenFader.new()
var _confirm_panel: ConfirmDialog
var _auto_started := false

## Game screen of the live session (or null).
var screen: GameScreen:
	get: return _sessions.screen
	set(v): _sessions.screen = v
## LocalHost of a hot-seat / bot session (or null).
var local_host: LocalHost:
	get: return _sessions.local_host
	set(v): _sessions.local_host = v
## NetSession of a LAN / Steam session (or null).
var net: NetSession:
	get: return _sessions.net
	set(v): _sessions.net = v
## Hot-seat "Pass to ..." screen while shown (or null).
var privacy_overlay: PanelContainer:
	get: return _sessions.privacy_overlay
	set(v): _sessions.privacy_overlay = v
## Series config of the menu pickers (best_of, deck_mode, names, ...).
var opts: Dictionary:
	get: return options.series
	set(v): options.series = v
var _privacy: bool:
	get: return options.privacy
	set(v): options.privacy = v
var _shown_seat: int:
	get: return _sessions.shown_seat
	set(v): _sessions.shown_seat = v


func _init() -> void:
	_sessions = SessionLauncher.new(self, options)
	_sessions.menu_requested.connect(_on_menu_requested)
	_sessions.leave_requested.connect(func(): _go(_show_menu))


func _ready() -> void:
	theme = UIStyle.make_theme()
	UIStyle.apply_aa()
	get_tree().set_auto_accept_quit(false)   # closing the window is handled in _notification
	var args := OS.get_cmdline_user_args()
	# Saved window mode (scripted runs keep their own window size).
	if not " ".join(args).contains("shots"):
		UIStyle.apply_window_mode()
	Music.start()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not ("--no-steam" in args):
		SteamBridge.init()
		if SteamBridge.available():
			SteamBridge.steam().join_requested.connect(_on_steam_join_requested)
	_parse_cmdline()
	var launch_lobby := SteamBridge.launch_lobby()
	if launch_lobby != 0 and SteamBridge.available():
		_auto_started = true
		call_deferred("join_steam_lobby", launch_lobby)
	if not _auto_started:
		_show_menu()


## Command-line hooks for automated runs and screenshots:
##   -- --local / --bot [--seed=N] [--draft] [--bo=5] [--no-privacy]
##   -- --host=PORT / --join=HOST:PORT   (LAN dev transport)
##   -- --shots= / --net-shots= / --bot-shots= / --f02-shots= / --deckbuilder-shots=<dir>
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
			SeriesStore.DIR = DEV_SAVES_DIR
			PlayerProgress.persist = false   # nor flip the real "has played" flag (F04-09)
	for a in args:
		if a.begins_with("--net-shots="):
			_run_driver("res://src/dev/net_shot_driver.gd", a.split("=")[1])
			return
		if a.begins_with("--deckbuilder-shots="):
			_run_driver(DECKBUILDER_SHOT_DRIVER, a.split("=", true, 1)[1])
			return
		if a.begins_with("--bot-shots="):
			_run_driver("res://src/dev/bot_driver.gd", a.split("=", true, 1)[1])
			return
		if a.begins_with("--f04-series-shots="):
			_run_driver("res://src/dev/f04_series_driver.gd", a.split("=", true, 1)[1])
			return
		if a.begins_with("--f02-shots="):
			_run_driver("res://src/dev/f02_driver.gd", a.split("=", true, 1)[1])
			return
		if a.begins_with("--shots="):
			_run_driver("res://src/dev/shot_driver.gd", a.split("=")[1])
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


## Adds the dev driver script at `path` as a child and runs it (deferred) with output `dir`.
func _run_driver(path: String, dir: String) -> void:
	_auto_started = true
	var driver: Node = load(path).new()
	add_child(driver)
	driver.call_deferred("run", self, dir)


## The window's close button behaves like the in-game "Quit to desktop": a live series asks
## first and is forfeited; anywhere else the game simply quits.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen != null and is_instance_valid(screen) and screen.has_live_series():
			screen.menu.confirm_forfeit(true)
		else:
			get_tree().quit()


## Esc in the main menu closes the shown panel or steps back one level.
func _unhandled_input(event: InputEvent) -> void:
	if menu == null or not is_instance_valid(menu) or not (menu is MainMenu):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		(menu as MainMenu).step_back()
		get_viewport().set_input_as_handled()


## Frees the current screen, the play session and any open confirmation.
func _clear_screens() -> void:
	_close_confirm()
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	status_label = null
	_sessions.clear()


## Fades to black, runs `fn` (which builds the next screen) and fades back in. Ignored while a
## fade runs; immediate for scripted runs that have not shown a screen yet.
func _go(fn: Callable) -> void:
	if _fader.busy:
		return
	if _auto_started and menu == null and screen == null:
		fn.call()
		return
	_fader.fade(self, fn)


# ---------------------------------------------------------------- confirmations

## Asks before leaving the current series (or another destructive step); `on_yes` runs on confirm.
func _confirm_leave(title: String, text: String, on_yes: Callable, confirm: String = "Leave and continue",
		cancel: String = "Stay") -> void:
	_close_confirm()
	_confirm_panel = ConfirmDialog.open(self, title, text, confirm, on_yes, cancel)


func _close_confirm() -> void:
	if _confirm_panel != null and is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	_confirm_panel = null


# ---------------------------------------------------------------- screens

## Shows the main menu (no fade).
func _show_menu() -> void:
	_clear_screens()
	var m := MainMenu.new(options)
	menu = m
	add_child(m)
	status_label = m.status_label
	m.bot_requested.connect(func(): _go(func(): _start_bot(opts.duplicate(true))))
	m.hotseat_requested.connect(func(): _go(func(): _start_local(opts.duplicate(true))))
	m.lan_host_requested.connect(func(port: int): _go(func(): _start_lan_host(port, opts.duplicate(true))))
	m.lan_join_requested.connect(func(host: String, port: int): _go(func(): _start_lan_join(host, port)))
	m.steam_host_requested.connect(func(): _go(func(): _start_steam_host()))
	m.steam_browse_requested.connect(_start_steam_browse)
	m.resume_requested.connect(_resume)
	m.delete_save_requested.connect(func(id: String): _confirm_leave("Delete save?", "Delete this saved series?", func():
		SeriesStore.delete(id)
		_show_menu(), "Delete", "Cancel"))
	m.deck_builder_requested.connect(func(): _go(_show_deck_builder))
	m.card_list_requested.connect(func(): _go(_show_card_list))
	m.tutorial_requested.connect(func(lesson: int): _go(func(): _start_tutorial(lesson)))


func _show_deck_builder() -> void:
	_clear_screens()
	var db := DeckBuilder.new()
	menu = db
	add_child(db)
	db.closed.connect(func(): _go(_show_menu))


func _show_card_list() -> void:
	_clear_screens()
	var cl := CardListScreen.new()
	menu = cl
	add_child(cl)
	cl.closed.connect(func(): _go(_show_menu))


func _on_menu_requested() -> void:
	if _sessions.has_active_net():
		_confirm_leave("Leave series?", "Leave this online series? Your opponent will be left waiting.", func(): _go(_show_menu))
		return
	_go(_show_menu)


# ---------------------------------------------------------------- sessions

func _start_local(cfg: Dictionary) -> void:
	_clear_screens()
	_sessions.start_local(cfg)


func _start_bot(cfg: Dictionary) -> void:
	_clear_screens()
	_sessions.start_bot(cfg)


## Guided tutorial (F03-15) at lesson `lesson`; no series is saved.
func _start_tutorial(lesson: int = 0) -> void:
	_clear_screens()
	_sessions.start_tutorial(lesson)


func _start_lan_host(port: int, cfg: Dictionary) -> void:
	_clear_screens()
	_sessions.start_lan_host(port, cfg)


func _start_lan_join(host: String, port: int) -> void:
	_clear_screens()
	_sessions.start_lan_join(host, port)


func _start_steam_host(cfg: Dictionary = {}) -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	_clear_screens()
	_sessions.start_steam_host(cfg)


## Searches public Steam lobbies over the menu (which stays as it is); the results open in a
## LobbyListPanel. Back closes the panel and ends the search.
func _start_steam_browse() -> void:
	if not SteamBridge.available():
		status_label.text = SteamBridge.describe()
		return
	var panel := LobbyListPanel.new()
	add_child(panel)
	panel.join_chosen.connect(func(id: int): _go(func(): join_steam_lobby(id)))
	panel.back_chosen.connect(_sessions.clear)
	_sessions.start_steam_browse(func(lobbies: Array):
		if is_instance_valid(panel):
			panel.show_lobbies(lobbies))


## Joins Steam lobby `lobby_id`, replacing whatever is on screen.
func join_steam_lobby(lobby_id: int) -> void:
	_clear_screens()
	_sessions.join_steam_lobby(lobby_id)


## A friend's invite was accepted in the Steam overlay while the game is running.
func _on_steam_join_requested(lobby: int, _friend: int) -> void:
	if _sessions.has_active_net():
		if net.lobby_id == lobby:
			return
		_confirm_leave("Accept invite?", "Accepting this invite will leave your current series. Continue?", func(): join_steam_lobby(lobby))
		return
	join_steam_lobby(lobby)


## Reopens a saved series the way it was being played (bot, hot-seat, LAN host, Steam host).
func _resume(id: String, how: String) -> void:
	var s := SeriesStore.load_series(id)
	if s == null:
		status_label.text = "That save could not be read."
		return
	var cfg := {"resume": s}
	match how:
		"bot": _go(func(): _start_bot(cfg))
		"lan": _go(func(): _start_lan_host(SessionOptions.DEFAULT_LAN_PORT, cfg))
		"steam": _go(func(): _start_steam_host(cfg))
		_: _go(func(): _start_local(cfg))
