extends SceneTree
## Boots the main scene and runs the L8 status evidence driver (src/dev/l_status_shots.gd) in it,
## without a command-line hook in main.gd. Run NOT headless:
##   godot --path rldb -s res://src/dev/l_status_shots_boot.gd -- <absolute dir> [before|4k] --l-status-shots
## The "--l-status-shots" argument makes Main use the development save paths (as every *shots run).
## "before" takes only the board / badge shots (for the before-and-after pair).


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = String(args[0]) if args.size() > 0 and not String(args[0]).begins_with("--") else "user://l_status_shots"
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var driver: Node = load("res://src/dev/l_status_shots.gd").new()
	driver.set("before", "before" in args)
	driver.set("uhd", "4k" in args)
	if "4k" in args:
		DisplayServer.window_set_size(Vector2i(3840, 2160))
		root.size = Vector2i(3840, 2160)
	main.add_child(driver)
	driver.run(main, dir)
