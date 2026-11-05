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

## Seat this brain plays.
var me: int = 1
## Random source.
var rng := RandomNumberGenerator.new()
## Explanation of the last best_action decision (move, margin, stance score breakdown).
var last_debug := ""


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
	var best_sim: MatchEngine = null
	for c in candidates(m):
		var sim := m.clone_for_sim()
		if sim.submit(me, c) != "":
			continue
		resolve(sim, 1)
		var s := evaluate(sim) + rng.randf_range(0.0, JITTER)
		if s > best_s:
			best_s = s
			best = c
			best_sim = sim
	last_debug = _debug_text(best, best_sim, best_s - base)
	return best


## Debug string for the last decision of best_action: the move, its margin over doing nothing
## and, for stance moves and summons, the stance score breakdown of the unit (F11).
func _debug_text(cmd: Dictionary, sim: MatchEngine, margin: float) -> String:
	var s := "%s margin %+.2f" % [cmd.get("t", "?"), margin]
	if sim != null and cmd.has("uid") and (cmd["t"] in ["stance", "summon", "ritual", "arcane"]):
		var u: int = int(cmd["uid"])
		if sim.unit_on_field(u):
			s += " :: " + BotStance.compare_text(sim, u, me)
	return s


## Legal actions of the bot right now, as commands (next_phase excluded).
func candidates(m: MatchEngine) -> Array:
	var out := []
	for a in MatchView.actions_for(m, me):
		# Ritual Tribute is the Extra Deck Ritual summon started from its material: already covered.
		# The plate's Sacrifice Unit button (J11) is the per-unit "sacrifice" with a pick: covered too.
		if not a.get("ok", false) or a["t"] in ["next_phase", "ritual_tribute", "sacrifice_pick"]:
			continue
		var cmd := {"t": a["t"], "uid": a["uid"]}
		if a.has("idx"):
			cmd["idx"] = a["idx"]
		if a.has("stance"):
			cmd["stance"] = a["stance"]
		if a.has("mode"):
			cmd["mode"] = a["mode"]          # G07: Attack / Attack Direct
		out.append(cmd)
	return out


## Answer to the bot's pending choice. depth 0 = the real game; deeper levels are simulations.
func choose(m: MatchEngine, depth: int) -> Dictionary:
	var pd: Dictionary = m.pending
	var opts: Array = pd["options"]
	var n := opts.size()
	if n == 0:
		return {"t": "cancel", "id": pd["id"]}
	if String(pd["kind"]) == "evolve":
		# L23 (owner, 2026-11-05): the bot always evolves.
		for i in n:
			if String(opts[i]["label"]) == MatchEngine.EVOLVE_YES:
				return {"t": "choose", "id": pd["id"], "indices": [i]}
	if int(pd["max"]) > 1:
		return {"t": "choose", "id": pd["id"], "indices": _multi_pick(m, depth)}
	if n == 1 or depth >= 2:
		return {"t": "choose", "id": pd["id"], "indices": [0]}
	var best_i := 0
	var best_s := -INF
	for i in mini(n, MAX_OPTIONS):
		# D13: the bot never stops responding for the rest of a turn; Skip covers one window.
		if pd["kind"] == "trap_response" and int(opts[i]["v"]) == EffectEngine.TRAP_V_PASS_TURN:
			continue
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
	# F03-04: an exact-total selection (Arcane materials) takes a combination hitting the total.
	if pd.get("total_exact", false):
		var vals := []
		for o in pd["options"]:
			vals.append(int(o.get("value", 0)))
		return SummonOps.exact_subset(vals, int(pd["total_required"]))
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
##
## B6 (owner feedback 2026-10-20, "the bot doesn't attack when it could easily kill a unit"): in
## the bot's own Battle Phase its units are scored on what they are (presence, stats, statuses),
## not on the attacks they could still make. The stance value counts an attack's potential (a kill
## plus PROTECTEE_W of the unit it would expose), so before this the bot kept the potential rather
## than cash it: killing a Defense guard in front of a strong back-row unit lowered its score. The
## opponent's threats still count, so it does not make attacks that leave it exposed.
func evaluate(m: MatchEngine) -> float:
	if m.winner == me:
		return 100000.0
	if m.winner != -1:
		return -100000.0
	var realized := realized_only(m)
	var s := 0.0
	for p in 2:
		var sign := 1.0 if p == me else -1.0
		var pl: Dictionary = m.players[p]
		s += sign * W_HP * float(pl["hp"])
		for u in m.field_units(p):
			s += sign * unit_value(m, u, realized and p == me)
		s += sign * W_POWER * float(m.power_cards(p).size())
		s += sign * W_SET * float(m.backrow_cards(p).size())
		s += sign * W_HAND * float(pl["hand"].size())
	if m.active == me:
		s += W_AP * float(m.players[me]["ap"])
	return s


## True while the bot is attacking (its own Battle Phase): its own units' attack potential is then
## left out of evaluate(), so an attack is judged by what it actually achieves (B6).
func realized_only(m: MatchEngine) -> bool:
	return m.active == me and m.phase == MatchEngine.PHASE_BATTLE


## Value of one unit on the field: presence, stats, a stance that suits its stats, statuses.
## `realized`: leave out the stance value (the attacks it could make), see evaluate().
func unit_value(m: MatchEngine, u: int, realized: bool = false) -> float:
	var atk := float(m.atk_of(u))
	var def := float(m.def_of(u))
	var v := W_UNIT + W_ATK * atk + W_DEF * def
	if not realized:
		v += float(BotStance.explain(m, u, me)["total"])   # F11: stance value (offense, threat, protection)
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
				# The bot keeps the default basic unit and drafts the open category each time; J30:
				# once every card is drafted it confirms at once.
				if s.draft_complete(me):
					return {"t": "draft_confirm"}
				s._ensure_offer(me)
				return {"t": "draft_pick", "index": rng.randi_range(0, maxi(0, s.draft[me]["offer"].size() - 1))}
			if s.bot_deck_pick():
				return {}   # J24: the player chooses this seat's deck (LocalHost "bot_deck")
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
			# G05: choose (when the bot lost), then press Start next duel at once, so the bot
			# never keeps the player waiting.
			if s.last_loser == me and not s.first_chosen:
				return {"t": "first_player", "who": me}
			if not s.duel_ready[me]:
				return {"t": "start_duel"}
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
