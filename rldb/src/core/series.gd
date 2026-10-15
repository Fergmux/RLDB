class_name Series
extends RefCounted
## Authority for a whole series: deck selection or draft, games, score, between-game
## rewards for both players and the loser's first-player choice. Wraps one
## MatchEngine per game. Per-game state (HP, statuses, runes, Exhaust, cost changes)
## is discarded between games because each game builds fresh card instances; only
## the deck lists and the score carry forward.

signal changed

const STAGE_DECKS := "decks"
const STAGE_GAME := "game"
const STAGE_REWARDS := "rewards"
const STAGE_FIRST := "first_player"
const STAGE_OVER := "over"

var cfg: Dictionary = {}
var names: Array = ["Player 1", "Player 2"]
var stage: String = STAGE_DECKS
var decks: Array = [[], []]          # card ids per player: main + extra
var deck_names: Array = ["", ""]
var scores: Array = [0, 0]
var game_no: int = 0
var game: MatchEngine
var last_loser: int = -1
var first_player: int = -1
var rng := RandomNumberGenerator.new()
var history: Array = []              # finished game summaries
var deck_ready: Array = [false, false]
var draft: Array = [{}, {}]          # per-player draft state
var rewards: Array = [{}, {}]        # per-player reward state
var series_log: Array = []
var forfeit_by: int = -1             # player who abandoned the series, if any
var starters: Array = []
var _seed: int = 0


static func load_mode_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/mode_config.json"))


static func load_starters() -> Array:
	var decks_raw: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))["decks"]
	for dk in decks_raw:
		# JSON numbers parse as floats; card ids are ints everywhere else.
		dk["main"] = dk["main"].map(func(i): return int(i))
		dk["extra"] = dk["extra"].map(func(i): return int(i))
	return decks_raw


## overrides: best_of, deck_mode, seed, names, rewards_per_game ...
func setup(overrides: Dictionary = {}) -> void:
	CardDB.ensure_loaded()
	cfg = load_mode_config()
	cfg.merge(overrides, true)
	_seed = int(cfg.get("seed", Time.get_ticks_usec()))
	rng.seed = _seed
	if cfg.has("names"):
		names = cfg["names"]
	starters = load_starters()
	stage = STAGE_DECKS
	if cfg["deck_mode"] == "draft":
		for p in 2:
			draft[p] = _new_draft()
	_log("Series start: best of %d, %s decks." % [cfg["best_of"], cfg["deck_mode"]])


func _log(text: String) -> void:
	series_log.append(text)


func wins_needed() -> int:
	return int(cfg["best_of"]) / 2 + 1


# ---------------------------------------------------------------- commands

## Validates and applies a series-level or in-game command from player p.
func submit(p: int, cmd: Dictionary) -> String:
	var t: String = cmd.get("t", "")
	var err := ""
	match stage:
		STAGE_GAME:
			if t == "concede_series":
				err = _concede_series(p)
			else:
				err = game.submit(p, cmd)
				if err == "" and game.winner != -1:
					_on_game_over()
		STAGE_DECKS:
			err = _deck_command(p, cmd)
		STAGE_REWARDS:
			err = _reward_command(p, cmd)
		STAGE_FIRST:
			err = _first_command(p, cmd)
		_:
			err = "The series is over."
	if err == "":
		changed.emit()
	return err


## Ends the whole series because player p abandoned it (P-02: the host may stop
## waiting for a disconnected player, who then forfeits).
func forfeit(p: int, reason: String) -> void:
	if stage == STAGE_OVER:
		return
	forfeit_by = p
	if game != null and game.winner == -1:
		game.end_game(1 - p, reason)
		history.append({"game": game_no, "winner": 1 - p, "turns": game.turn, "hp": [game.players[0]["hp"], game.players[1]["hp"]], "forfeit": true})
	stage = STAGE_OVER
	_log("%s forfeits the series (%s)." % [names[p], reason])
	changed.emit()


func _concede_series(p: int) -> String:
	game.submit(p, {"t": "concede"})
	_on_game_over()
	return ""


# ---------------------------------------------------------------- deck selection / draft

func _deck_command(p: int, cmd: Dictionary) -> String:
	if deck_ready[p]:
		return "Your deck is already locked in."
	match cmd.get("t", ""):
		"pick_starter":
			if cfg["deck_mode"] != "starter":
				return "This series uses drafting."
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= starters.size():
				return "No such starter deck."
			decks[p] = starters[i]["main"] + starters[i]["extra"]
			deck_names[p] = starters[i]["name"]
			deck_ready[p] = true
			_log("%s locks in a deck." % names[p])
		"draft_pick":
			if cfg["deck_mode"] != "draft":
				return "This series uses starter decks."
			var e := _draft_pick(p, int(cmd.get("index", -1)))
			if e != "":
				return e
		_:
			return "Choose a deck first."
	if deck_ready[0] and deck_ready[1]:
		first_player = rng.randi_range(0, 1)
		_log("Coin flip: %s goes first in game 1 (proposal P-01)." % names[first_player])
		_start_game()
	return ""


