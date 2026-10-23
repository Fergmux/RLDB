extends SceneTree
## Dev-only windowed gallery for K2 (owner, 23 Oct): the TickMedallion in every draft category
## colour and the reward colours, at the sizes the game uses (20 sidebar, 22 rewards, 24 draft tabs)
## and enlarged (48, 96) to judge the cut, rim and tick. Run NOT headless:
##   godot --path rldb -s res://src/dev/k2_tick_shots.gd -- <absolute output dir>

const SIZES := [20.0, 22.0, 24.0, 48.0, 96.0]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://k2_ticks"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	_run.call_deferred(out_dir)


func _run(out_dir: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.075, 0.062, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cols: Array = []
	for k in ["unit", "spell", "trap", "power", "extra"]:
		cols.append(UIStyle.CATEGORY_COLORS.get(k, UIStyle.BRONZE))
	cols.append(UIStyle.GOOD)
	var y := 24.0
	for d in SIZES:
		var x := 24.0
		for c in cols:
			var m := TickMedallion.new(c, d)
			m.position = Vector2(x, y)
			m.size = m.custom_minimum_size
			bg.add_child(m)
			x += d + 28.0 + (40.0 if d >= 48.0 else 0.0)
		y += d + 28.0
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("k2_tick_gallery.png"))
	print("K2 tick gallery saved")
	quit(0)
