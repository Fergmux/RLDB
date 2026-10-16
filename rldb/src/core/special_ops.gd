class_name SpecialOps
extends EffectEngine
## Operations with card-specific semantics that do not reduce to the generic ops:
## special summons, Fusion, control change, stat copying and the two rule-bending
## Spells (Freaky Funday, Sneaky Snunday). Each is explicit and named.


## Ops appended after a unit lands: trap response window, then On Summon triggers.
func summon_tail(uid: int, p: int = -1) -> Array:
	if p == -1:
		p = cards[uid]["owner"]
	# P-22: the unit's own On Summon effects resolve before summon-response Traps.
	return [{"op": "summoned", "target": uid},
		{"op": "window", "event": {"name": "summon", "player": p, "card": uid, "text": "%s summons %s" % [pname(p), name_of(uid)]}}]


func _op_let(f: Dictionary, op: Dictionary) -> int:
	f["vars"][op["as"]] = eval_num(f, op["n"])
	return R.CONT


## Cost change limited to this turn (Tag Team searches).
func _op_cost_turn(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		cards[u]["cost_t"].append({"n": op["n"], "turn": turn})
		add_log("%s costs %+d AP this turn." % [public_label(u) if cards[u]["zone"] != "hand" else "That card", op["n"]],
			{cards[u]["owner"]: "%s costs %+d AP this turn." % [name_of(u), op["n"]]})
	return R.CONT


## Persistent cost change for the rest of this game (resets between games).
func _op_cost_perm(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		change_cost_perm(u, -op["n"] if f["reversed"] else op["n"])
	return R.CONT


func _op_near_self(f: Dictionary, op: Dictionary) -> int:
	f["vars"][op["as"]] = [f["src"]] + adjacent_units(f["src"])
	return R.CONT


func _op_declare_type(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = op["types"][ans[0]]
		return R.CONT
	var opts := []
	for i in op["types"].size():
		var ty: String = op["types"][i]
		opts.append({"v": i, "label": ty if ty != "" else "No type"})
	return ask(f, f["ctl"], "mode", "Choose a Type.", opts)


func _op_set_declared(f: Dictionary, op: Dictionary) -> int:
	cards[f["src"]]["declared_type"] = f["vars"][op["var"]]
	add_log("%s declares %s: all Mage units on the Field become that Type." % [name_of(f["src"]), _type_name(f["vars"][op["var"]])])
	return R.CONT


func _type_name(t: String) -> String:
	return t if t != "" else "no type"


func _op_set_type(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		if unit_on_field(u):
			cards[u]["type_o"] = f["vars"][op["var"]]
			add_log("%s becomes %s." % [name_of(u), _type_name(f["vars"][op["var"]])])
	return R.CONT


## ATK/DEF (and Race or Type) become those of another unit — a snapshot copy.
func _op_copy_stats(f: Dictionary, op: Dictionary) -> int:
	var from := refs(f, op["from"])
	if from.is_empty() or not unit_on_field(f["src"]):
		return R.CONT
	var s: int = from[0]
	var me: int = f["src"]
	cards[me]["base_atk"] = atk_of(s)
	cards[me]["base_def"] = def_of(s)
	if op.get("race", false):
		cards[me]["race_o"] = unit_race(s)
	if op.get("type", false):
		cards[me]["type_o"] = unit_type(s)
	add_log("%s copies %s: now %d/%d." % [name_of(me), name_of(s), atk_of(me), def_of(me)])
	return R.CONT


## Spirit Bomb: gains a copy of every Buff stack on other units on the Field.
func _op_copy_all_buffs(f: Dictionary, op: Dictionary) -> int:
	var me: int = f["src"]
	var totals := {}
	for u in all_field_units():
		if u == me:
			continue
		for s in cards[u]["st"]:
			if CardDB.is_buff(s):
				totals[s] = totals.get(s, 0) + cards[u]["st"][s]
	for s in CardDB.STATUS_ORDER:
		if totals.has(s):
			apply_status(me, s, totals[s])
	if totals.is_empty():
		add_log("%s: no Buffs on the Field to copy." % name_of(me))
	return R.CONT


## Dante: revive at the start of its controller's next turn.
func _op_delay_revive(f: Dictionary, op: Dictionary) -> int:
	players[f["ctl"]]["delayed"].append({"uid": f["src"]})
	return R.CONT


func _op_wukong_swap(f: Dictionary, op: Dictionary) -> int:
	var me: int = f["src"]
	if not unit_on_field(me) or status_count(me, "paralyse") > 0:
		return R.CONT
	var slot: int = cards[me]["slot"]
	var other := slot + 3 if slot < 3 else slot - 3
	if players[cards[me]["ctl"]]["units"][other] != -1:
		add_log("%s cannot move: the other zone in its column is occupied." % name_of(me))
		return R.CONT
	_splice(f, [{"op": "move_slot", "target": me, "slot": other}])
	return R.CONT


## Moves a unit to an adjacent or any free zone chosen by the controller.
func _op_move_unit(f: Dictionary, op: Dictionary) -> int:
	var t := refs(f, op["target"])
	if t.is_empty() or not unit_on_field(t[0]):
		return R.CONT
	var u: int = t[0]
	if status_count(u, "paralyse") > 0 or has_flag(u, "cant_move"):
		add_log("%s cannot move zone." % name_of(u))
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans != null:
		_splice(f, [{"op": "move_slot", "target": u, "slot": ans[0]}])
		return R.CONT
	var p: int = cards[u]["ctl"]
	var slots: Array = adjacent_slots(cards[u]["slot"]) if op["to"] == "adjacent" else range(UNIT_SLOTS)
	slots = slots.filter(func(s): return players[p]["units"][s] == -1)
	if slots.is_empty():
		add_log("No free zone to move %s to." % name_of(u))
		return R.CONT
	var opts := []
	for s in slots:
		opts.append({"v": s, "label": "%s row, column %d" % ["Front" if slot_row(s) == 0 else "Back", slot_col(s) + 1], "slot": s, "zone": "unit"})
	return ask(f, f["ctl"], "slot", "Move %s to which zone?" % name_of(u), opts)


## Special summon of a chosen card from a pile.
func _op_summon(f: Dictionary, op: Dictionary) -> int:
	var t := refs(f, op["target"])
	if t.is_empty():
		return R.CONT
	var u: int = t[0]
	if on_field(u):
		return R.CONT
	if _summon_blocked(f["ctl"], unit_type(u)):
		add_log("%s cannot be summoned (Bahatia)." % name_of(u))
		return R.CONT
	var ops := [{"op": "pick_slot", "zone": op.get("place", "any") if op.get("place", "any") != "any" else "unit", "as": "sslot", "for": u},
		{"op": "pick_stance", "as": "stance", "fixed": "atk" if op.get("stance", "choose") == "atk" else "", "for": u},
		{"op": "place", "target": u, "slot": "$sslot", "stance": "$stance"}]
	ops += summon_tail(u, f["ctl"])
	_splice(f, ops)
	return R.CONT


func _summon_blocked(p: int, t: String) -> bool:
	for u in field_units(opp(p)):
		if has_flag(u, "type_summon_lock") and unit_type(u) == t and t != "":
			return true
	return false


## Ambush: summon as many Basic Units as possible from Hand and Draw (Attack stance).
func _op_ambush(f: Dictionary, op: Dictionary) -> int:
	var p: int = f["ctl"]
	var pool: Array = players[p]["hand"].filter(func(u): return category(u) == "basic_unit") \
		+ players[p]["draw"].filter(func(u): return category(u) == "basic_unit")
	pool = pool.filter(func(u): return not _summon_blocked(p, unit_type(u)))   # blocked cards use no zone
	var ops := []
	var free := free_unit_slots(p)
	for i in mini(free.size(), pool.size()):
		var u: int = pool[i]
		ops.append({"op": "place", "target": u, "slot": free[i], "stance": "atk"})
		ops += summon_tail(u, p)
	if ops.is_empty():
		add_log("Ambush: no Basic Units could be summoned.")
	_splice(f, ops)
	return R.CONT


## Freaky Funday: until end of turn, switch ATK/DEF of all units currently on the Field.
func _op_swap_all(f: Dictionary, op: Dictionary) -> int:
	swap_turn = turn
	swap_uids = all_field_units()
	add_log("Freaky Funday: ATK and DEF of %d unit(s) are switched until end of turn." % swap_uids.size())
	return R.CONT


## Sneaky Snunday: until end of turn, numerical gains/losses from card effects are reversed.
## Applied per frame when a card is played, and to continuous auras while active.
func _op_reversal(f: Dictionary, op: Dictionary) -> int:
	if reversal_turn != turn:
		reversal_turn = turn
		reversal_count = 0
	reversal_count += 1
	if reversal_active():
		add_log("Sneaky Snunday: gains and losses from card effects are reversed until end of turn.")
	else:
		add_log("Sneaky Snunday: a second reversal cancels the first; gains and losses are normal again.")
	return R.CONT


## Hypnotise: take control of a unit until end of turn; it cannot be sacrificed.
func _op_take_control(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		if not unit_on_field(u):
			continue
		var free := free_unit_slots(f["ctl"])
		if free.is_empty():
			add_log("No free zone: control of %s cannot be taken." % name_of(u))
			continue
		var prev: int = cards[u]["ctl"]
		players[prev]["units"][cards[u]["slot"]] = -1
		cards[u]["ctl"] = f["ctl"]
		cards[u]["slot"] = free[0]
		cards[u]["control_until"] = turn
		players[f["ctl"]]["units"][free[0]] = u
		add_log("%s takes control of %s until end of turn." % [pname(f["ctl"]), name_of(u)])
	return R.CONT


## Plan B: destroy any number of your cards, gain 10 HP for each destroyed.
## Plan B: targets were chosen together, in order. Each destruction and its whole
## chain (own On Destruction effects, then listening Traps and their knock-ons)
## resolves before the next target; healing for cards actually destroyed comes last.
func _op_plan_b(f: Dictionary, op: Dictionary) -> int:
	f["vars"]["planb_count"] = 0
	var ops := []
	for u in refs(f, "$u"):
		ops.append({"op": "planb_destroy", "target": u})
	ops.append({"op": "planb_heal"})
	_splice(f, ops)
	return R.CONT


func _op_planb_destroy(f: Dictionary, op: Dictionary) -> int:
	var u: int = op["target"]
	if cards.has(u) and on_field(u) and destroy(u, "effect", f["src"], f["ctl"]):
		f["vars"]["planb_count"] += 1
	return R.CONT


func _op_planb_heal(f: Dictionary, op: Dictionary) -> int:
	var count: int = f["vars"].get("planb_count", 0)
	var gain := 10 * count
	if f["reversed"]:
		gain = -gain
	if count > 0:
		change_hp(f["ctl"], gain, " (Plan B, %d destroyed)" % count)
	return R.CONT


## No Loyalty: attacked unit gains ATK/DEF of an adjacent unit, which is sent to Spent.
func _op_no_loyalty(f: Dictionary, op: Dictionary) -> int:
	var tgt := refs(f, "event.target")
	if tgt.is_empty() or not unit_on_field(tgt[0]):
		return R.CONT
	var u: int = tgt[0]
	var ans: Variant = take_answer(f)
	var adj := adjacent_units(u)
	if adj.is_empty():
		add_log("No Loyalty: no adjacent unit.")
		return R.CONT
	if ans == null and adj.size() > 1:
		var opts := []
		for a in adj:
			opts.append(card_option(a))
		return ask(f, f["ctl"], "select", "Choose the adjacent unit to send to Spent.", opts)
	var a: int = adj[0] if ans == null else ans[0]
	var ga := atk_of(a)
	var gd := def_of(a)
	_leave_field(a, "spent", "effect")
	add_log("%s is sent to Spent." % name_of(a))
	_splice(f, [{"op": "stat", "target": u, "atk": ga, "def": gd}])
	return R.CONT


## Mirrorflesh Construct: ATK/DEF/Type become the combined values of its materials.
func _op_mirrorflesh(f: Dictionary, op: Dictionary) -> int:
	var me: int = f["src"]
	var mats: Array = cards[me].get("fusion_mats", [])
	var a := 0
	var df := 0
	for m in mats:
		a += m["atk"]
		df += m["def"]
	cards[me]["base_atk"] = a
	cards[me]["base_def"] = df
	cards[me]["type_o"] = mats[0]["type"] if not mats.is_empty() else ""
	add_log("%s becomes %d/%d, %s." % [name_of(me), a, df, _type_name(cards[me]["type_o"])])
	return R.CONT


func _op_roma(f: Dictionary, op: Dictionary) -> int:
	var me: int = f["src"]
	var n: int = cards[me].get("runes_used", 1)
	cards[me]["base_atk"] = 12 * n
	cards[me]["base_def"] = 12 * n
	add_log("Roma uses %d Rune(s): becomes %d/%d." % [n, 12 * n, 12 * n])
	return R.CONT


## Doubles debuff stacks directly (not a new application, so Cleanse does not intervene).
func _op_double_debuffs(f: Dictionary, op: Dictionary) -> int:
	var units: Array = all_field_units() if op["side"] == "any" else field_units(opp(f["ctl"]))
	for u in units:
		for s in cards[u]["st"].keys():
			if CardDB.is_debuff(s):
				cards[u]["st"][s] *= 2
	add_log("All Debuffs on %s are doubled." % ("the Field" if op["side"] == "any" else "the opponent's units"))
	return R.CONT


# ---------------------------------------------------------------- Fusion

func _fusion_pool(p: int, sources: Array) -> Array:
	var pool := []
	if "field" in sources:
		pool += field_units(p).filter(func(u): return not is_debilitated(u))
	if "spent" in sources:
		pool += players[p]["spent"].filter(func(u): return is_unit(u))
	if player_has_flag(p, "hand_fusion"):
		pool += players[p]["hand"].filter(func(u): return is_unit(u))
	return pool


func _mat_stats(u: int) -> Dictionary:
	if unit_on_field(u):
		return {"atk": atk_of(u), "def": def_of(u), "type": unit_type(u), "race": unit_race(u)}
	return {"atk": base_atk(u), "def": base_def(u), "type": unit_type(u), "race": unit_race(u)}


func _req_ok(u: int, req: Dictionary, chosen: Array) -> bool:
	var s := _mat_stats(u)
	for k in req:
		var v = req[k]
		match k:
			"race": if s["race"] != v: return false
			"type": if s["type"] != v: return false
			"category": if not (category(u) in v): return false
			"atk_min": if s["atk"] < v: return false
			"def_min": if s["def"] < v: return false
			"has_buff": if has_any_buff(u) != v: return false
			"has_debuff": if has_any_debuff(u) != v: return false
			"has_type": if (s["type"] != "") != v: return false
			"same_type_as":
				if chosen.size() <= v or s["type"] == "" or s["type"] != _mat_stats(chosen[v])["type"]: return false
	return true


func _assignable(reqs: Array, pool: Array, chosen: Array) -> bool:
	var i := chosen.size()
	if i >= reqs.size():
		return true
	for u in pool:
		if u in chosen:
			continue
		if _req_ok(u, reqs[i], chosen):
			if _assignable(reqs, pool, chosen + [u]):
				return true
	return false


func fusion_candidates(p: int, sources: Array, exclude: int = -1) -> Array:
	var pool := _fusion_pool(p, sources).filter(func(u): return u != exclude)
	var out := []
	for u in players[p]["extra"]:
		if category(u) != "fusion" or _summon_blocked(p, unit_type(u)):
			continue
		var reqs: Array = script_of(u).get("fusion", [])
		if reqs.is_empty():
			continue
		if _assignable(reqs, pool, []):
			out.append(u)
	return out


## Chooses the Fusion unit before an ability's cost is paid (cancellable). `_op_fusion` then
## uses this pick if it is still summonable.
func _op_fusion_pick(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"]["fusion_pre"] = ans[0]
		return R.CONT
	if op.get("exclude_self", false):
		f["vars"]["fusion_exclude"] = f["src"]     # the paying unit is never its own material
	var cands := fusion_candidates(f["ctl"], op["sources"], f["vars"].get("fusion_exclude", -1))
	if cands.is_empty():
		return R.END
	var opts := []
	for u in cands:
		opts.append(card_option(u))
	return ask(f, f["ctl"], "select", "Choose a Fusion unit to summon.", opts, 1, 1, true, {"reveal_pile": true})


func _op_fusion(f: Dictionary, op: Dictionary) -> int:
	var p: int = f["ctl"]
	var ans: Variant = take_answer(f)
	if ans == null and f["vars"].has("fusion_pre"):
		var pre: int = f["vars"]["fusion_pre"]
		f["vars"].erase("fusion_pre")
		if pre in fusion_candidates(p, op["sources"], f["vars"].get("fusion_exclude", -1)):
			ans = [pre]
	if ans == null:
		var cands := fusion_candidates(p, op["sources"], f["vars"].get("fusion_exclude", -1))
		if cands.is_empty():
			add_log("No Fusion Summon is possible.")
			return R.CONT
		var opts := []
		for u in cands:
			opts.append(card_option(u))
		return ask(f, p, "select", "Choose a Fusion unit to summon.", opts, 1, 1, false, {"reveal_pile": true})
	var fu: int = ans[0]
	f["vars"]["fusion"] = fu
	f["vars"]["fmats"] = []
	f["vars"]["fsources"] = op["sources"]
	var ops := []
	for i in script_of(fu)["fusion"].size():
		ops.append({"op": "fusion_mat", "i": i})
	# Zone is checked (counting zones the Field materials will free) before anything is consumed (P-16).
	ops.append({"op": "pick_slot", "zone": "unit", "as": "fslot", "freeing": "$fmats", "for": fu})
	ops.append({"op": "pick_stance", "as": "stance", "for": fu})
	ops.append({"op": "fusion_tribute"})
	ops.append({"op": "place", "target": fu, "slot": "$fslot", "stance": "$stance"})
	ops += summon_tail(fu, p)
	_splice(f, ops)
	return R.CONT


func _op_fusion_mat(f: Dictionary, op: Dictionary) -> int:
	var fu: int = f["vars"]["fusion"]
	var reqs: Array = script_of(fu)["fusion"]
	var chosen: Array = f["vars"]["fmats"]
	var ans: Variant = take_answer(f)
	if ans != null:
		chosen.append(ans[0])
		return R.CONT
	var ex: int = f["vars"].get("fusion_exclude", -1)
	var pool := _fusion_pool(f["ctl"], f["vars"]["fsources"]).filter(func(u): return u != ex)
	var ok := []
	for u in pool:
		if u in chosen or not _req_ok(u, reqs[op["i"]], chosen):
			continue
		if _assignable(reqs, pool, chosen + [u]):
			ok.append(u)
	if ok.is_empty():
		add_log("Fusion materials are no longer available.")
		return R.END
	if ok.size() == 1:
		chosen.append(ok[0])
		return R.CONT
	var opts := []
	for u in ok:
		opts.append(card_option(u, "%s (%s)" % [name_of(u), cards[u]["zone"].capitalize()]))
	return ask(f, f["ctl"], "select", "Choose %s for the summon of %s." % [_a_an(_req_text(reqs[op["i"]])), name_of(fu)], opts, 1, 1, false, {"reveal_pile": true})


## "a Fire unit" / "an Earth unit" (fusion material prompts).
static func _a_an(t: String) -> String:
	if t == "":
		return "a material"
	return ("an " if "AEIOUaeiou".contains(t.substr(0, 1)) else "a ") + t


## Material requirement as a noun phrase: "Fire Mage", "Basic Unit", "unit with at least 20 ATK".
func _req_text(req: Dictionary) -> String:
	var adj := []
	var noun := "unit"
	var tail := []
	for k in req:
		var v = req[k]
		match k:
			"type": adj.append(String(v))
			"race": noun = String(v)
			"category": noun = "Basic Unit" if "basic_unit" in v else "unit"
			"atk_min": tail.append("with at least %d ATK" % int(v))
			"def_min": tail.append("with at least %d DEF" % int(v))
			"has_buff": adj.append("buffed" if v else "unbuffed")
			"has_debuff": adj.append("debuffed" if v else "undebuffed")
			"has_type": tail.append("with a Type" if v else "with no Type")
			"same_type_as": tail.append("of the same Type")
	if noun == "Basic Unit" and req.has("race"):
		noun = "Basic " + String(req["race"])
	return " ".join(adj + [noun] + tail)


func _op_fusion_tribute(f: Dictionary, op: Dictionary) -> int:
	var fu: int = f["vars"]["fusion"]
	var mats := []
	for m in f["vars"]["fmats"]:
		mats.append(_mat_stats(m))
	cards[fu]["fusion_mats"] = mats
	_splice(f, [{"op": "tribute", "target": f["vars"]["fmats"].duplicate()}])
	return R.CONT
