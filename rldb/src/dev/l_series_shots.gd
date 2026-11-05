extends SceneTree
## Dev-only windowed evidence for the L batch series items (design/owner-feedback-2026-11-05.md
## L3 L12 L13 L14 L26): an online series over ENet loopback (the real main scene as host, a client
## session in the same process) through game 1, the in-game menu, the lobby list, the rewards and
## the Extra Deck reward offer, the start of game 2 (its opening deal), then a local draft's Extra
## Deck offer. Saves JPGs (q88). Run NOT headless:
##   godot --path rldb -s res://src/dev/l_series_shots.gd -- <absolute output dir> [WxH]

const PORT := 24795

var out_dir: String = ""
var main: Node
var client: NetSession
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://l_series_shots"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	root.size = sz
	SeriesStore.DIR = "user://dev_saves_l_series"
	PlayerProgress.persist = false
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(cond: Callable, secs: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _sleep(secs: float) -> void:
	await create_timer(secs).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)
	print("SHOT ", name)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, detail])


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	root.push_input(mv, true)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)
		await _frames(1)


func _gs() -> GameScreen:
	return main.screen if main != null and is_instance_valid(main.screen) else null


func _host_series() -> Series:
	var ns: NetSession = main._sessions.net if main._sessions != null else null
	return ns.series if ns != null and is_instance_valid(ns) else null


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	main._auto_started = true
	main._privacy = false
	await _online()
	await _draft()
	await _single()
	print("L SERIES SHOTS DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- online series (L12 L13 L14 L26 L3)
func _online() -> void:
	main._start_lan_host(PORT, {"seed": 77, "best_of": 3, "deck_mode": "starter", "host_name": "Ana"})
	await _wait(func(): return _gs() != null, 5.0)
	client = NetSession.new()
	client.name = "LClient"
	root.add_child(client)
	client._token = "l-series-shots-client"
	client.join_enet("127.0.0.1", PORT)
	var s: Series = null
	await _wait(func(): return _host_series() != null and client.local_seat != null and not client.local_seat.last_view.is_empty(), 10.0)
	s = _host_series()
	_check("online series up", s != null)
	if s == null:
		return
	var gs := _gs()
	gs.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 1})
	await _wait(func(): return s.stage == Series.STAGE_GAME, 10.0)
	await _sleep(4.0)   # the coin flip and the deal
	gs.skip_effects()
	await _sleep(0.6)
	await _shot("a01_game1_board")
	# L13: the in-game menu, then a click off it.
	gs.menu.toggle()
	await _sleep(0.5)
	await _shot("a02_menu_open")
	await _click(Vector2(420, 520))
	await _sleep(0.06)
	await _shot("a03_menu_click_off_closing")
	await _sleep(0.5)
	await _shot("a04_menu_click_off_closed")
	_check("L13 click off the menu closes it", not gs.menu.game_menu.visible)
	gs.menu.close_popups()
	# L12 / L26: the lobby list from the menu.
	gs.menu.toggle()
	await _sleep(0.4)
	(gs.menu.items["spectators"] as Button).pressed.emit()
	await _sleep(0.6)
	await _shot("a05_lobby_panel_game1")
	gs.spectate.close_list()
	await _sleep(0.3)
	# Game 1 ends: Ana concedes.
	gs.send({"t": "concede"})
	await _wait(func(): return s.stage == Series.STAGE_REWARDS, 5.0)
	await _wait(func(): return not gs.fx.game_end_hold, 12.0)   # the victory / defeat presentation
	await _sleep(0.8)
	await _shot("a06a_rewards_point_popping")
	await _sleep(1.2)
	await _shot("a06_rewards")
	gs.send({"t": "reward_type", "category": "extra"})
	await _sleep(1.0)
	await _shot("a07_reward_extra_offer")
	client.local_seat.send({"t": "reward_finish"})
	gs.send({"t": "reward_add", "index": 0})
	await _sleep(0.6)
	gs.send({"t": "reward_finish"})
	await _wait(func(): return s.stage == Series.STAGE_FIRST, 5.0)
	await _sleep(0.8)
	await _shot("a08_next_game")
	gs.send({"t": "first_player", "who": 0})
	gs.send({"t": "start_duel"})
	client.local_seat.send({"t": "start_duel"})
	await _wait(func(): return s.stage == Series.STAGE_GAME and s.game_no == 2, 5.0)
	# L14: the opening of game 2, Ana going first.
	for t in [0.05, 0.3, 0.45, 0.7, 1.4]:
		await _sleep(t if t == 0.05 else t - 0.0)
		await _shot("a09_game2_opening_%03d" % int(t * 100))
	await _sleep(1.0)
	gs.skip_effects()
	await _shot("a10_game2_board")
	gs.menu.toggle()
	await _sleep(0.4)
	(gs.menu.items["spectators"] as Button).pressed.emit()
	await _sleep(0.6)
	await _shot("a11_lobby_panel_game2")
	gs.spectate.close_list()
	# Game 2 ends: Ana wins this time (Ben concedes); the point fills.
	client.local_seat.send({"t": "concede"})
	await _sleep(0.9)
	await _shot("a12_game2_won_moment")
	await _wait(func(): return not gs.fx.game_end_hold, 12.0)
	await _sleep(0.8)
	await _shot("a13a_point_popping_after_game2")
	await _sleep(1.2)
	await _shot("a13_rewards_after_game2")
	main._clear_screens()
	client.queue_free()
	await _sleep(0.5)


# ---------------------------------------------------------------- local draft (L3)
func _draft() -> void:
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _wait(func(): return _gs() != null and not _gs().view.is_empty(), 5.0)
	await _sleep(1.0)
	var gs := _gs()
	gs.send({"t": "draft_category", "category": "extra"})
	await _sleep(1.2)
	await _shot("b01_draft_extra_offer")
	gs.send({"t": "draft_pick", "index": 1})
	await _sleep(1.2)
	await _shot("b02_draft_after_extra_pick")


# ---------------------------------------------------------------- a single game (L26: no scoreboard)
func _single() -> void:
	main._start_local({"seed": 5151, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(func(): return _gs() != null and not _gs().view.is_empty(), 5.0)
	var gs := _gs()
	gs.send({"t": "pick_starter", "index": 0})
	await _sleep(0.3)
	main.local_host.handle(1, {"t": "pick_starter", "index": 1})
	await _sleep(4.0)
	gs.skip_effects()
	await _sleep(0.5)
	await _shot("c01_single_game_board")
	var sb = gs.menu.get("scoreboard")
	_check("L26 no scoreboard in a single game", sb == null or not (sb as Control).visible)
