extends SceneTree
## Development-only screenshots for the 22 Oct batch, lobby / chat area (J17-J22). Run windowed
## (never --headless):
##   godot --path rldb -s res://src/dev/lobby_chat_shots.gd -- <abs out dir> [--modes=draft,game,lobby,spec]
## An ENet host, a client and two spectators run in this process. `draft` shows the Chat button
## and the open chat over the online draft and clicks the chat's close button with real mouse
## input; `game` shows the new-message pop-up, the badge and the chat box; `lobby` shows the View
## lobby list (players and spectators, one muted) and the chat with that person's lines hidden;
## `spec` shows a spectator's top strip and lobby list.

const PORT := 24945

var out_dir := ""
var modes: Array = ["draft", "game", "lobby", "spec"]
var host: NetSession
var client: NetSession
var spec: NetSession
var spec2: NetSession
var screen: GameScreen
var roots: Array = []
var results: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() and not args[0].begins_with("--") else "user://lobby_chat_shots"
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


func _check(n: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", n, detail])


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


## Real mouse input: moves to `p` (viewport coordinates) and, when `click`, presses and releases.
func _mouse(p: Vector2, click: bool = false) -> void:
	root.warp_mouse(p)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await _wait(0.15)
	if not click:
		return
	# The click goes straight to the viewport (as the OS would deliver it), after a motion event at
	# the same point, so a stray real-mouse position cannot redirect it.
	root.push_input(mv, true)
	await process_frame
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = p
		ev.global_position = p
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(ev, true)
		await _wait(0.08)


## The chat's close button (also before J20 named it).
func _close_of(chat: GameChat) -> Control:
	if chat.get("close_button") != null:
		return chat.get("close_button")
	for c in chat.panel.head_row.get_children():
		if c is Button:
			return c
	return null


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


func _net(cfg: Dictionary, port: int) -> void:
	roots = []
	for n in ["H", "C", "S", "S2"]:
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
	spec2 = NetSession.new()
	roots[3].add_child(spec2)
	client._token = "lobby-client-token"
	spec._token = "lobby-spectator-1"
	spec2._token = "lobby-spectator-2"
	host.host_enet(port, cfg)
	client.join_enet("127.0.0.1", port)
	await _until(func(): return host.remote_peer != 0)
	host.series.names[1] = "Morwen"


func _add_spectators() -> void:
	spec.join_enet("127.0.0.1", PORT + 10)
	await _until(func(): return spec.is_spectator and not spec.local_seat.last_view.is_empty())
	spec2.join_enet("127.0.0.1", PORT + 10)
	await _until(func(): return spec2.is_spectator and not spec2.local_seat.last_view.is_empty())
	var names := ["Tamsin", "Grimble"]
	var i := 0
	for pid in host.spectators.keys():
		host.spectators[pid]["name"] = names[mini(i, 1)]
		i += 1
	host._broadcast()
	await _wait(0.4)


func _teardown() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	for r in roots:
		r.queue_free()
	await _wait(0.4)


func _run() -> void:
	if "draft" in modes:
		await _run_draft()
	if "game" in modes or "lobby" in modes or "spec" in modes:
		await _run_game()
	var bad := results.count(false)
	print("LOBBY CHAT SHOTS DONE: %d checks, %d failed -> %s" % [results.size(), bad, out_dir])
	quit(1 if bad > 0 else 0)


# ---------------------------------------------------------------- J18 / J20: chat over the online draft

func _run_draft() -> void:
	await _net({"seed": 31, "best_of": 3, "host_name": "Aldric", "deck_mode": "draft"}, PORT)
	screen = GameScreen.new()
	root.add_child(screen)
	await _show(host.local_seat)
	await _wait(0.8)
	_check("draft: on the deck stage", String(screen.view.get("stage", "")) == "decks")
	_check("draft: the Chat button shows", screen.chat.button.is_visible_in_tree())
	client.send_chat("Ready when you are. Drafting Water again?")
	await _wait(1.2)
	await _shot("j18_draft_chat_button_new_message")
	screen.chat.open_box()
	await _wait(0.7)
	await _shot("j18_draft_chat_open")
	var close: Control = _close_of(screen.chat)
	await _mouse(close.get_global_rect().get_center())
	await _wait(0.3)
	await _shot("j20_draft_close_hover")
	await _mouse(close.get_global_rect().get_center(), true)
	await _wait(0.3)
	_check("draft: a real click on the round close button closes the chat", not screen.chat.is_open())
	await _mouse(Vector2(1590, 890))
	await _show(client.local_seat)
	await _wait(0.8)
	_check("draft (client): the Chat button shows", screen.chat.button.is_visible_in_tree())
	await _shot("j18_draft_client_side")
	await _teardown()


# ---------------------------------------------------------------- J17 / J19-J22 in a duel

func _run_game() -> void:
	await _net({"seed": 21, "best_of": 3, "host_name": "Aldric"}, PORT + 10)
	host.local_seat.send({"t": "pick_starter", "index": 1})
	client.local_seat.send({"t": "pick_starter", "index": 0})
	await _until(func(): return host.series.stage == Series.STAGE_GAME)
	host.series.game.players[1]["name"] = "Morwen"
	await _add_spectators()
	screen = GameScreen.new()
	root.add_child(screen)
	await _show(host.local_seat)
	if "game" in modes:
		host.send_chat("Good luck, have fun!")
		await _wait(0.3)
		client.send_chat("You too. That Water deck looks dangerous.")
		await _wait(0.3)
		spec.send_chat("Watching from the gallery. May the best mage win!")
		await _wait(0.3)
		host.send_chat("Thanks Tamsin, glad you could make it.")
		await _wait(0.5)
		screen.chat.open_box()
		screen.chat.input.text = "Your move, Morwen"
		screen.chat._on_typed(screen.chat.input.text)
		await _wait(0.8)
		await _shot("j19_chat_box_open_no_hint")
		await _mouse(_close_of(screen.chat).get_global_rect().get_center())
		await _wait(0.3)
		await _shot("j20_chat_close_hover")
		await _mouse(_close_of(screen.chat).get_global_rect().get_center(), true)
		await _wait(0.3)
		_check("game: a real click on the close button closes the chat", not screen.chat.is_open())
		await _mouse(Vector2(700, 500))
		client.send_chat("Thinking...")
		await _wait(0.16)
		await _shot("j17_new_message_popup_mid_animation")
		await _wait(0.6)
		await _shot("j17_new_message_popup")
		spec2.send_chat("Ooh, tense.")
		await _wait(0.9)
		await _shot("j17_second_message_badge_2")
		await _wait(4.5)
		await _shot("j17_popup_gone_badge_stays")
	if "lobby" in modes:
		screen.spectate.toggle_list()
		await _wait(0.7)
		await _shot("j22_view_lobby_players_and_spectators")
		var mute: Button = screen.spectate.panel.find_child("Mute_s*", true, false)
		_check("lobby: a spectator row has a mute button", mute != null)
		if mute != null:
			await _mouse(mute.get_global_rect().get_center())
			await _wait(1.2)
			await _shot("j21_mute_hover_tooltip")
			await _mouse(mute.get_global_rect().get_center(), true)
			await _wait(0.5)
		var pm: Button = screen.spectate.panel.find_child("Mute_p1", true, false)
		_check("lobby: the other player's row has a mute button", pm != null)
		_check("lobby: my own row has none", screen.spectate.panel.find_child("Mute_p0", true, false) == null)
		await _mouse(Vector2(700, 500))
		await _wait(0.4)
		await _shot("j21_lobby_one_muted")
		screen.spectate.toggle_list()
		await _wait(0.3)
		var unread0 := screen.chat.unread
		spec.send_chat("You cannot hear me now.")
		await _wait(0.8)
		_check("lobby: a muted person's message raises no badge", screen.chat.unread == unread0, "%d -> %d" % [unread0, screen.chat.unread])
		screen.chat.open_box()
		await _wait(0.6)
		_check("lobby: a muted person's lines are hidden", not screen.chat.history.get_parsed_text().contains("You cannot hear me"))
		await _shot("j21_chat_with_muted_spectator_hidden")
		screen.chat.close_box()
		await _wait(0.3)
	if "spec" in modes:
		await _show(spec2.local_seat)
		await _wait(0.4)
		await _shot("j22_spectator_top_strip")
		screen.spectate.toggle_list()
		await _wait(0.7)
		await _shot("j22_spectator_view_lobby")
		_check("spec: a spectator sees both sections", screen.spectate.panel.find_child("Mute_p0", true, false) != null)
		_check("spec: a spectator gets no eye toggles", screen.spectate.panel.find_child("EyeToggle*", true, false) == null)
		screen.spectate.toggle_list()
	await _teardown()
