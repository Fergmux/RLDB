extends SceneTree
## Development-only F03 check over a real ENet connection (host and client NetSessions in one
## process, the GameScreen attached to the CLIENT seat): healing above 60 in game 1, a real
## lethal attack, the client's DEFEAT presentation and result modal, rewards and first-player
## choice, then game 2's HP plates (F03-13, F03-14), Power mirroring from the client's side
## (F03-07) and a reconnect that must not replay the game-end presentation.
##   godot --path rldb -s res://src/dev/f03_net_series_driver.gd -- <abs out dir> [--client-loses]

const PORT := 24870

var main: Node
var host: NetSession
var client: NetSession
var screen: GameScreen
var out_dir := ""
var results: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() and not args[0].begins_with("--") else "user://f03net"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_run.call_deferred()


func _check(name: String, ok: bool, detail: String = "") -> void:
	results.append({"name": name, "pass": ok, "detail": detail})
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _until(cond: Callable, secs: float = 10.0) -> bool:
	var t := 0.0
	while not cond.call():
		await process_frame
		t += 1.0 / 60.0
		if t > secs:
			return false
	return true


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))


func _plates() -> Dictionary:
	var out := {}
	for p in 2:
		var pl: PlayerPlate = screen.plate_of(p)
		out[p] = {"cap": pl._max_hp, "bar_max": pl.hp_bar.max_hp}
	return out


