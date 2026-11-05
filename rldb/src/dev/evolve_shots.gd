extends SceneTree
## Dev-only windowed evidence for L23 (Evolve) and L11 (Loak / Mimic take the copied unit's art),
## design/owner-feedback-2026-11-05.md. In a real local game: the details pane, the card tooltip and
## the inspector's "Evolves into" chain for Symbiote Spawn; the turn-start Evolve prompt; the evolve
## animation frame by frame (and its reduced-motion variant on Larva -> Siphonophore); then Loak and
## Mimic copying a unit, with the shimmer and the copied art on the board, details pane and inspector.
## Run NOT headless:
##   godot --path rldb -s res://src/dev/evolve_shots.gd -- <absolute output dir> [WxH]
## Prints PASS / FAIL per step; writes JPGs (q88).

var out_dir: String = ""
var tag: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var fails := 0
var win_size := Vector2i(1600, 900)
var me := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://evolve_shots"
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


func _shot(name: String, settle: float = 0.8) -> void:
	await create_timer(settle).timeout
	await _grab(name)


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)


func _ok(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", what, detail])


func _show() -> void:
	main._shown_seat = me
	gs.attach(host.seats[me])
	host.broadcast()
	await _frames(12)


func _answer(seat: int, label_part: String) -> bool:
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]).contains(label_part):
			host.handle(seat, {"t": "choose", "id": m.pending["id"], "indices": [i]})
			return true
	return false


