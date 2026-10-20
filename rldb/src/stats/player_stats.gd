class_name PlayerStats
extends RefCounted
## The player's own statistics: finished duels, series and draft picks seen from this install's
## seat(s). `facts()` turns the record into the short list the Statistics modal shows
## (Decks > Statistics).
##
## Storage (C1, 20 Oct 2026). The local file (user://player_stats.json) is the offline cache and
## always works. When Steam runs and statistics sharing is on, StatsSync also keeps a copy in
## Firestore keyed by a salted one-way hash of the Steam ID (`account`), so the same record
## appears on another computer. Copies are merged, never overwritten:
##   duels / series   grow-only sets keyed by a random row id (the newest MAX_DUELS / MAX_SERIES kept);
##   draft counters   one counter set per writer (`devices[device]`), merged by maximum, summed for display.
## Each local file has its own random `device` id, so every counter has exactly one writer and the
## merge is commutative, associative and idempotent (a CRDT): the order in which machines sync
## never changes the result.
##
## Recording: StatsObserver watches a Series run here (bot, hot-seat, network host) through the
## read-only `stats_observer` hooks, and a network client's views; it calls the record_* functions.

const PLAYER_PATH := "user://player_stats.json"
const TEST_PATH := "user://test_player_stats.json"
const VERSION := 2
## Oldest entries are dropped beyond these (the file stays small).
const MAX_DUELS := 500
const MAX_SERIES := 300
## Writers whose draft counters are kept (the largest first); more machines than this is rare.
const MAX_DEVICES := 16
## Distinct cards kept per map (deck multiset, plays, draft counters); bounds hostile cloud data.
const MAX_MAP := 160
## A card needs this many of your duels before it can be "your best card".
const BEST_CARD_MIN_DUELS := 5
const MODES := ["bot", "local", "lan", "steam"]

## Automated runs (GdUnit, `-s` scripts, shot drivers) use TEST_PATH, like DeckStore, so they
## never touch the player's own record.
static var PATH := _default_path()
## Bumped on every change (StatsSync and the open dialog poll it).
static var revision: int = 0

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
	return {"version": VERSION, "account": "", "device": "", "duels": [], "series": [], "devices": {}}


## A random 16-hex id (row ids and device ids).
static func new_id() -> String:
	return Series.new_telemetry_id().substr(0, 16)


## The stored record (loaded once, then cached). Old (v1) files are migrated in place.
static func load_data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_cache = sanitize(d if d is Dictionary else {}, true)
	var fresh := String(_cache["device"]) == ""
	if fresh:
		_cache["device"] = new_id()
	_cache["devices"][_cache["device"]] = _cache["devices"].get(_cache["device"], {"draft_picks": {}, "drafts_completed": 0})
	if d is Dictionary and (int(d.get("version", 1)) < VERSION or fresh):
		save()   # a migrated file keeps the row and device ids it was just given
	return _cache


static func save() -> void:
	revision += 1
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(load_data()))


## Forgets the cached copy (tests, or after the file was replaced).
static func reload() -> void:
	_cache = {}
	revision += 1


## Deletes the record and any per-account copies (tests only; there is no player-facing reset).
static func clear() -> void:
	_cache = {}
	revision += 1
	for p in [PATH] + _stash_files():
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## One finished duel. `d`: mode (bot | local | lan | steam), won (true / false / null for hot-seat),
## turns, ms, tms (time of your own turns, ms), tn (your turns), deck (deck name),
## cards {id: copies} (your starting deck), plays {id: n}, summons, spells (spells and traps used),
## damage (dealt), best_hit.
static func record_duel(d: Dictionary) -> void:
	var data := load_data()
	var row := _duel_row(d)
	row["id"] = new_id()
	row["t"] = int(Time.get_unix_time_from_system())
	row["s"] = _next_s(data)
	data["duels"].append(row)
	while data["duels"].size() > MAX_DUELS:
		data["duels"].pop_front()
	save()


## One finished series: `won` true / false, or null for hot-seat.
static func record_series(mode: String, won, score: Array) -> void:
	var data := load_data()
	data["series"].append(_series_row({"id": new_id(), "t": int(Time.get_unix_time_from_system()), "s": _next_s(data), "mode": mode, "won": won, "score": score}))
	while data["series"].size() > MAX_SERIES:
		data["series"].pop_front()
	save()


## Order of rows recorded within the same second (the last `s` of the record, plus one).
static func _next_s(data: Dictionary) -> int:
	var s := 0
	for list in [data["duels"], data["series"]]:
		if not list.is_empty():
			s = maxi(s, int(list[-1].get("s", 0)))
	return s + 1


