extends SceneTree
## Development-only screenshots for the 20 Oct release batch, network area (A1 chat, A2 spectators,
## F1 main menu line). Run windowed (never --headless):
##   godot --path rldb -s res://src/dev/net_release_shots.gd -- <abs out dir> [--modes=menu,net]
## `menu` shows the real main menu (Steam is initialised when the client runs, so the line reads
## "Logged in as <Persona>"); `net` runs an ENet host, a client and a spectator in this process and
## photographs the chat box, the Spectators list in both states and the spectator's views.

const PORT := 24930

var out_dir := ""
var modes: Array = ["menu", "net"]
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() and not args[0].begins_with("--") else "user://net_release_shots"
	for a in args:
		if a.begins_with("--modes="):
			modes = Array(a.split("=", true, 1)[1].split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _until(cond: Callable, secs: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("saved ", n)


func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if "menu" in modes:
		await _shot("f1_main_menu_identity")
	if "net" in modes:
		await _run_net()
	print("NET RELEASE SHOTS DONE: ", out_dir)
	quit()


var host: NetSession
var client: NetSession
var spec: NetSession
var screen: GameScreen


func _clear_coin() -> void:
	for n in screen.get_children():
		if n is CoinFlip:
			n.queue_free()
	screen.hand.layer.modulate.a = 1.0
	screen.board.opp_hand_box.modulate.a = 1.0


func _show(seat: NetSeat) -> void:
	screen.attach(seat)
	await _wait(0.6)
	screen.skip_effects()
	_clear_coin()
	await _wait(0.3)


## Moves the real mouse over `c` and waits for its tooltip.
func _hover(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	root.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)
	await _wait(1.3)


func _put(m: MatchEngine, p: int, id: int, slot: int, stance: String = "atk") -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, stance)
	m.cards[uid]["summoned_turn"] = m.turn - 1
	return uid


func _set_card(m: MatchEngine, p: int, id: int, slot: int) -> void:
	var u := m._create_instance(id, p)
	m.cards[u]["zone"] = "backrow"
	m.cards[u]["slot"] = slot
	m.cards[u]["ctl"] = p
	m.cards[u]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][slot] = u


func _run_net() -> void:
	main.queue_free()
	await _wait(0.3)
	var roots := []
	for n in ["H", "C", "S"]:
		var r := Node.new()
		r.name = n
		root.add_child(r)
		roots.append(r)
	host = NetSession.new()
	roots[0].add_child(host)
	client = NetSession.new()
	roots[1].add_child(client)
	spec = NetSession.new()
	roots[2].add_child(spec)
	client._token = "shots-client-token"
	spec._token = "shots-spectator-tok"
	host.host_enet(PORT, {"seed": 21, "best_of": 3, "host_name": "Aldric"})
	client.join_enet("127.0.0.1", PORT)
	await _until(func(): return host.remote_peer != 0)
	host.series.names[1] = "Morwen"
	host.local_seat.send({"t": "pick_starter", "index": 1})
	client.local_seat.send({"t": "pick_starter", "index": 0})
	await _until(func(): return host.series.stage == Series.STAGE_GAME)
	var m: MatchEngine = host.series.game
	m.players[1]["name"] = "Morwen"
	spec.join_enet("127.0.0.1", PORT)
	await _until(func(): return spec.is_spectator and not spec.local_seat.last_view.is_empty())
	for pid in host.spectators:
		host.spectators[pid]["name"] = "Tamsin"
	# A lived-in board: units on both sides, set cards, a few turns of log.
	_put(m, 0, 37, 0)
	_put(m, 0, 28, 4, "def")
	_put(m, 1, 34, 1)
	_put(m, 1, 1, 3)
	_set_card(m, 0, 45, 1)
	_set_card(m, 1, 45, 0)
	for id in [1, 110, 120]:
		var hu := m._create_instance(id, 1)
		m.cards[hu]["zone"] = "hand"
		m.players[1]["hand"].append(hu)
	host._broadcast()
	screen = GameScreen.new()
	root.add_child(screen)
	await _show(host.local_seat)
	# ---- A1 chat
	host.send_chat("Good luck, have fun!")
	await _wait(0.4)
	client.send_chat("You too. That Water deck looks [b]dangerous[/b].")
	await _wait(0.4)
	spec.send_chat("Watching from the gallery. May the best mage win!")
	await _wait(0.4)
	host.send_chat("Thanks Tamsin, glad you could make it.")
	await _wait(0.6)
	screen.chat.open_box()
	screen.chat.input.text = "Your move, Morwen"
	screen.chat._on_typed(screen.chat.input.text)
	await _wait(0.8)
	await _shot("a1_chat_box_open")
	screen.chat.close_box()
	await _wait(0.4)
	client.send_chat("Thinking...")
	await _wait(0.4)
	spec.send_chat("Ooh, tense.")
	await _wait(0.9)
	await _shot("a1_chat_unread_badge")
	# ---- A2 spectators list, default then allowed (each with its tooltip)
	screen.menu.toggle()
	await _wait(0.6)
	await _shot("a2_player_menu_spectators_button")
	screen.menu.game_menu.visible = false
	screen.spectate.toggle_list()
	await _wait(0.6)
	var tg: Control = screen.spectate.panel.find_child("EyeToggle*", true, false)
	if tg != null:
		await _hover(tg)
	await _shot("a2_spectators_list_default_tooltip")
	host.local_seat.send({"t": "spectator_allow", "id": host.spectator_list(0)[0]["id"]})
	await _wait(0.8)
	root.warp_mouse(Vector2(20, 880))
	await _wait(0.3)
	tg = screen.spectate.panel.find_child("EyeToggle*", true, false)
	if tg != null:
		await _hover(tg)
	await _shot("a2_spectators_list_allowed_tooltip")
	screen.spectate.panel.visible = false
	root.warp_mouse(Vector2(1580, 880))
	# ---- the spectator's views
	await _show(spec.local_seat)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		var k := (Time.get_ticks_msec() - t0) / 1500.0
		host._cursor_last = [0, 0]
		host.send_cursor(Vector2(lerpf(0.1, 0.62, k), lerpf(0.85, 0.36, k)))
		await create_timer(1.0 / CursorTrack.SEND_HZ).timeout
	await _shot("a2_spectator_view_permitted_with_cursor")
	host.local_seat.send({"t": "spectator_revoke", "id": host.spectator_list(0)[0]["id"]})
	await _wait(1.0)
	screen.skip_effects()
	await _shot("a2_spectator_view_default_redacted")
	spec.local_seat.send({"t": "spectate_follow", "who": 1})
	await _wait(1.0)
	screen.skip_effects()
	await _shot("a2_spectator_view_flipped_to_seat1")
	screen.menu.toggle()
	await _wait(0.6)
	await _shot("a2_spectator_menu")
	screen.menu.game_menu.visible = false
	# ---- between duels: the spectator watches the rewards stage
	host.local_seat.send({"t": "concede"})
	await _until(func(): return host.series.stage == Series.STAGE_REWARDS)
	await _wait(3.5)
	screen.skip_effects()
	screen.fx.release_game_end_hold()
	screen.render_all()
	await _wait(0.8)
	await _shot("a2_spectator_rewards_stage")
	await _show(host.local_seat)
	await _wait(0.5)
	screen.fx.release_game_end_hold()
	screen.render_all()
	await _wait(0.5)
	await _shot("a2_host_rewards_with_spectator_badge")
	screen.queue_free()
	for r in roots:
		r.queue_free()
	await _wait(0.3)
