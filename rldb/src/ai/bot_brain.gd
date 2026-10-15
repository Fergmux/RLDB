class_name BotBrain
extends RefCounted
## Heuristic opponent (no machine learning). For every legal move it plays the move on a private
## copy of the match (MatchEngine.clone_for_sim), lets the effects resolve, and scores the result
## with evaluate(): HP difference, the value of each side's units (ATK/DEF, sensible stance,
## buffs/debuffs), Powers, set cards and cards in hand. It takes the best move while that beats
## doing nothing by a margin, otherwise it moves on to the next phase. Its own choices inside an
## effect (targets, zones, Trap responses) are picked the same way, one level deep.
##
## Fairness: the bot only scores public information. In its simulations the human always passes
## on Trap responses and the human's hand is only ever counted, never read. A small random jitter
## keeps it from playing identically every game.

## Score a move must beat "do nothing" by before the bot makes it.
const MARGIN := 1.0
const JITTER := 0.6
## Weights of the position score (see evaluate()).
const W_HP := 1.2
const W_UNIT := 6.0
const W_ATK := 0.45
const W_DEF := 0.35
const W_STATUS := 1.5
const W_POWER := 6.0
const W_SET := 3.0
const W_HAND := 0.5
const W_AP := 0.6
const MAX_OPTIONS := 12
const MAX_RESOLVE_STEPS := 40

var me: int = 1
var rng := RandomNumberGenerator.new()


func _init(seat: int = 1, seed_value: int = -1) -> void:
	me = seat
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## The command the bot wants to send now in match `m`, or {} when it has nothing to do (not its
## turn, or the human is deciding).
func decide(m: MatchEngine) -> Dictionary:
	if m.winner != -1:
		return {}
	if not m.pending.is_empty():
		if int(m.pending["player"]) != me:
			return {}
		return choose(m, 0)
	if m.active != me or not m.stack.is_empty():
		return {}
	return best_action(m)


## Best legal action, or next_phase when nothing improves the position enough.
func best_action(m: MatchEngine) -> Dictionary:
	var base := evaluate(m)
	var best := {"t": "next_phase"}
	var best_s := base + MARGIN
	for c in candidates(m):
		var sim := m.clone_for_sim()
		if sim.submit(me, c) != "":
			continue
		resolve(sim, 1)
		var s := evaluate(sim) + rng.randf_range(0.0, JITTER)
		if s > best_s:
			best_s = s
			best = c
	return best


## Legal actions of the bot right now, as commands (next_phase excluded).
func candidates(m: MatchEngine) -> Array:
	var out := []
	for a in MatchView.actions_for(m, me):
		if not a.get("ok", false) or a["t"] == "next_phase":
			continue
		var cmd := {"t": a["t"], "uid": a["uid"]}
		if a.has("idx"):
			cmd["idx"] = a["idx"]
		if a.has("stance"):
			cmd["stance"] = a["stance"]
		out.append(cmd)
	return out


## Answer to the bot's pending choice. depth 0 = the real game; deeper levels are simulations.
func choose(m: MatchEngine, depth: int) -> Dictionary:
	var pd: Dictionary = m.pending
	var opts: Array = pd["options"]
	var n := opts.size()
	if n == 0:
		return {"t": "cancel", "id": pd["id"]}
	if int(pd["max"]) > 1:
		return {"t": "choose", "id": pd["id"], "indices": _multi_pick(m, depth)}
	if n == 1 or depth >= 2:
		return {"t": "choose", "id": pd["id"], "indices": [0]}
	var best_i := 0
	var best_s := -INF
	for i in mini(n, MAX_OPTIONS):
		var sim := m.clone_for_sim()
		if sim.submit(me, {"t": "choose", "id": pd["id"], "indices": [i]}) != "":
			continue
		resolve(sim, depth + 1)
		var s := evaluate(sim) + rng.randf_range(0.0, JITTER * 0.5)
		if s > best_s:
			best_s = s
			best_i = i
	return {"t": "choose", "id": pd["id"], "indices": [best_i]}


