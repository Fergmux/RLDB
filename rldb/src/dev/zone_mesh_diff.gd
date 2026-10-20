extends SceneTree
## J31 follow-up: pixel comparison of the merged empty zones (ZoneMesh: one draw call each) against
## the live drawing (one draw call per primitive, the code as it was).
## Opens a real window (no --headless):
##   godot --path rldb --resolution 1600x1000 -s res://src/dev/zone_mesh_diff.gd -- --no-steam --perf-shots \
##       --diff-out=<dir> [--resize=1366x768]
## Runs a bot duel to seat 0's idle turn, freezes the dust motes and the zone pick clock, then for each
## state (idle, dimmed, picked + hovered pick) captures the window with ZoneMesh.enabled off (the live
## path, the code as it was) and on (merged), and diffs them over the rects of every visible empty zone
## that no card covers. Prints per state: the zones merged, the draw calls of both frames, the share of
## zone pixels that differ at all and by more than 2/255 in any channel, and the largest difference.
## Saves <res>_<state>_live.jpg, _merged.jpg and _diff.jpg (a differing pixel white at 1/255, yellow at
## 2/255, red above; the live frame dimmed behind; zones outlined) to the dir.
## `--resize=WxH` repeats the idle state after resizing the window live (a content scale change).

var main: Control
var out_dir := ""
## `--verbose`: print a sample of the differing pixels.
var verbose := false
var _res := ""


func _initialize() -> void:
	verbose = "--verbose" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--diff-out="):
			out_dir = a.split("=", true, 1)[1]
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main.call("_start_bot", {"seed": 12, "best_of": 3, "deck_mode": "starter", "names": ["P1", "P2"]})
	await _frames(90)
	var host: LocalHost = main.get("local_host")
	host.handle(0, {"t": "pick_starter", "index": 0})
	await _until(func() -> bool: return host.series.stage == Series.STAGE_GAME, 20.0)
	await _frames(400)
	await _until(func() -> bool: return _my_idle_turn(host), 30.0)
	# Time-based (a windowed run draws ~1000 fps): the coin flip, the deal and the hand settle.
	await _seconds(8.0)
	CardLayouts.clock_ms = func() -> float: return 12345.0
	_freeze_motes(root)
	_res = "%dx%d" % [root.size.x, root.size.y]
	var zones := _empty_zones()
	print("DIFF setup: window=%s zones=%d msaa_2d=%d final=%s" % [_res, zones.size(), root.msaa_2d, root.get_final_transform()])
	await _compare("idle", zones)
	# Hard dim (the non-targets while a target is chosen) and soft dim.
	for i in zones.size():
		(zones[i] as CardWidget).set_marks(false, false, i % 2 == 0, i % 2 == 1)
	await _compare("dimmed", zones)
	# A zone pick on every third zone, the first one hovered (glow lifted, mote).
	var first := true
	for i in zones.size():
		var w: CardWidget = zones[i]
		w.set_marks(i % 3 == 0, false, i % 3 != 0)
		if i % 3 == 0 and first:
			w.hovered = true
			first = false
	await _compare("picked", zones)
	if "--noise-probe" in OS.get_cmdline_user_args():
		await _noise_probe(zones)
	for w: CardWidget in zones:
		w.hovered = false
		w.set_marks(false, false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--resize="):
			var wh := a.split("=", true, 1)[1].split("x")
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
			await _frames(60)
			_res = "%dx%d" % [root.size.x, root.size.y]
			print("DIFF resized: window=%s final=%s" % [_res, root.get_final_transform()])
			# Merged first this time: the zones must have picked the mesh for the new scale on their own.
			await _frames(10)
			await _compare("resized", _empty_zones(), true)
	quit()


## Every visible empty zone widget no visible card overlaps.
func _empty_zones() -> Array:
	var all: Array = []
	_collect(root, all)
	var cards: Array = all.filter(func(w: CardWidget) -> bool: return not w.view.is_empty())
	var out: Array = []
	for w: CardWidget in all:
		if not w.view.is_empty() or w.size_kind not in ["board", "trap", "power"]:
			continue
		var r := _screen_rect(w)
		var covered := false
		for c: CardWidget in cards:
			covered = covered or _screen_rect(c).grow(8).intersects(r)
		if not covered:
			out.append(w)
	return out


func _collect(n: Node, out: Array) -> void:
	if n is CardWidget and (n as CardWidget).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _screen_rect(w: Control) -> Rect2:
	return w.get_viewport().get_final_transform() * w.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, w.size)


func _redraw_all(zones: Array) -> void:
	for w: CardWidget in zones:
		w.queue_redraw()


