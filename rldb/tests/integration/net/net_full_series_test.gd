extends GdUnitTestSuite
## Two network clients play a complete best-of-3 series over real ENet sockets,
## choosing every command only from their own redacted views (no access to the
## authority's state). Includes a forced disconnect/reconnect in the middle of a game.

const PORT := 24721
const TURN_CAP := 150

var host: NetSession
var client: NetSession
var roots: Array = []
var rng := RandomNumberGenerator.new()
var views := [0, 0]
var errors := [[], []]


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	var hroot := Node.new()
	hroot.name = "FH"
	add_child(hroot)
	var croot := Node.new()
	croot.name = "FC"
	add_child(croot)
	roots = [hroot, croot]
	host = NetSession.new()
	hroot.add_child(host)
	client = NetSession.new()
	croot.add_child(client)
	views = [0, 0]
	errors = [[], []]
	host.local_seat.view_changed.connect(func(_v): views[0] += 1)
	client.local_seat.view_changed.connect(func(_v): views[1] += 1)
	host.local_seat.status_changed.connect(func(t): errors[0].append(t))
	client.local_seat.status_changed.connect(func(t): errors[1].append(t))


func after_test() -> void:
	for n in roots:
		n.queue_free()
	roots = []
	for i in 5:
		await get_tree().process_frame


func _seat(p: int) -> SeatClient:
	return host.local_seat if p == 0 else client.local_seat


## Picks a command for seat p from its own view, or {} if it has nothing to do.
func _decide(p: int) -> Dictionary:
	var v: Dictionary = _seat(p).last_view
	if v.is_empty() or v.get("net", {}).get("paused", false):
		return {}
	match v["stage"]:
		"decks":
			if v["deck_ready"][p]:
				return {}
			if v.has("draft"):
				var dv: Dictionary = v["draft"]
				# 2026-10-18 draft: sometimes switch category or change the basic unit, through the network.
				var roll := rng.randi_range(0, 4)
				if roll == 0:
					var bt: Array = dv["basic_types"]
					var br: Array = dv["basic_races"]
					return {"t": "draft_basic", "basic_type": bt[rng.randi_range(0, bt.size() - 1)], "basic_race": br[rng.randi_range(0, br.size() - 1)]}
				if roll == 1:
					var open: Array = dv["categories"].filter(func(c): return int(dv["left"].get(c, 0)) > 0 and c != dv["category"])
					if not open.is_empty():
						return {"t": "draft_category", "category": open[rng.randi_range(0, open.size() - 1)]}
				if bool(dv.get("complete", false)):
					return {"t": "draft_confirm"}   # J30: every card drafted, lock the deck in
				return {"t": "draft_pick", "index": rng.randi_range(0, dv["offer"].size() - 1)}
			return {"t": "pick_starter", "index": rng.randi_range(0, v["starters"].size() - 1)}
		"rewards":
			var r: Dictionary = v["rewards"]
			if r["done"]:
				return {}
			if r.get("pending", false):
				return {"t": "reward_add", "index": rng.randi_range(0, r["offer"].size() - 1)}
			match rng.randi_range(0, 3):
				0: return {"t": "reward_type", "category": r["types"][rng.randi_range(0, r["types"].size() - 1)]}
				1: return {"t": "reward_remove", "card_id": v["deck"][rng.randi_range(0, v["deck"].size() - 1)]["id"]}
				2:
					for c in v["deck"]:
						if c["category"] == "basic_unit":
							var types: Array = r["basic_types"].filter(func(t): return t != c["type"])
							return {"t": "reward_basic", "to_type": types[rng.randi_range(0, types.size() - 1)], "to_race": c["race"]}
			return {"t": "reward_type", "category": r["types"][0]}
		"first_player":
			# G05: the loser chooses, then each seat starts the next duel.
			if v["last_loser"] == p and not v["next"]["first_chosen"]:
				return {"t": "first_player", "who": rng.randi_range(0, 1)}
			return {"t": "start_duel"} if not v["next"]["you_ready"] else {}
		"game":
			var mv: Dictionary = v["match"]
			if mv["winner"] != -1:
				return {}
			var pd: Dictionary = mv["pending"]
			if not pd.is_empty():
				if not pd["mine"]:
					return {}
				var n: int = pd["options"].size()
				var idx := range(n)
				idx.shuffle()
				var want := clampi(rng.randi_range(pd["min"], pd["max"]), 0, n)
				if pd.get("min_total", 0) > 0:
					want = n
				return {"t": "choose", "id": pd["id"], "indices": idx.slice(0, want)}
			if mv["active"] != p or mv["resolving"]:
				return {}
			if mv["turn"] > TURN_CAP:
				# Random bots can exhaust both decks into a stalemate (no fatigue rule exists).
				return {"t": "concede"}
			var legal: Array = mv["actions"].filter(func(a): return a["ok"])
			if legal.is_empty():
				return {}
			if rng.randf() < 0.3:
				return legal[0]   # next_phase keeps games moving
			var a: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
			var cmd := {"t": a["t"]}
			if a.has("uid"):
				cmd["uid"] = a["uid"]
			if a.has("idx"):
				cmd["idx"] = a["idx"]
			return cmd
	return {}