func _run() -> void:
	main = load("res://main.tscn").instantiate()
	main._auto_started = true
	root.add_child(main)
	await _wait(0.5)
	host = NetSession.new()
	client = NetSession.new()
	var hr := Node.new()
	hr.name = "H"
	var cr := Node.new()
	cr.name = "C"
	root.add_child(hr)
	root.add_child(cr)
	hr.add_child(host)
	cr.add_child(client)
	host.host_enet(PORT, {"seed": 11, "best_of": 3, "host_name": "Host"})
	client.join_enet("127.0.0.1", PORT)
	screen = GameScreen.new()
	main.add_child(screen)
	screen.attach(client.local_seat)
	await _until(func(): return host.remote_peer != 0)
	host.local_seat.send({"t": "pick_starter", "index": 1})
	client.local_seat.send({"t": "pick_starter", "index": 0})
	await _until(func(): return host.series.stage == Series.STAGE_GAME)
	await _wait(1.0)
	for n in screen.get_children():
		if n is CoinFlip:
			n.queue_free()
	var m: MatchEngine = host.series.game
	# ---- Power mirroring, seen from the client (seat 1) for the host's Powers (seat 0)
	var pids := [88, 53, 54, 55]
	for s in 4:
		var u := m._create_instance(pids[s], 0)
		m.cards[u]["zone"] = "power"
		m.cards[u]["slot"] = s
		m.cards[u]["ctl"] = 0
		m.players[0]["powers"][s] = u
	# ---- game 1: the client heals above 60
	m.players[1]["hp"] = 95
	host._broadcast()
	await _wait(1.0)
	screen.skip_effects()
	await _shot("01_client_g1_hp95_powers")
	var pl := _plates()
	_check("F03-14 client plate reference grows to 95 in game 1", int(pl[1]["cap"]) == 95, str(pl))
	var cells := {}
	for s in 4:
		cells[s] = screen.fx_slot_global_rect(0, "power", s).get_center()
	screen.attach(host.local_seat)
	await _wait(0.8)
	screen.skip_effects()
	await _shot("01b_host_g1_powers")
	var own := {}
	for s in 4:
		own[s] = screen.fx_slot_global_rect(0, "power", s).get_center()
	screen.attach(client.local_seat)
	await _wait(0.8)
	screen.skip_effects()
	# 180-degree rotation: every left/right and above/below relation between two slots flips.
	var ok_map := true
	for i in 4:
		for j in 4:
			if i == j:
				continue
			var dx_c := signf(cells[i].x - cells[j].x)
			var dx_o := signf(own[i].x - own[j].x)
			var dy_c := signf(cells[i].y - cells[j].y)
			var dy_o := signf(own[i].y - own[j].y)
			if dx_c != -dx_o or dy_c != -dy_o:
				ok_map = false
	_check("F03-07 client sees the host's Power block rotated 180 degrees from the host's own view", ok_map, "client %s / host %s" % [str(cells), str(own)])
	# ---- lethal: whoever is active attacks the other directly
	var a := m.active
	var sender: NetSeat = host.local_seat if a == 0 else client.local_seat
	if m.turn == 1:
		sender.send({"t": "next_phase"})
		sender.send({"t": "next_phase"})
		await _until(func(): return m.active != a)
		a = m.active
		sender = host.local_seat if a == 0 else client.local_seat
	if "--client-loses" in OS.get_cmdline_user_args() and a == 1:
		# Hand the turn to the host so the client is the one who loses.
		for i in 3:
			sender.send({"t": "next_phase"})
		await _until(func(): return m.active == 0)
		a = 0
		sender = host.local_seat
	var att := TB.unit(m, a, TB.WATER, 0, "atk", 36)
	m.players[1 - a]["hp"] = 5
	host._broadcast()
	await _wait(0.6)
	sender.send({"t": "next_phase"})
	await _until(func(): return m.phase == "battle")
	sender.send({"t": "attack", "uid": att})
	await _wait(0.3)
	var lv: Dictionary = (host.local_seat if a == 0 else client.local_seat).last_view
	var pd: Dictionary = lv.get("match", {}).get("pending", {})
	if not pd.is_empty():
		var idx := -1
		for o in pd["options"]:
			if String(o.get("label", "")).to_lower().contains("direct"):
				idx = int(o["i"])
		if idx == -1:
			idx = int(pd["options"][0]["i"])
		sender.send({"t": "choose", "id": pd["id"], "indices": [idx]})
	await _until(func(): return host.series.stage != Series.STAGE_GAME, 6.0)
	var client_lost := host.series.game.winner == 0 if host.series.game != null else (a == 0)
	_check("lethal attack ended game 1", host.series.stage != Series.STAGE_GAME, "stage=%s attacker=%d" % [host.series.stage, a])
	await _wait(0.2)
	var hold := screen.fx.game_end_hold
	_check("F03-13 result modal held while the presentation plays", hold)
	# The killing-blow sequence (F04-07) plays first; wait for the title to appear.
	var find_titles := func() -> Array:
		return screen.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and (l.text == "DEFEAT" or l.text == "VICTORY"))
	await _until(func(): return not find_titles.call().is_empty(), 8.0)
	await _wait(0.6)
	await _shot("02_client_game_end_presentation")
	var titles: Array = find_titles.call()
	_check("F03-13 client sees its own outcome", not titles.is_empty() and titles[0].text == ("DEFEAT" if a == 0 else "VICTORY"), str(titles.map(func(l): return l.text)))
	await _until(func(): return not screen.fx.game_end_hold, 15.0)
	await _wait(0.5)
	await _shot("03_client_result_modal")
	_check("F03-13 result modal appears after the presentation", screen.overlays.overlay_box != null and screen.overlays.overlay_box.is_visible_in_tree())
	# ---- reconnect after the game ended: no replayed presentation
	client.simulate_drop()
	await _until(func(): return host.paused, 6.0)
	await _until(func(): return not host.paused, 15.0)
	await _wait(1.0)
	_check("reconnect after game end does not replay the presentation", not screen.fx.game_end_hold and screen.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and l.text in ["DEFEAT", "VICTORY"]).is_empty())
	# ---- rewards, first player, game 2
	host.local_seat.send({"t": "reward_finish"})
	client.local_seat.send({"t": "reward_finish"})
	await _until(func(): return host.series.stage == Series.STAGE_FIRST, 5.0)
	var loser := host.series.last_loser
	await _wait(0.8)
	await _shot("03b_client_next_duel")
	(host.local_seat if loser == 0 else client.local_seat).send({"t": "first_player", "who": loser})
	await _until(func(): return client.local_seat.last_view.get("next", {}).get("first_chosen", false), 4.0)
	await _wait(0.6)
	_check("G05 the first-player choice alone does not start the next duel", host.series.stage == Series.STAGE_FIRST, host.series.stage)
	var start := _button("Start next duel")
	_check("G05 the client sees Start next duel, enabled", start != null and not start.disabled)
	if start != null:
		start.pressed.emit()
	await _until(func(): return host.series.duel_ready[1], 4.0)
	await _wait(0.6)
	await _shot("03c_client_ready_waiting")
	_check("G05 the client's press readies only the client", host.series.duel_ready[1] and not host.series.duel_ready[0] and host.series.stage == Series.STAGE_FIRST)
	host.local_seat.send({"t": "start_duel"})
	await _until(func(): return host.series.stage == Series.STAGE_GAME and host.series.game_no == 2, 6.0)
	await _wait(1.5)
	screen.skip_effects()
	await _shot("04_client_g2_start")
	pl = _plates()
	var hp1: int = int(host.series.game.players[1]["hp"])
	_check("F03-14 client plates show 60/60 at game 2 start", int(pl[0]["cap"]) == 60 and int(pl[1]["cap"]) == 60 and hp1 == 60, "%s hp=%d" % [str(pl), hp1])
	await _g01_save_and_leave()
	var f := FileAccess.open(out_dir.path_join("checks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	f.close()
	var fails := results.filter(func(r): return not r["pass"]).size()
	print("F03 NET DONE: %d passed, %d failed" % [results.size() - fails, fails])
	quit()


## The button with `text` in the client screen's series modal, or null.
func _button(text: String) -> Button:
	for b in screen.overlays.overlay_box.find_children("*", "Button", true, false):
		if (b as Button).text == text and b.is_visible_in_tree():
			return b
	return null


## G01 over the network: game 2 ends (1-1, the series goes on); the client leaves with Save and
## leave (the host keeps the save, nothing is forfeited, the host is told), rejoins, and then the
## host saves and leaves (the client is told the series was saved, not lost).
func _g01_save_and_leave() -> void:
	# The winner of game 1 concedes game 2: 1-1, so the series goes on.
	var leader: int = 0 if int(host.series.scores[0]) > int(host.series.scores[1]) else 1
	(host.local_seat if leader == 0 else client.local_seat).send({"t": "concede"})
	await _until(func(): return host.series.stage == Series.STAGE_REWARDS or host.series.stage == Series.STAGE_OVER, 6.0)
	if host.series.stage != Series.STAGE_REWARDS:
		_check("G01 game 2 leaves the series open (rewards)", false, host.series.stage)
		return
	await _until(func(): return not screen.fx.game_end_hold, 15.0)
	screen.skip_effects()
	await _wait(1.0)
	screen.menu.confirm_forfeit(false)
	await _wait(0.5)
	await _shot("05_client_leave_dialog")
	var d := screen.menu.dialog()
	var texts: Array = d.choices.map(func(c): return String(c["text"])) if d != null else []
	_check("G01 client dialog offers Save / Forfeit / Keep playing", texts == ["Save and leave", "Forfeit and leave", "Keep playing"], str(texts))
	if d != null:
		d.press("Save and leave")
	await _until(func(): return host.opponent_suspended, 4.0)
	_check("G01 client Save and leave: host told, nothing forfeited, series saved",
		host.opponent_suspended and host.series.forfeit_by == -1 and host.series.stage == Series.STAGE_REWARDS
		and SeriesStore.list().any(func(e): return e["id"] == host.series.save_id), "dir=%s" % SeriesStore.DIR)
	client._reconnect_timer.stop()
	client.host_gone = true
	client.simulate_drop()
	await _until(func(): return host.paused, 6.0)
	screen.attach(host.local_seat)
	await _wait(1.0)
	await _shot("06_host_sees_opponent_saved")
	_check("G01 host's pause veil says the opponent saved and left", String(host.local_seat.last_view.get("net", {}).get("message", "")) == NetSession.OPPONENT_SAVED_MESSAGE)
	# The client comes back, then the host saves and leaves.
	client.host_gone = false
	client.join_enet("127.0.0.1", PORT)
	await _until(func(): return not host.paused and host.remote_peer != 0, 15.0)
	_check("G01 a rejoining client clears the saved-and-left note", not host.opponent_suspended)
	await _wait(0.8)
	screen.menu.confirm_forfeit(true)
	await _wait(0.5)
	await _shot("07_host_quit_dialog")
	var hd := screen.menu.dialog()
	_check("G01 host dialog explains Resume on the main menu", hd != null and screen.menu.save_text().contains("Resume"), screen.menu.save_text())
	screen.menu.close_dialog()          # pressing Save and quit would end this run: send it directly
	host.local_seat.send({"t": "suspend"})
	await _until(func(): return client.host_suspended, 4.0)
	host.api.multiplayer_peer.close()
	screen.attach(client.local_seat)
	await _until(func(): return client.host_gone, 6.0)
	await _wait(1.0)
	await _shot("08_client_sees_host_saved")
	_check("G01 client is told the host saved and left (no reconnect loop)", client.host_gone and String(client.local_seat.last_view.get("net", {}).get("message", "")) == NetSession.HOST_SAVED_MESSAGE)
	_check("G01 host Save and quit forfeits nothing", host.series.forfeit_by == -1 and host.series.stage == Series.STAGE_REWARDS)
	screen.menu.confirm_forfeit(false)
	_check("G01 with the host gone, leaving asks nothing", screen.menu.dialog() == null)
