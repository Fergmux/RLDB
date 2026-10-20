extends SceneTree
## Development-only evidence driver for the H1 duel-side pass, part 2 (release batch 20 Oct 2026:
## WP-6 board surfaces, WP-5 / WP-7 duel margins and dead space, D10 follow-up). Run windowed from rldb/:
##   godot --path . -s res://src/dev/h1_duel2_shots.gd -- --no-steam --out=<abs dir> [--size=1600x900] [--calm]
## Stages one board through the real engine and LocalHost and saves one PNG per state:
## board at rest (empty details), hovered unit and long card details, an effect's target pick, a zone pick,
## the waiting notice and the opponent's trap response, the Arcane picker, then the game end and the log's
## winner line. `--calm` runs with reduced motion (the static states).

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
	# main applies the saved window mode (fullscreen): force a window of the requested size. The
	# project's canvas_items stretch (1600x1000 base, expand) then lays out exactly as the game does.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(want)
	await _wait(0.4)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.5)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	gs = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_stage()
	_show(a)
	await _wait(0.8)
	await _states()
	print("H1 DUEL2 DONE ", tag)
	quit()


func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	a = m.active
	o = 1 - a
	uids["water"] = TB.unit(m, a, 1, 0)
	uids["fire"] = TB.unit(m, a, 110, 1, "atk", 10)
	uids["pierce"] = TB.unit(m, a, 15, 4)
	uids["h_loak"] = TB.card(m, a, 19)
	uids["h_water"] = TB.card(m, a, 1)
	uids["h_dante"] = TB.card(m, a, 36)
	TB.card(m, a, 1, "spent")
	TB.card(m, a, 110, "spent")
	uids["tyde"] = TB.card(m, a, 172, "extra")
	uids["o_fire"] = TB.unit(m, o, 110, 0, "atk", 10)
	uids["o_water"] = TB.unit(m, o, 1, 1, "def")
	TB.set_card(m, o, 49, 2)          # Trap Hole: answers the summon below
	m.players[a]["ap"] = 6
	host.broadcast()


func _states() -> void:
	_move(_neutral())
	await _wait(0.6)
	await _snap("01_board_rest")
	await _hover(gs.board.slot_global_rect(a, "unit", 4).get_center())
	await _snap("02_details_unit")
	await _hover(gs.board.slot_global_rect(o, "unit", 0).get_center())
	await _snap("03_details_opponent_unit")
	await _hover((gs.hand.items[uids["h_dante"]]["holder"] as Control).get_global_rect().get_center())
	await _snap("04_details_hand_card")
	_move(_neutral())
	# An effect that targets a unit (Da Mage: apply Pierce).
	m.submit(a, {"t": "ability", "uid": uids["pierce"], "idx": 0})
	host.broadcast()
	await _wait(0.7)
	await _snap("05_target_pick")
	_answer_first()
	await _wait(0.6)
	# A summon's zone pick, then the opponent's Trap Hole window.
	m.submit(a, {"t": "summon", "uid": uids["h_water"]})
	host.broadcast()
	await _wait(0.7)
	await _hover(gs.board.slot_global_rect(a, "unit", 3).get_center())
	await _snap("06_zone_pick")
	_move(_neutral())
	_answer_first()
	await _wait(1.6)
	if TB.pend_kind(m) == "trap_response":
		_show(a)    # hot-seat follows the deciding seat: show the waiting side
		await _wait(0.8)
		await _snap("07_waiting_for_opponent")
		_show(o)
		await _wait(0.8)
		await _snap("08_trap_response")
		_answer_text("Skip")
		_show(a)
		await _wait(1.2)
	# The Arcane picker (Tyde from Extra, paid from Spent).
	m.submit(a, {"t": "arcane", "uid": uids["tyde"]})
	host.broadcast()
	await _wait(0.8)
	await _snap("09_arcane_picker")
	_auto_answer()
	await _wait(1.6)
	_show(a)
	await _wait(0.6)
	# The game end: a lethal attack, then the log's winner line.
	m.submit(a, {"t": "next_phase"})
	for u in m.players[o]["units"]:
		if u != null:
			TB.kill(m, int(u))
	m.players[o]["hp"] = 4
	host.broadcast()
	await _wait(0.6)
	m.submit(a, {"t": "attack", "uid": uids["fire"]})
	host.broadcast()
	_auto_answer()
	await _wait(2.6)
	await _snap("10_game_end")
	await _wait(3.0)
	await _snap("11_game_end_settled")


# ---------------------------------------------------------------- helpers

## A pointer rest over bare table (left of the piles, under the prompt column): nothing hovers.
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
	var mn := int(pd.get("min", 1))
	var picks := []
	for i in maxi(1, mn):
		picks.append(i)
	host.handle(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": picks})
	host.broadcast()


func _answer_text(text: String) -> void:
	if m.pending.is_empty():
		return
	var pd := m.pending
	for i in pd["options"].size():
		if String(pd["options"][i].get("label", "")).contains(text):
			host.handle(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": [i]})
			host.broadcast()
			return
	_answer_first()


func _auto_answer() -> void:
	var guard := 0
	while not m.pending.is_empty() and guard < 12:
		guard += 1
		var id0 = m.pending.get("id")
		if TB.pend_kind(m) == "trap_response":
			_answer_text("Skip")
		else:
			_answer_first()
		if not m.pending.is_empty() and m.pending.get("id") == id0:
			# An exact-total pick (Arcane): take the first two.
			host.handle(int(m.pending["player"]), {"t": "choose", "id": id0, "indices": [0, 1]})
			host.broadcast()