func _new_draft() -> Dictionary:
	var quota: Dictionary = cfg["draft"]["quota"]
	var order := []
	for cat in ["basic", "unit", "spell", "trap", "power", "extra"]:
		for i in int(quota.get(cat, 0)):
			order.append(cat)
	return {"order": order, "step": 0, "picked": [], "offer": []}


func _draft_pool(cat: String) -> Array:
	var out := []
	for d in CardDB.all():
		if not CardScripts.is_implemented(d["id"]):
			continue
		var c: String = d["category"]
		var ok := false
		match cat:
			"basic": ok = c == "basic_unit"
			"unit": ok = c == "unit"
			"spell", "trap", "power": ok = c == cat
			"extra": ok = c in ["fusion", "ritual", "arcane"]
		if ok:
			out.append(d["id"])
	return out


func _ensure_offer(p: int) -> void:
	var st: Dictionary = draft[p]
	if st["step"] >= st["order"].size() or not st["offer"].is_empty():
		return
	var pool := _draft_pool(st["order"][st["step"]])
	var offer := []
	for i in mini(int(cfg["draft"]["offer"]), pool.size()):
		var j := rng.randi_range(0, pool.size() - 1)
		offer.append(pool[j])
		pool.remove_at(j)
	st["offer"] = offer


func _draft_pick(p: int, index: int) -> String:
	var st: Dictionary = draft[p]
	_ensure_offer(p)
	if index < 0 or index >= st["offer"].size():
		return "Invalid draft choice."
	var id: int = st["offer"][index]
	var copies: int = int(cfg["draft"]["basic_copies"]) if st["order"][st["step"]] == "basic" else 1
	for i in copies:
		st["picked"].append(id)
	st["step"] += 1
	st["offer"] = []
	if st["step"] >= st["order"].size():
		decks[p] = st["picked"].duplicate()
		deck_names[p] = "Drafted deck"
		deck_ready[p] = true
		_log("%s finishes drafting." % names[p])
	else:
		_ensure_offer(p)
	return ""


# ---------------------------------------------------------------- games

func _start_game() -> void:
	game_no += 1
	stage = STAGE_GAME
	game = MatchEngine.new()
	game.setup(decks.duplicate(true), first_player, rng.randi(), {"names": names, "start_hp": int(cfg["start_hp"]), "hidden_response_windows": cfg.get("hidden_response_windows", false), "fatigue_damage": int(cfg.get("fatigue_damage", 2))})
	_log("Game %d begins. %s goes first." % [game_no, names[first_player]])


func _on_game_over() -> void:
	var w: int = game.winner
	if w == -1:
		return
	scores[w] += 1
	last_loser = 1 - w
	history.append({"game": game_no, "winner": w, "turns": game.turn, "hp": [game.players[0]["hp"], game.players[1]["hp"]]})
	_log("Game %d: %s wins. Score %d-%d." % [game_no, names[w], scores[0], scores[1]])
	if scores[w] >= wins_needed():
		stage = STAGE_OVER
		_log("%s wins the series %d-%d." % [names[w], scores[0], scores[1]])
		return
	stage = STAGE_REWARDS
	for p in 2:
		rewards[p] = {"left": int(cfg["rewards_per_game"]), "offer": [], "done": false, "taken": []}
		_new_add_offer(p)


## Leaves the finished game visible until rewards complete; then the next game replaces it.
func _new_add_offer(p: int) -> void:
	var pool := []
	for d in CardDB.all():
		if CardScripts.is_implemented(d["id"]) and d["category"] != "basic_unit":
			pool.append(d["id"])
	var offer := []
	for i in mini(int(cfg["reward_add_offer_count"]), pool.size()):
		var j := rng.randi_range(0, pool.size() - 1)
		offer.append(pool[j])
		pool.remove_at(j)
	rewards[p]["offer"] = offer