func _compare(state: String, zones: Array, merged_first: bool = false) -> void:
	var live: Image
	var merged: Image
	var dl := 0.0
	var db := 0.0
	var nb := 0
	if merged_first:
		nb = zones.filter(func(w: CardWidget) -> bool: return w.is_zone_merged()).size()
		db = await _draws()
		merged = await _grab()
	ZoneMesh.enabled = false
	_redraw_all(zones)
	await _frames(6)
	dl = await _draws()
	live = await _grab()
	ZoneMesh.enabled = true
	_redraw_all(zones)
	await _frames(12)
	if not merged_first:
		nb = zones.filter(func(w: CardWidget) -> bool: return w.is_zone_merged()).size()
		db = await _draws()
		merged = await _grab()
	# Control: a second live frame. What differs between the two live frames is the scene's own
	# noise floor (anything still animating), not the merge.
	ZoneMesh.enabled = false
	_redraw_all(zones)
	await _frames(6)
	var live2 := await _grab()
	ZoneMesh.enabled = true
	_redraw_all(zones)
	await _frames(6)
	var masks: Array = []
	for w: CardWidget in zones:
		var r := _screen_rect(w).grow(3)
		masks.append(Rect2i(Vector2i(r.position.floor()), Vector2i(r.size.ceil()) + Vector2i.ONE))
	var res := _diff(live, merged, masks, live2)
	var ctl := _diff(live, live2, masks)
	var st: Dictionary = res[0]
	var cs: Dictionary = ctl[0]
	var tot := maxf(st["total"], 1)
	print("DIFF %s %s: zones=%d merged=%d draw_calls live=%.0f merged=%.0f zone_px=%d differ=%d (%.3f%%) over_2=%d (%.3f%%) max=%d/255 | control live-vs-live differ=%d (%.3f%%) max=%d/255 | on pixels the old code draws the same twice: differ=%d (%.3f%%) max=%d/255" % [
		_res, state, zones.size(), nb, dl, db, st["total"], st["any"], 100.0 * st["any"] / tot, st["over2"],
		100.0 * st["over2"] / tot, st["worst"], cs["any"], 100.0 * cs["any"] / tot, cs["worst"],
		st["stable_any"], 100.0 * st["stable_any"] / tot, st["stable_worst"]])
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		_save(live, "%s_%s_live.jpg" % [_res, state])
		_save(merged, "%s_%s_merged.jpg" % [_res, state])
		_save(res[1], "%s_%s_diff.jpg" % [_res, state])
		_save(ctl[1], "%s_%s_control_diff.jpg" % [_res, state])


## Diagnostics: live frames of the picked state against each other, with the zones' per-frame redraw
## on and then off.
func _noise_probe(zones: Array) -> void:
	ZoneMesh.enabled = false
	_redraw_all(zones)
	var masks: Array = []
	for w: CardWidget in zones:
		var r := _screen_rect(w).grow(3)
		masks.append(Rect2i(Vector2i(r.position.floor()), Vector2i(r.size.ceil()) + Vector2i.ONE))
	await _frames(6)
	var a := await _grab()
	for gap in [1, 30]:
		await _frames(gap)
		var b := await _grab()
		var st: Dictionary = _diff(a, b, masks)[0]
		print("DIFF noise redraw-on gap=%d differ=%d max=%d" % [gap, st["any"], st["worst"]])
	for w: CardWidget in zones:
		w.set_process(false)
	await _frames(6)
	a = await _grab()
	for gap in [1, 30]:
		await _frames(gap)
		var b := await _grab()
		var st: Dictionary = _diff(a, b, masks)[0]
		print("DIFF noise redraw-off gap=%d differ=%d max=%d" % [gap, st["any"], st["worst"]])
	_redraw_all(zones)
	await _frames(3)
	var b2 := await _grab()
	var st2: Dictionary = _diff(a, b2, masks)[0]
	print("DIFF noise redraw-off then one redraw differ=%d max=%d" % [st2["any"], st2["worst"]])
	var tws := get_processed_tweens()
	for tw in tws:
		tw.pause()
	await _frames(4)
	var e := await _grab()
	await _frames(3)
	var f := await _grab()
	print("DIFF noise with %d tweens paused differ=%d" % [tws.size(), _diff(e, f, masks)[0]["any"]])
	for tw in tws:
		if tw.is_valid():
			tw.play()
	var all_off: Array = []
	var pr: Dictionary = {}
	_collect_proc(root, pr)
	for k in pr:
		all_off.append_array(pr[k])
	for n: Node in all_off:
		n.set_process(false)
	for tw in get_processed_tweens():
		tw.pause()
	await _frames(4)
	var g := await _grab()
	await _frames(3)
	var h := await _grab()
	print("DIFF noise with every _process and tween stopped differ=%d" % _diff(g, h, masks)[0]["any"])
	for n: Node in all_off:
		n.set_process(true)
	for tw in get_processed_tweens():
		tw.play()
	# Which processing items make the flicker: stop each script's _process in turn.
	var procs: Dictionary = {}
	_collect_proc(root, procs)
	for script_name in procs:
		for n: Node in procs[script_name]:
			n.set_process(false)
		await _frames(4)
		var c := await _grab()
		await _frames(3)
		var d := await _grab()
		var st3: Dictionary = _diff(c, d, masks)[0]
		print("DIFF noise without %s (%d nodes) differ=%d" % [script_name, procs[script_name].size(), st3["any"]])
		for n: Node in procs[script_name]:
			n.set_process(true)
	ZoneMesh.enabled = true


