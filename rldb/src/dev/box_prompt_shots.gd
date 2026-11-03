extends SceneTree
## Dev-only windowed evidence for Do Not Open Box (card 191, 2026-11-03): in a real local game the
## active player's effect destroys the opponent's set Box; the owner gets the ordinary Trap window,
## picks a unit from their Draw (shown to them only) and places it in the Box's column.
## Run NOT headless:
##   godot --path rldb -s res://src/dev/box_prompt_shots.gd -- <absolute output dir> [WxH]
## Prints PASS / FAIL per step; writes JPGs (q88).

var out_dir: String = ""
var tag: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var fails := 0
var win_size := Vector2i(1600, 900)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://box_prompt"
	if args.size() > 1 and String(args[1]).contains("x"):
		var p := String(args[1]).split("x")
		win_size = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(win_size)
	root.size = win_size
	tag = "%dx%d" % [win_size.x, win_size.y]
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)


func _ok(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", what, detail])


func _show(seat: int) -> void:
	main._shown_seat = seat
	gs.attach(host.seats[seat])
	host.broadcast()
	await _frames(12)


func _answer(seat: int, label_part: String) -> void:
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]).contains(label_part):
			host.handle(seat, {"t": "choose", "id": m.pending["id"], "indices": [i]})
			return


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win_size)
	await _frames(6)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	await _frames(4)
	m = host.series.game
	while m.turn < 2 or m.phase != "main1":
		m.submit(m.active, {"t": "next_phase"})
	gs = main.screen
	var me := m.active
	var opp := 1 - me
	TB.unit(m, me, 23, 0)                                    # Auric, the destroyer
	TB.unit(m, opp, 1, 0)
	var box := TB.set_card(m, opp, 191, 1)
	var dragon := TB.card(m, opp, 31, "draw")                # a Cosmic Dragon to summon
	await _show(me)
	await create_timer(4.0).timeout                          # the coin flip
	# The active player's Auric pays 8 HP to destroy the set Box.
	host.handle(me, {"t": "ability", "uid": m.players[me]["units"][0], "idx": 0})
	await _frames(4)
	_answer(me, "Destroy a Spell/Trap")
	await _frames(4)
	host.handle(me, {"t": "choose", "id": m.pending["id"], "values": [box]})
	await _frames(6)
	_ok("the owner is asked in the ordinary Trap window", String(m.pending.get("kind", "")) == "trap_response" and int(m.pending["player"]) == opp)
	await _show(opp)
	await _shot("box_trap_window")
	_answer(opp, "Activate Do Not Open Box")
	await _frames(6)
	_ok("the owner picks from their Draw", String(m.pending.get("kind", "")) == "select" and m.pending.get("reveal_pile", false))
	await _show(opp)
	await _shot("box_draw_pick")
	host.handle(opp, {"t": "choose", "id": m.pending["id"], "values": [dragon]})
	await _frames(6)
	_ok("only the Box's column is offered", String(m.pending.get("kind", "")) == "slot" \
		and m.pending["options"].all(func(o): return int(o["slot"]) % 3 == 1), str(m.pending["options"].map(func(o): return o["label"])))
	await _show(opp)
	await _shot("box_zone_pick")
	_answer(opp, "column 2")
	await _frames(4)
	if String(m.pending.get("kind", "")) == "stance":
		_answer(opp, "Defense")
	await _frames(6)
	_ok("the Cosmic Dragon is on the Field in column 2", m.cards[dragon]["zone"] == "unit" and int(m.cards[dragon]["slot"]) % 3 == 1)
	await _show(me)
	await _shot("box_after_summon")
	print("box_prompt_shots: %d failure(s) -> %s" % [fails, out_dir])
	quit(1 if fails > 0 else 0)