static func record_draft_pick(card_id: int) -> void:
	var picks: Dictionary = _mine()["draft_picks"]
	var k := str(card_id)
	picks[k] = int(picks.get(k, 0)) + 1
	save()


static func record_draft_done() -> void:
	var me := _mine()
	me["drafts_completed"] = int(me["drafts_completed"]) + 1
	save()


static func _mine() -> Dictionary:
	var data := load_data()
	return data["devices"][data["device"]]


## Draft picks over every machine: {card id: picks}.
static func draft_picks(data: Dictionary) -> Dictionary:
	var out := {}
	for dev in data.get("devices", {}):
		var p: Dictionary = data["devices"][dev].get("draft_picks", {})
		for k in p:
			out[k] = int(out.get(k, 0)) + int(p[k])
	return out


## Drafts completed over every machine.
static func drafts_completed(data: Dictionary) -> int:
	var n := 0
	for dev in data.get("devices", {}):
		n += int(data["devices"][dev].get("drafts_completed", 0))
	return n


# ------------------------------------------------------------------ accounts

## Makes `hash` (a Steam-ID hash, "" for none) the owner of the active record. A record that was
## never linked is adopted by the first account; a record of another account is set aside in its
## own file and that account's own record (if this computer has one) becomes active, so two Steam
## accounts on one computer never mix their statistics.
static func use_account(hash: String) -> void:
	if hash == "":
		return
	var data := load_data()
	var cur := String(data["account"])
	if cur == hash:
		return
	if cur == "":
		data["account"] = hash
		save()
		return
	_write(stash_path(cur), data)
	var other = JSON.parse_string(FileAccess.get_file_as_string(stash_path(hash))) if FileAccess.file_exists(stash_path(hash)) else null
	_cache = {}
	_cache = sanitize(other if other is Dictionary else {}, true)
	_cache["account"] = hash
	if String(_cache["device"]) == "":
		_cache["device"] = new_id()
	if not _cache["devices"].has(_cache["device"]):
		_cache["devices"][_cache["device"]] = {"draft_picks": {}, "drafts_completed": 0}
	if FileAccess.file_exists(stash_path(hash)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stash_path(hash)))
	save()


## Where account `hash`'s record waits while another account is active.
static func stash_path(hash: String) -> String:
	return "%s_%s.json" % [PATH.get_basename(), hash.substr(0, 32)]


static func _stash_files() -> Array:
	var out := []
	var dir := PATH.get_base_dir()
	var stem := PATH.get_file().get_basename() + "_"
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.begins_with(stem) and f.ends_with(".json"):
			out.append(dir.path_join(f))
	return out


static func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


# ------------------------------------------------------------------ merge (cloud sync)

## Combines two records of the same player. Pure; commutative and idempotent for the shared
## parts (duels, series, devices). `a` is this computer's: its `device` and `account` are kept.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := empty()
	out["account"] = String(a.get("account", "")) if String(a.get("account", "")) != "" else String(b.get("account", ""))
	out["device"] = String(a.get("device", ""))
	out["duels"] = _union(a.get("duels", []), b.get("duels", []), MAX_DUELS)
	out["series"] = _union(a.get("series", []), b.get("series", []), MAX_SERIES)
	var devs := {}
	for src in [a.get("devices", {}), b.get("devices", {})]:
		for dev in src:
			var have: Dictionary = devs.get(dev, {"draft_picks": {}, "drafts_completed": 0})
			var add: Dictionary = src[dev]
			var picks: Dictionary = have["draft_picks"].duplicate()
			for k in add.get("draft_picks", {}):
				picks[k] = maxi(int(picks.get(k, 0)), int(add["draft_picks"][k]))
			devs[dev] = {"draft_picks": picks, "drafts_completed": maxi(int(have["drafts_completed"]), int(add.get("drafts_completed", 0)))}
	out["devices"] = _top_devices(devs, out["device"])
	return out


## Rows of both lists, each id once, oldest first, at most `cap` (the newest).
static func _union(x: Array, y: Array, cap: int) -> Array:
	var by_id := {}
	for row in x + y:
		if row is Dictionary and not by_id.has(row["id"]):
			by_id[row["id"]] = row
	var rows := by_id.values()
	rows.sort_custom(func(p, q):
		if p["t"] != q["t"]:
			return p["t"] < q["t"]
		if p["s"] != q["s"]:
			return p["s"] < q["s"]
		return String(p["id"]) < String(q["id"]))
	while rows.size() > cap:
		rows.pop_front()
	return rows


