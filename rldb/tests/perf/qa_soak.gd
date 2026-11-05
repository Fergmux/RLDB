extends SceneTree
## L batch final QA soak (headless, not a unit test): full bot-vs-bot best-of-3 series with "spiced"
## custom decks built around the L-batch systems (Symbiote Evolve, Hypnotise, Sneaky Snunday,
## Shapeshifter Loak / Mimic, Fusion Ceremony, Cleanse / Curse and the status cards), checking
## engine invariants after EVERY command:
##   - zone integrity: every card is in exactly one place and its zone / slot / controller agree;
##   - Evolve: a card's id only ever changes along its Evolve chain; an Evolve prompt only goes to
##     the active player about a unit they control; every game of a series starts with base cards;
##   - hidden information: no seat's view (or a spectator's) carries the uid of a card that seat has
##     never been allowed to see; no presentation event of the new kinds names a hidden card;
##   - views build for both seats and a spectator; the game ends (no stall, no refused command).
##
##   godot --headless --path rldb -s res://tests/perf/qa_soak.gd -- [--series=N] [--seed=S] [--verbose]
##
## Prints "SOAK OK" or "SOAK FAIL" with the first violations, and exits 0 / 1.

const TURN_LIMIT := 120
const STEP_LIMIT := 30000

## Main-deck spice: three Spawns, Hypnotise, Snunday, Loak, the status / Cleanse / Curse cards.
const SPICE_MAIN := [155, 155, 155, 180, 154, 154, 19, 36, 78, 102, 164, 81, 182, 82, 76, 32, 86, 69, 71, 14]
## Extra-deck spice: status Fusions, Mimic, a Curse Ritual, Typhoon Simorgh, Ultimate Dragon.
const SPICE_EXTRA := [60, 145, 95, 62, 143, 151, 61]
const EVOLUTION_ONLY := [156, 157]

var opts := {"series": 6, "seed": 1, "verbose": false}
var violations: Array = []
var stats := {"series": 0, "games": 0, "commands": 0, "evolves": 0, "evolve_prompts": 0, "hypnotise": 0,
	"snunday": 0, "copy_form": 0, "status_fx": 0, "to_hand": 0, "miss": 0, "refused": 0}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() == 2 else true
	_run.call_deferred()


func _run() -> void:
	CardDB.ensure_loaded()
	SeriesStore.DIR = "user://test_saves"
	var t0 := Time.get_ticks_msec()
	for i in int(opts["series"]):
		_series(int(opts["seed"]) * 1009 + i)
		if violations.size() > 40:
			break
	print("SOAK stats %s in %.1f s" % [JSON.stringify(stats), (Time.get_ticks_msec() - t0) / 1000.0])
	if violations.is_empty():
		print("SOAK OK")
		quit(0)
	else:
		print("SOAK FAIL %d violation(s):" % violations.size())
		for v in violations.slice(0, 40):
			print("  - " + str(v))
		quit(1)


## A spiced custom deck: 4 copies of a basic unit, the spice, 6 random offerable cards, the extra spice.
static func spice_deck(rng: RandomNumberGenerator) -> Array:
	var basics := []
	var pool := []
	for d in CardDB.all():
		if d["category"] == "basic_unit":
			basics.append(int(d["id"]))
		elif d["category"] in ["unit", "spell", "trap", "power"] and Series.is_offerable(int(d["id"])):
			pool.append(int(d["id"]))
	var b: int = basics[rng.randi_range(0, basics.size() - 1)]
	var deck := [b, b, b, b]
	deck.append_array(SPICE_MAIN)
	for i in 6:
		deck.append(pool[rng.randi_range(0, pool.size() - 1)])
	deck.append_array(SPICE_EXTRA)
	return deck


