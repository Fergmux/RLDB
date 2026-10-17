class_name Series
extends RefCounted
## Authority for a whole series: deck selection or draft, games, score, between-game
## rewards for both players and the loser's first-player choice. Wraps one
## MatchEngine per game. Per-game state (HP, statuses, runes, Exhaust, cost changes)
## is discarded between games because each game builds fresh card instances; only
## the deck lists and the score carry forward.

signal changed
## Emitted at between-game checkpoints (P-02: series can be saved/resumed between games).
signal checkpoint

const STAGE_DECKS := "decks"
const MAX_CUSTOM_DECK := 500
const STAGE_GAME := "game"
const STAGE_REWARDS := "rewards"
const STAGE_FIRST := "first_player"
const STAGE_OVER := "over"
## Card types offered by an add-card reward (user feedback 2026-10-16: choose the type first).
## F03-11: Fusion, Ritual and Arcane form one "extra" (Extra Deck) group drawing from all three.
const REWARD_TYPES := ["unit", "spell", "trap", "power", "extra"]
## Draft categories in their default pick order (F03-10 / F03-11: one combined Extra Deck
## category). F06-06: the basic unit is not a drafted category; each player chooses it by Type
## and Race in the draft setup and gets `basic_copies` copies. F06-05: each player may reorder
## these categories in the draft setup.
const DRAFT_CATEGORIES := ["unit", "spell", "trap", "power", "extra"]
## Quota key of the basic-unit category before F06-06; still accepted (and ignored) in old overrides.
const LEGACY_BASIC_KEY := "basic"
## Player-facing names of draft / reward categories.
const DRAFT_LABELS := {"unit": "Unit", "spell": "Spell", "trap": "Trap", "power": "Power", "extra": "Extra Deck"}
## Upper bound per draft category (a sanity limit for the setup steppers, not a deck rule).
const DRAFT_MAX_PER_CATEGORY := 40
const EXTRA_CATEGORIES := ["fusion", "ritual", "arcane"]

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
var save_id: String = ""             # identifies this series' save file
var seat_ids: Array = [0, 0]         # optional platform ids (e.g. SteamIDs) bound to seats
var client_token: String = ""        # network seat-1 token, kept so a resumed series binds the same player
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


## The draft counts per category from data/mode_config.json (the setup pickers' defaults).
static func default_draft_quota() -> Dictionary:
	var q: Dictionary = load_mode_config()["draft"]["quota"]
	var out := {}
	for cat in DRAFT_CATEGORIES:
		out[cat] = int(q.get(cat, 0))
	return out


## Why a draft composition is unusable ("" when it is fine): every category must be a whole
## number from 0 to DRAFT_MAX_PER_CATEGORY, unknown categories are refused, and at least one
## pick must be drafted (F03-10). The pre-F06-06 "basic" count is ignored, not refused.
static func validate_draft_quota(q) -> String:
	if not (q is Dictionary):
		return "The draft composition is missing."
	for k in q:
		if String(k) == LEGACY_BASIC_KEY:
			continue
		if not (String(k) in DRAFT_CATEGORIES):
			return "Unknown draft category \"%s\"." % String(k)
	var total := 0
	for cat in DRAFT_CATEGORIES:
		var v = q.get(cat, 0)
		if not (v is int or v is float) or float(v) != floorf(float(v)):
			return "%s picks must be a whole number." % DRAFT_LABELS[cat]
		if int(v) < 0 or int(v) > DRAFT_MAX_PER_CATEGORY:
			return "%s picks must be between 0 and %d." % [DRAFT_LABELS[cat], DRAFT_MAX_PER_CATEGORY]
		total += int(v)
	if total <= 0:
		return "Choose at least one card to draft."
	return ""


## Player-facing summary of a draft composition in `order` (default: DRAFT_CATEGORIES):
## "9 Unit, 3 Spell, ..." (zeros omitted).
static func draft_composition_text(q: Dictionary, order: Array = DRAFT_CATEGORIES) -> String:
	var parts := []
	for cat in order:
		var n := int(q.get(cat, 0))
		if n > 0:
			parts.append("%d %s" % [n, DRAFT_LABELS[cat]])
	return ", ".join(parts)