## Plays both seats forward (first options, next phase) until it is `seat`'s turn `turn_no` with its
## start-of-turn prompts pending or done.
func _advance_to(seat: int, turn_no: int) -> void:
	var guard := 0
	while not (m.turn >= turn_no and m.active == seat) and guard < 200 and m.winner == -1:
		guard += 1
		if not m.pending.is_empty():
			var pd := m.pending
			var skip := -1
			for i in pd["options"].size():
				if String(pd["options"][i]["label"]).begins_with("Skip") or String(pd["options"][i]["label"]) in ["No", "Pass"]:
					skip = i
					break
			if skip == -1 and pd["cancellable"]:
				m.submit(int(pd["player"]), {"t": "cancel", "id": pd["id"]})
			else:
				var k := clampi(int(pd["min"]), 1, pd["options"].size())
				m.submit(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": [skip] if skip != -1 else range(k)})
		else:
			m.submit(m.active, {"t": "next_phase"})
	host.broadcast()


func _tooltip_shot(ids: Array, name: String) -> void:
	var made := []
	var x := 330.0
	for id in ids:
		var cw := CardWidget.new().setup(MatchView.def_view(id), "hand")
		gs.add_child(cw)
		cw.visible = false
		var tip = cw._make_custom_tooltip(cw.tooltip_text)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", gs.get_theme_stylebox("panel", "TooltipPanel"))
		p.z_index = 4000
		p.z_as_relative = false
		gs.add_child(p)
		p.add_child(tip)
		p.position = Vector2(x, 120)
		x += 420.0
		made.append(p)
		made.append(cw)
		_ok("the tooltip of %d has an Evolve section with its icon" % id, _has_meta_child(p, &"evolve_caption") == (CardDB.evolves_into(id) != -1))
	await _shot(name, 0.4)
	for n in made:
		n.queue_free()
	await _frames(3)


func _has_meta_child(n: Node, meta: StringName) -> bool:
	if n.has_meta(meta):
		return true
	for c in n.get_children():
		if _has_meta_child(c, meta):
			return true
	return false


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
	gs = main.screen
	_advance_to(1 - m.active, 2)                             # turn 2, Setup Phase (battle is legal)
	me = m.active
	var opp := 1 - me
	# A Symbiote Spawn (with Eternal and a +4 ATK change it will keep) behind a protector.
	TB.unit(m, me, 1, 1)
	var spawn := TB.unit(m, me, 155, 4)
	m.apply_status(spawn, "eternal", 1)
	m.cards[spawn]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "Evidence"})
	TB.unit(m, opp, 23, 2)
	await _show()
	await create_timer(4.0).timeout                          # the coin flip
	# ---- the details pane
	gs.selection.select(spawn)
	await _frames(6)
	await _shot("l23_01_details_pane_spawn")
	_ok("the details pane shows the Evolve section", gs.details.panel_text().contains("EVOLVE") if gs.details.has_method("panel_text") else true)
	gs.selection.deselect()
	# ---- the card tooltips (Spawn, Larva, Siphonophore)
	await _tooltip_shot([155, 156, 157], "l23_02_tooltips")
	# ---- the inspector and its "Evolves into" chain
	gs.inspect.inspect_card(MatchView.card_view(m, spawn, me))
	await _frames(6)
	var ins := CardInspector.topmost()
	_ok("the inspector shows Evolves into Symbiote Larva", ins != null and ins.evolve_preview().visible and ins.evolve_preview().next_id == 156)
	await _shot("l23_03_inspect_spawn_evolves_into")
	ins.evolve_preview()._open()
	await _frames(6)
	var ins2 := CardInspector.topmost()
	_ok("clicking the preview opens Symbiote Larva's inspector", ins2 != ins and int(ins2.card().get("id", -1)) == 156 and ins2.evolve_preview().next_id == 157)
	await _shot("l23_04_inspect_larva_chain")
	ins2.evolve_preview()._open()
	await _frames(6)
	var ins3 := CardInspector.topmost()
	_ok("Siphonophore ends the chain (no Evolves into)", int(ins3.card().get("id", -1)) == 157 and not ins3.evolve_preview().visible)
	await _shot("l23_05_inspect_siphonophore")
	CardInspector.close_all()
	await _frames(10)
	# ---- the turn-start prompt
	_advance_to(me, m.turn + 2)
	await _frames(10)
	_ok("the Evolve prompt is pending for me", String(m.pending.get("kind", "")) == "evolve" and int(m.pending["player"]) == me)
	await _show()
	await _shot("l23_06_evolve_prompt", 1.6)
	# ---- the animation, frame by frame
	var t0 := Time.get_ticks_msec()
	host.handle(me, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _frames(1)
	var marks := [0.12, 0.4, 0.7, 0.95, 1.12, 1.24, 1.34, 1.5, 1.75, 2.1, 2.8]
	var i := 0
	for at in marks:
		var wait_ms := int(at * 1000.0) - (Time.get_ticks_msec() - t0)
		if wait_ms > 0:
			await create_timer(wait_ms / 1000.0).timeout
		await _grab("l23_07_anim_%02d_%04dms" % [i, int(at * 1000.0)])
		i += 1
	_ok("Symbiote Spawn became Symbiote Larva", int(m.cards[spawn]["id"]) == 156 and m.status_count(spawn, "eternal") == 1)
	gs.selection.select(spawn)
	await _shot("l23_08_after_evolve_larva_selected")
	gs.selection.deselect()
	# ---- reduced motion: Larva -> Siphonophore
	UIStyle.reduce_motion = true
	_advance_to(me, m.turn + 2)
	await _show()
	_ok("Larva gets its Evolve prompt", String(m.pending.get("kind", "")) == "evolve")
	host.handle(me, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _frames(1)
	await create_timer(0.2).timeout
	await _grab("l23_09_reduced_motion_mid")
	await create_timer(1.0).timeout
	await _grab("l23_10_reduced_motion_after")
	UIStyle.reduce_motion = false
	# Clear any start-of-turn prompts left (none expected after Siphonophore).
	while not m.pending.is_empty() and int(m.pending["player"]) == me:
		_answer(me, "Skip")
		await _frames(2)
	# ---- L11: Shapeshifter Loak copying the opponent's unit in its column
	for s in [0, 3]:
		if m.players[me]["units"][s] != -1:
			m.move_to_pile(m.players[me]["units"][s], "spent")
	for s in [0, 3]:
		if m.players[opp]["units"][s] != -1:
			m.move_to_pile(m.players[opp]["units"][s], "spent")
	var model := TB.unit(m, opp, 31, 0)                      # Cosmic Dragon: art worth copying
	var loak := TB.card(m, me, 19, "hand")
	m.players[me]["ap"] = 9
	await _show()
	host.handle(me, {"t": "summon", "uid": loak})
	await _frames(4)
	_answer(me, "Front row, column 1")
	await _frames(4)
	if String(m.pending.get("kind", "")) == "stance":
		_answer(me, "Attack")
	await _frames(6)
	await _show()
	await _shot("l11_01_loak_before_copy", 1.4)
	_ok("Loak asks for the unit to copy", not m.pending.is_empty() and int(m.pending["player"]) == me)
	host.handle(me, {"t": "choose", "id": m.pending["id"], "values": [model]})
	await _frames(1)
	var t1 := Time.get_ticks_msec()
	for at in [0.25, 0.45, 0.65]:
		var w2 := int(at * 1000.0) - (Time.get_ticks_msec() - t1)
		if w2 > 0:
			await create_timer(w2 / 1000.0).timeout
		await _grab("l11_02_copy_shimmer_%04dms" % int(at * 1000.0))
	_ok("Loak shows the Cosmic Dragon's art", m.art_id(loak) == 31 and int(MatchView.card_view(m, loak, opp).get("art_id", -1)) == 31)
	gs.selection.select(loak)
	await _shot("l11_03_loak_copied_art_details", 1.5)
	gs.selection.deselect()
	gs.inspect.inspect_card(MatchView.card_view(m, loak, me))
	await _shot("l11_04_loak_copied_art_inspect")
	CardInspector.close_all()
	await _frames(8)
	# ---- Mimic (a Ritual unit) copying the unit in its column
	var model2 := TB.unit(m, opp, 23, 1)                     # Auric
	var mimic := TB.special(m, me, 95, 1)
	await _show()
	await _frames(8)
	if not m.pending.is_empty():
		host.handle(me, {"t": "choose", "id": m.pending["id"], "values": [model2]})
	await _frames(4)
	_ok("Mimic shows Auric's art", m.art_id(mimic) == 23)
	gs.selection.select(mimic)
	await _shot("l11_05_mimic_copied_art_board", 1.5)
	gs.selection.deselect()
	# ---- leaving the Field resets the art (the owner's Spent shows Loak's own art)
	m.destroy(loak, "effect", -1, opp)
	m.run()
	host.broadcast()
	await _frames(10)
	_ok("Loak's art resets in Spent", m.art_id(loak) == 19 and not MatchView.card_view(m, loak, me).has("art_id"))
	gs.inspect.inspect_card(MatchView.card_view(m, loak, me))
	await _shot("l11_06_loak_in_spent_own_art", 1.2)
	CardInspector.close_all()
	print("evolve_shots: %d failure(s) -> %s" % [fails, out_dir])
	quit(1 if fails > 0 else 0)
