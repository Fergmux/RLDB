extends SceneTree
## Windowed performance probe: a hot-seat series with the real GameScreen, driven by a
## simple bot so animations play, recording frame times. Not a unit test.
##   godot --path rldb --resolution 1600x1000 -s res://tests/perf/perf_run.gd
## Prints average/95th/99th-percentile frame time and the slowest frame.

const COMMANDS := 400

var frames: Array = []
var host: LocalHost
var screen: GameScreen
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 99
	SeriesStore.DIR = "user://dev_saves"
	host = LocalHost.new()
	root.add_child(host)
	host.start({"seed": 12, "best_of": 3, "names": ["P1", "P2"]})
	screen = GameScreen.new()
	root.add_child(screen)
	screen.attach(host.seats[0])
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await process_frame
	var sent := 0
	var last := Time.get_ticks_usec()
	while sent < COMMANDS and host.series.stage != Series.STAGE_OVER:
		var p := host.acting_seat()
		if screen.client != host.seats[p]:
			screen.attach(host.seats[p])
		var cmd := _decide(p)
		if not cmd.is_empty():
			host.handle(p, cmd)
			sent += 1
		# let animations run between commands, as a human-paced game would
		for f in 6:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
	frames.sort()
	var n := frames.size()
	var avg := 0.0
	for f in frames:
		avg += f
	avg /= maxf(n, 1)
	print("PERF frames=%d avg=%.2fms (%.0f fps) p95=%.2fms p99=%.2fms max=%.2fms commands=%d stage=%s" % [
		n, avg, 1000.0 / maxf(avg, 0.001), frames[int(n * 0.95)], frames[int(n * 0.99)], frames[n - 1], sent, host.series.stage])
	quit()


func _decide(p: int) -> Dictionary:
	var v: Dictionary = host.seats[p].last_view
	match v.get("stage", ""):
		"decks":
			return {"t": "pick_starter", "index": p} if not v["deck_ready"][p] else {}
		"rewards":
			return {"t": "reward_finish"} if not v["rewards"]["done"] else {}
		"first_player":
			if v["last_loser"] == p and not v["next"]["first_chosen"]:
				return {"t": "first_player", "who": 0}
			return {"t": "start_duel"} if not v["next"]["you_ready"] else {}
		"game":
			var mv: Dictionary = v["match"]
			var pd: Dictionary = mv["pending"]
			if not pd.is_empty():
				if not pd["mine"]:
					return {}
				var idx := range(pd["options"].size())
				var want: int = pd["options"].size() if pd.get("min_total", 0) > 0 else maxi(pd["min"], 1)
				return {"t": "choose", "id": pd["id"], "indices": idx.slice(0, mini(want, idx.size()))}
			if mv["active"] != p:
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
