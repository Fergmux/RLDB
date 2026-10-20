extends SceneTree
## Development-only screenshots for the 20 Oct release batch, network area (A1 chat, A2 spectators,
## F1 main menu line). Run windowed (never --headless):
##   godot --path rldb -s res://src/dev/net_release_shots.gd -- <abs out dir> [--modes=menu,net]
## `menu` shows the real main menu (Steam is initialised when the client runs, so the line reads
## "Logged in as <Persona>"); `net` runs an ENet host, a client and a spectator in this process and
## photographs the chat box, the Spectators list in both states and the spectator's views.

const PORT := 24930

var out_dir := ""
var modes: Array = ["menu", "net"]
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if not args.is_empty() and not args[0].begins_with("--") else "user://net_release_shots"
	for a in args:
		if a.begins_with("--modes="):
			modes = Array(a.split("=", true, 1)[1].split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	SeriesStore.DIR = "user://dev_saves"
	PlayerProgress.persist = false
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _until(cond: Callable, secs: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("saved ", n)


func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if "menu" in modes:
		await _shot("f1_main_menu_identity")
	if "net" in modes and has_method("_run_net"):
		await call("_run_net")
	print("NET RELEASE SHOTS DONE: ", out_dir)
	quit()
