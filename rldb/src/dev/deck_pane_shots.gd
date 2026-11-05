extends SceneTree
## Dev-only windowed evidence for the deck builder's middle pane (owner feedback 21 Oct, H24-H27).
## Run NOT headless:
##   godot --path rldb -s res://src/dev/deck_pane_shots.gd -- <absolute output dir> [WxH] [--all]
## Opens the deck builder, shows a long-text Fusion, a long-text unit, a spell, a basic unit and an
## Arcane card with 0 / 1 / 2 / 3 / 15 copies, and saves one JPG (q88, at most 1600 px wide) per
## card. Prints the middle pane's content height against its room for each shot; `--all` also walks
## every card and prints the tightest fit; `--steps` also shows the longest card at each density step
## the pane takes when a card would not fit (DeckBuilder.FIT_STEPS). Nothing is saved: the copies are
## added in memory only.

const SHOTS := [[146, 3, "fusion_longest"], [147, 0, "fusion_long"], [36, 1, "unit_long"], [155, 2, "evolve_spawn"],
	[156, 0, "evolve_larva"], [80, 2, "spell"], [1, 3, "basic"], [185, 15, "arcane_15"]]

var out_dir: String = ""
var tag: String = ""
var walk_all: bool = false
var show_steps: bool = false
var win := Vector2i(1600, 1000)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://deck_pane"
	var sz := Vector2i(1600, 1000)
	for a in args.slice(1):
		if String(a) == "--all":
			walk_all = true
		elif String(a) == "--steps":
			show_steps = true
		elif String(a).contains("x"):
			var p := String(a).split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
	win = sz
	tag = "%dx%d" % [sz.x, sz.y]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(sz)
	root.size = sz
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, roundi(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join("%s_%s.jpg" % [shot_name, tag])
	img.save_jpg(path, 0.88)
	print("saved ", path)


func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	# The main scene restores the player's window mode and size: set the shot size after it.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win)
	await _frames(6)
	main._show_deck_builder()
	await _frames(8)
	var db := main.menu as DeckBuilder
	for s in SHOTS:
		var id: int = s[0]
		db.counts.erase(id)
		db.add_card(id, int(s[1]))
		db.show_preview(id)
		await _frames(4)
		await create_timer(0.4).timeout
		print("%s  id %d  copies %d  fit %s" % [tag, id, int(s[1]), str(db.call("preview_fit") if db.has_method("preview_fit") else "-")])
		await _snap("%s_x%d" % [s[2], int(s[1])])
	if show_steps and db.get("FIT_STEPS") != null:
		db.show_preview(146)
		await _frames(6)
		for st in range(1, db.FIT_STEPS.size()):
			db._restep(st)
			await _frames(6)
			await create_timer(0.3).timeout
			print("%s  id 146 forced step %d  fit %s" % [tag, st, str(db.preview_fit())])
			await _snap("fusion_longest_step%d" % st)
		db._restep(0)
		await _frames(6)
	if walk_all and db.has_method("preview_fit"):
		var worst := 1 << 30
		var worst_id := -1
		for d in CardDB.all():
			db.show_preview(int(d["id"]))
			await _frames(2)
			var f: Dictionary = db.call("preview_fit")
			var spare := int(f["room"] - f["need"])
			if spare < worst:
				worst = spare
				worst_id = int(d["id"])
		print("%s  tightest card %d  spare %d px" % [tag, worst_id, worst])
	quit()
