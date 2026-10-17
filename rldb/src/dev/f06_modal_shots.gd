extends SceneTree
## Dev-only windowed evidence for F06-01 (every modal on the HousePanel house plate). Run NOT headless:
##   godot --path rldb -s res://src/dev/f06_modal_shots.gd -- <absolute output dir> [WxH]
## Opens each modal and popover in turn (menu settings, lobby list, deck select, in-game menu,
## settings, confirm, inspector, pile browser, pause veil, privacy screen, rewards) and saves a
## screenshot of each. Quits itself (and after a 200 s safety limit).

var out_dir: String = ""
var main: Node
var gs: GameScreen
var host: LocalHost


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://f06"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	create_timer(200.0).timeout.connect(func(): quit(1))
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _widgets() -> Array:
	var out := []
	for n in gs.find_children("*", "", true, false):
		var w := n as CardWidget
		if w != null and w.visible and w.view.get("face_up", true) and CardInspector.is_inspectable(w.view):
			out.append(w)
	return out


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(8)
	# Main-menu centre panel (Settings) and the lobby list.
	var mm := main.menu as MainMenu
	if mm != null:
		mm.pick("settings")
		await _shot("01_menu_settings")
		mm.pick("@play")
		await _frames(2)
		mm.pick("@local")
		await _frames(2)
		mm.pick("bot")
		await _shot("02_menu_play_vs_bot")
	var lobby := LobbyListPanel.new()
	main.add_child(lobby)
	await _frames(2)
	lobby.show_lobbies([{"id": 1, "host": "Morwen", "members": 1}, {"id": 2, "host": "Tobias", "members": 1}])
	await _shot("03_lobby_list")
	lobby.queue_free()
	await _frames(2)
	# A local series: deck select.
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(10)
	host = main.local_host
	gs = main.screen
	await _shot("04_deck_select")
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(6)
	var me: int = host.series.game.active
	main._shown_seat = me
	gs.attach(host.seats[me])
	await create_timer(3.0).timeout
	await _shot("05_board_prompt")
	# In-game menu, settings, confirm.
	gs.menu.toggle()
	await _shot("06_game_menu")
	gs.menu.game_menu.visible = false
	gs.menu._show_popup(gs.menu.settings_popup)
	gs.menu.layout_popups(gs.size.x)
	await _shot("07_game_settings")
	gs.menu.settings_popup.visible = false
	gs.menu._confirm_concede()
	await _shot("08_confirm_concede")
	gs.menu.close_dialog()
	await _frames(2)
	# Inspector and pile browser.
	var ws := _widgets()
	if not ws.is_empty():
		CardInspector.open(gs, (ws[0] as CardWidget).view)
		await _shot("09_card_inspector")
		CardInspector.close_all()
		await _frames(2)
		var views := ws.slice(0, 5).map(func(w): return (w as CardWidget).view)
		var pb := PileBrowser.open(gs, "Your hand", views, "Right-click a card to inspect it")
		await _shot("10_pile_browser")
		pb.close()
		await _frames(2)
	# Pause veil (a faked network pause).
	var real_net = gs.view.get("net", {})
	gs.view["net"] = {"paused": true, "message": "", "is_host": false}
	gs.overlays.render_pause()
	gs.overlays.layout_pause(gs.size.x, gs.size.y)
	await _shot("11_pause_veil")
	gs.view["net"] = real_net
	gs.overlays.render_pause()
	# Hot-seat privacy screen.
	main._sessions.show_privacy(1 - me)
	await _shot("12_privacy")
	if main._sessions.privacy_overlay != null:
		main._sessions.privacy_overlay.queue_free()
		main._sessions.privacy_overlay = null
	await _frames(2)
	# Rewards after a concession.
	host.handle(me, {"t": "concede"})
	await create_timer(9.0).timeout
	await _shot("13_rewards")
	print("F06 MODAL SHOTS DONE")
	quit(0)