## The draft categories with at least one pick, in the default order: the categories a draft
## setup orders (F06-05).
static func draft_order_default(q: Dictionary) -> Array:
	return DRAFT_CATEGORIES.filter(func(cat): return int(q.get(cat, 0)) > 0)


## Why `order` is not a usable draft order for quota `q` ("" when it is): it must name every
## category with picks exactly once and nothing else (F06-05).
static func validate_draft_order(q: Dictionary, order) -> String:
	if not (order is Array):
		return "Choose an order for your draft categories."
	var want := draft_order_default(q)
	if order.size() != want.size():
		return "Order every draft category exactly once."
	var seen := {}
	for cat in order:
		if not (cat is String) or not (String(cat) in want) or seen.has(String(cat)):
			return "Order every draft category exactly once."
		seen[String(cat)] = true
	return ""


## The basic unit with this Type and Race, or -1 (F06-04 / F06-06).
static func basic_for(to_type: String, to_race: String) -> int:
	for d in CardDB.all():
		if d["category"] == "basic_unit" and d["type"] == to_type and d["race"] == to_race:
			return int(d["id"])
	return -1


## Every basic-unit Race, in card-database order (the Race choices of the basic-unit pickers).
static func basic_races() -> Array:
	var races := []
	for d in CardDB.all():
		if d["category"] == "basic_unit" and not (d["race"] in races):
			races.append(d["race"])
	return races


## The default basic unit of a draft setup: the first Type and the first Race (F06-06).
static func default_basic() -> int:
	var races := basic_races()
	for t in CardDB.ELEMENTS:
		for r in races:
			var id := basic_for(t, r)
			if id != -1:
				return id
	return -1


## "Basic Mage (Water)": basic-unit names do not carry their Type (F03-09), so it is added.
static func basic_label(id: int) -> String:
	var d := CardDB.get_def(id)
	return "%s (%s)" % [d["name"], d["type"]]


## overrides: best_of, deck_mode, seed, names, rewards_per_game, draft_quota (F03-10) ...
func setup(overrides: Dictionary = {}) -> void:
	CardDB.ensure_loaded()
	cfg = load_mode_config()
	var draft_over = overrides.get("draft", null)
	cfg.merge(overrides, true)
	if draft_over is Dictionary:
		# A partial "draft" override keeps the other draft settings (offer size, basic copies).
		var base: Dictionary = load_mode_config()["draft"]
		base.merge(draft_over, true)
		cfg["draft"] = base
	var quota_error := ""
	if overrides.has("draft_quota"):
		# F03-10: the series creator's (the host's) composition is authoritative for both seats.
		quota_error = validate_draft_quota(overrides["draft_quota"])
		if quota_error == "":
			var q := {}
			for cat in DRAFT_CATEGORIES:
				q[cat] = int(overrides["draft_quota"].get(cat, 0))
			cfg["draft"]["quota"] = q
	# F06-06: no basic-unit count (a pre-F06-06 config or override may still carry one).
	cfg["draft"]["quota"].erase(LEGACY_BASIC_KEY)
	_seed = int(cfg.get("seed", Time.get_ticks_usec()))
	rng.seed = _seed
	if cfg.has("names"):
		names = cfg["names"]
	starters = load_starters()
	save_id = "%d_%04d" % [int(Time.get_unix_time_from_system()), rng.randi_range(0, 9999)]
	stage = STAGE_DECKS
	if cfg["deck_mode"] == "draft":
		for p in 2:
			draft[p] = _new_draft()
	_log("Series start: best of %d, %s decks." % [cfg["best_of"], cfg["deck_mode"]])
	if cfg["deck_mode"] == "draft":
		if quota_error != "":
			# Explained, never silent: the menu blocks this, but a bad config from elsewhere is reported.
			_log("Draft composition not used (%s) The default counts apply." % quota_error)
		_log("Draft: %s, plus %d copies of a basic unit each player chooses." % [draft_composition_text(cfg["draft"]["quota"]), int(cfg["draft"]["basic_copies"])])


func _log(text: String) -> void:
	series_log.append(text)


func wins_needed() -> int:
	return int(cfg["best_of"]) / 2 + 1


# ---------------------------------------------------------------- commands

