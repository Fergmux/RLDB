class_name BotBrain
extends RefCounted
## Heuristic opponent (no machine learning), reworked for L27 (owner feedback 2026-11-05: "smarter
## logic around positioning, stance, attack targets ... play better").
##
## How it decides. For every legal move it plays the move on a private copy of the match, lets the
## effects resolve (its own choices inside the effect are picked the same way, one level deeper)
## and scores the result with evaluate(). In the Setup and Recovery Phases the best few moves are
## also tried with the best follow-up move, so two-step plans (sacrifice then summon, buff then
## flip, summon a guard then a back-row unit) are found. It makes the best move while that beats
## moving on to the next phase by MARGIN.
##
## evaluate() looks past the move with BotForecast: the rest of the bot's own Battle Phase, the
## opponent's best reply on its next turn (it may change stance, and is expected to summon one
## more unit), then the bot's follow-up. On the board left after those battles it scores HP on a
## danger curve (hp_value: the last HP matter most, and a forecast kill is worth LETHAL_FORECAST),
## units (presence, ATK, DEF, statuses, Runes, effects), Powers, set cards, and AP and Hand
## cards while they can still be used this turn (nothing in the Recovery Phase: unspent AP and
## cards discarded at end of turn are wasted). So it takes lethal, attacks the protector before the
## unit behind it, avoids losing trades, keeps guards in Defense, puts fragile or valuable units
## behind a front unit, and grows its ATK on the Field.
##
## Fairness (the bot must never cheat): it thinks on belief(), a copy of the match holding only
## what its own seat may see (MatchView.can_see). Every card hidden from it (the opponent's Hand,
## Draw, Spent, Exhaust, Extra Deck and face-down cards) becomes an effectless placeholder; its own
## Draw is reshuffled (it knows the contents, not the order); the copy's random number generator is
## reseeded from the bot's own, so random effects are not foreseen; and the opponent's Trap prompts
## are off, so the opponent's set cards never act in its look-ahead. Deterministic for a seed.

## Score a move must beat moving on by before the bot makes it.
static var MARGIN := 0.5
## Random jitter added to each score (variety between games; deterministic for a seed).
static var JITTER := 0.3
## Weights of the position score (see evaluate()). Static vars, not consts, so the bot arena can
## try other values (tune()); the game always runs with these defaults.
static var W_HP := 1.0
static var DANGER := 18.0
static var DANGER_SCALE := 14.0
static var LETHAL_FORECAST := 120.0
static var W_POWER := 6.0
static var W_SET := 3.0
static var W_HAND := 0.4
static var W_HAND_OPP := 0.5
static var W_RETAIN := 1.5
static var W_AP := 0.8
## A back-row unit with no unit in front of it (it is as exposed as a front unit and blocks a
## protected zone).
static var W_BACK_EXPOSED := 0.0
## Extra value of each of the bot's own set cards per AP of its cost (it knows them; a dearer
## Trap or Spell is usually a stronger one).
static var W_SET_COST := 0.0
## Weight of the bot's follow-up turn in the forecast (it is further away and less certain).
static var FOLLOW_W := 0.35
## Two-step look-ahead: how many of the best first moves get a follow-up search.
static var TWO_STEP := 3
## Cap on look-ahead copies per decision (keeps every decision fast).
const MAX_SIMS := 260
const MAX_OPTIONS := 12
const MAX_RESOLVE_STEPS := 40
const MAX_COMBOS := 20
## Id of the effectless card that stands in for every hidden card in belief().
const PLACEHOLDER_ID := 1

## Seat this brain plays.
var me: int = 1
## Random source.
var rng := RandomNumberGenerator.new()
## Explanation of the last best_action decision (move, margin, stance score breakdown).
var last_debug := ""
## Look-ahead copies made by the current decision.
var _sims := 0


