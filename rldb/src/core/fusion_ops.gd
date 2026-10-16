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


## Fusion materials player p could use among `sources`, optionally excluding one uid.
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