func _reward_command(p: int, cmd: Dictionary) -> String:
	var r: Dictionary = rewards[p]
	if r["done"]:
		return "You have finished choosing rewards."
	var t: String = cmd.get("t", "")
	match t:
		"reward_add":
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= r["offer"].size():
				return "Invalid card choice."
			var id: int = r["offer"][i]
			decks[p].append(id)
			r["taken"].append("Added %s" % CardDB.get_def(id)["name"])
			_new_add_offer(p)
		"reward_remove":
			var id2 := int(cmd.get("card_id", -1))
			if not (id2 in decks[p]):
				return "That card is not in your deck."
			if decks[p].size() <= 1:
				return "Your deck cannot be empty."
			decks[p].erase(id2)
			r["taken"].append("Removed %s" % CardDB.get_def(id2)["name"])
		"reward_basic":
			var from_id := int(cmd.get("from_id", -1))
			var to_type: String = cmd.get("to_type", "")
			if not (from_id in decks[p]) or CardDB.get_def(from_id)["category"] != "basic_unit":
				return "Choose a basic unit in your deck."
			var to_id := basic_variant(from_id, to_type)
			if to_id == -1 or to_id == from_id:
				return "Choose a different Type."
			var changed_n := 0
			for i in decks[p].size():
				if decks[p][i] == from_id:
					decks[p][i] = to_id
					changed_n += 1
					if not cfg["basic_change_all_copies"]:
						break
			r["taken"].append("Changed %d %s to %s" % [changed_n, CardDB.get_def(from_id)["name"], CardDB.get_def(to_id)["name"]])
		"reward_finish":
			r["left"] = 0
		_:
			return "Choose a reward."
	if t != "reward_finish":
		r["left"] -= 1
	if r["left"] <= 0:
		r["done"] = true
		_log("%s finishes choosing rewards." % names[p])
	if rewards[0]["done"] and rewards[1]["done"]:
		stage = STAGE_FIRST
	return ""


## The basic unit with the same Race and the requested Type, or -1.
static func basic_variant(from_id: int, to_type: String) -> int:
	var src := CardDB.get_def(from_id)
	for d in CardDB.all():
		if d["category"] == "basic_unit" and d["race"] == src["race"] and d["type"] == to_type:
			return d["id"]
	return -1


func _first_command(p: int, cmd: Dictionary) -> String:
	if cmd.get("t", "") != "first_player":
		return "Waiting for the first-player choice."
	if p != last_loser:
		return "The loser of the previous game chooses who goes first."
	var w := int(cmd.get("who", -1))
	if w != 0 and w != 1:
		return "Choose a player."
	first_player = w
	_log("%s chooses %s to go first." % [names[p], names[w]])
	_start_game()
	return ""


# ---------------------------------------------------------------- views

func view_for(p: int) -> Dictionary:
	var v := {"you": p, "stage": stage, "scores": scores.duplicate(), "game_no": game_no,
		"best_of": cfg["best_of"], "names": names.duplicate(), "series_log": series_log.duplicate(),
		"history": history.duplicate(true), "last_loser": last_loser, "deck_mode": cfg["deck_mode"],
		"deck_ready": deck_ready.duplicate(), "deck_name": deck_names[p], "forfeit_by": forfeit_by}
	if game != null:
		v["match"] = MatchView.build(game, p)
	match stage:
		STAGE_DECKS:
			if cfg["deck_mode"] == "starter":
				v["starters"] = starters.map(func(s): return {"name": s["name"], "theme": s["theme"],
					"main": s["main"].map(func(i): return _card_summary(i)), "extra": s["extra"].map(func(i): return _card_summary(i))})
			else:
				_ensure_offer(p)
				var st: Dictionary = draft[p]
				v["draft"] = {"step": st["step"], "total": st["order"].size(),
					"category": st["order"][st["step"]] if st["step"] < st["order"].size() else "",
					"offer": st["offer"].map(func(i): return _card_summary(i)), "picked": st["picked"].map(func(i): return _card_summary(i))}
		STAGE_REWARDS:
			var r: Dictionary = rewards[p]
			v["rewards"] = {"left": r["left"], "done": r["done"], "taken": r["taken"].duplicate(),
				"offer": r["offer"].map(func(i): return _card_summary(i)),
				"opponent_done": rewards[1 - p]["done"], "basic_types": CardDB.ELEMENTS}
	if stage in [STAGE_REWARDS, STAGE_FIRST, STAGE_OVER, STAGE_DECKS]:
		v["deck"] = decks[p].map(func(i): return _card_summary(i))
	return v


static func _card_summary(id: int) -> Dictionary:
	var d := CardDB.get_def(id)
	return {"id": id, "name": d["name"], "category": d["category"], "cost_text": CardDB.cost_label(d),
		"atk": d["atk"], "def": d["def"], "type": d["type"], "race": d["race"],
		"text": MatchView._rules_text(d), "support": CardScripts.support_status(id)}
