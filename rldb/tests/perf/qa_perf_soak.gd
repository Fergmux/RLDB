extends SceneTree
## L batch final QA, windowed (design/qa-final-2026-11-05.md): a long bot-vs-bot series on the real
## GameScreen with the "spiced" decks of qa_soak.gd (Evolve, Hypnotise, Snunday, Loak / Mimic, Cleanse /
## Curse and many status cards), so status looks, ticks, expiries, Evolve set pieces and queued
## animations (L4) all play. It records frame times, and the scene-tree node count and the orphan node
## count at every new turn once the animation queue has drained, then checks that neither grows.
##
##   godot --path rldb --resolution 1600x1000 -s res://tests/perf/qa_perf_soak.gd -- [--commands=N] [--pace=F]
##
## --profile: adds a PerfRecorder (perf_recorder.gd) and prints its frame-time breakdown.
## --pace: frames between commands (default 4: faster than a human, so the L4 queue builds a backlog).
## Prints "PERF ..." and "NODES ..." lines, then "QA PERF OK" or "QA PERF FAIL <reason>" (exit 0 / 1).

const Soak = preload("res://tests/perf/qa_soak.gd")

## A node-count rise across the run beyond this many nodes (at drained turn starts) is a leak.
const NODE_GROWTH_LIMIT := 150
## Orphan nodes (freed from the tree but never freed) allowed at the end.
const ORPHAN_LIMIT := 40
## p99 frame time limit (ms) for the windowed run.
const P99_LIMIT_MS := 50.0

var opts := {"commands": 900, "pace": 4, "seed": 5}
var frames: Array = []
var host: LocalHost
var screen: GameScreen
var bots: Array = []
var samples: Array = []   # [command index, turn, game, nodes, orphans]
## Milliseconds the authority + both views + the screen's render take per command (inside a frame).
var handle_ms: Array = []
var recorder: Node = null


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() == 2 else true
	SeriesStore.DIR = "user://test_saves"
	host = LocalHost.new()
	root.add_child(host)
	host.start({"seed": int(opts["seed"]), "best_of": 5, "names": ["P1", "P2"], "deck_mode": "starter"})
	screen = GameScreen.new()
	root.add_child(screen)
	screen.attach(host.seats[0])
	bots = [BotBrain.new(0, 11), BotBrain.new(1, 12)]
	if opts.has("profile"):
		recorder = preload("res://tests/perf/perf_recorder.gd").new()
		root.add_child(recorder)
	_run.call_deferred()


func _drained() -> bool:
	return screen.fx == null or not screen.fx.busy()


func _run() -> void:
	for i in 30:
		await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts["seed"])
	for p in 2:
		host.handle(p, {"t": "custom_deck", "name": "spice", "cards": Soak.spice_deck(rng)})
	var sent := 0
	var last := Time.get_ticks_usec()
	var last_turn := -1
	var last_game := -1
	var limit := int(opts["commands"])
	var pace := int(opts["pace"])
	var idle := 0
	while sent < limit and host.series.stage != Series.STAGE_OVER:
		var s: Series = host.series
		var cmd := {}
		var who := -1
		for p in 2:
			var c: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
			if not c.is_empty():
				cmd = c
				who = p
				break
		last = Time.get_ticks_usec()   # the bots' thinking is not a frame cost a human game has
		if s.stage == Series.STAGE_GAME and (s.game.turn != last_turn or s.game_no != last_game):
			# A new turn: let the queued animations finish, then sample the node counts.
			var guard := 0
			while not _drained() and guard < 900:
				guard += 1
				await process_frame
			for f in 10:
				await process_frame
			last_turn = s.game.turn
			last_game = s.game_no
			samples.append([sent, last_turn, last_game, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
			last = Time.get_ticks_usec()
		if cmd.is_empty():
			idle += 1
			if idle > 600:
				print("QA PERF FAIL stalled at stage %s" % s.stage)
				quit(1)
				return
		else:
			idle = 0
			if s.stage == Series.STAGE_GAME and s.game.turn > 120:
				cmd = {"t": "concede"}
			var h0 := Time.get_ticks_usec()
			host.handle(who, cmd)
			handle_ms.append((Time.get_ticks_usec() - h0) / 1000.0)
			sent += 1
			if recorder != null:
				recorder.cmd_flag = true
		for f in pace:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
	_report(sent)


func _report(sent: int) -> void:
	frames.sort()
	var n := frames.size()
	var avg := 0.0
	for f in frames:
		avg += f
	avg /= maxf(n, 1)
	var p99: float = frames[int(n * 0.99)] if n > 0 else 0.0
	print("PERF frames=%d avg=%.2fms (%.0f fps) p95=%.2fms p99=%.2fms max=%.2fms commands=%d games=%d stage=%s" % [
		n, avg, 1000.0 / maxf(avg, 0.001), frames[int(n * 0.95)] if n > 0 else 0.0, p99, frames[n - 1] if n > 0 else 0.0,
		sent, host.series.game_no, host.series.stage])
	handle_ms.sort()
	if not handle_ms.is_empty():
		print("HANDLE per command: p50=%.1fms p95=%.1fms max=%.1fms" % [handle_ms[handle_ms.size() / 2],
			handle_ms[int(handle_ms.size() * 0.95)], handle_ms[-1]])
	if recorder != null:
		recorder.report()
	for s in samples:
		print("NODES cmd=%d turn=%d game=%d nodes=%d orphans=%d" % s)
	# Leak check: compare the first and last thirds of the samples taken at drained turn starts.
	var fail := ""
	if samples.size() >= 9:
		var k := samples.size() / 3
		var early := 0
		var late := 0
		for i in k:
			early = maxi(early, int(samples[i][3]))
			late = maxi(late, int(samples[samples.size() - 1 - i][3]))
		print("NODES early-max=%d late-max=%d growth=%d" % [early, late, late - early])
		if late - early > NODE_GROWTH_LIMIT:
			fail = "node count grew by %d" % (late - early)
	if not samples.is_empty() and int(samples[-1][4]) > ORPHAN_LIMIT:
		fail = "%d orphan nodes" % int(samples[-1][4])
	if p99 > P99_LIMIT_MS:
		fail = "p99 frame %.1f ms" % p99
	if fail == "":
		print("QA PERF OK")
		quit(0)
	else:
		print("QA PERF FAIL " + fail)
		quit(1)
