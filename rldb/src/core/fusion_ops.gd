class_name FusionOps
extends SpecialOps
## Fusion summoning: which Fusion units can be summoned from the current board, material
## selection against each recipe requirement, and the tribute of the chosen materials.


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


## True when `chosen` can be completed into a distinct assignment of `reqs` from `pool`.
## `need_field`: the assignment must use at least one Field material, because only a Field
## material leaving frees a zone for the Fusion unit (P-16, F03-08).
func _assignable(reqs: Array, pool: Array, chosen: Array, need_field: bool = false) -> bool:
	var i := chosen.size()
	if i >= reqs.size():
		if not need_field:
			return true
		for c in chosen:
			if unit_on_field(c):
				return true
		return false
	for u in pool:
		if u in chosen:
			continue
		if _req_ok(u, reqs[i], chosen):
			if _assignable(reqs, pool, chosen + [u], need_field):
				return true
	return false


## True when p has no free unit zone, so a Fusion summon needs a Field material to free one.
## A method unit that leaves the Field to pay (`exclude`, e.g. Void Basilisk) frees its own zone.
func _fusion_needs_field_mat(p: int, exclude: int = -1) -> bool:
	if not free_unit_slots(p).is_empty():
		return false
	return not (exclude != -1 and unit_on_field(exclude) and cards[exclude]["ctl"] == p)


## Fusion materials player p could use among `sources`, optionally excluding one uid.
## Owner rule 2026-10-18: no Fusion, Ritual or Arcane summon happens in the Battle Phase (either
## player's), whatever card offers it.
const NO_EXTRA_IN_BATTLE := "Fusion, Ritual and Arcane summons cannot be made in the Battle Phase."


## True while Extra Deck summons are not allowed (the Battle Phase).
func extra_summons_locked() -> bool:
	return phase == PHASE_BATTLE


## Fusion units player p could summon now from `sources`; none in the Battle Phase.
func fusion_candidates(p: int, sources: Array, exclude: int = -1) -> Array:
	if extra_summons_locked():
		return []
	var pool := _fusion_pool(p, sources).filter(func(u): return u != exclude)
	var need_field := _fusion_needs_field_mat(p, exclude)
	var out := []
	for u in players[p]["extra"]:
		if category(u) != "fusion" or _summon_blocked(p, unit_type(u)):
			continue
		var reqs: Array = script_of(u).get("fusion", [])
		if reqs.is_empty():
			continue
		if _assignable(reqs, pool, [], need_field):
			out.append(u)
	return out


## Ends the effect quietly when no Fusion Summon from `sources` is possible right now, so an
## optional "You can Fusion Summon" (Tag Team - S, Bronze Salaman) is never offered for nothing.
func _op_fusion_possible(f: Dictionary, op: Dictionary) -> int:
	return R.CONT if not fusion_candidates(f["ctl"], op["sources"]).is_empty() else R.END


## F04-22 / F07 (2026-10-17): every Fusion method makes all of its choices first, while its
## source is still where it was: the Fusion unit, each material (picked on the board for Field
## materials), the zone and the stance. The Attack/Defense stance choice is the final, committing
## step (F07 removed the separate Confirm). Until then everything is cancellable and nothing has
## changed (only frame vars are written). Costs, self-destruction / exhaustion, the response
## window and the summon follow; `_op_fusion` rechecks the plan before anything is tributed.
## Op fields: sources, exclude_self (the paying unit leaves, so it is never a material and frees
## its own zone), cancellable.
func _op_fusion_pick(f: Dictionary, op: Dictionary) -> int:
	var cancellable: bool = op.get("cancellable", true)
	var ans: Variant = take_answer(f)
	if ans != null:
		_fusion_plan_ops(f, int(ans[0]), op["sources"], op.get("exclude_self", false), cancellable)
		return R.CONT
	f["vars"].erase("fusion_ready")
	if op.get("exclude_self", false):
		f["vars"]["fusion_exclude"] = f["src"]     # the paying unit is never its own material
	var cands := fusion_candidates(f["ctl"], op["sources"], f["vars"].get("fusion_exclude", -1))
	if cands.is_empty():
		add_log(NO_EXTRA_IN_BATTLE if extra_summons_locked() else "No Fusion Summon is possible.")
		return R.END
	var opts := []
	for u in cands:
		opts.append(card_option(u))
	return ask(f, f["ctl"], "select", "Choose a Fusion unit to summon.", opts, 1, 1, cancellable, {"reveal_pile": true})


