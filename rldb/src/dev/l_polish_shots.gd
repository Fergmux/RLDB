extends SceneTree
## Dev-only windowed evidence for the L batch polish follow-ups (design/owner-feedback-2026-11-05.md):
## the match sidebar's card details pane for long and Evolve cards (Symbiote Spawn / Larva, Akiramari),
## the details pane "Base" of a unit whose base an effect set (Shapeshifter Loak copying a unit, a
## set base on a printed unit), the turn panel chip during a zone prompt, and Esc closing the game
## menu with its close motion. Runs on a build before the fixes too (for the "before" shots).
## Run NOT headless:
##   godot --path rldb -s res://src/dev/l_polish_shots.gd -- <absolute output dir> [WxH] [prefix]
## Prints PASS / FAIL / INFO per step; writes JPGs (q88, at most 1600 px wide).

var out_dir: String = ""
var tag: String = ""
var prefix: String = ""
var main: Node
var gs: GameScreen
var m: MatchEngine
var host: LocalHost
var fails := 0
var win_size := Vector2i(1600, 900)
var me := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://l_polish_shots"
	if args.size() > 1 and String(args[1]).contains("x"):
		var p := String(args[1]).split("x")
		win_size = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 2:
		prefix = String(args[2]) + "_"
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	img.save_jpg(out_dir.path_join("%s%s_%s.jpg" % [prefix, name, tag]), 0.88)


func _ok(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", what, detail])


func _show() -> void:
	main._shown_seat = me
	gs.attach(host.seats[me])
	host.broadcast()
	await _frames(12)


## Plays both seats forward (first options or Skip, next phase) until it is `seat`'s turn `turn_no`.
func _advance_to(seat: int, turn_no: int) -> void:
	var guard := 0
	while not (m.turn >= turn_no and m.active == seat) and guard < 200 and m.winner == -1:
		guard += 1
		if not m.pending.is_empty():
			var pd := m.pending
			if pd["cancellable"]:
				m.submit(int(pd["player"]), {"t": "cancel", "id": pd["id"]})
			else:
				var k := clampi(int(pd["min"]), 1, pd["options"].size())
				m.submit(int(pd["player"]), {"t": "choose", "id": pd["id"], "indices": range(k)})
		else:
			m.submit(m.active, {"t": "next_phase"})
	host.broadcast()


## How far the details pane's content runs below its fold (px; 0 when it fits).
func _below_fold() -> float:
	var sc := gs.details.details_scroll
	return maxf(0.0, gs.details.details_view.get_combined_minimum_size().y - sc.size.y)


## The y (in the details scroll's visible area) where the caption `needle` sits, or -1.
func _caption_y(needle: String) -> float:
	var sc := gs.details.details_scroll
	for n in gs.details.details_view.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.text.to_upper().contains(needle):
			return l.get_global_rect().end.y - sc.get_global_rect().position.y
	return -1.0


func _details(name: String, uid: int, check_caption: String = "") -> void:
	gs.selection.select(uid)
	await _frames(8)
	await _shot(name)
	var sc := gs.details.details_scroll
	var cy := _caption_y(check_caption) if check_caption != "" else -1.0
	print("INFO  %s: below fold %d px, pane %d px, %s caption bottom at %d, cue %s" % [name, int(_below_fold()), int(sc.size.y),
		check_caption, int(cy), str(gs.details.scroll_cue.shown)])
	if check_caption != "":
		_ok("%s: the %s section is visible without scrolling (or the cue shows)" % [name, check_caption],
			(cy >= 0.0 and cy <= sc.size.y) or gs.details.scroll_cue.shown)
	gs.selection.deselect()
	await _frames(4)


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win_size)
	await _frames(6)
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only
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
	_advance_to(1 - m.active, 2)
	me = m.active
	var opp := 1 - me
	TB.unit(m, me, 1, 1)
	var spawn := TB.unit(m, me, 155, 4)
	m.apply_status(spawn, "eternal", 1)
	m.cards[spawn]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "Evidence"})
	var larva := TB.unit(m, me, 156, 3)
	m.apply_status(larva, "eternal", 1)
	var aki := TB.unit(m, me, 146, 5)
	var foe := TB.unit(m, opp, 37, 0)       # Solomon, the Captain 20/14
	m.players[me]["ap"] = 9
	await _show()
	await create_timer(4.0).timeout         # the coin flip and the deal
	# ---- item 3: the sidebar details pane of long / Evolve cards
	await _details("item3_details_spawn", spawn, "EVOLVE")
	await _details("item3_details_larva", larva, "EVOLVE")
	await _details("item3_details_akiramari", aki, "ON DESTRUCTION")
	# ---- item 4: Base of a unit whose base an effect set
	var loak := TB.card(m, me, 19, "hand")
	host.handle(me, {"t": "summon", "uid": loak})
	await _frames(4)
	# ---- item 2: the turn-panel chip during the zone prompt (summon placement)
	await _show()
	await _shot("item2_zone_prompt_chip", 1.0)
	var chip: String = gs.sidebar.state_label.text
	print("INFO  zone prompt chip: '%s'" % chip)
	_ok("zone prompt chip reads Choose a zone", chip == "Choose a zone", chip)
	for i in m.pending["options"].size():
		if String(m.pending["options"][i]["label"]) == "Front row, column 1":
			host.handle(me, {"t": "choose", "id": m.pending["id"], "indices": [i]})
			break
	await _frames(4)
	if String(m.pending.get("kind", "")) == "stance":
		host.handle(me, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _frames(4)
	if not m.pending.is_empty() and int(m.pending["player"]) == me:
		host.handle(me, {"t": "choose", "id": m.pending["id"], "values": [foe]})
	await _frames(6)
	await _show()
	await create_timer(1.5).timeout
	_ok("Loak copied Solomon", m.base_atk(loak) == 20 and m.base_def(loak) == 14, "base %d/%d" % [m.base_atk(loak), m.base_def(loak)])
	await _details("item4_details_loak_copied", loak)
	m.cards[aki]["base_atk"] = 30            # as Mirrorflesh / set_base do
	m.cards[aki]["base_def"] = 18
	host.broadcast()
	await _frames(6)
	await _details("item4_details_set_base_printed_unit", aki)
	m.cards[aki]["base_atk"] = null
	m.cards[aki]["base_def"] = null
	host.broadcast()
	await _frames(6)
	# ---- item 5: Esc closes the game menu with its close motion
	gs.menu.toggle()
	await _shot("item5_menu_open", 0.6)
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Sfx._reset_ui()
	gs.keyboard.handle_key(e)
	await create_timer(0.07).timeout
	await _grab("item5_menu_esc_closing_70ms")
	_ok("Esc keeps the menu animating out (not hidden at once)", gs.menu.game_menu.visible)
	_ok("Esc plays panel_close, not back", Sfx.debug_ui.has("panel_close") and not Sfx.debug_ui.has("back"), str(Sfx.debug_ui))
	await _shot("item5_menu_after_esc", 0.6)
	print("l_polish_shots: %d failure(s) -> %s" % [fails, out_dir])
	quit(1 if fails > 0 else 0)