## At most MAX_DEVICES writers: this computer's, then the largest (ties: smaller id).
static func _top_devices(devs: Dictionary, keep: String) -> Dictionary:
	if devs.size() <= MAX_DEVICES:
		return devs
	var ids := devs.keys()
	var weight := func(id) -> int:
		var w := int(devs[id]["drafts_completed"]) * 1000
		for k in devs[id]["draft_picks"]:
			w += int(devs[id]["draft_picks"][k])
		return w
	ids.sort_custom(func(p, q):
		if (p == keep) != (q == keep):
			return p == keep
		var wp: int = weight.call(p)
		var wq: int = weight.call(q)
		return wp > wq or (wp == wq and String(p) < String(q)))
	var out := {}
	for id in ids.slice(0, MAX_DEVICES):
		out[id] = devs[id]
	return out


## The part of a record that is shared between machines (the cloud copy): no device or account,
## and no writer that has not counted anything yet (a new computer adds nothing until it drafts).
static func shared(data: Dictionary) -> Dictionary:
	var devs := {}
	var src: Dictionary = data.get("devices", {})
	for dev in src:
		if int(src[dev].get("drafts_completed", 0)) > 0 or not (src[dev].get("draft_picks", {}) as Dictionary).is_empty():
			devs[dev] = src[dev]
	return {"version": VERSION, "duels": data.get("duels", []), "series": data.get("series", []), "devices": devs}


## Stable signature of the shared part (equal records have equal signatures).
static func signature(data: Dictionary) -> String:
	return JSON.stringify(shared(data), "", true).sha256_text()


## Replaces the active record (after a cloud merge) and saves it.
static func replace(data: Dictionary) -> void:
	_cache = sanitize(data)
	if String(_cache["device"]) == "":
		_cache["device"] = new_id()
	if not _cache["devices"].has(_cache["device"]):
		_cache["devices"][_cache["device"]] = {"draft_picks": {}, "drafts_completed": 0}
	save()


# ------------------------------------------------------------------ validation

## A clean record from any parsed JSON (the local file, a v1 file, or a cloud copy that another
## client may have written: the hash link is unverified, so every field is type-checked, bounded
## and copied, never trusted).
## `assign_ids`: rows without an id get one (this computer's own old rows); otherwise they are
## dropped (a cloud copy must never gain new random ids, or every sync would duplicate them).
static func sanitize(d, assign_ids: bool = false) -> Dictionary:
	var out := empty()
	if not (d is Dictionary):
		return out
	out["account"] = _hex(d.get("account", ""), 32)
	out["device"] = _hex(d.get("device", ""), 16)
	var duels := []
	if d.get("duels") is Array:
		for x in d["duels"]:
			if x is Dictionary:
				var row := _duel_row(x)
				row["id"] = _hex(x.get("id", ""), 16)
				row["t"] = _int(x.get("t", 0), 0, 4102444800)
				row["s"] = _int(x.get("s", duels.size()), 0, 1000000000)
				if row["id"] == "" and assign_ids:
					row["id"] = new_id()   # v1 rows get a stable id the first time they are saved
				if row["id"] != "":
					duels.append(row)
	out["duels"] = _union(duels, [], MAX_DUELS)
	var series := []
	if d.get("series") is Array:
		for x in d["series"]:
			if x is Dictionary:
				var row := _series_row(x)
				if not x.has("s"):
					row["s"] = series.size()
				if row["id"] == "" and assign_ids:
					row["id"] = new_id()
				if row["id"] != "":
					series.append(row)
	out["series"] = _union(series, [], MAX_SERIES)
	var devs := {}
	if d.get("devices") is Dictionary:
		for dev in d["devices"]:
			var id := _hex(dev, 16)
			if id != "" and d["devices"][dev] is Dictionary:
				devs[id] = {"draft_picks": _counts(d["devices"][dev].get("draft_picks", {})),
					"drafts_completed": _int(d["devices"][dev].get("drafts_completed", 0), 0, 100000)}
	# v1: one counter set for the whole file becomes this file's device.
	if d.get("draft_picks") is Dictionary or d.has("drafts_completed"):
		if out["device"] == "":
			out["device"] = new_id()
		devs[out["device"]] = {"draft_picks": _counts(d.get("draft_picks", {})), "drafts_completed": _int(d.get("drafts_completed", 0), 0, 100000)}
	out["devices"] = _top_devices(devs, out["device"])
	return out


