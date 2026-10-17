class_name SummonOps
extends BattleOps
## Placement and summoning ops: choosing a zone and stance, placing units / set cards / Powers,
## tribute, Ritual and Arcane materials, and Nimble zone moves.


# ---------------------------------------------------------------- placement

func _adjacent_free(uid: int) -> Array:
	var p: int = cards[uid]["ctl"]
	return adjacent_slots(cards[uid]["slot"]).filter(func(s): return players[p]["units"][s] == -1)



func _op_pick_slot(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans[0]
		return R.CONT
	var p: int = f["ctl"]
	var slots := []
	var free_after := refs(f, op["freeing"]) if op.has("freeing") else []
	match op["zone"]:
		"unit":
			slots = free_unit_slots(p)
			for m in free_after:
				if unit_on_field(m) and cards[m]["ctl"] == p:
					slots.append(cards[m]["slot"])
			# A paying unit that leaves before the summon (Sepukku, Void Basilisk) frees its zone.
			if op.get("free_src", false) and unit_on_field(f["src"]) and cards[f["src"]]["ctl"] == p and not (cards[f["src"]]["slot"] in slots):
				slots.append(cards[f["src"]]["slot"])
		"backrow": slots = free_backrow_slots(p)
		"power": slots = free_power_slots(p)
		"adjacent": slots = _adjacent_free(f["src"])
		"column", "orig": slots = placement_slots(f, op["zone"])
	slots.sort()
	if slots.is_empty():
		add_log("%s: no free zone." % f["label"])
		# The rest of the effect is skipped, but a used Spell/Trap still finishes.
		for j in range(f["pc"] + 1, f["ops"].size()):
			if f["ops"][j]["op"] == "finish_card":
				f["pc"] = j
				return R.STAY
		return R.END
	var opts := []
	for s in slots:
		var label := ""
		match op["zone"]:
			"unit", "adjacent", "column", "orig": label = "%s row, column %d" % ["Front" if slot_row(s) == 0 else "Back", slot_col(s) + 1]
			"backrow": label = "Trap/Spell zone, column %d" % (s + 1)
			"power": label = "Power zone %d" % (s + 1)
		opts.append({"v": s, "label": label, "slot": s, "zone": op["zone"]})
	# The prompt names the card being placed (a summoned Fusion unit, not the effect's source).
	var for_name: String = name_of(int(op["for"])) if op.has("for") else String(f["label"])
	return ask(f, p, "slot", "Choose a zone for %s." % for_name, opts, 1, 1, op.get("cancellable", false))


func _op_pick_stance(f: Dictionary, op: Dictionary) -> int:
	# `for`: the unit being summoned when it is not the frame's source (Fusion / special summons).
	var unit: int = int(op.get("for", f["src"]))
	if has_flag_raw(unit, "no_defense") or op.get("fixed", "") == "atk":
		f["vars"][op["as"]] = "atk"
		return R.CONT
	if op.get("fixed", "") == "def":
		f["vars"][op["as"]] = "def"
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = "atk" if ans[0] == 0 else "def"
		return R.CONT
	return ask(f, f["ctl"], "stance", "Choose a stance for %s." % name_of(unit),
		[{"v": 0, "label": "Attack stance"}, {"v": 1, "label": "Defense stance"}], 1, 1, op.get("cancellable", false))


func _op_place(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = refs(f, op["target"])[0]
	var slot: int = eval_num(f, op["slot"])
	var stance: String = f["vars"].get("stance", "atk") if op.get("stance", "") is String and String(op.get("stance", "")).begins_with("$") else op.get("stance", "atk")
	if players[f["ctl"]]["units"][slot] != -1:
		var free := free_unit_slots(f["ctl"])
		if free.is_empty():
			add_log("No free zone; the summon fails.")
			return R.END
		slot = free[0]
	place_unit(uid, f["ctl"], slot, stance)
	add_log("%s summons %s in %s stance (%s row, column %d)." % [pname(f["ctl"]), name_of(uid),
		"Attack" if stance == "atk" else "Defense", "front" if slot_row(slot) == 0 else "back", slot_col(slot) + 1])
	add_fx({"k": "summon", "p": f["ctl"], "slot": slot})
	return R.CONT


func _op_summoned(f: Dictionary, op: Dictionary) -> int:
	var uid: int = op["target"] if op["target"] is int else refs(f, op["target"])[0]
	if unit_on_field(uid):
		emit("summoned", {"self": uid, "ctl": cards[uid]["ctl"], "player": cards[uid]["ctl"]})
		emit("any_summoned", {"unit": uid, "ctl": cards[uid]["ctl"], "player": cards[uid]["ctl"]})
	return R.CONT


func _op_set_card(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var slot: int = eval_num(f, op["slot"])
	_remove_from_zone(uid)
	var inst: Dictionary = cards[uid]
	inst["zone"] = "backrow"
	inst["slot"] = slot
	inst["ctl"] = f["ctl"]
	inst["face_up"] = false
	inst["set_turn"] = turn
	players[f["ctl"]]["backrow"][slot] = uid
	add_log("%s sets a card in column %d." % [pname(f["ctl"]), slot + 1], {f["ctl"]: "You set %s in column %d." % [name_of(uid), slot + 1]})
	add_fx({"k": "play", "p": f["ctl"], "zone": "backrow", "slot": slot})
	return R.CONT


func _op_place_power(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var slot: int = eval_num(f, op["slot"])
	_remove_from_zone(uid)
	var inst: Dictionary = cards[uid]
	inst["zone"] = "power"
	inst["slot"] = slot
	inst["ctl"] = f["ctl"]
	inst["face_up"] = true
	players[f["ctl"]]["powers"][slot] = uid
	add_log("%s plays Power %s." % [pname(f["ctl"]), name_of(uid)])
	add_fx({"k": "play", "p": f["ctl"], "zone": "power", "slot": slot})
	return R.CONT


## Tribute materials for a special summon. Field materials go to Spent and fire
## tribute triggers; Spent materials (Arcane) are exhausted without field triggers.
func _op_tribute(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var p: int = f["ctl"]
	for m in refs(f, op["target"]):
		var from: String = cards[m]["zone"]
		# Presentation only (F03-17): where the material came from and where it goes, by summon kind.
		var mfx := {"k": "material", "p": p, "from": from, "at": fx_pos(m),
			"kind": "ritual" if op.get("ritual", false) else ("arcane" if op.get("to", "") == "exhaust" else "fusion"),
			"to": "spent" if from == "unit" and not has_flag_raw(m, "exhaust_on_spent") else "exhaust"}
		mfx.merge(fx_identity(m, [0, 1] if from == "unit" else [p]))
		if op.get("ritual", false):
			f["vars"]["runes_used"] = status_count(m, "rune")
		if from == "unit":
			var snap := _leave_field(m, op.get("to", "spent") if op.get("to", "") != "exhaust" else "spent", "tribute")
			add_log("%s tributes %s." % [pname(p), name_of(m)])
			add_fx(mfx)
			emit("tribute_or_sacrifice", {"self": m, "ctl": p, "player": p, "tribute": true, "debilitated": snap["st"].get("debilitate", 0) > 0})
			# Magentric (2026-10-17): "If this Unit is Tributed, Apply 2 Pierce to the Fusion or
			# Ritual Unit Summoned". Its On Field text needs it undebilitated on the Field.
			var tb: Dictionary = script_of(m).get("tribute_bonus", {})
			if not tb.is_empty() and snap["st"].get("debilitate", 0) <= 0 and not op.get("to", "") == "exhaust":
				if not f["vars"].has("tribute_bonus"):
					f["vars"]["tribute_bonus"] = []
				f["vars"]["tribute_bonus"].append({"s": tb["s"], "n": tb["n"], "from": name_of(m)})
		elif from == "hand":
			move_to_pile(m, "exhaust")
			add_log("%s tributes a card from Hand (exhausted)." % pname(p), {p: "%s tributes %s from Hand (exhausted)." % [pname(p), name_of(m)]})
			add_fx(mfx)
		else:
			move_to_pile(m, "exhaust")
			add_log("%s exhausts a card from %s as material." % [pname(p), from.capitalize()],
				{p: "%s exhausts %s from %s as material." % [pname(p), name_of(m), from.capitalize()]})
			add_fx(mfx)
	if op.get("ritual", false) and d(f["src"])["cost"] == null:
		var n: int = f["vars"]["runes_used"]
		cards[f["src"]]["runes_used"] = n
	return R.CONT


## Applies benefits recorded by `_op_tribute` to the Fusion/Ritual unit that just landed,
## before its own On Summon effects and the summon-response window.
func _op_tribute_bonus(f: Dictionary, op: Dictionary) -> int:
	var bonuses: Array = f["vars"].get("tribute_bonus", [])
	f["vars"].erase("tribute_bonus")
	for u in refs(f, op["target"]):
		if not unit_on_field(u):
			continue
		for b in bonuses:
			add_log("%s was tributed: %s gains %d %s." % [b["from"], name_of(u), b["n"], String(b["s"]).capitalize()])
			apply_status(u, b["s"], b["n"])
	return R.CONT


func _ritual_materials(p: int, uid: int) -> Array:
	var need = d(uid)["cost"]
	var out := []
	for u in field_units(p):
		if is_debilitated(u):
			continue
		var r := status_count(u, "rune")
		if (need == null and r >= 1) or (need != null and r >= need):
			out.append(u)
	return out


func _op_ritual_material(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans
		return R.CONT
	var opts := []
	for u in _ritual_materials(f["ctl"], f["src"]):
		opts.append(card_option(u, "%s (%d Runes)" % [name_of(u), status_count(u, "rune")]))
	if opts.is_empty():
		return R.END
	return ask(f, f["ctl"], "select", "Choose the unit to tribute for %s." % name_of(f["src"]), opts, 1, 1, true)


## Arcane materials player p may offer (F03-04 / F03-05): ordinary AP-cost Units in Spent
## (never Extra Deck units or non-Units) whose *current* cost is above 0. A zero-cost Unit
## adds nothing to an exact total, so it is not offered in the Arcane material choice.
func arcane_materials(p: int) -> Array:
	var out := []
	for u in players[p]["spent"]:
		if d(u)["cost_kind"] == "ap" and is_unit(u) and not is_extra(u) and current_cost(u) > 0:
			out.append(u)
	return out


## Indices of a subset of `values` (non-negative ints) summing exactly to `target`, or [] when
## no such subset exists (also [] for target <= 0). Deterministic: the first subset found by a
## dynamic programme over the values in order.
static func exact_subset(values: Array, target: int) -> Array:
	if target <= 0:
		return []
	# reach[s] = index of the value that first reached sum s (-1: unreachable; s 0 is the seed).
	var reach := []
	reach.resize(target + 1)
	reach.fill(-2)
	reach[0] = -1
	var prev := []
	prev.resize(target + 1)
	prev.fill(-1)
	for i in values.size():
		var v := int(values[i])
		if v <= 0:
			continue
		for s in range(target, v - 1, -1):
			if reach[s] == -2 and reach[s - v] != -2:
				reach[s] = i
				prev[s] = s - v
	if reach[target] == -2:
		return []
	var out := []
	var s2 := target
	while s2 > 0:
		out.push_front(reach[s2])
		s2 = prev[s2]
	return out


## True when some combination of p's Arcane materials totals exactly `need` (F03-04).
func arcane_payable(p: int, need: int) -> bool:
	return not exact_subset(arcane_materials(p).map(func(u): return current_cost(u)), need).is_empty()


func _op_arcane_materials(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans
		return R.CONT
	var need: int = d(f["src"])["cost"]
	var opts := []
	for u in arcane_materials(f["ctl"]):
		var o := card_option(u, "%s (cost %d)" % [name_of(u), current_cost(u)])
		o["value"] = current_cost(u)
		opts.append(o)
	# `min_total` is kept as the required total for older readers; `total_exact` makes it exact.
	return ask(f, f["ctl"], "select", "Exhaust units from Spent whose current costs total exactly %d." % need,
		opts, 1, opts.size(), true, {"min_total": need, "total_required": need, "total_exact": true, "reveal_pile": true})


func _op_move_slot(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"] if not op.has("target") else refs(f, op["target"])[0]
	var slot: int = eval_num(f, op["slot"])
	if not unit_on_field(uid) or players[cards[uid]["ctl"]]["units"][slot] != -1:
		return R.CONT
	f["committed"] = true
	move_unit_slot(uid, slot)
	if op.get("nimble", false):
		cards[uid]["moved_turn"] = turn
		decrement_status(uid, "nimble")
	add_log("%s moves to %s row, column %d." % [name_of(uid), "front" if slot_row(slot) == 0 else "back", slot_col(slot) + 1])
	emit("moved", {"self": uid, "ctl": cards[uid]["ctl"], "player": active})
	emit("own_unit_moved", {"unit": uid, "ctl": cards[uid]["ctl"], "player": active})
	return R.CONT

