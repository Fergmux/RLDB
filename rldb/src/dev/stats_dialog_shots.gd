extends SceneTree
## Windowed check of Decks > Statistics: the empty state, then a seeded record (the test stats
## file, never the player's). Run from rldb/:
##   godot --path . -s res://src/dev/stats_dialog_shots.gd -- <out_dir> [1600x900]

var out_dir: String = ""
var tag: String = ""
var fails: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://stats_dialog"
	var sz := Vector2i(1600, 900)
	if args.size() > 1:
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = sz
	run.call_deferred()


func _check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [name, tag]))


func _seed() -> void:
	var ids := CardDB.all().map(func(c): return int(c["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 37:
		var cards := {}
		for j in 12:
			var id: int = ids[rng.randi_range(20, 80)]
			cards[str(id)] = int(cards.get(str(id), 0)) + 1
		var plays := {str(ids[33]): rng.randi_range(1, 4), str(ids[rng.randi_range(20, 80)]): 1}
		PlayerStats.record_duel({"mode": ["steam", "steam", "bot", "lan", "local"][i % 5],
			"won": null if i % 5 == 4 else rng.randf() < 0.6, "turns": rng.randi_range(4, 19),
			"ms": rng.randi_range(240000, 900000), "deck": ["Deck 3 - Spirit Bomb", "Ashen Host", "Draft deck"][i % 3],
			"cards": cards, "plays": plays, "summons": rng.randi_range(2, 7), "spells": rng.randi_range(0, 4),
			"damage": rng.randi_range(20, 60), "best_hit": rng.randi_range(4, 23)})
	for i in 9:
		PlayerStats.record_series("steam", i % 3 != 0, [2, 1])
	for i in 6:
		PlayerStats.record_draft_pick(int(ids[40]))
	PlayerStats.record_draft_done()
	PlayerStats.record_draft_done()


func run() -> void:
	PlayerStats.clear()
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var menu: MainMenu = main.menu
	menu.pick("@decks")
	await create_timer(0.5).timeout
	menu.pick("stats")
	var d := root.find_children("*", "StatsDialog", true, false)
	_check("Statistics opens a dialog", d.size() == 1)
	await _snap("01_empty")
	(d[0] as StatsDialog).close()
	_seed()
	await create_timer(0.3).timeout
	menu.pick("stats")
	d = root.find_children("*", "StatsDialog", true, false).filter(func(x): return not x.is_queued_for_deletion())
	_check("Statistics reopens with the record", d.size() == 1)
	await _snap("02_record")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	await create_timer(0.2).timeout
	_check("Esc closes the dialog", root.find_children("*", "StatsDialog", true, false).filter(func(x): return not x.is_queued_for_deletion()).is_empty())
	_check("Esc did not leave the Decks menu", main.menu == menu and menu._menu_path.back() == "decks")
	PlayerStats.clear()
	print("DONE fails=%d" % fails)
	quit(1 if fails else 0)
