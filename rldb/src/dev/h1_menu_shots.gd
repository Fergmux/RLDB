extends SceneTree
## Dev-only windowed evidence for the H1 menus pass (design review WP-2, WP-5, WP-7, WP-8, menus
## side): the main menu (logo, items at rest and hovered, ambient motes), its centre panels
## (Settings, Credits, Play vs Bot, Tutorial, Host game), the Back item, the statistics dialog
## (empty), the lobby list (searching, empty, two lobbies), a confirmation, then a hot-seat series
## for the privacy screen and the in-game menu and settings. Run NOT headless:
##   godot --path rldb -s res://src/dev/h1_menu_shots.gd -- <abs out dir> [WxH] [--reduce-motion] [--debug-margins]
## `--reduce-motion` turns the option on for the run (not saved); `--debug-margins` is read by Main.
## Prints PASS / FAIL checks and quits with the number of failures.

var out_dir: String = ""
var main: Node
var sz := Vector2i(1600, 900)
var fails := 0
var reduced := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://h1_menus"
	for a in args.slice(1):
		if String(a).contains("x") and not String(a).begins_with("--"):
			var p := String(a).split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
		elif a == "--reduce-motion":
			reduced = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(240.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what, "  ", detail)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String, wait: float = 0.9) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var suffix := "_%dx%d" % [sz.x, sz.y]
	if reduced:
		suffix += "_reduced"
	root.get_texture().get_image().save_png(out_dir.path_join(name + suffix + ".png"))
	print("SHOT ", name)


func _item(mm: MainMenu, text: String) -> MenuItem:
	for c in mm._menu_list.get_children():
		if c is MenuItem and (c as MenuItem).label_text == text:
			return c
	return null


func run() -> void:
	# Scripted runs never create or show the player's real saves, nor flip the "has played" flag.
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(8)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	await create_timer(1.2).timeout
	if reduced:
		UIStyle.reduce_motion = true
	var mm := main.menu as MainMenu
	_check("main menu shown", mm != null)
	if mm == null:
		quit(1)
		return
	_check("hero logo is a TitleText HERO", mm.logo != null and mm.logo.tier == TitleText.Tier.HERO)
	_check("ambient motes present", mm.motes != null and mm.motes.count() > 0)
	await _shot("00_main_menu", 2.0)
	var play := _item(mm, "Play")
	if play != null:
		play._to_hl(1.0)
		await _shot("01_item_hover_play", 0.5)
		_check("menu item hover blends the MENU title to gold", play.title.hover > 0.9)
		play._to_hl(0.0)
	mm.pick("settings")
	await _frames(2)
	_check("settings panel uses the shared SettingsForm", mm.find_children("*", "SettingsForm", true, false).size() == 1)
	await _shot("02_settings")
	mm.pick("credits")
	await _shot("03_credits")
	mm.step_back()
	await _frames(2)
	mm.pick("@play")
	await _frames(4)
	var back := _item(mm, "Back")
	_check("sub-level Back item is muted and 85% size", back != null and back.muted and back.fs == MainMenu.BACK_ITEM_SIZE)
	if back != null:
		back._to_hl(1.0)
	mm.pick("tutorial")
	await _shot("04_play_tutorial")
	if back != null:
		back._to_hl(0.0)
	mm.pick("@local")
	await _frames(2)
	mm.pick("bot")
	await _shot("05_play_vs_bot")
	mm.step_back()
	mm.back_out()
	await _frames(2)
	mm.pick("@online")
	await _frames(2)
	mm.pick("host_online")
	await _shot("06_host_online")
	mm.step_back()
	await _frames(2)
	# Statistics (empty record).
	var sd := StatsDialog.open(mm, [])
	await _frames(2)
	sd._fill([])
	await _shot("07_stats_empty")
	sd.close()
	await _frames(2)
	# Lobby list: searching, none found, two lobbies.
	var lobby := LobbyListPanel.new()
	main.add_child(lobby)
	await _shot("08_lobby_searching")
	lobby.show_lobbies([])
	await _shot("09_lobby_empty", 0.4)
	lobby.show_lobbies([{"id": 1, "host": "Morwen", "members": 1}, {"id": 2, "host": "Tobias", "members": 3}])
	await _shot("10_lobby_list", 0.4)
	lobby.queue_free()
	await _frames(2)
	var cd := ConfirmDialog.open(mm, "Delete deck", "Delete the saved deck \"Ember Rush\"? This cannot be undone.", "Delete", func(): pass, "Cancel", "Deck builder", "danger")
	await _shot("11_confirm")
	cd.close()
	await _frames(2)
	# Hot-seat: the privacy screen, then the in-game menu and settings.
	main._auto_started = true
	main._privacy = true
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(10)
	var host: LocalHost = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await create_timer(1.0).timeout
	main._sessions.show_privacy(1)
	await _shot("12_privacy", 1.6)
	var po: Control = main._sessions.privacy_overlay
	if po != null:
		for b in po.find_children("*", "Button", true, false):
			(b as Button).pressed.emit()
			break
	await create_timer(1.5).timeout
	var gs: GameScreen = main.screen
	if gs != null:
		gs.menu.toggle()
		await _shot("13_game_menu", 0.25)
		await _shot("13b_game_menu_settled", 0.6)
		gs.menu.game_menu.visible = false
		gs.menu._show_popup(gs.menu.settings_popup)
		gs.menu.layout_popups(gs.size.x)
		await _frames(2)
		_check("in-game settings uses the shared SettingsForm", gs.menu.settings_popup.find_children("*", "SettingsForm", true, false).size() == 1)
		await _shot("14_game_settings")
		gs.menu.settings_popup.visible = false
	print("H1 MENU SHOTS DONE: %d failed" % fails)
	quit(fails)