func test_two_clients_complete_a_best_of_three_series_with_a_reconnect(timeout := 600000) -> void:
	await _play_series(2024, 31, 3)


func test_two_clients_complete_a_best_of_five_draft_series_with_a_reconnect(timeout := 600000) -> void:
	await _play_series(77, 5, 5, "draft")


func _play_series(bot_seed: int, series_seed: int, best_of: int, deck_mode: String = "starter") -> void:
	rng.seed = bot_seed
	assert_str(host.host_enet(PORT, {"seed": series_seed, "best_of": best_of, "deck_mode": deck_mode})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	for i in 600:
		if host.remote_peer != 0 and not client.local_seat.last_view.is_empty():
			break
		await get_tree().process_frame
	var commands := 0
	var dropped := false
	var idle := 0
	var cancels := 0
	while host.series.stage != Series.STAGE_OVER and commands < 20000:
		var acted := false
		for p in 2:
			var cmd := _decide(p)
			if cmd.is_empty():
				continue
			var before: int = views[p] + errors[p].size()
			_seat(p).send(cmd)
			commands += 1
			acted = true
			# Wait for the authority's answer (a new view or an error) before acting again.
			for f in 300:
				if views[p] + errors[p].size() > before:
					break
				await get_tree().process_frame
			if errors[p].size() > 0 and cmd["t"] == "choose":
				# A random multi-select can be invalid (e.g. material totals); cancel or pick all.
				var pd: Dictionary = _seat(p).last_view.get("match", {}).get("pending", {})
				if pd.get("cancellable", false):
					_seat(p).send({"t": "cancel", "id": pd["id"]})
					cancels += 1
			errors[p].clear()
		# Mid-series network drop during a live game.
		if not dropped and commands > 150 and host.series.stage == Series.STAGE_GAME:
			dropped = true
			client.simulate_drop()
			for f in 900:
				if not host.paused and host.remote_peer != 0 and client.local_seat.last_view.get("net", {}).get("opponent_connected", true):
					break
				await get_tree().process_frame
			assert_bool(host.paused).is_false()
		if (commands + idle) % 2000 == 0 and (commands + idle) > 0:
			var hv: Dictionary = host.local_seat.last_view
			print("progress cmds=%d idle=%d stage=%s game=%d pend=%s act=%s" % [commands, idle, host.series.stage, host.series.game_no,
				str(host.series.game.pending.get("kind", "")) if host.series.game != null else "-",
				str(host.series.game.active) if host.series.game != null else "-"])
			if host.series.game != null:
				var gm: MatchEngine = host.series.game
				print("   turn=%d hp=%s units=%d/%d draw=%d/%d spent=%d/%d exh=%d/%d" % [gm.turn, str([gm.players[0]["hp"], gm.players[1]["hp"]]),
					gm.field_units(0).size(), gm.field_units(1).size(), gm.players[0]["draw"].size(), gm.players[1]["draw"].size(),
					gm.players[0]["spent"].size(), gm.players[1]["spent"].size(), gm.players[0]["exhaust"].size(), gm.players[1]["exhaust"].size()])
		if not acted:
			idle += 1
			await get_tree().process_frame
			if idle > 2000:
				break
		else:
			idle = 0
	print("full series: commands=%d games=%d scores=%s history=%s" % [commands, host.series.game_no, str(host.series.scores), str(host.series.history)])
	assert_bool(dropped).is_true()
	assert_str(host.series.stage).is_equal(Series.STAGE_OVER)
	assert_int(maxi(host.series.scores[0], host.series.scores[1])).is_equal(best_of / 2 + 1)
	# Every game ended by HP reaching zero, or by the bots' turn cap.
	for h in host.series.history:
		assert_bool(mini(h["hp"][0], h["hp"][1]) == 0 or h["turns"] > TURN_CAP).is_true()
	# The client's final view agrees with the authority.
	for f in 120:
		if client.local_seat.last_view.get("stage", "") == "over":
			break
		await get_tree().process_frame
	var cv: Dictionary = client.local_seat.last_view
	assert_str(cv["stage"]).is_equal("over")
	assert_array(cv["scores"]).is_equal(host.series.scores)
