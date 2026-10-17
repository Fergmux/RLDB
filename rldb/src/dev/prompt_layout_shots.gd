extends SceneTree
## Dev-only windowed evidence for the input panel's placement (UI review 2026-10-17): a zone pick,
## the longest Type choice (Chaos Witch) and an Arcane material payment, at one window size.
## Run NOT headless:
##   godot --path rldb -s res://src/dev/prompt_layout_shots.gd -- <absolute output dir> [WxH] [--fullscreen]
## Prints PASS / FAIL for "the settled panel covers no zone, pile or plate".

var out_dir: String = ""
var tag: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var me: int
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://prompt_layout"
	var sz := Vector2i(1600, 900)
	if args.size() > 1 and String(args[1]).contains("x"):
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	if "--fullscreen" in args:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		tag = "fullscreen"
	else:
		DisplayServer.window_set_size(sz)
		root.size = sz
		tag = "%dx%d" % [sz.x, sz.y]
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


## The settled panel must not cover any zone, pile or plate.
func _check_clear(what: String) -> void:
	var br := gs.prompt.ctx_banner.get_global_rect()
	var hits := []
	for k in gs.board.slots:
		if br.intersects((gs.board.slots[k]["zone_node"] as Control).get_global_rect()):
			hits.append(str(k))
	for pl in gs.board.plates:
		if br.intersects((pl as Control).get_global_rect()):
			hits.append("plate")
	for side in 2:
		for z in gs.board.piles[side]:
			if br.intersects((gs.board.piles[side][z] as Control).get_global_rect()):
				hits.append("pile %d %s" % [side, z])
	var ok := hits.is_empty() and gs.prompt.ctx_banner.visible
	if not ok:
		fails += 1
	print("%s  %s panel %s clear of the board (viewport %s, window %s) %s" % ["PASS" if ok else "FAIL", what, br, root.get_visible_rect().size, DisplayServer.window_get_size(), hits])


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
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
	me = m.active
	main._shown_seat = me
	gs.attach(host.seats[me])
	TB.unit(m, 1 - me, 1, 0)
	TB.unit(m, 1 - me, 28, 4)
	TB.set_card(m, 1 - me, 45, 1)
	m.players[me]["ap"] = 4
	host.broadcast()
	await create_timer(4.0).timeout      # the coin flip
	# 1. A zone pick: summon a unit from the Hand.
	var hu := -1
	for u in m.players[me]["hand"]:
		if m.is_unit(u) and m.validate(me, {"t": "summon", "uid": u}) == "":
			hu = u
	host.handle(me, {"t": "summon", "uid": hu, "stance": "atk"})
	await _frames(12)
	await _shot("prompt_zone")
	_check_clear("zone pick")
	host.handle(me, {"t": "cancel", "id": m.pending["id"]})
	await _frames(4)
	# 2. The longest Type choice: Chaos Witch offers every Type.
	var cw := TB.unit(m, me, 13, 2, "atk")
	TB.ability(m, cw, 0)
	host.broadcast()
	await _frames(12)
	await _shot("prompt_type")
	_check_clear("type choice")
	gs.selection.pick_option(0)
	await _frames(6)
	# 3. An Arcane payment with one material picked.
	for id in [34, 27, 28]:
		TB.card(m, me, id, "spent")
	var boom := TB.card(m, me, 170, "extra")
	host.broadcast()
	await _frames(4)
	for a in gs.action_row.actions_for_card(boom):
		if String(a["t"]) == "arcane":
			gs.action_row.run_action(boom, a)
			break
	await _frames(12)
	if not m.pending.is_empty() and String(m.pending.get("kind", "")) == "select":
		gs.selection.pick_option(0)
		await _frames(12)
	await _shot("prompt_materials")
	_check_clear("materials")
	print("prompt layout: %d failures" % fails)
	quit(1 if fails > 0 else 0)