## Splices the material, zone and stance choices for Fusion unit `fu`.
func _fusion_plan_ops(f: Dictionary, fu: int, sources: Array, leaves: bool, cancellable: bool) -> void:
	f["vars"]["fusion"] = fu
	f["vars"]["fmats"] = []
	f["vars"]["fsources"] = sources
	var ops := []
	for i in script_of(fu)["fusion"].size():
		ops.append({"op": "fusion_mat", "i": i, "cancellable": cancellable})
	# Zones the Field materials (and a paying unit that leaves) will free count (P-16).
	ops.append({"op": "pick_slot", "zone": "unit", "as": "fslot", "freeing": "$fmats", "free_src": leaves, "for": fu, "cancellable": cancellable})
	ops.append({"op": "pick_stance", "as": "stance", "for": fu, "cancellable": cancellable})
	ops.append({"op": "fusion_ready"})
	_splice(f, ops)


## F07: the stance answer completes the plan; no further Confirm prompt is asked.
func _op_fusion_ready(f: Dictionary, op: Dictionary) -> int:
	f["vars"]["fusion_ready"] = true
	return R.CONT


## True while the confirmed plan (Fusion unit, materials in requirement order) is still legal:
## rechecked after the cost, the response window and any triggers (P-15 / P-16).
func _fusion_plan_valid(f: Dictionary) -> bool:
	var p: int = f["ctl"]
	var fu: int = f["vars"].get("fusion", -1)
	if not (fu in players[p]["extra"]) or _summon_blocked(p, unit_type(fu)):
		return false
	var reqs: Array = script_of(fu).get("fusion", [])
	var mats: Array = f["vars"].get("fmats", [])
	if mats.size() != reqs.size():
		return false
	var ex: int = f["vars"].get("fusion_exclude", -1)
	var pool := _fusion_pool(p, f["vars"]["fsources"]).filter(func(u): return u != ex)
	var chosen := []
	for i in mats.size():
		var m: int = mats[i]
		if not (m in pool) or m in chosen or not _req_ok(m, reqs[i], chosen):
			return false
		chosen.append(m)
	if free_unit_slots(p).is_empty():
		for m in mats:
			if unit_on_field(m):
				return true
		return false
	return true


## Skips the rest of a failed effect; a used Spell/Trap still finishes.
func _fusion_fizzle(f: Dictionary) -> int:
	for j in range(f["pc"] + 1, f["ops"].size()):
		if f["ops"][j]["op"] == "finish_card":
			f["pc"] = j
			return R.STAY
	return R.END


## The Fusion summon itself. With a completed plan it tributes and places; without one (a
## triggered method such as Tag Team - S) it first runs the same choice steps.
func _op_fusion(f: Dictionary, op: Dictionary) -> int:
	var p: int = f["ctl"]
	if not f["vars"].get("fusion_ready", false):
		if op.get("planned", false):
			return R.CONT                 # the plan was abandoned (no candidates / materials)
		_splice(f, [{"op": "fusion_pick", "sources": op["sources"], "cancellable": not f["committed"]},
			{"op": "fusion", "sources": op["sources"], "planned": true}])
		return R.CONT
	f["vars"].erase("fusion_ready")
	var fu: int = f["vars"]["fusion"]
	if not _fusion_plan_valid(f):
		add_log("The chosen Fusion materials are no longer available, so the Fusion Summon of %s fails." % name_of(fu))
		return _fusion_fizzle(f)
	var ops := [{"op": "fusion_tribute"}, {"op": "place", "target": fu, "slot": "$fslot", "stance": "$stance"}, {"op": "tribute_bonus", "target": fu}]
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
	var need_field := _fusion_needs_field_mat(f["ctl"], ex)
	var ok := []
	for u in pool:
		if u in chosen or not _req_ok(u, reqs[op["i"]], chosen):
			continue
		if _assignable(reqs, pool, chosen + [u], need_field):
			ok.append(u)
	if ok.is_empty():
		add_log("Fusion materials are no longer available.")
		return R.END
	# F04-22 / 2026-10-15: each material is picked by the player, even a sole legal one.
	var opts := []
	for u in ok:
		opts.append(card_option(u, "%s (%s)" % [name_of(u), cards[u]["zone"].capitalize()]))
	return ask(f, f["ctl"], "select", "Choose %s for the summon of %s (material %d of %d)." % [_a_an(_req_text(reqs[op["i"]])), name_of(fu), op["i"] + 1, reqs.size()],
		opts, 1, 1, op.get("cancellable", false), {"reveal_pile": true, "placing": fu})   # arrow from the Fusion unit (2026-10-18)


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
