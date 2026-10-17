class_name TelemetryCollector
extends RefCounted
## Turns committed rules-engine and series events into telemetry records (schema v1,
## docs/telemetry/schema-v1.md). It observes a Series (series.observer) and the current
## MatchEngine (game.observer); both call it synchronously from their note() hooks. It only reads
## state, never changes it, and does no I/O itself: finished or checkpointed records go to
## `emit_item`, which the Telemetry service writes to the durable outbox.
##
## emit_item.call(kind: String, doc_id: String, state: "open" | "ready", mode: String, body: Dictionary)
##
## Who reports what: the process that runs the Series (hot-seat, bot, network host) reports both
## seats' drafts, rewards, starting decks, game events and the series result. A network client
## only sends a small corroborating "gclient" report per duel (from its own views), which the
## admin tool compares with the host's report (verified / provisional / conflicted).

const PLAY_KINDS := ["normal_summon", "cast_spell", "set_spell", "set_trap", "power",
	"special_ritual", "special_arcane", "special_fusion", "special_effect"]

var emit_item: Callable
var now_ms: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
var max_events: int = 3000
## Participant id of this install's profile (never the Firebase uid; the admin tool maps them).
var profile_pid: String = ""
## Salted one-way hash of the Steam ID ("" when Steam is unavailable). Unverified.
var steam_hash: String = ""

var series: Series
var mode: String = ""                # local | bot | lan | steam
var role: String = ""                # local | host
var resumed: bool = false
var deck_src: Array = [{}, {}]
var drafts: Array = [{}, {}]
var rewards: Dictionary = {}         # "<game_no>_<seat>" -> reward record
var series_games: Array = []
var first_choices: Array = []
var series_reported: bool = false
## Current duel (empty when none).
var g: Dictionary = {}
var paused: bool = false
var _pause_started: int = 0
## Network client corroboration state.
var client: Dictionary = {}
var client_deck: Array = []


# ------------------------------------------------------------------ attach

## Starts observing `s`. `p_mode`: local | bot | lan | steam; `p_role`: local | host.
func attach(s: Series, p_mode: String, p_role: String) -> void:
	if series != null and series != s:
		detach()
	series = s
	mode = p_mode if p_mode in ["local", "bot", "lan", "steam"] else "local"
	role = p_role
	resumed = s.stage != Series.STAGE_DECKS
	series_reported = false
	s.observer = self
	if resumed:
		for h in s.history:
			series_games.append({"game_no": int(h.get("game", 0)), "winner": int(h.get("winner", -1)), "game_id": "", "from_save": true})


## Stops observing; an unfinished duel is reported as abandoned and open drafts as abandoned.
func detach() -> void:
	if series == null:
		return
	if not g.is_empty() and not g.get("done", false):
		_finish_abandoned()
	for p in 2:
		if not drafts[p].is_empty() and drafts[p]["status"] == "in_progress":
			drafts[p]["status"] = "abandoned"
			_emit_draft(p, "ready")
	if series.observer == self:
		series.observer = null
	series = null


func _sid() -> String:
	return String(series.telemetry_ids.get("series", "")) if series != null else ""


func flags() -> Dictionary:
	return {"tutorial": false, "bot": mode == "bot", "local": mode in ["local", "bot"], "network": mode in ["lan", "steam"]}


func participant(seat: int) -> Dictionary:
	if role == "host" or mode in ["local", "bot"]:
		if seat == 0:
			var me := {"seat": 0, "kind": "human", "link": "profile", "participant_id": profile_pid}
			if steam_hash != "":
				me["steam_hash"] = steam_hash
				me["steam_link"] = "unverified"
			return me
		if mode == "bot":
			return {"seat": 1, "kind": "bot", "link": "bot", "participant_id": "bot"}
		if mode == "local":
			return {"seat": 1, "kind": "human", "link": "guest", "participant_id": "guest_" + _sid()}
		return {"seat": 1, "kind": "human", "link": "remote", "participant_id": null}
	return {"seat": seat, "kind": "human", "link": "unknown", "participant_id": null}


