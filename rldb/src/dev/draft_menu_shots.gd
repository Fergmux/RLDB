extends SceneTree
## Dev-only windowed evidence for the draft setup in the menu (J26, owner 22 Oct: a fixed draft
## composition, no per-category counts): the Play vs Bot panel with Draft chosen. Run NOT headless:
##   godot --path rldb -s res://src/dev/draft_menu_shots.gd -- <abs out dir> [WxH]
## Prints PASS / FAIL checks and quits with the number of failures.

var out_dir: String = ""
var main: Node
var sz := Vector2i(1600, 900)
var fails := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://draft_menu"
	for a in args.slice(1):
		if String(a).contains("x") and not String(a).begins_with("--"):
			var p := String(a).split("x")
			sz = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	create_timer(90.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what, "  ", detail)


func _shot(name: String, wait: float = 0.9) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s_%dx%d.png" % [name, sz.x, sz.y]))
	print("SHOT ", name)


func run() -> void:
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	await create_timer(1.2).timeout
	var mm := main.menu as MainMenu
	main.opts["deck_mode"] = "draft"
	main.opts["draft_quota"] = {"unit": 9, "spell": 3, "trap": 3, "power": 2, "extra": 3}   # a stale pre-J26 key
	mm.pick("@play")
	await process_frame
	mm.pick("@local")
	await process_frame
	mm.pick("bot")
	await _shot("menu_vs_bot_draft")
	var steppers := mm.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "+")
	_check("J26 no per-category count steppers", steppers.is_empty(), str(steppers.size()))
	_check("J26 the fixed composition is shown", mm.find_child("DraftSummary", true, false) != null)
	_check("J26 a stale draft_quota is dropped", not main.opts.has("draft_quota"))
	print("DRAFT MENU DONE fails=%d" % fails)
	quit(fails)