## Validates and applies a series-level or in-game command from player p.
func submit(p: int, cmd: Dictionary) -> String:
	var t: String = cmd.get("t", "")
	var err := ""
	if t == "forfeit_series":
		# Leaving mid-series (in-game menu: Return to menu / Quit): the whole series is lost and
		# the save is marked over so it is no longer offered under Resume.
		if stage == STAGE_OVER:
			return "The series is over."
		forfeit(p, "%s left the series" % names[p])
		checkpoint.emit()
		return ""
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


## P-02/P-06 (user): after the reconnection wait the host may claim the CURRENT GAME
## only; the series continues with normal win thresholds.
func award_game(p: int, reason: String) -> String:
	if stage != STAGE_GAME or game == null or game.winner != -1:
		return "There is no game in progress."
	game.end_game(p, reason)
	_on_game_over()
	changed.emit()
	return ""


## Serializable between-game checkpoint (not mid-game state, per the user's answer).
func to_save() -> Dictionary:
	return {"version": 1, "save_id": save_id, "cfg": cfg, "names": names, "stage": stage,
		"decks": decks, "deck_names": deck_names, "scores": scores, "game_no": game_no,
		"last_loser": last_loser, "first_player": first_player, "history": history,
		"rewards": rewards, "series_log": series_log, "forfeit_by": forfeit_by,
		"rng_state": str(rng.state), "seat_ids": seat_ids.map(func(x): return str(x)), "client_token": client_token,
		"saved_at": Time.get_datetime_string_from_system()}


## True when the series sits at a between-game checkpoint that can be saved.
func at_checkpoint() -> bool:
	return stage in [STAGE_REWARDS, STAGE_FIRST, STAGE_OVER]


## True when `d` (parsed JSON) looks like a to_save() checkpoint this version can restore. Saves
## are only ever written between games, so any other stage (e.g. a hand-edited "game") is refused.
static func is_valid_save(d) -> bool:
	if not (d is Dictionary):
		return false
	for k in ["save_id", "cfg", "names", "stage", "decks", "deck_names", "scores", "game_no", "last_loser",
			"first_player", "history", "rewards", "series_log", "rng_state"]:
		if not d.has(k):
			return false
	if not (d["cfg"] is Dictionary) or not d["cfg"].has("best_of"):
		return false
	if not (d["names"] is Array) or d["names"].size() != 2 or not (d["scores"] is Array) or d["scores"].size() != 2:
		return false
	if not (d["decks"] is Array) or d["decks"].size() != 2 or not (d["rewards"] is Array) or d["rewards"].size() != 2:
		return false
	return d["stage"] in [STAGE_REWARDS, STAGE_FIRST, STAGE_OVER]


## Restores a series saved with to_save(). JSON numbers come back as floats.
static func from_save(d: Dictionary) -> Series:
	var s := Series.new()
	CardDB.ensure_loaded()
	s.cfg = d["cfg"]
	s.names = d["names"]
	s.stage = d["stage"]
	s.decks = d["decks"].map(func(dk): return dk.map(func(i): return int(i)))
	s.deck_names = d["deck_names"]
	s.scores = d["scores"].map(func(x): return int(x))
	s.game_no = int(d["game_no"])
	s.last_loser = int(d["last_loser"])
	s.first_player = int(d["first_player"])
	s.history = d["history"]
	for h in s.history:
		h["winner"] = int(h["winner"])
		h["game"] = int(h["game"])
		h["turns"] = int(h["turns"])
		h["hp"] = h["hp"].map(func(x): return int(x))
	s.rewards = d["rewards"]
	for r in s.rewards:
		if not r.is_empty():
			r["left"] = int(r["left"])
			r["offer"] = r["offer"].map(func(i): return int(i))
			r["pending"] = bool(r.get("pending", false))
	s.series_log = d["series_log"]
	s.forfeit_by = int(d.get("forfeit_by", -1))
	s.save_id = d["save_id"]
	s.seat_ids = d.get("seat_ids", ["0", "0"]).map(func(x): return int(x))
	s.client_token = String(d.get("client_token", ""))
	s.rng.state = int(d["rng_state"])
	s.starters = load_starters()
	s.deck_ready = [true, true]
	s._log("Series resumed from save (%s)." % d.get("saved_at", "?"))
	return s


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
		"custom_deck":
			if cfg["deck_mode"] == "draft":
				return "This series uses drafting."
			var raw_cards = cmd.get("cards", [])
			if not (raw_cards is Array) or not (cmd.get("name", "") is String):
				return "Malformed deck."
			# Resource guard before parsing; the real size caps are DeckStore.validate below.
			if raw_cards.size() > MAX_CUSTOM_DECK:
				return "Decks are limited to %d cards for performance." % MAX_CUSTOM_DECK
			var ids := []
			for raw in raw_cards:
				if not (raw is int or raw is float):
					return "Malformed deck."
				var id := int(raw)
				if not CardDB.has(id):
					return "Unknown card id %d." % id
				ids.append(id)
			if ids.is_empty():
				return "A deck needs at least one card."
			var cap_err := DeckStore.validate(ids)   # F16: Main + Extra <= 99, Extra <= 15
			if cap_err != "":
				return cap_err
			decks[p] = ids        # Main/Extra placement follows each card's category at game start
			deck_names[p] = String(cmd.get("name", "Custom deck")).substr(0, 40)
			deck_ready[p] = true
			_log("%s locks in a custom deck." % names[p])
		"draft_setup":
			if cfg["deck_mode"] != "draft":
				return "This series uses starter decks."
			var e0 := _draft_setup(p, cmd)
			if e0 != "":
				return e0
		"draft_pick":
			if cfg["deck_mode"] != "draft":
				return "This series uses starter decks."
			if not draft[p]["setup_done"]:
				return "Choose your basic unit and category order, then start drafting."
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