# ------------------------------------------------------------------ series events

func on_series_event(s: Series, kind: String, data: Dictionary) -> void:
	if s != series:
		return
	match kind:
		"deck_locked":
			deck_src[int(data["p"])] = {"source": data["source"], "name": data.get("name", "")}
		"draft_setup":
			_draft_setup(int(data["p"]))
		"draft_pick":
			_draft_pick(data)
		"draft_done":
			var p := int(data["p"])
			deck_src[p] = {"source": "draft", "name": ""}
			if not drafts[p].is_empty():
				drafts[p]["status"] = "complete"
				drafts[p]["finished_at"] = now_ms.call()
				_emit_draft(p, "ready")
		"game_create":
			_game_start()
		"award":
			if not g.is_empty():
				g["hint"] = "disconnect_claim"
		"forfeit":
			if not g.is_empty() and not g.get("done", false):
				g["hint"] = "forfeit"
		"reward":
			_reward(data)
		"first_choice":
			first_choices.append({"after_game_no": series.game_no, "chooser": int(data["p"]), "first": int(data["who"])})
		"series_over":
			_series_over()


func _draft_setup(p: int) -> void:
	var st: Dictionary = series.draft[p]
	drafts[p] = {"draft_id": "%s_d%d" % [_sid(), p], "series_id": _sid(), "seat": p, "participant": participant(p),
		"category_order": st["cat_order"].duplicate(), "quota": series.cfg["draft"]["quota"].duplicate(),
		"offer_size": int(series.cfg["draft"]["offer"]), "basic_unit": int(st["basic"]),
		"basic_copies": int(series.cfg["draft"]["basic_copies"]), "picks": [], "status": "in_progress",
		"started_at": now_ms.call(), "finished_at": 0, "rerolls_supported": false}
	_emit_draft(p, "open")


func _draft_pick(data: Dictionary) -> void:
	var p := int(data["p"])
	if drafts[p].is_empty():
		_draft_setup(p)
	var counts := {}
	for id in data["offer"]:
		counts[str(int(id))] = int(counts.get(str(int(id)), 0)) + 1
	drafts[p]["picks"].append({"n": int(data["step"]) + 1, "category": String(data["category"]),
		"offered": data["offer"].map(func(i): return int(i)), "offered_counts": counts,
		"selected": int(data["picked"]), "selected_count": 1, "status": "picked", "t": now_ms.call()})
	_emit_draft(p, "open")


func _emit_draft(p: int, state: String) -> void:
	var d: Dictionary = drafts[p]
	emit_item.call("draft", "draft_" + String(d["draft_id"]), state, mode,
		{"kind": "draft", "ids": {"draft_id": d["draft_id"], "series_id": d["series_id"]}, "mode": mode, "flags": flags(), "draft": d})


func _reward(data: Dictionary) -> void:
	var p := int(data["p"])
	var key := "%d_%d" % [series.game_no, p]
	if not rewards.has(key):
		rewards[key] = {"series_id": _sid(), "after_game_no": series.game_no, "after_game_id": String(g.get("id", "")),
			"seat": p, "participant": participant(p), "actions": [], "deck_after": {}, "status": "in_progress",
			"rewards_per_game": int(series.cfg.get("rewards_per_game", 0))}
	var r: Dictionary = rewards[key]
	var cmd: Dictionary = data["cmd"]
	match String(data["t"]):
		"reward_type":
			r["actions"].append({"kind": "type", "category": String(cmd.get("category", "")), "offered": data["offer"].map(func(i): return int(i))})
		"reward_add":
			var deck: Array = data["deck"]
			r["actions"].append({"kind": "add", "selected": int(deck[-1]) if not deck.is_empty() else -1, "index": int(cmd.get("index", -1))})
		"reward_remove":
			r["actions"].append({"kind": "remove", "card": int(cmd.get("card_id", -1))})
		"reward_basic":
			r["actions"].append({"kind": "basic", "to_type": String(cmd.get("to_type", "")), "to_race": String(cmd.get("to_race", ""))})
		"reward_finish":
			r["actions"].append({"kind": "finish"})
	if data["done"]:
		r["status"] = "complete"
		r["deck_after"] = multiset(data["deck"])
		emit_item.call("reward", "reward_%s_g%d_s%d" % [_sid(), series.game_no, p], "ready", mode,
			{"kind": "reward", "ids": {"series_id": _sid(), "after_game_id": r["after_game_id"]}, "mode": mode, "flags": flags(), "reward": r})


