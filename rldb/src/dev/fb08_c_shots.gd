extends SceneTree
## Development-only evidence shots for playtest feedback 08 G07 and G08. Run windowed:
##   godot --path rldb -s res://src/dev/fb08_c_shots.gd -- --no-steam --fb08-shots=<abs dir>
## G07: Diggie selected in the Battle Phase with an opposing unit shows Attack and Attack Direct.
## G08: a unit in front zone 2 is sacrificed for AP, an ability summons it back from Spent; the
## zone arrow starts at the summoned card (banner card), not at the ability's card or zone 2.
## Also a normal summon from Hand after a sacrifice. Prints PASS/FAIL lines.

var main: Node
var host: LocalHost
var m: MatchEngine
var out_dir := ""
var fails := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fb08-shots="):
			out_dir = a.split("=", true, 1)[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	SeriesStore.DIR = "user://test_saves"
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % name))


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("FB08C %s %s %s" % ["PASS" if ok else "FAIL", name, detail])


func _fresh() -> GameScreen:
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _wait(0.6)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	var gs: GameScreen = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	return gs


func _show(gs: GameScreen) -> void:
	main._shown_seat = m.active
	host.broadcast()
	gs.attach(host.seats[m.active])
	await _wait(0.8)
	gs.fx.finish_all()
	await _wait(0.3)


func _run() -> void:
	await _wait(0.3)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.8)
	main._auto_started = true
	await _g07()
	await _g08_spent()
	await _g08_hand()
	print("FB08C DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _g07() -> void:
	var gs: GameScreen = await _fresh()
	var a := m.active
	for s in 6:
		if m.players[a]["units"][s] != -1:
			m.move_to_pile(m.players[a]["units"][s], "spent")
	var dg := TB.unit(m, a, 162, 1)
	TB.unit(m, 1 - a, TB.WATER, 1)
	m.submit(a, {"t": "next_phase"})                 # Battle Phase
	await _show(gs)
	gs.selection.select(dg)
	await _wait(0.5)
	var texts := []
	if gs.action_row.stack != null:
		texts = gs.action_row.stack.get_children().map(func(b): return (b as Button).text)
	_check("G07 Diggie offers Attack and Attack Direct", texts == ["Attack", "Attack Direct"], str(texts))
	await _snap("g07_diggie_attack_and_attack_direct")
	# Attack: the target choice offers only the opposing unit (no direct option in the banner).
	for b in gs.action_row.stack.get_children():
		if (b as Button).text == "Attack":
			(b as Button).pressed.emit()
	await _wait(0.6)
	var pd := gs.pending()
	var direct := (pd.get("options", []) as Array).any(func(o): return String(o["label"]).contains("directly"))
	_check("G07 Attack asks for a unit only", String(pd.get("kind", "")) == "attack_target" and not direct, str(pd.get("options", []).map(func(o): return o["label"])))
	gs.targeting.hover_opt = 0
	await _wait(0.3)
	await _snap("g07_diggie_attack_targets_a_unit")
	gs.targeting.hover_opt = -1
	main._sessions.clear()
	await _wait(0.3)


func _g08_spent() -> void:
	var gs: GameScreen = await _fresh()
	var a := m.active
	for s in 6:
		if m.players[a]["units"][s] != -1:
			m.move_to_pile(m.players[a]["units"][s], "spent")
	var sac := TB.unit(m, a, TB.WATER, 1)              # front zone 2
	var ab := TB.unit(m, a, 12, 4)                     # Pay 2 AP: summon from Spent in this column
	m.players[a]["ap"] = 1
	await _show(gs)
	host.handle(a, {"t": "sacrifice", "uid": sac})
	await _wait(0.6)
	gs.fx.finish_all()
	host.handle(a, {"t": "ability", "uid": ab, "idx": 0})
	await _wait(0.4)
	host.handle(a, {"t": "choose", "id": m.pending["id"], "values": [sac]})
	await _wait(0.8)
	gs.fx.finish_all()
	gs.targeting.hover_opt = 0                        # point at the offered zone
	await _wait(0.4)
	var src: Rect2 = gs.targeting._source_rect()
	var bad_old: bool = src == gs.fx_slot_global_rect(a, "unit", 1)
	var bad_ab: bool = src == gs.fx_slot_global_rect(a, "unit", 4)
	_check("G08 Spent summon arrow starts at the summoned card", src.size != Vector2.ZERO and not bad_old and not bad_ab and gs.arrow.on,
		"src %s subject %s" % [src, gs.prompt.subject_card.get_global_rect()])
	await _snap("g08_arrow_from_summoned_card_after_sacrifice_spent")
	gs.targeting.hover_opt = -1
	main._sessions.clear()
	await _wait(0.3)


func _g08_hand() -> void:
	var gs: GameScreen = await _fresh()
	var a := m.active
	for s in 6:
		if m.players[a]["units"][s] != -1:
			m.move_to_pile(m.players[a]["units"][s], "spent")
	var sac := TB.unit(m, a, TB.WATER, 1)
	var h := TB.card(m, a, TB.FIRE)
	m.players[a]["ap"] = 0
	await _show(gs)
	host.handle(a, {"t": "sacrifice", "uid": sac})
	await _wait(0.6)
	gs.fx.finish_all()
	gs.acting_uid = h
	host.handle(a, {"t": "summon", "uid": h, "stance": "atk"})
	await _wait(0.6)
	gs.targeting.hover_opt = 0
	await _wait(0.4)
	var src: Rect2 = gs.targeting._source_rect()
	var want: Rect2 = (gs.hand.items[h]["holder"] as Control).get_global_rect() if gs.hand.items.has(h) else Rect2()
	_check("G08 Hand summon arrow starts at the Hand card", src == want and gs.arrow.on, "src %s hand %s" % [src, want])
	await _snap("g08_arrow_from_hand_card_after_sacrifice")
	gs.targeting.hover_opt = -1
	main._sessions.clear()
	await _wait(0.3)
