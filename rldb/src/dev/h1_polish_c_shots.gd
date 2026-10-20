extends SceneTree
## Development-only evidence driver for the H1 final polish pass (release batch 20 Oct 2026: WP-9
## motion and sound, WP-10 polish tail, leftovers). Run windowed from rldb/:
##   godot --path . -s res://src/dev/h1_polish_c_shots.gd -- --no-steam --out=<abs dir> [--size=1600x900] [--calm]
## Stages one hot-seat series through the real engine and LocalHost and saves one PNG per state:
## the deck choice with a hovered tile, the board at rest (table dust), a hovered hand card, a status
## tip, the inspector mid-flight and landed, the pile browser mid-deal and settled, the game end
## title, the rewards reveal mid-way and settled with a hovered tile, and the statistics count-up.
## `--calm` runs with reduced motion (every shot is then a static state). Writes no user files.

var main: Node
var host: LocalHost
var m: MatchEngine
var gs: GameScreen
var out_dir := ""
var tag := ""
var calm := false
var a := 0
var o := 1
var uids := {}
var want := Vector2i(1600, 900)


func _initialize() -> void:
	var size := Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=", true, 1)[1]
		elif arg.begins_with("--size="):
			var p := arg.split("=")[1].split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif arg == "--calm":
			calm = true
	want = size
	tag = "%dx%d%s" % [size.x, size.y, "_calm" if calm else ""]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	UIStyle.reduce_motion = calm
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(want)
	await _wait(0.4)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(1.2)
	host = main.local_host
	gs = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	await _deck_choice()
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_stage()
	_show(a)
	await _wait(0.8)
	await _board()
	await _game_end_and_rewards()
	await _stats()
	print("H1 POLISH C DONE ", tag)
	quit()


func _deck_choice() -> void:
	var tiles := gs.find_children("*", "DeckTile", true, false)
	if tiles.is_empty():
		await _snap("00_deck_choice")
		return
	_move(Vector2(4, 4))
	await _wait(0.4)
	await _hover((tiles[0] as Control).get_global_rect().get_center() + Vector2(0, -40))
	await _wait(0.4)
	await _snap("00_deck_tile_hover")
	_move(Vector2(4, 4))


func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	a = m.active
	o = 1 - a
	uids["water"] = TB.unit(m, a, 1, 0)
	uids["fire"] = TB.unit(m, a, 110, 1, "atk", 10)
	uids["h_water"] = TB.card(m, a, 1)
	uids["h_dante"] = TB.card(m, a, 36)
	uids["h_loak"] = TB.card(m, a, 19)
	for id in [1, 110, 15, 19, 36, 1, 110, 49]:
		TB.card(m, a, id, "spent")
	uids["o_fire"] = TB.unit(m, o, 110, 0, "atk", 10)
	m.players[a]["ap"] = 6
	host.broadcast()


func _board() -> void:
	_move(_neutral())
	await _wait(1.0)
	await _snap("01_board_rest_dust")
	await _hover((gs.hand.items[uids["h_dante"]]["holder"] as Control).get_global_rect().get_center())
	await _snap("02_hand_hover_lift")
	_move(_neutral())
	await _wait(0.4)
	# A status tip on a field card (the F5 tip with its notch).
	var it := gs.fx_slot_item(a, "unit", 1)
	if not it.is_empty():
		var w: CardWidget = it["widget"]
		var r := w.get_global_rect()
		StatusTip.show_for(w, "Burn ×2", Rect2(r.position + Vector2(r.size.x * 0.4, r.size.y * 0.1), Vector2(18, 18)), StatusHelp.describe("burn"))
		await _wait(0.4)
		await _snap("03_status_tip")
		StatusTip.hide_for(w)
		# The inspector flies out of the field card.
		gs.inspect.inspect_widget(w)
		await _wait(0.13)
		await _snap("04_inspector_flying")
		await _wait(0.7)
		await _snap("05_inspector_landed")
		CardInspector.close_all()
		await _wait(0.6)
	# The pile browser deals its cards out of Spent.
	gs.inspect.open_pile("spent")
	await _wait(0.16)
	await _snap("06_pile_browser_dealing")
	await _wait(1.0)
	await _hover(_first_browser_card())
	await _snap("07_pile_browser_hover")
	gs.inspect.close_all()
	_move(_neutral())
	await _wait(0.5)