func _series_over() -> void:
	if series_reported:
		return
	series_reported = true
	for p in 2:
		if not drafts[p].is_empty() and drafts[p]["status"] == "in_progress":
			drafts[p]["status"] = "abandoned"
			_emit_draft(p, "ready")
	var status := "forfeit" if series.forfeit_by != -1 else "complete"
	var sw := -1
	for p in 2:
		if series.scores[p] >= series.wins_needed():
			sw = p
	if series.forfeit_by != -1:
		sw = 1 - series.forfeit_by
	var body := {"kind": "series", "ids": {"series_id": _sid()}, "mode": mode, "flags": flags(),
		"series": {"series_id": _sid(), "best_of": int(series.cfg["best_of"]), "deck_mode": String(series.cfg["deck_mode"]),
			"participants": [participant(0), participant(1)], "scores": series.scores.duplicate(), "winner": sw,
			"status": status, "forfeit_by": series.forfeit_by, "games": series_games.duplicate(true),
			"first_choices": first_choices.duplicate(true), "resumed_from_save": resumed,
			"rewards_per_game": int(series.cfg.get("rewards_per_game", 0))}}
	emit_item.call("series", "series_" + _sid(), "ready", mode, body)


# ------------------------------------------------------------------ duel

func _game_start() -> void:
	if not g.is_empty() and not g.get("done", false):
		_finish_abandoned()
	var m := series.game
	var gid := String(series.telemetry_ids.get("game", ""))
	g = {"id": gid, "engine": m, "game_no": series.game_no, "started_at": now_ms.call(), "paused_ms": 0,
		"first_player": series.first_player, "start_hp": int(series.cfg.get("start_hp", GameCore.START_HP)),
		"decks": [deck_snapshot(0), deck_snapshot(1)], "events": [], "events_truncated": 0, "seq": 0,
		"opps": {}, "open_by_uid": {}, "next_opp": 1, "counters": [{}, {}],
		"totals": [_new_totals(), _new_totals()], "turn_draw": false, "last_paid": -1, "pending_play": -1,
		"pending_special": -1, "pending_mat": -1, "mats": [], "hint": "", "done": false, "turn": 0, "active": -1}
	paused = false
	m.observer = self
	_checkpoint()


func _new_totals() -> Dictionary:
	return {"turns_taken": 0, "ap_granted": 0, "ap_unspent": 0, "ap_spent_on_plays": 0, "damage_taken": 0,
		"healing": 0, "draws": 0, "hand_entries": 0, "plays": 0, "activations": 0, "special_summons": 0}


