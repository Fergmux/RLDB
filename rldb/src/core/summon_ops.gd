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
		if op.get("ritual", false):
			f["vars"]["runes_used"] = status_count(m, "rune")
		if from == "unit":
			var snap := _leave_field(m, op.get("to", "spent") if op.get("to", "") != "exhaust" else "spent", "tribute")
			add_log("%s tributes %s." % [pname(p), name_of(m)])
			emit("tribute_or_sacrifice", {"self": m, "ctl": p, "player": p, "tribute": true, "debilitated": snap["st"].get("debilitate", 0) > 0})
		elif from == "hand":
			move_to_pile(m, "exhaust")
			add_log("%s tributes a card from Hand (exhausted)." % pname(p), {p: "%s tributes %s from Hand (exhausted)." % [pname(p), name_of(m)]})
		else:
			move_to_pile(m, "exhaust")
			add_log("%s exhausts a card from %s as material." % [pname(p), from.capitalize()],
				{p: "%s exhausts %s from %s as material." % [pname(p), name_of(m), from.capitalize()]})
	if op.get("ritual", false) and d(f["src"])["cost"] == null:
		var n: int = f["vars"]["runes_used"]
		cards[f["src"]]["runes_used"] = n
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


func _arcane_eligible(p: int) -> Array:
	return players[p]["spent"].filter(func(u): return d(u)["cost_kind"] == "ap" and is_unit(u))


func _arcane_total(p: int) -> int:
	var t := 0
	for u in _arcane_eligible(p):
		t += current_cost(u)
	return t


func _op_arcane_materials(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans
		return R.CONT
	var opts := []
	for u in _arcane_eligible(f["ctl"]):
		opts.append(card_option(u, "%s (cost %d)" % [name_of(u), current_cost(u)]))
	return ask(f, f["ctl"], "select", "Exhaust units from Spent whose current costs total at least %d." % d(f["src"])["cost"],
		opts, 1, opts.size(), true, {"min_total": d(f["src"])["cost"], "reveal_pile": true})


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

