class_name StatsObserver
extends RefCounted
## Feeds PlayerStats from a Series run in this process (bot, hot-seat, network host) through the
## read-only `stats_observer` hooks on Series and GameCore, or from a network client's views.
## It only reads; play never depends on it. The tutorial is not recorded.

## The observer of the series running here, and the one for a network client.
static var current: StatsObserver = null
static var client: StatsObserver = null

var series: Series
var mode := "local"
## Seats played from this computer whose results count (hot-seat: none, both are local).
var seats: Array = []
var engine: Object = null
var started_ms := 0
var duel := {}
## Network client: the last game number recorded, and the series score already counted.
var client_game := -1
var client_series_done := false
var client_sid := ""
## Clock in ms (tests inject a fake one).
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
## Own-turn timing of the current duel: the seat whose turn runs, when it started, and the totals
## of the turns played from this computer (hot-seat: both seats).
var turn_seat := -1
var turn_started := 0
var own_ms := 0
var own_turns := 0
## Network client: the last turn number seen in a view.
var client_turn := -1


## Starts recording `s`. `role`: "local" (bot / hot-seat) or "host" (network host, seat 0).
static func attach(s: Series, p_mode: String, role: String) -> void:
	if p_mode == "tutorial" or s == null:
		return
	if current != null and current.series != null and current.series.stats_observer == current:
		current.series.stats_observer = null
	var o := StatsObserver.new()
	o.series = s
	o.mode = p_mode if p_mode in ["local", "bot", "lan", "steam"] else "local"
	o.seats = [] if o.mode == "local" and role == "local" else [0]
	s.stats_observer = o
	current = o


## A network client received view `v` (records its finished duels and series).
static func client_view(v: Dictionary, transport: String) -> void:
	if client == null:
		client = StatsObserver.new()
	client.mode = "steam" if transport == "steam" else "lan"
	client._on_view(v)


func on_series_event(s: Series, kind: String, data: Dictionary) -> void:
	if s != series:
		return
	match kind:
		"game_create":
			engine = s.game
			engine.stats_observer = self
			started_ms = now_ms.call()
			_reset_turns()
			duel = {"plays": {}, "summons": 0, "spells": 0, "damage": 0, "best_hit": 0}
		"draft_pick":
			if int(data["p"]) in seats:
				PlayerStats.record_draft_pick(int(data["picked"]))
		"draft_done":
			if int(data["p"]) in seats:
				PlayerStats.record_draft_done()
		"game_over":
			_finish_duel(s)
		"series_over":
			var w := 0 if s.scores[0] > s.scores[1] else 1
			PlayerStats.record_series(mode, (w in seats) if not seats.is_empty() else null, s.scores)


func on_core_event(m: Object, kind: String, data: Dictionary) -> void:
	if m != engine or duel.is_empty():
		return
	var local := seats.is_empty() or int(data.get("p", -1)) in seats
	match kind:
		"turn":
			_turn_begins(int(data["p"]))
		"play":
			if not local or not m.cards.has(int(data["uid"])):
				return
			var id := int(m.cards[int(data["uid"])]["id"])
			duel["plays"][str(id)] = int(duel["plays"].get(str(id), 0)) + 1
			if CardDB.has(id) and CardDB.get_def(id)["category"] in ["spell", "trap"]:
				duel["spells"] += 1
		"summon":
			if local:
				duel["summons"] += 1
		"hp":
			var dmg := -int(data["d"])
			# Damage to an opponent of a local seat (hot-seat counts both sides).
			if dmg > 0 and (seats.is_empty() or not (int(data["p"]) in seats)):
				duel["damage"] += dmg
				duel["best_hit"] = maxi(int(duel["best_hit"]), dmg)


