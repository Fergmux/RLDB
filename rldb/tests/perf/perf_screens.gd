extends SceneTree
## Windowed per-screen frame-rate probe (H7, 21 Oct). Not a unit test: it opens a real window.
##   godot --path rldb --resolution 1600x1000 -s res://tests/perf/perf_screens.gd -- --no-steam --perf-shots [--attribute]
## Runs the real entry scene (main.tscn) with vsync off and no frame cap, then measures:
##   menu        the main menu, idle
##   decks       the pre-game deck choice of a bot series, idle
##   duel_idle   the duel screen on your turn with nothing happening
##   duel_play   the duel with commands and animations (seat 0 is driven like tests/perf/perf_run.gd)
##   rewards     the between-game rewards modal after the bot concedes game 1, idle (J31)
##   draft       the draft picks of a hot-seat draft series, idle (J31)
## For each it prints the average / p95 frame time, fps, CPU process time, GPU and CPU render time.
## `split` (J31) divides the main thread's frame: `scr` = scripts, layout and _draw callbacks
## (process_frame to frame_pre_draw), `rnd` = the RenderingServer's draw and submit (frame_pre_draw to
## frame_post_draw), `oth` = present, physics, input (the rest). `process=` is Godot's per-second max.
## `--quick` stops after duel_idle; `--off=a.gd,b.gd` stops _process of those scripts (bisect).
## `--perf-out=<dir>` saves a JPG of each screen with every AmbientMotes frozen at MOTE_T s.
## `--attribute` also lists which CanvasItems redraw (`draw` signal) on most idle frames, the
## nodes that run _process, and the live tweens: the usual sources of an idle frame cost.
## `--drawcalls` (J31) lists, per idle screen, the canvas items whose subtree issues the most draw
## calls: each is hidden at the RenderingServer level for a few frames (no layout change) and the drop
## in RENDER_TOTAL_DRAW_CALLS_IN_FRAME is its subtree's share.
## "--perf-shots" only makes main.gd use the dev save folders (no real saves are touched).

const WARM := 90
const SAMPLE := 400
const PLAY_COMMANDS := 120

var main: Control
var rng := RandomNumberGenerator.new()
var attribute := false
var _draws: Dictionary = {}   # instance id -> count of draw emissions
var _names: Dictionary = {}   # instance id -> path label
var _shots := ""   # `--perf-out=<dir>`: a JPG of each screen with the motes frozen at MOTE_T
const MOTE_T := 37.0
var _off: PackedStringArray = []   # `--off=a.gd,b.gd`: bisect, stop _process of these scripts
# Frame phase stamps (usec) of the last frame: process_frame, frame_pre_draw, frame_post_draw.
var _t_proc := 0
var _t_pre := 0
var _t_post := 0
# Phases (ms) of the frame that just ended: [scripts, render, other].
var _phase := [0.0, 0.0, 0.0]


