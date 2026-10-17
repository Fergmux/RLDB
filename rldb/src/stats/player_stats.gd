class_name PlayerStats
extends RefCounted
## The player's own statistics, kept on this computer only (user://player_stats.json): finished
## duels, series and draft picks seen from this install's seat(s). Independent of the anonymous
## sharing setting, never uploaded. `facts()` turns the record into the short list the
## Statistics modal shows (Decks > Statistics).
##
## Recording: StatsObserver watches a Series run here (bot, hot-seat, network host) through the
## read-only `stats_observer` hooks, and a network client's views; it calls the record_* functions.

const PLAYER_PATH := "user://player_stats.json"
const TEST_PATH := "user://test_player_stats.json"
const VERSION := 1
## Oldest entries are dropped beyond these (the file stays small).
const MAX_DUELS := 500
const MAX_SERIES := 300
## A card needs this many of your duels before it can be "your best card".
const BEST_CARD_MIN_DUELS := 5

## Automated runs (GdUnit, `-s` scripts, shot drivers) use TEST_PATH, like DeckStore, so they
## never touch the player's own record.
static var PATH := _default_path()

static var _cache: Dictionary = {}


static func _default_path() -> String:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "-s" or args[i] == "--script" or String(args[i]).contains("GdUnitCmdTool"):
			return TEST_PATH
	for a in OS.get_cmdline_user_args():
		if String(a).contains("shots"):
			return TEST_PATH
	return PLAYER_PATH


static func empty() -> Dictionary:
	return {"version": VERSION, "duels": [], "series": [], "draft_picks": {}, "drafts_completed": 0}


## The stored record (loaded once, then cached).
static func load_data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_cache = empty()
	if d is Dictionary:
		for k in _cache:
			if not d.has(k):
				continue
			if _cache[k] is int and (d[k] is int or d[k] is float):
				_cache[k] = int(d[k])   # JSON numbers load as floats
			elif typeof(d[k]) == typeof(_cache[k]):
				_cache[k] = d[k]
	return _cache


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(load_data()))


## Forgets the cached copy (tests, or after the file was replaced).
static func reload() -> void:
	_cache = {}


## Deletes the record (tests only; there is no player-facing reset).
static func clear() -> void:
	_cache = empty()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## One finished duel. `d`: mode (bot | local | lan | steam), won (true / false / null for hot-seat),
## turns, ms, deck (deck name), cards {id: copies} (your starting deck), plays {id: n},
## summons, spells (spells and traps used), damage (dealt), best_hit.
static func record_duel(d: Dictionary) -> void:
	var data := load_data()
	var row := {"t": int(Time.get_unix_time_from_system()), "mode": String(d.get("mode", "local")),
		"won": d.get("won", null), "turns": int(d.get("turns", 0)), "ms": int(d.get("ms", 0)),
		"deck": String(d.get("deck", "")), "cards": _ints(d.get("cards", {})), "plays": _ints(d.get("plays", {})),
		"summons": int(d.get("summons", 0)), "spells": int(d.get("spells", 0)),
		"damage": int(d.get("damage", 0)), "best_hit": int(d.get("best_hit", 0))}
	data["duels"].append(row)
	while data["duels"].size() > MAX_DUELS:
		data["duels"].pop_front()
	save()


## One finished series: `won` true / false, or null for hot-seat.
static func record_series(mode: String, won, score: Array) -> void:
	var data := load_data()
	data["series"].append({"t": int(Time.get_unix_time_from_system()), "mode": mode, "won": won, "score": score.duplicate()})
	while data["series"].size() > MAX_SERIES:
		data["series"].pop_front()
	save()


static func record_draft_pick(card_id: int) -> void:
	var picks: Dictionary = load_data()["draft_picks"]
	var k := str(card_id)
	picks[k] = int(picks.get(k, 0)) + 1
	save()


static func record_draft_done() -> void:
	load_data()["drafts_completed"] = int(load_data()["drafts_completed"]) + 1
	save()


static func _ints(m) -> Dictionary:
	var out := {}
	if m is Dictionary:
		for k in m:
			out[str(k)] = int(m[k])
	return out


# ------------------------------------------------------------------ summary

