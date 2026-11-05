extends SceneTree
## L27 bot arena (headless, not a unit test): plays the current BotBrain against the frozen
## pre-L27 brain (tests/perf/bot_baseline/) over many seeded games with varied decks, and reports
## the win rate (overall, as first player and as second player), the mean game length and the
## decision time of each brain.
##
##   godot --headless --path rldb -s res://tests/perf/bot_arena.gd -- [options]
##
## Options (all optional):
##   --pairs=N        deck pairings to play (each pairing is 4 games: both seats x both decks)
##   --seed=S         base seed (the whole run is deterministic for a seed)
##   --a=new|old      brain A (default new)   --b=new|old   brain B (default old)
##   --draft=F        share of decks that are random drafts instead of Structure decks (0..1)
##   --series=N       also play N full bot-vs-bot best-of-3 series (starter + draft) as a smoke run
##   --out=PATH       write the JSON report there
##   --verbose        one line per game
##   --log=K          print the full public log of game K (0-based, in play order)
##   --tune=K=V,K=V   override BotBrain tuning weights (BotBrain.tune) for this run
##
## Fairness: brain A and brain B each see the same MatchEngine; the current BotBrain redacts it
## to its own seat's information before thinking (it never reads hidden cards). The frozen brain
## is left as it was, so it is if anything stronger than a fair player.

const OldBrain = preload("res://tests/perf/bot_baseline/old_bot_brain.gd")

const TURN_LIMIT := 150
const STEP_LIMIT := 6000

var opts := {"pairs": 30, "seed": 1, "a": "new", "b": "old", "draft": 0.25, "series": 0, "out": "", "verbose": false, "log": -1}
var _game_index := 0
var times := {"a": [], "b": []}
var report := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
		else:
			opts[kv[0]] = true
	_run.call_deferred()


func _brain(kind: String, seat: int, seed_value: int):
	return BotBrain.new(seat, seed_value) if kind == "new" else OldBrain.new(seat, seed_value)


func _run() -> void:
	CardDB.ensure_loaded()
	if String(opts.get("tune", "")) != "":
		var d := {}
		for pair in String(opts["tune"]).split(","):
			var kv2 := pair.split("=")
			d[kv2[0]] = float(kv2[1])
		var bad := BotBrain.tune(d)
		print("TUNE %s%s" % [d, "  unknown: %s" % [bad] if not bad.is_empty() else ""])
	var base_seed := int(opts["seed"])
	var pairs := int(opts["pairs"])
	var draft_share := float(opts["draft"])
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed
	var starters := Series.load_starters()
	var res := {"games": 0, "a_wins": 0, "a_first_games": 0, "a_first_wins": 0, "a_second_games": 0, "a_second_wins": 0,
		"turns": 0, "stalls": 0, "refusals": 0, "timeouts": 0, "draws": 0}
	var refusal_samples := []
	var t0 := Time.get_ticks_msec()
	for pi in pairs:
		var decks := []
		var names := []
		for k in 2:
			if rng.randf() < draft_share:
				decks.append(_random_draft(rng))
				names.append("draft")
			else:
				var s: Dictionary = starters[rng.randi_range(0, starters.size() - 1)]
				decks.append(s["main"] + s["extra"])
				names.append(String(s["name"]))
		for g in 4:
			var a_seat := g % 2                       # A plays seat 0 in games 0 and 2
			var swap := g >= 2                          # decks swap in games 2 and 3
			var dk := [decks[1], decks[0]] if swap else [decks[0], decks[1]]
			var first := (g / 2 + pi) % 2               # who starts alternates per pairing
			var game_seed := base_seed * 100003 + pi * 17 + g
			var out := _play(dk, first, game_seed, a_seat)
			res["games"] += 1
			res["turns"] += int(out["turns"])
			res["refusals"] += int(out["refusals"])
			if refusal_samples.size() < 10:
				refusal_samples.append_array(out["refusal_samples"].slice(0, 10 - refusal_samples.size()))
			if out["winner"] == -1:
				res["draws"] += 1
				if out["stall"]:
					res["stalls"] += 1
				else:
					res["timeouts"] += 1
			var a_first := first == a_seat
			res["a_first_games" if a_first else "a_second_games"] += 1
			if out["winner"] == a_seat:
				res["a_wins"] += 1
				res["a_first_wins" if a_first else "a_second_wins"] += 1
			if opts["verbose"]:
				print("pair %d game %d: decks %s/%s A=seat %d first=%d -> winner %d (A %s) turns %d hp %s%s" % [
					pi, g, names[1] if swap else names[0], names[0] if swap else names[1], a_seat, first, out["winner"],
					"won" if out["winner"] == a_seat else "lost", out["turns"], out["hp"], " STALL" if out["stall"] else ""])
	res["elapsed_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	res["a"] = opts["a"]
	res["b"] = opts["b"]
	res["a_win_rate"] = _rate(res["a_wins"], res["games"])
	res["a_win_rate_first"] = _rate(res["a_first_wins"], res["a_first_games"])
	res["a_win_rate_second"] = _rate(res["a_second_wins"], res["a_second_games"])
	res["mean_turns"] = float(res["turns"]) / maxf(1.0, float(res["games"]))
	res["a_ms"] = _stats(times["a"])
	res["b_ms"] = _stats(times["b"])
	res["refusal_samples"] = refusal_samples
	print("ARENA %s vs %s%s: %d games, A wins %.1f%% (first %.1f%%, second %.1f%%), mean %.1f turns, draws %d (stalls %d), refusals %d" % [
		res["a"], res["b"], " [%s]" % opts["tune"] if opts.has("tune") else "", res["games"], 100.0 * res["a_win_rate"], 100.0 * res["a_win_rate_first"], 100.0 * res["a_win_rate_second"],
		res["mean_turns"], res["draws"], res["stalls"], res["refusals"]])
	print("  decision ms  A: %s" % JSON.stringify(res["a_ms"]))
	print("  decision ms  B: %s" % JSON.stringify(res["b_ms"]))
	if not refusal_samples.is_empty():
		print("  refusals: %s" % str(refusal_samples))
	if int(opts["series"]) > 0:
		res["series"] = _series_smoke(int(opts["series"]), base_seed)
	report = res
	if String(opts["out"]) != "":
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  "))
		f.close()
	print("ARENA DONE in %.1f s" % res["elapsed_s"])
	quit(0)


func _rate(w: int, n: int) -> float:
	return float(w) / float(n) if n > 0 else 0.0


func _stats(arr: Array) -> Dictionary:
	if arr.is_empty():
		return {}
	var s := arr.duplicate()
	s.sort()
	var tot := 0.0
	for v in s:
		tot += float(v)
	return {"n": s.size(), "mean": snappedf(tot / s.size(), 0.01), "p50": snappedf(float(s[s.size() / 2]), 0.01),
		"p95": snappedf(float(s[int(s.size() * 0.95)]), 0.01), "max": snappedf(float(s[-1]), 0.01)}


## A random draft deck (the J26 composition: 3 basic units, 4 Units, 2 Spells, 2 Traps, 1 Power,
## 3 Extra Deck cards), each pick the best-looking of a 3-card offer at random.
func _random_draft(rng: RandomNumberGenerator) -> Array:
	var quota := {"unit": 4, "spell": 2, "trap": 2, "power": 1, "extra": 3}
	var basics := []
	for d in CardDB.all():
		if d["category"] == "basic_unit":
			basics.append(int(d["id"]))
	var basic: int = basics[rng.randi_range(0, basics.size() - 1)]
	var deck := [basic, basic, basic]
	for cat in quota:
		var cats: Array = Series.EXTRA_CATEGORIES if cat == "extra" else [cat]
		var pool := []
		for d in CardDB.all():
			if CardScripts.is_implemented(d["id"]) and d["category"] in cats:
				pool.append(int(d["id"]))
		for i in int(quota[cat]):
			deck.append(pool[rng.randi_range(0, pool.size() - 1)])
	return deck


## One game: brain A on seat a_seat, brain B on the other. Returns winner, turns, hp, stall flag.
func _play(decks: Array, first: int, seed_value: int, a_seat: int) -> Dictionary:
	var m := MatchEngine.new()
	m.setup(decks.duplicate(true), first, seed_value, {"names": ["Seat 0", "Seat 1"], "start_hp": 60, "hidden_response_windows": false, "fatigue_damage": 2})
	var brains := []
	for p in 2:
		var kind: String = opts["a"] if p == a_seat else opts["b"]
		brains.append(_brain(kind, p, seed_value * 2 + p))
	var refusals := 0
	var samples := []
	var stall := false
	var steps := 0
	var per_turn := 0
	var last_turn := -1
	while m.winner == -1 and m.turn <= TURN_LIMIT and steps < STEP_LIMIT:
		steps += 1
		var who := m.active
		if not m.pending.is_empty():
			who = int(m.pending["player"])
		if m.turn != last_turn:
			last_turn = m.turn
			per_turn = 0
		per_turn += 1
		var t := Time.get_ticks_usec()
		var cmd: Dictionary = brains[who].decide(m)
		times["a" if who == a_seat else "b"].append((Time.get_ticks_usec() - t) / 1000.0)
		if cmd.is_empty():
			stall = true
			break
		if per_turn > 80 and m.pending.is_empty():
			cmd = {"t": "next_phase"}      # the BotPlayer's per-turn safety valve
		var err := m.submit(who, cmd)
		if err != "":
			refusals += 1
			if samples.size() < 5:
				samples.append("%s seat %d %s -> %s" % [opts["a"] if who == a_seat else opts["b"], who, cmd, err])
			_recover(m, who)
	if int(opts["log"]) == _game_index:
		for e in m.log_entries:
			print("  | " + String(e["pub"]))
	_game_index += 1
	return {"winner": m.winner, "turns": m.turn, "hp": [m.players[0]["hp"], m.players[1]["hp"]], "stall": stall,
		"refusals": refusals, "refusal_samples": samples}


func _recover(m: MatchEngine, who: int) -> void:
	if not m.pending.is_empty() and int(m.pending["player"]) == who:
		if m.pending["cancellable"] and m.submit(who, {"t": "cancel", "id": m.pending["id"]}) == "":
			return
		var k: int = clampi(int(m.pending["min"]), 1, maxi(1, m.pending["options"].size()))
		m.submit(who, {"t": "choose", "id": m.pending["id"], "indices": range(k)})
	elif m.pending.is_empty() and m.active == who:
		m.submit(who, {"t": "next_phase"})


## Full best-of-3 series between two current bots (starter and draft decks): every stage is
## answered, nothing stalls, every command is accepted. Returns a summary.
func _series_smoke(n: int, base_seed: int) -> Dictionary:
	var out := {"series": 0, "finished": 0, "refused": 0, "games": 0, "turns": 0, "samples": []}
	for i in n:
		var s := Series.new()
		SeriesStore.DIR = "user://test_saves"
		s.setup({"seed": base_seed * 31 + i, "best_of": 3, "deck_mode": "draft" if i % 2 == 1 else "starter"})
		var bots := [BotBrain.new(0, i * 2 + 1), BotBrain.new(1, i * 2 + 2)]
		var steps := 0
		while s.stage != Series.STAGE_OVER and steps < 20000:
			steps += 1
			var acted := false
			for p in 2:
				var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
				if cmd.is_empty():
					continue
				if s.stage == Series.STAGE_GAME and s.game.turn > TURN_LIMIT:
					cmd = {"t": "concede"}
				var err := s.submit(p, cmd)
				if err != "":
					out["refused"] += 1
					if out["samples"].size() < 5:
						out["samples"].append("%s -> %s" % [cmd, err])
					if s.stage == Series.STAGE_GAME:
						_recover(s.game, p)
				acted = true
				break
			if not acted:
				break
		out["series"] += 1
		out["games"] += s.history.size()
		for h in s.history:
			out["turns"] += int(h["turns"])
		if s.stage == Series.STAGE_OVER:
			out["finished"] += 1
	print("SERIES SMOKE: %d/%d finished, %d games, mean %.1f turns, %d refused %s" % [out["finished"], out["series"], out["games"],
		float(out["turns"]) / maxf(1.0, float(out["games"])), out["refused"], str(out["samples"])])
	return out