## Multi-select: each option is scored alone (as if it were the only pick) and the best ones are
## taken until the minimum (and any cost total) is met.
func _multi_pick(m: MatchEngine, depth: int) -> Array:
	var pd: Dictionary = m.pending
	var n: int = pd["options"].size()
	var need: int = clampi(int(pd["min"]), 1, n)
	var scored := []
	for i in n:
		scored.append([i, rng.randf()])
	scored.sort_custom(func(a, b): return a[1] > b[1])
	var picks := []
	for e in scored:
		picks.append(e[0])
		if picks.size() >= need:
			var sim := m.clone_for_sim()
			if sim.submit(me, {"t": "choose", "id": pd["id"], "indices": picks.duplicate()}) == "":
				return picks
		if picks.size() >= int(pd["max"]):
			break
	return picks


## Plays out pending choices in a simulation: the bot chooses for itself, the human passes on
## Trap responses and otherwise takes the first options.
func resolve(sim: MatchEngine, depth: int) -> void:
	for step in MAX_RESOLVE_STEPS:
		if sim.winner != -1 or sim.pending.is_empty():
			return
		var pd: Dictionary = sim.pending
		var who: int = int(pd["player"])
		var cmd: Dictionary
		if who == me:
			cmd = choose(sim, depth)
		else:
			var k: int = clampi(int(pd["min"]), 1, pd["options"].size())
			cmd = {"t": "choose", "id": pd["id"], "indices": range(k)}
		if sim.submit(who, cmd) != "":
			if pd["cancellable"] and sim.submit(who, {"t": "cancel", "id": pd["id"]}) == "":
				continue
			return


## Position score from the bot's point of view (higher is better for the bot).
func evaluate(m: MatchEngine) -> float:
	if m.winner == me:
		return 100000.0
	if m.winner != -1:
		return -100000.0
	var s := 0.0
	for p in 2:
		var sign := 1.0 if p == me else -1.0
		var pl: Dictionary = m.players[p]
		s += sign * W_HP * float(pl["hp"])
		for u in m.field_units(p):
			s += sign * unit_value(m, u)
		s += sign * W_POWER * float(m.power_cards(p).size())
		s += sign * W_SET * float(m.backrow_cards(p).size())
		s += sign * W_HAND * float(pl["hand"].size())
	if m.active == me:
		s += W_AP * float(m.players[me]["ap"])
	return s


## Value of one unit on the field: presence, stats, a stance that suits its stats, statuses.
func unit_value(m: MatchEngine, u: int) -> float:
	var atk := float(m.atk_of(u))
	var def := float(m.def_of(u))
	var v := W_UNIT + W_ATK * atk + W_DEF * def
	var in_def: bool = m.cards[u]["stance"] == "def"
	if in_def and def > atk:
		v += 0.25 * def
	elif not in_def and atk >= def:
		v += 0.25 * atk
	for s in m.cards[u]["st"]:
		var n := float(m.cards[u]["st"][s])
		v += (W_STATUS if CardDB.is_buff(String(s)) else -W_STATUS) * minf(n, 4.0)
	v += 0.5 * float(m.cards[u]["runes"])
	return v


# ---------------------------------------------------------------- series stages

## Command for a non-game series stage (deck choice, rewards, first player), or {}.
func series_command(s: Series) -> Dictionary:
	match s.stage:
		Series.STAGE_DECKS:
			if s.deck_ready[me]:
				return {}
			if s.cfg["deck_mode"] == "draft":
				s._ensure_offer(me)
				return {"t": "draft_pick", "index": rng.randi_range(0, maxi(0, s.draft[me]["offer"].size() - 1))}
			return {"t": "pick_starter", "index": rng.randi_range(0, s.starters.size() - 1)}   # random deck
		Series.STAGE_REWARDS:
			var r: Dictionary = s.rewards[me]
			if r["done"]:
				return {}
			if r.get("pending", false):
				return {"t": "reward_add", "index": _best_offer(r["offer"])}
			var types := ["unit", "unit", "unit", "spell", "trap", "power"]
			return {"t": "reward_type", "category": types[rng.randi_range(0, types.size() - 1)]}
		Series.STAGE_FIRST:
			if s.last_loser == me:
				return {"t": "first_player", "who": me}
	return {}


## Strongest offered card (units by ATK+DEF, others at random).
func _best_offer(offer: Array) -> int:
	var best := 0
	var best_v := -1.0
	for i in offer.size():
		var d := CardDB.get_def(int(offer[i]))
		var v := rng.randf() * 10.0
		if d["atk"] != null:
			v = float(d["atk"]) + float(d["def"]) + rng.randf() * 4.0
		if v > best_v:
			best_v = v
			best = i
	return best