func _collect_proc(n: Node, out: Dictionary) -> void:
	if n.is_processing():
		var sc: Script = n.get_script()
		var k := sc.resource_path.get_file() if sc != null else n.get_class()
		if not out.has(k):
			out[k] = []
		out[k].append(n)
	for c in n.get_children(true):
		_collect_proc(c, out)


## [{"total", "any", "over2", "worst", "stable_any", "stable_worst"}, diff image] of `a` against `b`
## over the rects `masks`. With `ref` (a second frame of `a`'s code), stable_* count only the pixels
## where `a` and `ref` agree exactly (the GPU's own frame-to-frame flicker left out).
func _diff(a_img: Image, b_img: Image, masks: Array, ref: Image = null) -> Array:
	var diff := Image.create(a_img.get_width(), a_img.get_height(), false, Image.FORMAT_RGB8)
	var st := {"total": 0, "any": 0, "over2": 0, "worst": 0, "stable_any": 0, "stable_worst": 0}
	var seen := {}
	for m: Rect2i in masks:
		var cl := m.intersection(Rect2i(0, 0, a_img.get_width(), a_img.get_height()))
		for y in range(cl.position.y, cl.end.y):
			for x in range(cl.position.x, cl.end.x):
				var k := y * 65536 + x
				if seen.has(k):
					continue
				seen[k] = true
				st["total"] += 1
				var a := a_img.get_pixel(x, y)
				var b := b_img.get_pixel(x, y)
				var d := maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))
				if d > 0:
					st["any"] += 1
					if ref != null and ref.get_pixel(x, y).to_rgba32() == a.to_rgba32():
						st["stable_any"] += 1
						st["stable_worst"] = maxi(st["stable_worst"], d)
						if verbose and st["stable_any"] % 40 == 1:
							print("DIFF px (%d,%d) live=%s merged=%s" % [x, y, a.to_html(false), b.to_html(false)])
				if d > 2:
					st["over2"] += 1
				st["worst"] = maxi(st["worst"], d)
				# Readable at a glance: 1/255 white, 2/255 yellow, more red; the live frame faint behind.
				var shade := Color(a.r, a.g, a.b) * 0.18
				diff.set_pixel(x, y, shade if d == 0 else (Color.WHITE if d == 1 else (Color.YELLOW if d == 2 else Color.RED)))
		for x in range(cl.position.x, cl.end.x):
			diff.set_pixel(x, cl.position.y, Color(0.25, 0.25, 0.6))
			diff.set_pixel(x, cl.end.y - 1, Color(0.25, 0.25, 0.6))
		for y in range(cl.position.y, cl.end.y):
			diff.set_pixel(cl.position.x, y, Color(0.25, 0.25, 0.6))
			diff.set_pixel(cl.end.x - 1, y, Color(0.25, 0.25, 0.6))
	return [st, diff]


func _save(img: Image, name: String) -> void:
	var im := img.duplicate() as Image
	if im.get_width() > 1600:
		im.resize(1600, int(im.get_height() * 1600.0 / im.get_width()), Image.INTERPOLATE_LANCZOS)
	im.save_jpg(out_dir.path_join(name), 0.88)


func _grab() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _draws() -> float:
	var t := 0.0
	for i in 4:
		await process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / 4.0


func _freeze_motes(n: Node) -> void:
	if n is AmbientMotes:
		(n as AmbientMotes).clock = func() -> float: return 37.0
		(n as AmbientMotes).queue_redraw()
	for c in n.get_children(true):
		_freeze_motes(c)


func _until(ok: Callable, limit_s: float) -> void:
	var end := Time.get_ticks_msec() + int(limit_s * 1000.0)
	while not ok.call():
		if Time.get_ticks_msec() > end:
			print("DIFF wait timed out after %.0f s" % limit_s)
			return
		await process_frame


func _seconds(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
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