static func _duel_row(x: Dictionary) -> Dictionary:
	var won = x.get("won", null)
	return {"mode": String(x.get("mode", "local")) if String(x.get("mode", "local")) in MODES else "local",
		"won": won if won is bool else null, "turns": _int(x.get("turns", 0), 0, 10000),
		"ms": _int(x.get("ms", 0), 0, 86400000), "tms": _int(x.get("tms", 0), 0, 86400000),
		"tn": _int(x.get("tn", 0), 0, 10000), "deck": _text(x.get("deck", ""), 40),
		"cards": _counts(x.get("cards", {})), "plays": _counts(x.get("plays", {})),
		"summons": _int(x.get("summons", 0), 0, 100000), "spells": _int(x.get("spells", 0), 0, 100000),
		"damage": _int(x.get("damage", 0), 0, 10000000), "best_hit": _int(x.get("best_hit", 0), 0, 10000000)}


static func _series_row(x: Dictionary) -> Dictionary:
	var won = x.get("won", null)
	var score := []
	if x.get("score") is Array and (x["score"] as Array).size() == 2:
		score = [_int(x["score"][0], 0, 99), _int(x["score"][1], 0, 99)]
	return {"id": _hex(x.get("id", ""), 16), "t": _int(x.get("t", 0), 0, 4102444800), "s": _int(x.get("s", 0), 0, 1000000000),
		"mode": String(x.get("mode", "local")) if String(x.get("mode", "local")) in MODES else "local",
		"won": won if won is bool else null, "score": score}


static func _int(v, lo: int, hi: int) -> int:
	return clampi(int(v), lo, hi) if (v is int or v is float) else lo


static func _text(v, n: int) -> String:
	return String(v).substr(0, n) if v is String else ""


## Lowercase hex up to `n` chars, else "".
static func _hex(v, n: int) -> String:
	if not (v is String) or String(v).length() > n or String(v).length() == 0:
		return ""
	for ch in String(v):
		if not ch in "0123456789abcdef":
			return ""
	return String(v)


## {"<card id>": n >= 0} with digit keys only, at most MAX_MAP entries.
static func _counts(m) -> Dictionary:
	var out := {}
	if m is Dictionary:
		for k in m:
			if out.size() >= MAX_MAP:
				break
			var ks := str(k)
			if ks.is_valid_int() and not ks.begins_with("-") and ks.length() <= 9 and (m[k] is int or m[k] is float):
				out[str(int(ks))] = clampi(int(m[k]), 0, 1000000)
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
	var picks := draft_picks(data)
	var drafted := _top(picks)
	if drafted != "":
		out.append(_fact("Most drafted card", _name(drafted), "picked %d times in %d drafts" % [picks[drafted], drafts_completed(data)]))
	var summons := 0
	var spells := 0
	for x in duels:
		summons += int(x.get("summons", 0))
		spells += int(x.get("spells", 0))
	out.append(_fact("Units summoned", str(summons), "%d spells and traps used" % spells))
	out.append_array(time_facts(duels))
	return out


## Game-time facts (C2): total, average and longest duel by clock, and your average turn.
## Duels recorded before the clock existed (ms 0) are left out of the averages.
static func time_facts(duels: Array) -> Array:
	var out := []
	var ms := 0
	var timed := 0
	var longest := 0
	var tms := 0
	var tn := 0
	for x in duels:
		var m := int(x.get("ms", 0))
		ms += m
		if m > 0:
			timed += 1
			longest = maxi(longest, m)
		if int(x.get("tn", 0)) > 0:
			tms += int(x.get("tms", 0))
			tn += int(x.get("tn", 0))
	out.append(_fact("Time in duels", _duration(ms), ("%d timed duels" % timed) if timed > 0 and timed < duels.size() else ""))
	if timed > 0:
		out.append(_fact("Average duel", clock(ms / timed), "longest %s" % clock(longest)))
	if tn > 0:
		out.append(_fact("Average turn", clock(tms / tn), "over %d of your turns" % tn))
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
	var shared_name := CardDB.all().filter(func(c): return c["name"] == d["name"]).size() > 1
	return "%s (%s)" % [d["name"], d["type"]] if shared_name and String(d.get("type", "")) != "" else String(d["name"])


static func _duration(ms: int) -> String:
	var m := ms / 60000
	if m < 60:
		return "%d min" % m
	return "%d h %d min" % [m / 60, m % 60]


## "m:ss" (or "h:mm:ss" from an hour), the duel clock format.
static func clock(ms: int) -> String:
	var s := maxi(ms, 0) / 1000
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
