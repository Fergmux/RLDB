extends Node
## Frame-time breakdown for the windowed perf probes (perf_run.gd, qa_perf_soak.gd with --profile).
## Not a unit test. Added under the root, it samples every frame:
##   frame   wall time between the starts of two process passes (what the player sees)
##   proc    the _process pass (PerfRecorder runs first, its tail node last)
##   draw    time from the end of the _process pass to the last CanvasItem draw of the frame (the
##           deferred queue_redraw flush), and per-script draw counts / approximate cost
##   render  the viewport's measured render CPU / GPU time (RenderingServer)
## plus the draw calls, objects and node count monitors, and which scripts are processing.
## report() prints "PROFILE ..." lines; slow frames (over SLOW_MS) are summarised on their own.

## A frame slower than this (ms) counts as slow in the report.
const SLOW_MS := 16.7

var frames: Array = []          # [frame_ms, proc_ms, draw_ms, render_cpu, render_gpu, draw_calls, nodes, cmd]
var draws_total: Dictionary = {}   # script/class -> [count, approx usec]
var draws_slow: Dictionary = {}    # same, but only during slow frames
var _frame_draws: Dictionary = {}
var _t_frame := 0
var _t_proc_end := 0
var _t_last_draw := 0
var _t_prev_draw := 0
var _prev_key := "<proc end>"
var _tail: Node
var _vp: RID
## Set by the probe on the frame a command is handled.
var cmd_flag := false
## Bisect switches from `--exp=a,b` (see _ready).
var experiments: PackedStringArray = []
var _started := false
## Spans reported by temporarily instrumented code (span()): key -> [count, usec], all / slow frames.
var spans_total: Dictionary = {}
var spans_slow: Dictionary = {}
var _frame_spans: Dictionary = {}


## Instrumentation hook: code under investigation finds this node at /root/PerfRecorder and reports
## `usec` spent under `key`.
func span(key: String, usec: int) -> void:
	var e: Array = _frame_spans.get(key, [0, 0])
	e[0] += 1
	e[1] += usec
	_frame_spans[key] = e


func _ready() -> void:
	name = "PerfRecorder"
	process_priority = -100000
	_tail = Node.new()
	_tail.name = "PerfRecorderTail"
	_tail.process_priority = 100000
	_tail.set_script(_TailScript)
	add_child(_tail)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	get_tree().node_added.connect(_hook)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exp="):
			experiments.append_array(a.trim_prefix("--exp=").split(","))
	if experiments.has("nosysfb"):
		for f in DirAccess.get_files_at("res://assets/fonts"):
			if f.ends_with(".ttf"):
				var ff: FontFile = load("res://assets/fonts/" + f)
				ff.allow_system_fallback = false
	print("PROFILE experiments=%s" % [experiments])
	_hook_tree(get_tree().root)
	print("PROFILE vsync=%d refresh=%.1fHz renderer=%s driver=%s msaa2d=%d" % [
		DisplayServer.window_get_vsync_mode(), DisplayServer.screen_get_refresh_rate(),
		RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
		get_viewport().msaa_2d])


func _hook_tree(n: Node) -> void:
	_hook(n)
	for c in n.get_children():
		_hook_tree(c)


func _hook(n: Node) -> void:
	if n is CanvasItem and not n.draw.is_connected(_on_draw):
		n.draw.connect(_on_draw.bind(n))
	if n is Control and experiments.has("markers") and not n.resized.is_connected(_mark):
		n.resized.connect(_mark.bind(n, "resized"))
		n.minimum_size_changed.connect(_mark.bind(n, "minsize"))
		n.visibility_changed.connect(_mark.bind(n, "visibility"))
		n.theme_changed.connect(_mark.bind(n, "theme"))
	if n is Container and not n.pre_sort_children.is_connected(_on_pre_sort):
		n.pre_sort_children.connect(_on_pre_sort)
		n.sort_children.connect(_on_sorted.bind(n))


## Big gaps (> GAP_MS) between consecutive marker events: "before -> after" -> [count, usec].
var big_gaps: Dictionary = {}
const GAP_MS := 1.0
var _last_mark_t := 0
var _last_mark := ""


func _mark(n: Node, what: String) -> void:
	_mark_event("%s %s(%s)" % [what, key_of(n), n.name])


func _mark_event(ev: String) -> void:
	var now := Time.get_ticks_usec()
	if _t_proc_end > _t_frame and now > _t_proc_end and _last_mark_t >= _t_proc_end:
		var gap := now - _last_mark_t
		if gap > GAP_MS * 1000.0:
			_acc(big_gaps, "%s  ->  %s" % [_last_mark, ev], [1, gap])
	_last_mark_t = now
	_last_mark = ev


var _sort_t0 := 0
var _sort_depth := 0


func _on_pre_sort() -> void:
	if _sort_depth == 0:
		_sort_t0 = Time.get_ticks_usec()
	_sort_depth += 1


func _on_sorted(n: Node) -> void:
	_sort_depth = maxi(_sort_depth - 1, 0)
	if _sort_depth > 0:
		return
	var now := Time.get_ticks_usec()
	var p := n.get_parent()
	span("sort %s/%s(%s)" % [key_of(p) if p else "", key_of(n), n.name], now - _sort_t0)
	_t_prev_draw = now
	_t_last_draw = maxi(_t_last_draw, now)


static func key_of(n: Node) -> String:
	var s: Script = n.get_script()
	if s != null and s.resource_path != "":
		return s.resource_path.get_file()
	return n.get_class()