func _init(seat: int = 1, seed_value: int = -1) -> void:
	me = seat
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Overrides tuning weights by name, e.g. {"FOLLOW_W": 0.5, "VIRTUAL_ATK": 10} (bot arena
## experiments only). Returns the names it did not know.
static func tune(d: Dictionary) -> Array:
	var unknown := []
	for k in d:
		var v := float(d[k])
		match String(k):
			"MARGIN": MARGIN = v
			"JITTER": JITTER = v
			"W_HP": W_HP = v
			"DANGER": DANGER = v
			"DANGER_SCALE": DANGER_SCALE = v
			"LETHAL_FORECAST": LETHAL_FORECAST = v
			"W_POWER": W_POWER = v
			"W_SET": W_SET = v
			"W_HAND": W_HAND = v
			"W_HAND_OPP": W_HAND_OPP = v
			"W_RETAIN": W_RETAIN = v
			"W_AP": W_AP = v
			"W_BACK_EXPOSED": W_BACK_EXPOSED = v
			"W_SET_COST": W_SET_COST = v
			"FOLLOW_W": FOLLOW_W = v
			"TWO_STEP": TWO_STEP = int(v)
			"HPW": BotForecast.HPW = v
			"EXPOSE_W": BotForecast.EXPOSE_W = v
			"ECONOMY": BotForecast.ECONOMY = v
			"MIN_GAIN": BotForecast.MIN_GAIN = v
			"VIRTUAL_ATK": BotForecast.VIRTUAL_ATK = int(v)
			"VIRTUAL_DEF": BotForecast.VIRTUAL_DEF = int(v)
			"VIRTUAL_WORTH": BotForecast.VIRTUAL_WORTH = v
			"VIRTUAL_COUNT": BotForecast.VIRTUAL_COUNT = int(v)
			"W_UNIT": BotForecast.W_UNIT = v
			"W_ATK": BotForecast.W_ATK = v
			"W_DEF": BotForecast.W_DEF = v
			"W_STATUS": BotForecast.W_STATUS = v
			"W_EFFECT": BotForecast.W_EFFECT = v
			_: unknown.append(k)
	return unknown


## The command the bot wants to send now in match `m`, or {} when it has nothing to do (not its
## turn, or the human is deciding). `m` is never changed.
func decide(m: MatchEngine) -> Dictionary:
	if m.winner != -1:
		return {}
	if not m.pending.is_empty():
		if int(m.pending["player"]) != me:
			return {}
		return choose(belief(m), 0)
	if m.active != me or not m.stack.is_empty():
		return {}
	return best_action(belief(m))


# ---------------------------------------------------------------- fair information

## A copy of `m` holding only what seat `me` may see (see the class notes). The bot plays its
## look-ahead on it.
func belief(m: MatchEngine) -> MatchEngine:
	var b := m.clone_for_sim()
	var q := 1 - me
	for uid in b.cards:
		if MatchView.can_see(m, uid, me):
			continue
		var inst: Dictionary = b.cards[uid]
		inst["id"] = PLACEHOLDER_ID
		inst["st"] = {}
		inst["mods"] = []
		inst["runes"] = 0
		inst["cost_p"] = 0
		inst["cost_t"] = []
		inst["base_atk"] = null
		inst["base_def"] = null
		inst["type_o"] = null
		inst["race_o"] = null
	b.rng.seed = rng.randi()
	b.shuffle_array(b.players[me]["draw"])
	b.players[q]["trap_prompts"] = EffectEngine.TRAP_PROMPT_OFF
	return b


func _clone(m: MatchEngine) -> MatchEngine:
	_sims += 1
	return m.clone_for_sim()


# ---------------------------------------------------------------- moves

## Best legal action in `m` (a belief copy, or any match: it is not changed), or next_phase when
## nothing improves the position enough.
func best_action(m: MatchEngine) -> Dictionary:
	_sims = 0
	var base := _phase_end_score(m)
	var best := {"t": "next_phase"}
	var best_s := base + MARGIN
	var best_sim: MatchEngine = null
	var scored := []
	for c in candidates(m):
		var sim := _clone(m)
		if sim.submit(me, c) != "":
			continue
		resolve(sim, 1)
		var s := evaluate(sim) + rng.randf_range(0.0, JITTER)
		scored.append([s, c, sim])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	# Two-step plans in the Setup and Recovery Phases: the best first moves with their best follow-up.
	if m.phase != MatchEngine.PHASE_BATTLE:
		for i in mini(TWO_STEP, scored.size()):
			if _sims > MAX_SIMS:
				break
			var first: MatchEngine = scored[i][2]
			if first.winner != -1 or not first.pending.is_empty() or first.active != me or first.phase != m.phase:
				continue
			var follow := -INF
			for c2 in candidates(first):
				if _sims > MAX_SIMS:
					break
				var sim2 := _clone(first)
				if sim2.submit(me, c2) != "":
					continue
				resolve(sim2, 2)
				follow = maxf(follow, evaluate(sim2))
			if follow > scored[i][0]:
				scored[i][0] = lerpf(scored[i][0], follow, 0.85)
	for e in scored:
		if e[0] > best_s:
			best_s = e[0]
			best = e[1]
			best_sim = e[2]
	last_debug = _debug_text(best, best_sim, best_s - base)
	return best


## Score of moving on now: the position after next_phase from the Setup or Battle Phase (so the
## attacks the forecast expects are only credited once they are made), the position itself in the
## Recovery Phase (its end of turn). Moving on to the Recovery Phase does not spend AP or Hand
## cards, so they keep the value they have now (on turn 1 the Setup Phase leads straight to it).
func _phase_end_score(m: MatchEngine) -> float:
	if m.phase == MatchEngine.PHASE_MAIN2:
		return evaluate(m)
	var sim := _clone(m)
	if sim.submit(me, {"t": "next_phase"}) != "":
		return evaluate(m)
	resolve(sim, 2)
	if sim.winner != -1 or sim.active != me:
		return evaluate(sim)
	return evaluate(sim) - _resources(sim) + _resources(m)


## Debug string for the last decision of best_action: the move, its margin over moving on and,
## for stance moves and summons, the stance score breakdown of the unit (F11).
func _debug_text(cmd: Dictionary, sim: MatchEngine, margin: float) -> String:
	var s := "%s margin %+.2f (%d sims)" % [cmd.get("t", "?"), margin, _sims]
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
		# A unit whose stance was already changed this turn is not flipped back (no flip loops).
		if a["t"] == "stance" and int(m.cards[a["uid"]].get("stance_turn", -1)) == m.turn:
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


# ---------------------------------------------------------------- choices

## Answer to the bot's pending choice in `m`. depth 0 = the real decision; deeper levels are
## look-ahead. Any kind of prompt is answered (also kinds added after this was written): every
## option is tried on a copy and the best legal one is taken; if none can be tried, a legal
## default (the first options, or Cancel when nothing can be chosen).
func choose(m: MatchEngine, depth: int) -> Dictionary:
	var pd: Dictionary = m.pending
	var opts: Array = pd["options"]
	var n := opts.size()
	if n == 0:
		if pd.get("cancellable", false):
			return {"t": "cancel", "id": pd["id"]}
		return {"t": "choose", "id": pd["id"], "indices": []}
	# L23: the bot always evolves (owner rule, 2026-11-05).
	for i in n:
		if String(opts[i].get("label", "")).strip_edges().to_lower().begins_with("evolve"):
			return {"t": "choose", "id": pd["id"], "indices": [i]}
	if int(pd["max"]) > 1:
		return {"t": "choose", "id": pd["id"], "indices": _multi_pick(m, depth)}
	if n == 1 or depth >= 2:
		return {"t": "choose", "id": pd["id"], "indices": [_cheap_index(m, pd)]}
	var best_i := -1
	var best_s := -INF
	for i in mini(n, MAX_OPTIONS):
		# D13: the bot never stops responding for the rest of a turn; Skip covers one window.
		if pd["kind"] == "trap_response" and int(opts[i]["v"]) == EffectEngine.TRAP_V_PASS_TURN:
			continue
		var sim := _clone(m)
		if sim.submit(me, {"t": "choose", "id": pd["id"], "indices": [i]}) != "":
			continue
		resolve(sim, depth + 1)
		var s := evaluate(sim) + rng.randf_range(0.0, JITTER * 0.5)
		if s > best_s:
			best_s = s
			best_i = i
	if best_i == -1:
		return {"t": "choose", "id": pd["id"], "indices": [_first_legal(pd)]}
	return {"t": "choose", "id": pd["id"], "indices": [best_i]}


## Deep in a look-ahead (no more copies): a quick rule instead of trying every option.
## Unit zone: behind one of its own front units, else in front of one of its back units, else
## the front row. Attack target: the best battle preview. Otherwise the first legal option.
func _cheap_index(m: MatchEngine, pd: Dictionary) -> int:
	var opts: Array = pd["options"]
	if opts.size() <= 1:
		return 0
	if pd["kind"] == "slot" and String(opts[0].get("zone", "")) == "unit":
		var units: Array = m.players[me]["units"]
		var best := 0
		var best_v := -1
		for i in opts.size():
			var s: int = int(opts[i]["slot"])
			var v := 0
			if s >= 3 and units[s - 3] != -1:
				v = 3
			elif s < 3 and units[s + 3] != -1:
				v = 2
			elif s < 3:
				v = 1
			if v > best_v:
				best_v = v
				best = i
		return best
	if pd["kind"] == "attack_target":
		var a: int = int(pd.get("source", -1))
		var best2 := 0
		var best_v2 := -INF
		for i in opts.size():
			var pv: Dictionary = opts[i].get("preview", {})
			if pv.is_empty():
				continue
			var t: int = int(opts[i]["v"])
			var v2 := BotForecast.HPW * float(int(pv.get("dmg_opp", 0)) - int(pv.get("dmg_you", 0)))
			if pv.get("t_dies", false) and m.unit_on_field(t):
				v2 += BotForecast.worth(m, t)
			if pv.get("a_dies", false) and m.unit_on_field(a):
				v2 -= BotForecast.worth(m, a)
			if v2 > best_v2:
				best_v2 = v2
				best2 = i
		return best2
	return _first_legal(pd)


## First option that is not "Skip for the rest of this turn" (D13).
func _first_legal(pd: Dictionary) -> int:
	for i in pd["options"].size():
		if not (pd["kind"] == "trap_response" and int(pd["options"][i]["v"]) == EffectEngine.TRAP_V_PASS_TURN):
			return i
	return 0


## Multi-select. Exact-total selections (Arcane materials) take a combination hitting the total.
## Otherwise, when there are few combinations of the minimum size, each is tried on a copy and
## the best is taken; with many, options are tried one at a time (as the only extra pick) and the
## best ones are taken until the minimum is met.
func _multi_pick(m: MatchEngine, depth: int) -> Array:
	var pd: Dictionary = m.pending
	var n: int = pd["options"].size()
	if pd.get("total_exact", false):
		var vals := []
		for o in pd["options"]:
			vals.append(int(o.get("value", 0)))
		return SummonOps.exact_subset(vals, int(pd["total_required"]))
	var need: int = clampi(int(pd["min"]), 1, n)
	var combos := _combinations(n, need, MAX_COMBOS + 1)
	if depth < 2 and combos.size() <= MAX_COMBOS:
		var best: Array = []
		var best_s := -INF
		for cmb in combos:
			var sim := _clone(m)
			if sim.submit(me, {"t": "choose", "id": pd["id"], "indices": cmb}) != "":
				continue
			resolve(sim, depth + 1)
			var s := evaluate(sim) + rng.randf_range(0.0, JITTER * 0.5)
			if s > best_s:
				best_s = s
				best = cmb
		if not best.is_empty():
			return best
	# Many combinations (or deep in a look-ahead): rank options alone, keep the first legal set.
	var scored := []
	for i in n:
		scored.append([i, _option_rank(m, pd["options"][i])])
	scored.sort_custom(func(a, b): return a[1] > b[1])
	var picks := []
	for e in scored:
		picks.append(e[0])
		if picks.size() >= need:
			var sim2 := _clone(m)
			if sim2.submit(me, {"t": "choose", "id": pd["id"], "indices": picks.duplicate()}) == "":
				return picks
		if picks.size() >= int(pd["max"]):
			break
	return picks


## Cheap preference of one option of a multi-select: own cards it gives up are better cheap
## (materials, costs), the opponent's cards it hits are better valuable.
func _option_rank(m: MatchEngine, o: Dictionary) -> float:
	var u: int = int(o.get("uid", o.get("v", -1)))
	if not m.cards.has(u):
		return 0.0
	var v := float(m.current_cost(u)) if m.cards[u]["zone"] != "unit" else BotForecast.worth(m, u)
	return v if int(m.cards[u]["ctl"]) != me else -v


## Index combinations of size k out of n (at most `limit`).
static func _combinations(n: int, k: int, limit: int) -> Array:
	var out := []
	var idx := []
	for i in k:
		idx.append(i)
	if k > n:
		return out
	while out.size() < limit:
		out.append(idx.duplicate())
		var i := k - 1
		while i >= 0 and idx[i] == n - k + i:
			i -= 1
		if i < 0:
			break
		idx[i] += 1
		for j in range(i + 1, k):
			idx[j] = idx[j - 1] + 1
	return out


## Plays out pending choices in a look-ahead copy: the bot chooses for itself; the opponent takes
## the first options (its Traps are off in belief(), so it never responds).
func resolve(sim: MatchEngine, depth: int) -> void:
	for step in MAX_RESOLVE_STEPS:
		if sim.winner != -1 or sim.pending.is_empty():
			return
		var pd: Dictionary = sim.pending
		var who: int = int(pd["player"])
		var cmd: Dictionary
		if who == me:
			cmd = choose(sim, maxi(depth, 2) if _sims > MAX_SIMS else depth)
		else:
			var k: int = clampi(int(pd["min"]), 0, pd["options"].size())
			if pd["kind"] == "trap_response":
				k = 1
			cmd = {"t": "choose", "id": pd["id"], "indices": range(k)}
		if sim.submit(who, cmd) != "":
			if pd["cancellable"] and sim.submit(who, {"t": "cancel", "id": pd["id"]}) == "":
				continue
			var k2: int = clampi(int(pd["min"]), 1, maxi(1, pd["options"].size()))
			if sim.submit(who, {"t": "choose", "id": pd["id"], "indices": range(k2)}) != "":
				return


# ---------------------------------------------------------------- position score

## HP on a danger curve: every HP counts, the last ones count more, and none left is a loss.
static func hp_value(hp: float) -> float:
	if hp <= 0.0:
		return -LETHAL_FORECAST + hp
	return hp + DANGER * (1.0 - exp(-hp / DANGER_SCALE))


## Position score from the bot's point of view (higher is better for the bot). It looks past the
## position with BotForecast (see the class notes): the rest of the side to move's Battle Phase,
## the other side's reply, and the follow-up, then scores the board those battles leave.
##
## B6 (owner feedback 2026-10-20): an attack the bot could still make is credited through the
## forecast only, and best_action compares against the position after moving on, so the bot never
## prefers keeping an attack's potential to making it.
func evaluate(m: MatchEngine) -> float:
	if m.winner == me:
		return 100000.0
	if m.winner != -1:
		return -100000.0
	var q := 1 - me
	var s := BotForecast.snapshot(m)
	var mover := m.active
	var follow := 0.0
	if m.phase == MatchEngine.PHASE_BATTLE or (m.phase == MatchEngine.PHASE_MAIN1 and m.turn > 1):
		BotForecast.battle(s, mover, true, false, true)          # the rest of this Battle Phase
	s["active"] = 1 - mover                                        # Paralyse counts down at end of turn
	BotForecast.battle(s, 1 - mover, false, true, true)           # the other side's next turn
	s["active"] = mover
	var f := BotForecast.battle(s, mover, false, true, false)     # the mover's follow-up
	follow = float(f["value"]) if mover == me else -float(f["value"])
	var hp: Array = s["hp"]
	var v := W_HP * (hp_value(float(hp[me])) - hp_value(float(hp[q])))
	v += FOLLOW_W * clampf(follow, -60.0, 60.0)
	for r in s["units"]:
		if r["alive"]:
			var sign_u := 1.0 if int(r["p"]) == me else -1.0
			v += sign_u * float(r["worth"])
			if int(r["row"]) == 1 and not BotForecast._protected(s, r):
				v -= sign_u * W_BACK_EXPOSED          # a back-row zone with nothing in front of it
	for p in 2:
		var sign := 1.0 if p == me else -1.0
		v += sign * W_POWER * float(m.power_cards(p).size())
		v += sign * W_SET * float(m.backrow_cards(p).size())
	if W_SET_COST != 0.0:
		for u in m.backrow_cards(me):
			v += W_SET_COST * float(maxi(0, m.current_cost(u)))
	v += _resources(m)
	return v


## Value of the bot's Hand and AP while they can still be used this turn (none in the Recovery
## Phase but for retained cards), and of the opponent's Hand size.
func _resources(m: MatchEngine) -> float:
	var v := -W_HAND_OPP * float(m.players[1 - me]["hand"].size())
	var live := m.active == me and m.phase != MatchEngine.PHASE_MAIN2
	for u in m.players[me]["hand"]:
		if m.status_count(u, "retain") > 0:
			v += W_RETAIN
		elif live:
			v += W_HAND
		elif m.active != me:
			v += W_HAND_OPP
	if live:
		v += W_AP * float(m.players[me]["ap"])
	return v


## True while the bot is attacking (its own Battle Phase). Kept for callers of the pre-L27 API.
func realized_only(m: MatchEngine) -> bool:
	return m.active == me and m.phase == MatchEngine.PHASE_BATTLE


## Value of one unit on the Field (BotForecast.worth). `realized` is kept for the pre-L27 API.
func unit_value(m: MatchEngine, u: int, _realized: bool = false) -> float:
	return BotForecast.worth(m, u)


# ---------------------------------------------------------------- series stages

## Command for a non-game series stage (deck choice, draft, rewards, first player), or {}.
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
				return {"t": "draft_pick", "index": BotCards.best_index(s.draft[me]["offer"], s.draft[me]["picked"], rng)}
			if s.bot_deck_pick():
				return {}   # J24: the player chooses this seat's deck (LocalHost "bot_deck")
			return {"t": "pick_starter", "index": rng.randi_range(0, s.starters.size() - 1)}   # random deck
		Series.STAGE_REWARDS:
			var r: Dictionary = s.rewards[me]
			if r["done"]:
				return {}
			if r.get("pending", false):
				return {"t": "reward_add", "index": BotCards.best_index(r["offer"], s.decks[me], rng)}
			var cut := BotCards.removal(s.decks[me])
			if cut != -1 and int(r["left"]) % 2 == 0:
				return {"t": "reward_remove", "card_id": cut}
			return {"t": "reward_type", "category": BotCards.reward_category(s.decks[me], rng)}
		Series.STAGE_FIRST:
			# G05: choose (when the bot lost), then press Start next duel at once, so the bot
			# never keeps the player waiting. It goes first itself (L27 arena: neither seat has a
			# real edge between equal bots, and this bot does better going first).
			if s.last_loser == me and not s.first_chosen:
				return {"t": "first_player", "who": me}
			if not s.duel_ready[me]:
				return {"t": "start_duel"}
	return {}