## The modal's list: [{"label", "value", "detail"}], in display order. Empty before any duel.
## Pure over `data` (defaults to the stored record), so tests pass their own.
static func facts(data: Dictionary = {}) -> Array:
	if data.is_empty():
		data = load_data()
	var duels: Array = data.get("duels", [])
	var out := []
	if duels.is_empty():
		return out
	var rated := duels.filter(func(x): return x["won"] != null)
	var wins := rated.filter(func(x): return x["won"] == true)
	var by_mode := {}
	for x in duels:
		by_mode[x["mode"]] = int(by_mode.get(x["mode"], 0)) + 1
	var parts := []
	for m in [["steam", "online"], ["lan", "LAN"], ["bot", "vs bot"], ["local", "hot-seat"]]:
		if by_mode.has(m[0]):
			parts.append("%d %s" % [by_mode[m[0]], m[1]])
	out.append(_fact("Duels played", str(duels.size()), ", ".join(parts)))
	if not rated.is_empty():
		out.append(_fact("Win rate", "%d%%" % roundi(100.0 * wins.size() / rated.size()),
			"%d won, %d lost" % [wins.size(), rated.size() - wins.size()]))
		for m in [["steam", "Online record"], ["lan", "LAN record"], ["bot", "Record vs bot"]]:
			var r := rated.filter(func(x): return x["mode"] == m[0])
			if not r.is_empty():
				var w := r.filter(func(x): return x["won"] == true).size()
				out.append(_fact(m[1], "%d - %d" % [w, r.size() - w], ""))
	var series: Array = data.get("series", []).filter(func(x): return x["won"] != null)
	if not series.is_empty():
		var sw := series.filter(func(x): return x["won"] == true).size()
		out.append(_fact("Series won", "%d of %d" % [sw, series.size()], ""))
	if not rated.is_empty():
		var best := 0
		var run := 0
		for x in rated:
			run = run + 1 if x["won"] == true else 0
			best = maxi(best, run)
		out.append(_fact("Best win streak", str(best), ("current streak %d" % run) if run > 0 else ""))
	if not wins.is_empty():
		var fastest: int = wins.map(func(x): return int(x["turns"])).min()
		out.append(_fact("Fastest win", "%d turns" % fastest, ""))
	var longest: int = duels.map(func(x): return int(x["turns"])).max()
	out.append(_fact("Longest duel", "%d turns" % longest, ""))
	var hit: int = duels.map(func(x): return int(x.get("best_hit", 0))).max()
	if hit > 0:
		var dealt := 0
		for x in duels:
			dealt += int(x.get("damage", 0))
		out.append(_fact("Biggest single hit", "%d damage" % hit, "%d damage dealt in total" % dealt))
	var plays := {}
	for x in duels:
		for k in x.get("plays", {}):
			plays[k] = int(plays.get(k, 0)) + int(x["plays"][k])
	var top := _top(plays)
	if top != "":
		out.append(_fact("Most played card", _name(top), "played %d times" % plays[top]))
	var best_card := _best_card(rated)
	if not best_card.is_empty():
		out.append(_fact("Your best card", _name(best_card["id"]),
			"won %d of %d duels it was in your deck" % [best_card["w"], best_card["n"]]))
	var decks := {}
	for x in duels:
		if String(x.get("deck", "")) != "":
			decks[x["deck"]] = int(decks.get(x["deck"], 0)) + 1
	var fav := _top(decks)
	if fav != "":
		out.append(_fact("Favourite deck", fav, "%d duels" % decks[fav]))
	var picks: Dictionary = data.get("draft_picks", {})
	var drafted := _top(picks)
	if drafted != "":
		out.append(_fact("Most drafted card", _name(drafted), "picked %d times in %d drafts" % [picks[drafted], int(data.get("drafts_completed", 0))]))
	var summons := 0
	var spells := 0
	var ms := 0
	for x in duels:
		summons += int(x.get("summons", 0))
		spells += int(x.get("spells", 0))
		ms += int(x.get("ms", 0))
	out.append(_fact("Units summoned", str(summons), "%d spells and traps used" % spells))
	out.append(_fact("Time in duels", _duration(ms), ""))
	return out


static func _fact(label: String, value: String, detail: String) -> Dictionary:
	return {"label": label, "value": value, "detail": detail}


## Key with the highest count (ties: the smaller key, so the result is stable).
static func _top(m: Dictionary) -> String:
	var best := ""
	for k in m:
		if int(m[k]) <= 0:
			continue
		if best == "" or int(m[k]) > int(m[best]) or (int(m[k]) == int(m[best]) and String(k) < best):
			best = String(k)
	return best


## Highest win rate among cards in at least BEST_CARD_MIN_DUELS of your decided duels.
static func _best_card(rated: Array) -> Dictionary:
	var n := {}
	var w := {}
	for x in rated:
		for k in x.get("cards", {}):
			n[k] = int(n.get(k, 0)) + 1
			if x["won"] == true:
				w[k] = int(w.get(k, 0)) + 1
	var best := {}
	for k in n:
		if n[k] < BEST_CARD_MIN_DUELS:
			continue
		var r: float = float(w.get(k, 0)) / int(n[k])
		if best.is_empty() or r > best["r"] or (is_equal_approx(r, best["r"]) and n[k] > best["n"]):
			best = {"id": String(k), "r": r, "w": int(w.get(k, 0)), "n": n[k]}
	return best


## Card name; names shared by several cards (Basic Mage of each Type) carry their Type.
static func _name(id: String) -> String:
	var i := int(id)
	if not CardDB.has(i):
		return "Card %s" % id
	var d: Dictionary = CardDB.get_def(i)
	var shared := CardDB.all().filter(func(c): return c["name"] == d["name"]).size() > 1
	return "%s (%s)" % [d["name"], d["type"]] if shared and String(d.get("type", "")) != "" else String(d["name"])


static func _duration(ms: int) -> String:
	var m := ms / 60000
	if m < 60:
		return "%d min" % m
	return "%d h %d min" % [m / 60, m % 60]