## A seat's draft before its setup (F06-05): the default category order and basic unit until the
## seat locks in its own with "draft_setup"; no picks are offered until then.
func _new_draft() -> Dictionary:
	var quota: Dictionary = cfg["draft"]["quota"]
	var cats := draft_order_default(quota)
	return {"setup_done": false, "cat_order": cats, "basic": default_basic(),
		"order": _expand_order(cats), "step": 0, "picked": [], "offer": []}


## The pick sequence of a category order: each category repeated by its configured count.
func _expand_order(cats: Array) -> Array:
	var quota: Dictionary = cfg["draft"]["quota"]
	var order := []
	for cat in cats:
		for i in int(quota.get(cat, 0)):
			order.append(cat)
	return order


## F06-05 / F06-06: locks in seat p's category order and basic unit, then drafting starts.
## cmd: {"t": "draft_setup", "order": [category, ...], "basic_type": Type, "basic_race": Race}.
func _draft_setup(p: int, cmd: Dictionary) -> String:
	var st: Dictionary = draft[p]
	if st["setup_done"]:
		return "Your draft setup is already locked in."
	var quota: Dictionary = cfg["draft"]["quota"]
	var order = cmd.get("order", null)
	var oerr := validate_draft_order(quota, order)
	if oerr != "":
		return oerr
	var copies := int(cfg["draft"]["basic_copies"])
	var basic := -1
	if copies > 0:
		basic = basic_for(String(cmd.get("basic_type", "")), String(cmd.get("basic_race", "")))
		if basic == -1:
			return "Choose a Type and a Race for your basic unit."
	var cats: Array = order.map(func(c): return String(c))
	st["cat_order"] = cats
	st["order"] = _expand_order(cats)
	st["basic"] = basic
	st["setup_done"] = true
	st["step"] = 0
	st["offer"] = []
	st["picked"] = []
	for i in copies:
		st["picked"].append(basic)
	var basic_part: String = ("%d× %s, then " % [copies, basic_label(basic)]) if copies > 0 else ""
	_log("%s starts drafting: %s%s." % [names[p], basic_part, draft_composition_text(quota, cats)])
	if st["order"].is_empty():
		_finish_draft(p)
	else:
		_ensure_offer(p)
	return ""


func _finish_draft(p: int) -> void:
	decks[p] = draft[p]["picked"].duplicate()
	deck_names[p] = "Drafted deck"
	deck_ready[p] = true
	_log("%s finishes drafting." % names[p])


func _draft_pool(cat: String) -> Array:
	var out := []
	for d in CardDB.all():
		if not CardScripts.is_implemented(d["id"]):
			continue
		var c: String = d["category"]
		var ok := false
		match cat:
			"unit": ok = c == "unit"
			"spell", "trap", "power": ok = c == cat
			"extra": ok = c in EXTRA_CATEGORIES
		if ok:
			out.append(d["id"])
	return out