func _first_browser_card() -> Vector2:
	var b := gs.inspect.browser
	if b == null or not is_instance_valid(b) or b.card_widgets().is_empty():
		return _neutral()
	return (b.card_widgets()[0] as Control).get_global_rect().get_center()


func _game_end_and_rewards() -> void:
	m.submit(a, {"t": "next_phase"})
	for u in (m.players[o]["units"] as Array).duplicate():
		if u != null and int(u) >= 0:
			TB.kill(m, int(u))
	m.players[o]["hp"] = 4
	host.broadcast()
	await _wait(0.6)
	m.submit(a, {"t": "attack", "uid": uids["fire"]})
	host.broadcast()
	_auto_answer()
	await _wait(2.2)
	await _snap("08_game_end_lethal")
	await _wait(2.6)
	await _snap("08b_game_end_title")
	print("stage after game end: ", gs.view.get("stage", ""), " hold ", gs.fx.game_end_hold)
	# The rewards modal opens once the game end has played: catch the reveal mid-way, then at rest.
	var t0 := Time.get_ticks_msec()
	while not gs.overlays.overlay.visible and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
	await _wait(0.2)
	await _snap("09_rewards_revealing")
	await _wait(1.2)
	await _snap("10_rewards_settled")
	var tiles := gs.find_children("*", "ChoiceTile", true, false)
	if not tiles.is_empty():
		await _hover((tiles[0] as Control).get_global_rect().get_center())
		await _wait(0.5)
		await _snap("11_reward_tile_hover")
	_move(_neutral())


func _stats() -> void:
	var facts := [
		{"label": "Duels played", "value": "24", "detail": "18 vs bot, 6 hot-seat"},
		{"label": "Win rate", "value": "63%", "detail": "15 won, 9 lost"},
		{"label": "Record vs bot", "value": "12 - 6", "detail": ""},
		{"label": "Series won", "value": "4 of 6", "detail": ""},
		{"label": "Best win streak", "value": "5", "detail": "current streak 2"},
		{"label": "Fastest win", "value": "7 turns", "detail": ""},
		{"label": "Biggest single hit", "value": "38 damage", "detail": "912 damage dealt in total"},
		{"label": "Most played card", "value": "Basic Mage (Water)", "detail": "played 41 times"},
	]
	var d := StatsDialog.open(main, facts)
	await _wait(0.2)
	await _snap("12_stats_counting")
	await _wait(1.2)
	await _snap("13_stats_settled")
	d.close()


# ---------------------------------------------------------------- helpers

func _neutral() -> Vector2:
	return gs.get_global_transform() * Vector2(gs.board._ux - 320.0, gs.board._y0 + 520.0)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _show(p: int) -> void:
	main._shown_seat = p
	main.screen.attach(host.seats[p])


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))
	print("shot ", name)


func _move(pos: Vector2) -> void:
	root.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(4, 0)
	root.push_input(ev, true)


func _hover(pos: Vector2) -> void:
	for i in 6:
		_move(pos + Vector2(i % 2, 0))
		await process_frame
	await _wait(0.6)
	_move(pos)
	await process_frame


func _answer_first() -> void:
	if m.pending.is_empty():
		return
	var pd := m.pending
	var picks := []
	for i in maxi(1, int(pd.get("min", 1))):
		picks.append(i)
	host.handle(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": picks})
	host.broadcast()


func _auto_answer() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		_answer_first()