func _finish_duel(s: Series) -> void:
	if duel.is_empty() or s.game == null:
		return
	var w: int = s.game.winner
	var seat: int = seats[0] if not seats.is_empty() else 0
	_turn_begins(-1)
	PlayerStats.record_duel({"mode": mode, "won": (w == seat) if not seats.is_empty() else null,
		"turns": int(s.game.turn), "ms": now_ms.call() - started_ms, "tms": own_ms, "tn": own_turns, "deck": _deck_name(s, seat),
		"cards": _multiset(s.decks[seat]) if not seats.is_empty() else {}, "plays": duel["plays"],
		"summons": duel["summons"], "spells": duel["spells"], "damage": duel["damage"], "best_hit": duel["best_hit"]})
	duel = {}


func _reset_turns() -> void:
	turn_seat = -1
	turn_started = 0
	own_ms = 0
	own_turns = 0
	client_turn = -1


## Closes the running turn (counted when it was played from this computer) and starts seat
## `p`'s (-1: the duel ended).
func _turn_begins(p: int) -> void:
	var now: int = now_ms.call()
	if turn_seat != -1 and (seats.is_empty() or turn_seat in seats):
		own_ms += maxi(0, now - turn_started)
		own_turns += 1
	turn_seat = p
	turn_started = now


static func _deck_name(s: Series, seat: int) -> String:
	if s.cfg.get("deck_mode", "") == "draft":
		return "Draft deck"
	var names = s.get("deck_names")
	if names is Array and seat < names.size() and String(names[seat]) != "":
		return String(names[seat])
	return ""


static func _multiset(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		out[str(int(id))] = int(out.get(str(int(id)), 0)) + 1
	return out


# ------------------------------------------------------------------ network client

func _on_view(v: Dictionary) -> void:
	var tel = v.get("tel_ids", {})
	var sid := String(tel.get("series", "")) if tel is Dictionary else ""
	if sid != client_sid:
		client_sid = sid
		client_game = -1
		client_series_done = false
		started_ms = 0
		_reset_turns()
	var you := int(v.get("you", 1)) if (v.get("you") is int or v.get("you") is float) else 1
	var hist = v.get("history", [])
	if not (hist is Array) or String(v.get("stage", "")) == "game":
		if String(v.get("stage", "")) == "game":
			if started_ms == 0:
				started_ms = now_ms.call()
				_reset_turns()
			_client_turn(v, you)
		return
	for h in hist:
		if not (h is Dictionary):
			continue
		var g := int(h.get("game", -1))
		if g <= client_game:
			continue
		client_game = g
		var deck := []
		if v.get("deck") is Array:
			for c in v["deck"]:
				var cid = c.get("id", -1) if c is Dictionary else c
				if cid is int or cid is float:
					deck.append(int(cid))
		if started_ms > 0:
			_turn_begins(-1)
		PlayerStats.record_duel({"mode": mode, "won": int(h.get("winner", -1)) == you, "turns": int(h.get("turns", 0)),
			"ms": (now_ms.call() - started_ms) if started_ms > 0 else 0, "tms": own_ms, "tn": own_turns, "cards": _multiset(deck),
			"deck": "Draft deck" if String(v.get("deck_mode", "")) == "draft" else String(v.get("deck_name", ""))})
		started_ms = 0
		_reset_turns()
	if String(v.get("stage", "")) == "over" and not client_series_done and v.get("scores") is Array:
		var sc: Array = v["scores"]
		if sc.size() == 2:
			client_series_done = true
			PlayerStats.record_series(mode, int(sc[you]) > int(sc[1 - you]), sc)


## Network client: a new turn number in the match view starts that seat's turn (only this
## seat's own turns are counted).
func _client_turn(v: Dictionary, you: int) -> void:
	seats = [you]
	var mv = v.get("match", null)
	if not (mv is Dictionary) or not (mv.get("turn") is int or mv.get("turn") is float):
		return
	var t := int(mv["turn"])
	if t != client_turn and (mv.get("active") is int or mv.get("active") is float):
		client_turn = t
		_turn_begins(int(mv["active"]))