func _ensure_offer(p: int) -> void:
	var st: Dictionary = draft[p]
	if not st.get("setup_done", true) or st["step"] >= st["order"].size() or not st["offer"].is_empty():
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
	st["picked"].append(id)
	st["step"] += 1
	st["offer"] = []
	if st["step"] >= st["order"].size():
		_finish_draft(p)
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
		checkpoint.emit()
		return
	stage = STAGE_REWARDS
	for p in 2:
		# `pending`: a card type was chosen (its reward already spent) and one of `offer` must be taken.
		rewards[p] = {"left": int(cfg["rewards_per_game"]), "offer": [], "done": false, "taken": [], "pending": false, "offer_type": ""}
	checkpoint.emit()


## Implemented, non-basic cards of one reward type. "extra" (F03-11) is every Fusion, Ritual
## and Arcane card; the single categories still work for series saved before the change.
static func reward_pool(cat: String) -> Array:
	var cats: Array = EXTRA_CATEGORIES if cat == "extra" else [cat]
	var pool := []
	for d in CardDB.all():
		if CardScripts.is_implemented(d["id"]) and d["category"] in cats:
			pool.append(d["id"])
	return pool


## Draws the add-card offer for player p from the chosen type.
func _new_add_offer(p: int, cat: String) -> void:
	var pool := reward_pool(cat)
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
	if r.get("pending", false) and t != "reward_add":
		return "Pick one of the offered cards first."
	var spends := t in ["reward_type", "reward_remove", "reward_basic"]
	match t:
		"reward_type":
			# Choosing the type spends the reward at once; one of the offered cards must be taken.
			var cat: String = String(cmd.get("category", ""))
			if not (cat in REWARD_TYPES) or reward_pool(cat).is_empty():
				return "Choose a card type."
			_new_add_offer(p, cat)
			r["pending"] = true
			r["offer_type"] = cat
		"reward_add":
			if not r.get("pending", false):
				return "Choose a card type first."
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= r["offer"].size():
				return "Invalid card choice."
			var id: int = r["offer"][i]
			decks[p].append(id)
			r["taken"].append("Added %s" % CardDB.get_def(id)["name"])
			r["offer"] = []
			r["pending"] = false
			r["offer_type"] = ""
		"reward_remove":
			var id2 := int(cmd.get("card_id", -1))
			if not (id2 in decks[p]):
				return "That card is not in your deck."
			if decks[p].size() <= 1:
				return "Your deck cannot be empty."
			decks[p].erase(id2)
			r["taken"].append("Removed %s" % CardDB.get_def(id2)["name"])
		"reward_basic":
			var eb := _change_basics(p, cmd)
			if eb != "":
				return eb
		"reward_finish":
			r["left"] = 0
		_:
			return "Choose a reward."
	if spends:
		r["left"] -= 1
	if r["left"] <= 0 and not r.get("pending", false):
		r["done"] = true
		_log("%s finishes choosing rewards." % names[p])
	if rewards[0]["done"] and rewards[1]["done"]:
		stage = STAGE_FIRST
	checkpoint.emit()
	return ""


## F06-04 "Change basic units": EVERY basic unit in p's deck becomes the chosen variant in one
## step. cmd: {"t": "reward_basic", "to_type": Type, "to_race": Race}. A pre-F06-04 command with
## `from_id` is still accepted: an omitted race then keeps that unit's Race (otherwise the Race of
## the deck's first basic unit). A change that would alter nothing is refused.
func _change_basics(p: int, cmd: Dictionary) -> String:
	var idx := []
	for i in decks[p].size():
		if CardDB.get_def(decks[p][i])["category"] == "basic_unit":
			idx.append(i)
	if idx.is_empty():
		return "You have no basic units to change."
	var race := String(cmd.get("to_race", ""))
	if race == "":
		var from_id := int(cmd.get("from_id", -1))
		var src: int = decks[p][idx[0]]
		if from_id in decks[p] and CardDB.get_def(from_id)["category"] == "basic_unit":
			src = from_id
		race = String(CardDB.get_def(src)["race"])
	var to_id := basic_for(String(cmd.get("to_type", "")), race)
	if to_id == -1:
		return "Choose a Type and a Race for your basic units."
	var deck: Array = decks[p]
	if idx.all(func(i): return deck[i] == to_id):
		return "Your basic units are already %s. Choose a different Type or Race." % basic_label(to_id)
	for i in idx:
		deck[i] = to_id
	rewards[p]["taken"].append("Changed %d basic unit%s to %s" % [idx.size(), "" if idx.size() == 1 else "s", basic_label(to_id)])
	_log("%s changes their basic units to %s." % [names[p], basic_label(to_id)])
	return ""