func _on_draw(n: Node) -> void:
	if experiments.has("markers"):
		_mark(n, "draw")
	var now := Time.get_ticks_usec()
	var since := now - maxi(_t_prev_draw, _t_proc_end)
	_t_prev_draw = now
	_t_last_draw = now
	var k := key_of(n)
	var k2 := k
	if n is Label:
		k2 = "Label[%s|%s|parent %s]" % [n.name, (n as Label).text.left(60), key_of(n.get_parent())]
	var pair := "%s > %s" % [_prev_key, k2]
	_prev_key = k
	var pe: Array = _frame_spans.get("gap " + pair, [0, 0])
	pe[0] += 1
	pe[1] += since
	_frame_spans["gap " + pair] = pe
	var e: Array = _frame_draws.get(k, [0, 0])
	e[0] += 1
	e[1] += since
	_frame_draws[k] = e


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _started:
		var frame_ms := (now - _t_frame) / 1000.0
		var draw_ms := maxf(0.0, (_t_last_draw - _t_proc_end) / 1000.0) if _t_last_draw > _t_proc_end else 0.0
		frames.append([frame_ms, (_t_proc_end - _t_frame) / 1000.0, draw_ms,
			RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu(),
			RenderingServer.viewport_get_measured_render_time_gpu(_vp),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), cmd_flag])
		var slow := frame_ms > SLOW_MS
		for k in _frame_draws:
			_acc(draws_total, k, _frame_draws[k])
			if slow:
				_acc(draws_slow, k, _frame_draws[k])
		for k in _frame_spans:
			_acc(spans_total, k, _frame_spans[k])
			if slow:
				_acc(spans_slow, k, _frame_spans[k])
	_frame_spans = {}
	_frame_draws = {}
	cmd_flag = false
	_started = true
	_t_frame = now
	_t_prev_draw = 0
	_t_last_draw = 0
	_prev_key = "<proc end>"


static func _acc(d: Dictionary, k: String, e: Array) -> void:
	var t: Array = d.get(k, [0, 0])
	t[0] += e[0]
	t[1] += e[1]
	d[k] = t


func _tail_done() -> void:
	_t_proc_end = Time.get_ticks_usec()
	_last_mark_t = _t_proc_end
	_last_mark = "<proc end>"


## Scripts (or classes) with processing on, and how many nodes each.
func processing_census() -> Dictionary:
	var out := {}
	_census(get_tree().root, out)
	return out


func _census(n: Node, out: Dictionary) -> void:
	if n.is_processing() and n != self and n != _tail:
		var k := key_of(n)
		out[k] = int(out.get(k, 0)) + 1
	for c in n.get_children():
		_census(c, out)


## Prints the breakdown.
func report() -> void:
	var n := frames.size()
	if n == 0:
		return
	var cols := ["frame", "proc", "draw", "rcpu", "rgpu", "dcalls", "nodes"]
	var line := "PROFILE all n=%d" % n
	for i in cols.size():
		line += " %s[p50=%.2f p95=%.2f]" % [cols[i], _pct(frames, i, 0.5), _pct(frames, i, 0.95)]
	print(line)
	var slow := frames.filter(func(f): return f[0] > SLOW_MS)
	var cmd_slow := slow.filter(func(f): return f[7])
	print("PROFILE slow frames=%d (%.1f%%), of which command frames=%d; command frames total=%d" % [
		slow.size(), 100.0 * slow.size() / n, cmd_slow.size(), frames.filter(func(f): return f[7]).size()])
	if not slow.is_empty():
		var sl := "PROFILE slow"
		for i in cols.size():
			sl += " %s[avg=%.2f]" % [cols[i], _avg(slow, i)]
		print(sl)
	var noncmd := frames.filter(func(f): return not f[7])
	if not noncmd.is_empty():
		print("PROFILE non-command frames p50=%.2f p95=%.2f p99=%.2f" % [_pct(noncmd, 0, 0.5), _pct(noncmd, 0, 0.95), _pct(noncmd, 0, 0.99)])
	_print_draws("draws(all)", draws_total, n)
	_print_draws("draws(slow)", draws_slow, maxi(slow.size(), 1))
	_print_draws("biggap", big_gaps, n)
	_print_draws("spans(all)", spans_total, n)
	_print_draws("spans(slow)", spans_slow, maxi(slow.size(), 1))
	var census := processing_census()
	var ks := census.keys()
	ks.sort_custom(func(a, b): return census[a] > census[b])
	var cl := "PROFILE processing:"
	for k in ks:
		cl += " %s=%d" % [k, census[k]]
	print(cl)


func _print_draws(title: String, d: Dictionary, n_frames: int) -> void:
	var ks := d.keys()
	ks.sort_custom(func(a, b): return d[a][1] > d[b][1])
	for i in mini(ks.size(), 70):
		var k: String = ks[i]
		print("PROFILE %s %-34s draws/frame=%6.2f  ~ms/frame=%6.3f" % [title, k, float(d[k][0]) / n_frames, d[k][1] / 1000.0 / n_frames])


static func _pct(rows: Array, col: int, q: float) -> float:
	var v := rows.map(func(r): return float(r[col]))
	v.sort()
	return v[mini(int(v.size() * q), v.size() - 1)]


static func _avg(rows: Array, col: int) -> float:
	var s := 0.0
	for r in rows:
		s += float(r[col])
	return s / maxf(rows.size(), 1)


static var _TailScript: GDScript = _make_tail()


static func _make_tail() -> GDScript:
	var g := GDScript.new()
	g.source_code = "extends Node\nfunc _process(_d: float) -> void:\n\tget_parent()._tail_done()\n"
	g.reload()
	return g
