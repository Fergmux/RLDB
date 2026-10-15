extends Node
## Development-only check of "Play vs Bot". Launched with
##   godot --path rldb -- --bot-shots=<absolute dir>
## Starts a bot series from the real menu path, plays the human seat with simple moves (summon
## the first unit it can, attack when an attack is offered, pass Trap prompts, end the phase),
## and records when each bot command lands. Asserts the bot acts, never sends a refused command
## and leaves a human-readable gap between its moves; writes screenshots and bot_report.json.

var main: Node
var out_dir: String
var host: LocalHost
var checks: Array = []
var bot_times: Array = []      # msec of each accepted bot command
var bot_errors: Array = []
var bot_cmds: Array = []


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	await _frames(5)
	main._start_bot({"seed": 5150, "best_of": 1, "deck_mode": "starter"})
	await _frames(6)
	host = main.local_host
	host.error.connect(func(s, t): if s == 1: bot_errors.append(t))
	for n in host.get_children():
		if n is BotPlayer:
			(n as BotPlayer).moved.connect(func(c): bot_times.append(Time.get_ticks_msec()); bot_cmds.append(String(c.get("t", ""))))
	await _shot("00_deck_select")
	host.handle(0, {"t": "pick_starter", "index": 0})
	var t_end := Time.get_ticks_msec() + 70000
	var shots := 0
	var last_shot := 0
	while Time.get_ticks_msec() < t_end and host.series.stage in [Series.STAGE_GAME, Series.STAGE_DECKS]:
		await _frames(1)
		if host.series.stage != Series.STAGE_GAME:
			continue
		var m := host.series.game
		if m.winner != -1:
			break
		if m.active == 1 and Time.get_ticks_msec() - last_shot > 2500 and shots < 8:
			shots += 1
			last_shot = Time.get_ticks_msec()
			await _shot("bot_turn_%02d" % shots)
		_human_move(m)
	await _wait(1.0)
	await _shot("99_end")
	var gaps := []
	for i in range(1, bot_times.size()):
		gaps.append(bot_times[i] - bot_times[i - 1])
	gaps.sort()
	_check("bot made moves", bot_times.size() >= 8, "%d moves: %s" % [bot_times.size(), str(bot_cmds)])
	_check("bot never sent a refused command", bot_errors.is_empty(), str(bot_errors))
	_check("bot moves are spaced for a human to follow (min gap >= 700 ms)", not gaps.is_empty() and int(gaps[0]) >= 700, "min %s ms, median %s ms" % [gaps[0] if not gaps.is_empty() else -1, gaps[gaps.size() / 2] if not gaps.is_empty() else -1])
	var log := host.series.game.log_entries.map(func(e): return String(e["pub"])).filter(func(t): return t.begins_with("Bot "))
	_check("bot summoned or played cards", log.any(func(t): return t.contains("summons") or t.contains("casts") or t.contains("sets") or t.contains("plays")), str(log.slice(0, 8)))
	_finish()


var _human_next := 0


## Plain human play: answer prompts with the first option (Pass on Traps), summon one unit,
## attack with each ready unit, otherwise move to the next phase. One action every 0.4 s.
func _human_move(m: MatchEngine) -> void:
	if Time.get_ticks_msec() < _human_next:
		return
	var acting := -1
	if not m.pending.is_empty():
		acting = int(m.pending["player"])
	elif m.stack.is_empty():
		acting = m.active
	if acting != 0:
		return
	_human_next = Time.get_ticks_msec() + 400
	if not m.pending.is_empty():
		var k: int = clampi(int(m.pending["min"]), 1, m.pending["options"].size())
		host.handle(0, {"t": "choose", "id": m.pending["id"], "indices": range(k)})
		return
	for a in MatchView.actions_for(m, 0):
		if a["ok"] and a["t"] in ["summon", "attack"]:
			var cmd := {"t": a["t"], "uid": a["uid"]}
			if a.has("stance"):
				cmd["stance"] = a["stance"]
			host.handle(0, cmd)
			return
	host.handle(0, {"t": "next_phase"})


func _check(name: String, ok: bool, detail: String = "") -> void:
	checks.append({"check": name, "ok": ok, "detail": detail})
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])


func _finish() -> void:
	var passed := checks.filter(func(c): return c["ok"]).size()
	var f := FileAccess.open(out_dir.path_join("bot_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed": passed, "failed": checks.size() - passed, "checks": checks}, "  "))
	f.close()
	print("BOT DRIVER DONE: %d passed, %d failed" % [passed, checks.size() - passed])
	get_tree().quit()


func _shot(name: String) -> void:
	await _frames(2)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout
