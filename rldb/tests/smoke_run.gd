extends SceneTree
## Headless smoke: plays random legal moves for many turns to shake out runtime errors.
## Run: godot --headless --path rldb -s res://tests/smoke_run.gd

func _init():
	var games := 0
	var total_cmds := 0
	for seed_value in range(1, 31):
		var m := MatchEngine.new()
		var all_ids := []
		for d in CardDB.all():
			if CardScripts.is_implemented(d["id"]):
				all_ids.append(d["id"])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var decks := [[], []]
		for p in 2:
			for i in 30:
				decks[p].append(all_ids[rng.randi_range(0, all_ids.size() - 1)])
		m.setup(decks, seed_value % 2, seed_value)
		var steps := 0
		while m.winner == -1 and steps < 3000:
			steps += 1
			var p: int = m.pending["player"] if not m.pending.is_empty() else m.active
			var v := MatchView.build(m, p)
			var err := ""
			if not v["pending"].is_empty():
				var pd: Dictionary = v["pending"]
				var n: int = pd["options"].size()
				var picks := []
				var want: int = clampi(rng.randi_range(pd["min"], pd["max"]), 0, n)
				var idx := range(n)
				idx.shuffle()
				picks = idx.slice(0, want)
				err = m.submit(p, {"t": "choose", "id": pd["id"], "indices": picks})
				if err != "" and pd["cancellable"]:
					err = m.submit(p, {"t": "cancel", "id": pd["id"]})
				if err != "" and pd.get("min_total", 0) > 0:
					err = m.submit(p, {"t": "choose", "id": pd["id"], "indices": range(n)})
				if err != "":
					printerr("seed %d choice error: %s %s" % [seed_value, err, pd])
					break
			else:
				var legal: Array = v["actions"].filter(func(a): return a["ok"])
				var a: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
				if rng.randf() < 0.25:
					a = legal[0]
				err = m.submit(p, a)
				if err != "":
					printerr("seed %d action error: %s %s" % [seed_value, err, a])
					break
			total_cmds += 1
		games += 1
		print("seed %d: turns=%d winner=%d steps=%d log=%d" % [seed_value, m.turn, m.winner, steps, m.log_entries.size()])
	print("SMOKE DONE games=%d commands=%d" % [games, total_cmds])
	quit()