func _series(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s := Series.new()
	s.setup({"seed": seed_value, "best_of": 3, "deck_mode": "starter"})
	for p in 2:
		var e := s.submit(p, {"t": "custom_deck", "name": "spice", "cards": spice_deck(rng)})
		if e != "":
			_fail("series %d: custom deck refused: %s" % [seed_value, e])
			return
	var bots := [BotBrain.new(0, seed_value * 2 + 1), BotBrain.new(1, seed_value * 2 + 2)]
	stats["series"] += 1
	var steps := 0
	var game_seen: MatchEngine = null
	var ctx := {}
	while s.stage != Series.STAGE_OVER and steps < STEP_LIMIT:
		steps += 1
		if s.stage == Series.STAGE_GAME and s.game != game_seen:
			game_seen = s.game
			stats["games"] += 1
			ctx = _new_game_ctx(s.game, seed_value)
		var acted := false
		for p in 2:
			var cmd: Dictionary = bots[p].series_command(s) if s.stage != Series.STAGE_GAME else bots[p].decide(s.game)
			if cmd.is_empty():
				continue
			if s.stage == Series.STAGE_GAME and s.game.turn > TURN_LIMIT:
				cmd = {"t": "concede"}
			var in_game := s.stage == Series.STAGE_GAME
			var err := s.submit(p, cmd)
			stats["commands"] += 1
			if err != "":
				stats["refused"] += 1
				_fail("series %d game %d: seat %d %s refused: %s" % [seed_value, s.game_no, p, cmd, err])
				return
			if in_game:
				_check(ctx, s.game, "series %d game %d turn %d after %s" % [seed_value, s.game_no, s.game.turn, cmd.get("t", "?")])
			acted = true
			break
		if not acted:
			_fail("series %d: stalled at stage %s (game %d, turn %d, pending %s)" % [seed_value, s.stage, s.game_no,
				s.game.turn if s.game != null else -1, str(s.game.pending.get("kind", "")) if s.game != null else ""])
			return
	if s.stage != Series.STAGE_OVER:
		_fail("series %d: step limit" % seed_value)
	if opts["verbose"]:
		print("series %d: %d games, history %s" % [seed_value, s.history.size(), str(s.history)])


func _new_game_ctx(m: MatchEngine, seed_value: int) -> Dictionary:
	var ids := {}
	for u in m.cards:
		ids[u] = int(m.cards[u]["id"])
		if int(m.cards[u]["id"]) in EVOLUTION_ONLY:
			_fail("series %d: game starts with an evolved form (uid %d id %d)" % [seed_value, u, int(m.cards[u]["id"])])
	var seen := [{}, {}, {}]
	return {"ids": ids, "seen": seen, "log_n": 0}


func _fail(msg: String) -> void:
	violations.append(msg)
	if opts["verbose"]:
		print("VIOLATION " + msg)


func _check(ctx: Dictionary, m: MatchEngine, where: String) -> void:
	_check_zones(m, where)
	# Evolve: ids change only along the chain.
	for u in m.cards:
		var was: int = int(ctx["ids"].get(u, -1))
		var now: int = int(m.cards[u]["id"])
		if was != now:
			if CardDB.evolves_into(was) != now:
				_fail("%s: uid %d changed id %d -> %d (not its Evolve)" % [where, u, was, now])
			ctx["ids"][u] = now
	var pd: Dictionary = m.pending
	if not pd.is_empty() and String(pd["kind"]) == "evolve":
		stats["evolve_prompts"] += 1
		var src := int(pd.get("source", -1))
		if int(pd["player"]) != m.active or not m.cards.has(src) or int(m.cards[src]["ctl"]) != int(pd["player"]):
			_fail("%s: Evolve prompt for a unit the asked player does not control" % where)
	# Visibility bookkeeping: a card counts as seen by a seat once that seat could see it.
	for v in 3:
		var viewer := v if v < 2 else -1
		for u in m.cards:
			if viewer == -1:
				if m.is_public_card(u):
					ctx["seen"][v][u] = true
			elif MatchView.can_see(m, u, viewer):
				ctx["seen"][v][u] = true
	# Views: build them and look for uids of never-seen cards.
	for v in 3:
		var view: Dictionary = MatchView.build(m, v) if v < 2 else MatchView.build_spectator(m, 0, -1)
		var hits := []
		_scan_uids(view, ctx["seen"][v], m, hits)
		if not hits.is_empty():
			_fail("%s: view for %s carries never-seen uid(s) %s" % [where, "seat %d" % v if v < 2 else "spectator", str(hits.slice(0, 5))])
	# New presentation events of the L batch.
	var entries: Array = m.log_entries
	for i in range(int(ctx["log_n"]), entries.size()):
		var fxs: Array = entries[i].get("fx", [])
		var done: int = int(ctx.get("fx_done", {}).get(i, 0))
		if not ctx.has("fx_done"):
			ctx["fx_done"] = {}
		ctx["fx_done"][i] = fxs.size()
		for e in fxs.slice(done):
			var k := String(e.get("k", ""))
			match k:
				"evolve": stats["evolves"] += 1
				"copy_form": stats["copy_form"] += 1
				"status", "status_tick", "status_expire", "status_blocked": stats["status_fx"] += 1
				"to_hand": stats["to_hand"] += 1
				"miss": stats["miss"] += 1
				"control":
					if not bool(e.get("back", false)):
						stats["hypnotise"] += 1
	ctx["log_n"] = maxi(entries.size() - 1, 0)   # the last entry can still gain events
	if m.reversal_active():
		stats["snunday"] += 1
	for p in 2:
		for u in m.field_units(p):
			if int(m.cards[u]["id"]) in [155, 156]:
				stats["symbiote_checks"] = int(stats.get("symbiote_checks", 0)) + 1


func _scan_uids(x, seen: Dictionary, m: MatchEngine, hits: Array) -> void:
	if x is Dictionary:
		for k in x:
			if String(k) in ["uid", "source_uid", "placing_uid", "toast_uid"] and (x[k] is int or x[k] is float):
				var u := int(x[k])
				if u >= 0 and m.cards.has(u) and not seen.has(u):
					hits.append("%s=%d (%s, %s)" % [k, u, m.name_of(u), String(m.cards[u]["zone"])])
			else:
				_scan_uids(x[k], seen, m, hits)
	elif x is Array:
		for y in x:
			_scan_uids(y, seen, m, hits)


func _check_zones(m: MatchEngine, where: String) -> void:
	var where_is := {}
	for p in 2:
		var pl: Dictionary = m.players[p]
		for z in ["hand", "draw", "spent", "exhaust", "extra"]:
			for u in pl[z]:
				if where_is.has(u):
					_fail("%s: uid %d in two places (%s and %s %d)" % [where, u, where_is[u], z, p])
				where_is[u] = "%s %d" % [z, p]
				if String(m.cards[u]["zone"]) != z or int(m.cards[u]["owner"]) != p:
					_fail("%s: uid %d listed in %s of %d but zone %s owner %d" % [where, u, z, p, m.cards[u]["zone"], m.cards[u]["owner"]])
		for pair in [["units", "unit"], ["backrow", "backrow"], ["powers", "power"]]:
			var arr: Array = pl[pair[0]]
			for slot in arr.size():
				var u: int = arr[slot]
				if u == -1:
					continue
				if where_is.has(u):
					_fail("%s: uid %d in two places (%s and %s %d)" % [where, u, where_is[u], pair[1], p])
				where_is[u] = "%s %d" % [pair[1], p]
				var inst: Dictionary = m.cards[u]
				if String(inst["zone"]) != pair[1] or int(inst["slot"]) != slot or int(inst["ctl"]) != p:
					_fail("%s: uid %d in %s[%d] of %d but zone %s slot %d ctl %d" % [where, u, pair[0], slot, p, inst["zone"], inst["slot"], inst["ctl"]])
	for u in m.cards:
		var z := String(m.cards[u]["zone"])
		if z == "limbo":
			continue
		if not where_is.has(u):
			_fail("%s: uid %d (zone %s) is in no list" % [where, u, z])
		if z != "unit" and m.cards[u].get("art_o") != null and m.art_id(u) != int(m.cards[u]["id"]):
			_fail("%s: uid %d shows copied art off the Field" % [where, u])