## The basic unit with the requested Type and Race (default: the same Race), or -1.
static func basic_variant(from_id: int, to_type: String, to_race: String = "") -> int:
	var src := CardDB.get_def(from_id)
	var race: String = to_race if to_race != "" else String(src["race"])
	for d in CardDB.all():
		if d["category"] == "basic_unit" and d["race"] == race and d["type"] == to_type:
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
		"deck_ready": deck_ready.duplicate(), "deck_name": deck_names[p], "forfeit_by": forfeit_by,
		"save_id": save_id, "at_checkpoint": at_checkpoint()}
	if game != null:
		v["match"] = MatchView.build(game, p)
	match stage:
		STAGE_DECKS:
			if cfg["deck_mode"] == "starter":
				v["starters"] = starters.map(func(s): return {"name": s["name"], "theme": s["theme"],
					"main": s["main"].map(func(i): return card_summary(i)), "extra": s["extra"].map(func(i): return card_summary(i))})
			else:
				v["draft"] = _draft_view(p)
		STAGE_REWARDS:
			var r: Dictionary = rewards[p]
			var types := []
			for cat in REWARD_TYPES:
				if not reward_pool(cat).is_empty():
					types.append(cat)
			var races := basic_races()
			v["rewards"] = {"left": r["left"], "done": r["done"], "taken": r["taken"].duplicate(),
				"offer": r["offer"].map(func(i): return card_summary(i)), "pending": r.get("pending", false),
				"offer_type": r.get("offer_type", ""), "types": types,
				"opponent_done": rewards[1 - p]["done"], "basic_types": CardDB.ELEMENTS, "basic_races": races,
				"basic_options": basic_options()}
	if stage in [STAGE_REWARDS, STAGE_FIRST, STAGE_OVER, STAGE_DECKS]:
		v["deck"] = decks[p].map(func(i): return card_summary(i))
	return v


## Seat p's draft: its setup (order, basic unit, the Type and Race choices), its progress and
## offer. Of the other seat only the progress is shown, never its offer or picks (hidden info).
func _draft_view(p: int) -> Dictionary:
	_ensure_offer(p)
	var st: Dictionary = draft[p]
	var quota: Dictionary = cfg["draft"]["quota"]
	var dcat: String = st["order"][st["step"]] if st["setup_done"] and st["step"] < st["order"].size() else ""
	var opp: Dictionary = draft[1 - p]
	return {"setup_done": st["setup_done"], "cat_order": st["cat_order"].duplicate(),
		"basic": card_summary(st["basic"]) if st["basic"] != -1 else {},
		"basic_copies": int(cfg["draft"]["basic_copies"]), "basic_options": [] if st["setup_done"] else basic_options(),
		"basic_types": CardDB.ELEMENTS, "basic_races": basic_races(),
		"labels": DRAFT_LABELS.duplicate(),
		"step": st["step"], "total": st["order"].size(),
		"category": dcat, "category_label": DRAFT_LABELS.get(dcat, dcat.capitalize()),
		"quota": quota.duplicate(),
		"composition": draft_composition_text(quota, st["cat_order"]),
		"offer": st["offer"].map(func(i): return card_summary(i)), "picked": st["picked"].map(func(i): return card_summary(i)),
		"opponent": {"setup_done": opp["setup_done"], "step": opp["step"], "total": opp["order"].size()}}


## Card summaries of every basic unit (the Type x Race pickers' previews).
static func basic_options() -> Array:
	var out := []
	for d in CardDB.all():
		if d["category"] == "basic_unit":
			out.append(card_summary(int(d["id"])))
	return out


## Display summary of card `id` (name, cost, stats, rules text, support status) for menus and rewards.
static func card_summary(id: int) -> Dictionary:
	var d := CardDB.get_def(id)
	return {"id": id, "name": d["name"], "category": d["category"], "cost_text": CardDB.cost_label(d),
		"atk": d["atk"], "def": d["def"], "type": d["type"], "race": d["race"],
		"text": MatchView._rules_text(d), "support": CardScripts.support_status(id)}