## Seat p's starting deck, frozen when the duel starts (main / Extra Deck multisets).
func deck_snapshot(p: int) -> Dictionary:
	var main := []
	var extra := []
	var basics := []
	for id in series.decks[p]:
		var d := CardDB.get_def(int(id))
		if CardDB.is_extra_category(d["category"]):
			extra.append(int(id))
		else:
			main.append(int(id))
		if d["category"] == "basic_unit":
			basics.append(int(id))
	var src: Dictionary = deck_src[p]
	var source := String(src.get("source", "unknown"))
	if series.game_no > 1 or resumed:
		source += "+series_changes"
	var ms := multiset(main)
	var ex := multiset(extra)
	return {"snapshot_id": "%s_s%d" % [String(series.telemetry_ids.get("game", "")), p], "seat": p,
		"participant": participant(p), "source": source, "base_source": String(src.get("source", "unknown")),
		"main": ms, "extra": ex, "basic_units": multiset(basics), "main_size": main.size(), "extra_size": extra.size(),
		"size": main.size() + extra.size(), "fingerprint": fingerprint(ms, ex), "duel_index": series.game_no}


## {"<card id>": copies}.
static func multiset(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		var k := str(int(id))
		out[k] = int(out.get(k, 0)) + 1
	return out


## Stable deck fingerprint: sha256 of the sorted "M:id:n" / "X:id:n" list, 16 hex chars.
static func fingerprint(main: Dictionary, extra: Dictionary) -> String:
	var parts := []
	for k in main:
		parts.append("M:%s:%d" % [k, main[k]])
	for k in extra:
		parts.append("X:%s:%d" % [k, extra[k]])
	parts.sort()
	return ",".join(parts).sha256_text().substr(0, 16)


func _card(seat: int, def_id: int) -> Dictionary:
	var k := str(def_id)
	var cs: Dictionary = g["counters"][seat]
	if not cs.has(k):
		cs[k] = {"draws": 0, "hand_entries": 0, "draw_opps": 0, "draw_opps_played": 0, "hand_plays": 0,
			"plays": 0, "plays_by_kind": {}, "activations": 0, "activations_by_kind": {}, "special_summons": 0}
	return cs[k]


func _ev(row: Array) -> void:
	g["seq"] += 1
	if g["events"].size() >= max_events:
		g["events_truncated"] += 1
		return
	g["events"].append([g["seq"], int(g["turn"])] + row)


func on_core_event(m: Object, kind: String, data: Dictionary) -> void:
	if g.is_empty() or m != g["engine"] or g["done"]:
		return
	var eng: MatchEngine = m
	if kind != "draw":
		g["turn_draw"] = false
	match kind:
		"turn":
			_on_turn(eng, int(data["p"]), int(data["turn"]))
		"draw":
			_open_opp(eng, int(data["uid"]), "draw_turn" if g["turn_draw"] else "draw_effect")
		"to_hand":
			var from := String(data["from"])
			var reason: String = {"spent": "retrieve_spent", "exhaust": "retrieve_exhaust", "draw": "search_draw", "limbo": "return_limbo"}.get(from, "return_field")
			_open_opp(eng, int(data["uid"]), reason)
		"hand_exit":
			_close_opp(int(data["uid"]))
		"play":
			_on_play(eng, data)
		"summon":
			_on_summon(eng, data)
		"material":
			var mu := int(data["uid"])
			if eng.cards.has(mu):
				g["mats"].append([int(eng.cards[mu]["id"]), mu, String(data["from"])])
				if String(data["from"]) == "hand":
					g["pending_mat"] = mu
		"activation":
			_on_activation(eng, data["frame"])
		"trap":
			_activation(eng, int(data["uid"]), int(data["p"]), "trap", "trap", false, "resolved")
		"trigger":
			var ev: Dictionary = data.get("event", {})
			_activation(eng, int(data["uid"]), int(data["ctl"]), "trigger", "on:" + String(ev.get("name", "?")), false, "resolved")
		"hp":
			var p := int(data["p"])
			var dlt := int(data["d"])
			if dlt < 0:
				g["totals"][p]["damage_taken"] += -dlt
			else:
				g["totals"][p]["healing"] += dlt
			_ev(["hp", p, dlt])
		"concede":
			g["hint"] = "concede"
		"game_over":
			_finish(eng, int(data["winner"]))


func _on_turn(m: MatchEngine, p: int, turn: int) -> void:
	if g["active"] != -1:
		var prev: int = g["active"]
		g["totals"][prev]["ap_granted"] += int(m.players[prev].get("ap_start", 0))
		g["totals"][prev]["ap_unspent"] += int(m.players[prev]["ap"])
		g["totals"][prev]["turns_taken"] += 1
	g["active"] = p
	g["turn"] = turn
	g["turn_draw"] = true
	_ev(["turn", p])
	if turn > 1:
		_checkpoint()


func _open_opp(m: MatchEngine, uid: int, reason: String) -> void:
	if not m.cards.has(uid) or g["open_by_uid"].has(uid):
		return
	var seat: int = m.cards[uid]["owner"]
	var def_id: int = m.cards[uid]["id"]
	var token := "o%d" % g["next_opp"]
	g["next_opp"] += 1
	var is_draw := reason.begins_with("draw_")
	g["opps"][token] = [token, seat, def_id, uid, reason, int(g["turn"]), "open", -1]
	g["open_by_uid"][uid] = token
	var c := _card(seat, def_id)
	c["hand_entries"] += 1
	g["totals"][seat]["hand_entries"] += 1
	if is_draw:
		c["draws"] += 1
		c["draw_opps"] += 1
		g["totals"][seat]["draws"] += 1
	_ev(["hand", seat, def_id, uid, token, reason])


func _close_opp(uid: int) -> void:
	if not g["open_by_uid"].has(uid):
		return
	var token: String = g["open_by_uid"][uid]
	g["open_by_uid"].erase(uid)
	var o: Array = g["opps"][token]
	var outcome := "exited"
	if g["pending_play"] == uid:
		outcome = "played"
		g["pending_play"] = -1
	elif g["pending_special"] == uid:
		outcome = "special"
		g["pending_special"] = -1
	elif g["pending_mat"] == uid:
		outcome = "material"
		g["pending_mat"] = -1
	o[6] = outcome
	o[7] = int(g["turn"])
	if outcome == "played":
		var c := _card(o[1], o[2])
		c["hand_plays"] += 1
		if String(o[4]).begins_with("draw_"):
			c["draw_opps_played"] += 1
	_ev(["exit", o[1], o[2], uid, token, outcome])


func _play_kind_for_hand(m: MatchEngine, uid: int, is_set: bool) -> String:
	match String(m.d(uid)["category"]):
		"unit", "basic_unit":
			return "normal_summon"
		"spell":
			return "set_spell" if is_set else "cast_spell"
		"trap":
			return "set_trap"
		"power":
			return "power"
	return "other"


func _on_play(m: MatchEngine, data: Dictionary) -> void:
	var uid := int(data["uid"])
	if not m.cards.has(uid):
		return
	var p := int(data["p"])
	var kind := _play_kind_for_hand(m, uid, bool(data.get("set", false)))
	g["last_paid"] = uid
	g["pending_play"] = uid
	_record_play(m, uid, p, kind, String(m.cards[uid]["zone"]), int(data.get("ap", 0)), -1, [])


func _on_summon(m: MatchEngine, data: Dictionary) -> void:
	var uid := int(data["uid"])
	var from := String(data["from"])
	if not m.cards.has(uid) or from == "unit":
		return
	if uid == g["last_paid"] and from == "hand":
		return                           # placement of a normal summon already counted at payment
	var f: Dictionary = data["frame"]
	var ops: Array = f.get("ops", []).map(func(o): return String(o.get("op", "")))
	var kind := "special_effect"
	if from == "extra":
		if "ritual_material" in ops:
			kind = "special_ritual"
		elif "arcane_materials" in ops:
			kind = "special_arcane"
		elif int(f.get("vars", {}).get("fusion", -1)) == uid:
			kind = "special_fusion"
	var mats: Array = g["mats"] if kind != "special_effect" else []
	g["mats"] = []
	if from == "hand":
		g["pending_special"] = uid
	var src := int(f.get("src", -1))
	_record_play(m, uid, int(data["p"]), kind, from, 0, src if src != uid else -1, mats)


func _record_play(m: MatchEngine, uid: int, p: int, kind: String, from: String, ap: int, source_uid: int, mats: Array) -> void:
	var def_id: int = m.cards[uid]["id"]
	var c := _card(p, def_id)
	c["plays"] += 1
	c["plays_by_kind"][kind] = int(c["plays_by_kind"].get(kind, 0)) + 1
	g["totals"][p]["plays"] += 1
	g["totals"][p]["ap_spent_on_plays"] += ap
	if kind.begins_with("special_"):
		c["special_summons"] += 1
		g["totals"][p]["special_summons"] += 1
	var src_def: int = int(m.cards[source_uid]["id"]) if source_uid != -1 and m.cards.has(source_uid) else -1
	var action_id := "%s:%d" % [g["id"], int(g["seq"]) + 1]
	_ev(["play", p, def_id, uid, kind, from, ap, src_def, mats.map(func(x): return [x[0], x[1], x[2]]), action_id])


func _on_activation(m: MatchEngine, f: Dictionary) -> void:
	var uid := int(f.get("src", -1))
	if uid == -1 or not m.cards.has(uid):
		return
	var kind := "effect"
	var effect := "effect"
	for o in f.get("ops", []):
		match String(o.get("op", "")):
			"ability_cost":
				kind = "ability"
				effect = "ability:%d" % int(o.get("idx", 0))
			"flip_set_spell":
				kind = "set_spell"
				effect = "spell"
			"to_limbo":
				kind = "cast_spell"
				effect = "spell"
			"place_power":
				kind = "power"
				effect = "power"
	_activation(m, uid, int(f.get("ctl", m.cards[uid]["ctl"])), kind, effect, true, "negated" if f.get("negated", false) else "resolved")


func _activation(m: MatchEngine, uid: int, p: int, kind: String, effect: String, manual: bool, result: String) -> void:
	if not m.cards.has(uid):
		return
	var def_id: int = m.cards[uid]["id"]
	var c := _card(p, def_id)
	c["activations"] += 1
	var k := "%s:%s" % [kind, result]
	c["activations_by_kind"][k] = int(c["activations_by_kind"].get(k, 0)) + 1
	g["totals"][p]["activations"] += 1
	_ev(["act", p, def_id, uid, kind, effect, "manual" if manual else "triggered", result])


## Pause/resume of a network duel (disconnect). Paused time is excluded from active duration.
func set_paused(on: bool) -> void:
	if g.is_empty() or g["done"] or on == paused:
		return
	paused = on
	if on:
		_pause_started = now_ms.call()
	else:
		g["paused_ms"] += now_ms.call() - _pause_started
	_ev(["pause", 1 if on else 0])


func _reason_for(m: MatchEngine, winner: int) -> String:
	if g["hint"] != "":
		return g["hint"]
	if winner != -1 and int(m.players[1 - winner]["hp"]) <= 0:
		return "lethal"
	return "other"


func _finish(m: MatchEngine, winner: int) -> void:
	g["done"] = true
	if paused:
		set_paused(false)
	for uid in g["open_by_uid"].keys():
		var o: Array = g["opps"][g["open_by_uid"][uid]]
		o[6] = "in_hand_at_end"
	g["open_by_uid"].clear()
	if g["active"] != -1:
		var prev: int = g["active"]
		g["totals"][prev]["ap_granted"] += int(m.players[prev].get("ap_start", 0))
		g["totals"][prev]["ap_unspent"] += int(m.players[prev]["ap"])
		g["totals"][prev]["turns_taken"] += 1
	var reason := _reason_for(m, winner)
	var body := _game_body("completed", winner, reason, m.turn, [int(m.players[0]["hp"]), int(m.players[1]["hp"])])
	series_games.append({"game_no": g["game_no"], "game_id": g["id"], "winner": winner, "reason": reason})
	emit_item.call("game", "game_" + String(g["id"]), "ready", mode, body)
	m.observer = null


func _finish_abandoned() -> void:
	g["done"] = true
	var m: MatchEngine = g["engine"]
	var body := _game_body("abandoned", -1, "abandoned", m.turn if m != null else int(g["turn"]),
		[int(m.players[0]["hp"]), int(m.players[1]["hp"])] if m != null else [])
	emit_item.call("game", "game_" + String(g["id"]), "ready", mode, body)
	if m != null and m.observer == self:
		m.observer = null


func _checkpoint() -> void:
	var m: MatchEngine = g["engine"]
	emit_item.call("game", "game_" + String(g["id"]), "open", mode,
		_game_body("in_progress", -1, "", m.turn, [int(m.players[0]["hp"]), int(m.players[1]["hp"])] if m.players.size() == 2 else []))


func _game_body(outcome: String, winner: int, reason: String, turns: int, hp: Array) -> Dictionary:
	var end: int = now_ms.call()
	var pause_extra: int = (end - _pause_started) if paused else 0
	var decisive := outcome == "completed" and winner != -1
	var opps := []
	for t in g["opps"]:
		opps.append(g["opps"][t].duplicate())
	return {"kind": "game", "ids": {"game_id": g["id"], "series_id": _sid()}, "mode": mode, "flags": flags(),
		"reporter": {"role": role, "covers_seats": [0, 1]},
		"game": {"game_id": g["id"], "series_id": _sid(), "duel_index": g["game_no"], "best_of": int(series.cfg["best_of"]),
			"deck_mode": String(series.cfg["deck_mode"]), "started_at": g["started_at"], "ended_at": end if outcome != "in_progress" else 0,
			"active_ms": end - int(g["started_at"]) - int(g["paused_ms"]) - pause_extra, "paused_ms": int(g["paused_ms"]) + pause_extra,
			"turns": turns, "first_player": g["first_player"], "start_hp": g["start_hp"], "base_ap": GameCore.BASE_AP,
			"base_draw": GameCore.BASE_DRAW, "outcome": outcome, "decisive": decisive, "winner": winner,
			"loser": (1 - winner) if decisive else -1, "reason": reason, "final_hp": hp, "draws_supported": false},
		"participants": [participant(0), participant(1)],
		"decks": g["decks"], "counters": g["counters"], "totals": g["totals"], "opportunities": opps,
		"events": g["events"],
		"completeness": {"events": g["events_truncated"] == 0, "events_truncated": g["events_truncated"],
			"opportunities_closed": outcome == "completed", "measured_seats": [0, 1],
			"activation_results": ["resolved", "negated"], "unmeasured": ["response_latency", "attacks"]}}


## Converts an open record left by an earlier process into its abandoned final form.
static func abandon_body(kind: String, body: Dictionary) -> Dictionary:
	var b := body.duplicate(true)
	if kind == "game" and b.get("game") is Dictionary:
		b["game"]["outcome"] = "abandoned"
		b["game"]["decisive"] = false
		b["game"]["winner"] = -1
		b["game"]["loser"] = -1
		b["game"]["reason"] = "abandoned"
		var comp: Dictionary = b.get("completeness", {})
		comp["opportunities_closed"] = false
		comp["recovered_after_restart"] = true
		b["completeness"] = comp
	elif kind == "draft" and b.get("draft") is Dictionary:
		b["draft"]["status"] = "abandoned"
	elif kind == "gclient" and b.get("gclient") is Dictionary:
		b["gclient"]["outcome"] = "abandoned"
		b["gclient"]["winner"] = -1
	return b


# ------------------------------------------------------------------ network client

## A network client's view arrived. Builds one corroborating report per duel from public view
## data only (no hidden information beyond what this seat already sees).
## Every field comes from the host, which may be modified: ids must be plain names (they become
## outbox file names and document ids) and malformed values are skipped, never trusted.
func on_client_view(v: Dictionary, transport: String) -> void:
	var tel = v.get("tel_ids", {})
	if not (tel is Dictionary) or tel.is_empty():
		return
	var sid = tel.get("series", "")
	var gid_v = tel.get("game", "")
	if not (sid is String and gid_v is String) or not TelemetryOutbox.safe_id(String(sid)) \
			or (gid_v != "" and not TelemetryOutbox.safe_id(String(gid_v))):
		return
	var cmode := "steam" if transport == "steam" else "lan"
	if v.get("deck") is Array:
		client_deck = []
		for c in v["deck"]:
			var cid = c.get("id", -1) if c is Dictionary else c
			if cid is int or cid is float:
				client_deck.append(int(cid))
	var gid := String(gid_v)
	if String(v.get("stage", "")) == "game" and gid != "" and String(client.get("game_id", "")) != gid:
		if not client.is_empty() and not client.get("done", false):
			client["outcome"] = "unknown"
			_emit_client("ready")
		var main := []
		var extra := []
		for id in client_deck:
			if id >= 0 and CardDB.has(id) and CardDB.is_extra_category(CardDB.get_def(id)["category"]):
				extra.append(id)
			elif id >= 0:
				main.append(id)
		client = {"game_id": gid, "series_id": String(tel.get("series", "")), "duel_index": _num(v.get("game_no", 0)),
			"seat": _num(v.get("you", 1)), "mode": cmode, "started_at": now_ms.call(), "first_player": -1,
			"best_of": _num(v.get("best_of", 0)), "deck_mode": String(v.get("deck_mode", "")).substr(0, 16),
			"deck": {"main": multiset(main), "extra": multiset(extra), "size": main.size() + extra.size(),
				"fingerprint": fingerprint(multiset(main), multiset(extra))},
			"participant": {"seat": _num(v.get("you", 1)), "kind": "human", "link": "profile", "participant_id": profile_pid},
			"outcome": "in_progress", "winner": -1, "turns": 0, "final_hp": [], "forfeit": false, "done": false}
		if steam_hash != "":
			client["participant"]["steam_hash"] = steam_hash
			client["participant"]["steam_link"] = "unverified"
		_emit_client("open")
	if client.is_empty() or client["done"]:
		return
	var mv = v.get("match", null)
	if mv is Dictionary and int(client["first_player"]) == -1 and _num(mv.get("turn", 0)) == 1:
		client["first_player"] = _num(mv.get("active", -1))
	var hist = v.get("history", [])
	if not (hist is Array):
		return
	for h in hist:
		if h is Dictionary and _num(h.get("game", -1)) == int(client["duel_index"]) and String(v.get("stage", "")) != "game":
			client["done"] = true
			client["outcome"] = "completed"
			client["winner"] = _num(h.get("winner", -1))
			client["turns"] = _num(h.get("turns", 0))
			var hp = h.get("hp", [])
			client["final_hp"] = hp.map(func(x): return _num(x)) if hp is Array else []
			client["forfeit"] = bool(h.get("forfeit", false))
			client["ended_at"] = now_ms.call()
			_emit_client("ready")
			return


## An int from an untrusted view value (-1 when it is not a number).
static func _num(x) -> int:
	return int(x) if (x is int or x is float) else -1


func _emit_client(state: String) -> void:
	var c := client.duplicate(true)
	c.erase("done")
	emit_item.call("gclient", "gclient_" + String(client["game_id"]), state, String(client["mode"]),
		{"kind": "gclient", "ids": {"game_id": client["game_id"], "series_id": client["series_id"]}, "mode": client["mode"],
			"flags": {"tutorial": false, "bot": false, "local": false, "network": true},
			"reporter": {"role": "client", "covers_seats": [int(client["seat"])]}, "gclient": c})