func _initialize() -> void:
	rng.seed = 7
	attribute = "--attribute" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--off="):
			_off = a.split("=", true, 1)[1].split(",")
		if a.begins_with("--perf-out="):
			_shots = a.split("=", true, 1)[1]
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	process_frame.connect(_on_frame_start)
	RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _t_post = Time.get_ticks_usec())
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("PERF setup: vsync=%d max_fps=%d msaa_2d=%d size=%s driver=%s" % [
		DisplayServer.window_get_vsync_mode(), Engine.max_fps, root.msaa_2d, root.size,
		RenderingServer.get_current_rendering_driver_name()])
	await _measure("menu")
	main.call("_start_bot", {"seed": 12, "best_of": 3, "deck_mode": "starter", "names": ["P1", "P2"]})
	await _frames(WARM)
	await _measure("decks")
	var host: LocalHost = main.get("local_host")
	host.handle(0, {"t": "pick_starter", "index": 0})
	# coin flip, deal and opening animations
	# Waits are time-based (the bot thinks in real time; frame counts vary with the fps).
	await _until(func() -> bool: return host.series.stage == Series.STAGE_GAME, 20.0)
	await _frames(400)
	# wait until it is seat 0's open turn with no prompt
	await _until(func() -> bool: return _my_idle_turn(host), 30.0)
	await _frames(240)
	await _measure("duel_idle")
	if "--quick" in OS.get_cmdline_user_args():
		quit()
		return
	if attribute:
		_hook_draws(root)
	var stats := _begin()
	var sent := 0
	while sent < PLAY_COMMANDS and host.series.stage == Series.STAGE_GAME:
		var cmd := _decide(host)
		if not cmd.is_empty():
			host.handle(0, cmd)
			sent += 1
		Engine.max_fps = 0
		for f in 8:
			await process_frame
			_sample(stats)
	_report("duel_play", stats)
	if attribute:
		_attribution("duel_play", stats["n"])
	# J31: the rewards modal between games (the bot concedes game 1).
	if host.series.stage == Series.STAGE_GAME:
		host.handle(1, {"t": "concede"})
	await _until(func() -> bool: return host.series.stage == Series.STAGE_REWARDS, 20.0)
	await _frames(240)
	await _measure("rewards")
	# J31: the draft picks (a hot-seat draft series, seat 0's view).
	main.call("_start_local", {"seed": 777, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _frames(240)
	await _measure("draft")
	quit()


func _on_frame_start() -> void:
	var now := Time.get_ticks_usec()
	if _t_proc > 0 and _t_pre >= _t_proc and _t_post >= _t_pre:
		_phase = [(_t_pre - _t_proc) / 1000.0, (_t_post - _t_pre) / 1000.0, (now - _t_post) / 1000.0]
	_t_proc = now


## Waits until `ok` holds or `limit_s` seconds pass (prints a note on a timeout).
func _until(ok: Callable, limit_s: float) -> void:
	var end := Time.get_ticks_msec() + int(limit_s * 1000.0)
	while not ok.call():
		if Time.get_ticks_msec() > end:
			print("PERF wait timed out after %.0f s" % limit_s)
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _my_idle_turn(host: LocalHost) -> bool:
	var v: Dictionary = host.seats[0].last_view
	if v.get("stage", "") != "game":
		return false
	var mv: Dictionary = v["match"]
	return mv["active"] == 0 and mv["pending"].is_empty()


func _begin() -> Dictionary:
	return {"dt": [], "proc": 0.0, "gpu": 0.0, "rcpu": 0.0, "draws": 0.0, "n": 0, "last": Time.get_ticks_usec(),
		"scr": 0.0, "rnd": 0.0, "oth": 0.0}


func _sample(s: Dictionary) -> void:
	Engine.max_fps = 0   # main.gd caps an unfocused window at 30 fps; measure the foreground cost
	var now := Time.get_ticks_usec()
	var dt_ms: float = (now - int(s["last"])) / 1000.0
	s["dt"].append(dt_ms)
	s["last"] = now
	# The phases of the frame that just ended (stamped by _on_frame_start).
	s["scr"] += _phase[0]
	s["rnd"] += _phase[1]
	s["oth"] += _phase[2]
	s["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	s["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	s["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	s["rcpu"] += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	s["n"] += 1


func _measure(label: String) -> void:
	await _frames(WARM)
	if not _off.is_empty():
		_switch_off(root)
		await _frames(5)
	if attribute:
		_hook_draws(root)
	Engine.max_fps = 0   # main.gd caps a background window at 30 fps: measure the foreground cost
	var s := _begin()
	for i in SAMPLE:
		await process_frame
		_sample(s)
	_report(label, s)
	if attribute:
		_attribution(label)
	if "--drawcalls" in OS.get_cmdline_user_args():
		await _draw_call_tree(label)
	if _shots != "":
		await _shot(label)


func _shot(label: String) -> void:
	_freeze_motes(root)
	await _frames(3)
	DirAccess.make_dir_recursive_absolute(_shots)
	var path := _shots.path_join("%s.jpg" % label)
	root.get_texture().get_image().save_jpg(path, 0.88)
	print("PERF shot ", path)


func _freeze_motes(n: Node) -> void:
	if n is AmbientMotes:
		(n as AmbientMotes).clock = func() -> float: return MOTE_T
		(n as AmbientMotes).queue_redraw()
	for c in n.get_children(true):
		_freeze_motes(c)


func _report(label: String, s: Dictionary) -> void:
	var dt: Array = s["dt"]
	dt.sort()
	var n := dt.size()
	var avg := 0.0
	for f in dt:
		avg += f
	avg /= maxf(n, 1)
	var k := maxf(s["n"], 1)
	print("PERF %-10s frames=%d avg=%.2fms (%.0f fps) p95=%.2fms process=%.2fms render_cpu=%.2fms gpu=%.2fms draw_calls=%.0f nodes=%d split scr=%.2f rnd=%.2f oth=%.2f" % [
		label, n, avg, 1000.0 / maxf(avg, 0.001), dt[int(n * 0.95)], s["proc"] / k, s["rcpu"] / k,
		s["gpu"] / k, s["draws"] / k, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		s["scr"] / k, s["rnd"] / k, s["oth"] / k])


func _draw_call_tree(label: String) -> void:
	var items: Array = []
	_collect_items(root, items)
	var base := await _draw_calls_now()
	var rows: Array = []
	for ci: CanvasItem in items:
		if not is_instance_valid(ci) or not ci.is_visible_in_tree():
			continue
		RenderingServer.canvas_item_set_visible(ci.get_canvas_item(), false)
		var n := await _draw_calls_now()
		RenderingServer.canvas_item_set_visible(ci.get_canvas_item(), ci.visible)
		if base - n >= 15:
			rows.append([base - n, _depth(ci), "%s (%s)" % [str(ci.get_path()).replace("/root/Main/", ""), _script_name(ci)]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PERF %s draw calls %d; subtrees issuing >= 15:" % [label, base])
	for r in rows.slice(0, 70):
		print("    %5d  d%-2d %s" % r)


func _draw_calls_now() -> float:
	await _frames(3)
	var t := 0.0
	for i in 3:
		await process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / 3.0


func _collect_items(n: Node, out: Array) -> void:
	if n is CanvasItem:
		out.append(n)
	for c in n.get_children(true):
		_collect_items(c, out)


func _depth(n: Node) -> int:
	var d := 0
	while n.get_parent() != null:
		n = n.get_parent()
		d += 1
	return d


func _hook_draws(n: Node) -> void:
	if n is CanvasItem:
		var id := n.get_instance_id()
		if not _draws.has(id):
			_names[id] = "%s (%s)" % [str(n.get_path()).replace("/root/", ""), _script_name(n)]
			(n as CanvasItem).draw.connect(func(): _draws[id] = _draws.get(id, 0) + 1)
		_draws[id] = 0
	for c in n.get_children(true):
		_hook_draws(c)


func _switch_off(n: Node) -> void:
	if _script_name(n) in _off:
		n.set_process(false)
		n.set_physics_process(false)
	for c in n.get_children(true):
		_switch_off(c)


func _script_name(n: Node) -> String:
	var sc: Script = n.get_script()
	return sc.resource_path.get_file() if sc != null else n.get_class()


func _attribution(label: String, frames: int = SAMPLE) -> void:
	var hot: Array = []
	for id in _draws:
		if _draws[id] > frames / 4 and is_instance_id_valid(id):
			hot.append([_draws[id], _names[id]])
	hot.sort_custom(func(a, b): return a[0] > b[0])
	print("PERF %s redraws (>25%% of %d frames): %d items" % [label, frames, hot.size()])
	for h in hot.slice(0, 40):
		print("    %4d  %s" % h)
	var procs: Dictionary = {}
	_collect_process(root, procs)
	print("PERF %s processing nodes by script: %s" % [label, procs])
	print("PERF %s live tweens: %d" % [label, get_processed_tweens().size()])


func _collect_process(n: Node, out: Dictionary) -> void:
	if n.is_processing() or n.is_physics_processing():
		var k := _script_name(n)
		out[k] = out.get(k, 0) + 1
	for c in n.get_children(true):
		_collect_process(c, out)


func _decide(host: LocalHost) -> Dictionary:
	var v: Dictionary = host.seats[0].last_view
	match v.get("stage", ""):
		"game":
			var mv: Dictionary = v["match"]
			var pd: Dictionary = mv["pending"]
			if not pd.is_empty():
				if not pd["mine"]:
					return {}
				var idx := range(pd["options"].size())
				var want: int = pd["options"].size() if pd.get("min_total", 0) > 0 else maxi(pd["min"], 1)
				return {"t": "choose", "id": pd["id"], "indices": idx.slice(0, mini(want, idx.size()))}
			if mv["active"] != 0:
				return {}
			var legal: Array = mv["actions"].filter(func(a): return a["ok"])
			if legal.is_empty():
				return {}
			var a: Dictionary = legal[0] if rng.randf() < 0.35 else legal[rng.randi_range(0, legal.size() - 1)]
			var cmd := {"t": a["t"]}
			for k in ["uid", "idx"]:
				if a.has(k):
					cmd[k] = a[k]
			return cmd
	return {}
