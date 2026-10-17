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
var win_size := Vector2i(1600, 900)


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
		win_size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _ok(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", what, detail])


## Playtest feedback 08: G03 a Trap response to an attack (Radablast attacks Basic Monster,
## activate Damage Conversion?) and a yes / no question; G09 toasts over a card.
func _feedback08_shots() -> void:
	var opp := 1 - me
	m.submit(me, {"t": "next_phase"})                        # Battle Phase
	var rad := TB.unit(m, me, 77, 0, "atk")
	var mon := TB.unit(m, opp, 5, 2, "atk")
	TB.set_card(m, opp, 47, 2)
	m.submit(me, {"t": "attack", "uid": rad})
	if String(m.pending.get("kind", "")) == "attack_target":
		TB.choose_uids(m, [mon])
	main._shown_seat = opp
	gs.attach(host.seats[opp])
	host.broadcast()
	await _frames(12)
	var pr := gs.prompt
	var figs := pr.mention_row.get_children().filter(func(n): return n.has_meta("role"))
	_ok("G03 response shows attacker and target", figs.size() == 2 and String(m.pending.get("kind", "")) == "trap_response", str(m.pending.get("prompt", "")))
	_ok("G03 response shows the responding Trap", pr.respond_col.visible and pr.respond_col.get_child_count() >= 2)
	var btns := pr.banner_list.get_children()
	_ok("G03 Pass is the last button, below Activate", btns.size() == 2 and String((btns[1] as Button).text) == "Pass" \
		and (btns[1] as Control).get_global_rect().position.y > (btns[0] as Control).get_global_rect().end.y - 1.0, str(btns.map(func(b): return b.text)))
	await _shot("g03_trap_response")
	_check_clear("trap response")
	var pass_i := -1
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]) == "Pass":
			pass_i = i
	host.handle(opp, {"t": "choose", "id": m.pending["id"], "indices": [pass_i]})
	await _frames(6)
	main._shown_seat = me
	gs.attach(host.seats[me])
	host.broadcast()
	await _frames(12)
	# A yes / no question about a card of mine (the shape of a triggered "activate?" prompt).
	var src := -1
	for u in m.players[me]["units"]:
		if u != -1:
			src = u
	gs.mv["pending"] = {"id": 990, "mine": true, "player": me, "kind": "confirm", "prompt": "Draw a card and gain +1 AP?",
		"options": [{"i": 0, "label": "Yes"}, {"i": 1, "label": "No"}], "min": 1, "max": 1, "cancellable": false, "source_uid": src}
	pr.prompt_sig = 0
	pr.render()
	await _frames(12)
	var yn := pr.banner_list.get_children()
	_ok("G03 Yes sits above No", yn.size() == 2 and String((yn[0] as Button).text) == "Yes" and (yn[1] as Control).position.y > (yn[0] as Control).position.y)
	await _shot("g03_yes_no")
	_check_clear("yes / no")
	gs.mv["pending"] = {}
	pr.prompt_sig = 0
	pr.render()
	await _frames(4)
	# G09: toasts over a card of mine, over a card at the top of the board, and in the Hand.
	var shots := [["g09_toast_my_unit", src], ["g09_toast_top_card", m.players[opp]["units"][0]]]
	if not m.players[me]["hand"].is_empty():
		shots.append(["g09_toast_hand_card", m.players[me]["hand"][0]])
	for s in shots:
		var uid: int = int(s[1])
		if uid == -1:
			continue
		pr.show_toast("%s: no legal target." % m.name_of(uid), UIStyle.GOLD_HI, 6.0, {"uid": uid})
		await _frames(6)
		var r := pr.toast_anchor_rect({"uid": uid})
		var tr := pr.toast.get_global_rect()
		var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_ok("G09 %s next to its card, on screen" % s[0], r.has_area() and not tr.intersects(r) and view.encloses(tr) \
			and (absf(tr.end.y - r.position.y) < 20.0 or absf(tr.position.y - r.end.y) < 20.0), "toast %s card %s" % [tr, r])
		await _shot(String(s[0]))
		pr.hide_toast()


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
	if tag != "fullscreen":
		# Main applies the saved window mode (full screen by default) on start-up: undo it for the
		# requested window size (not saved).
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
	if not m.pending.is_empty():
		host.handle(me, {"t": "cancel", "id": m.pending["id"]})
		await _frames(4)
	await _feedback08_shots()
	print("prompt layout: %d failures" % fails)
	quit(1 if fails > 0 else 0)
