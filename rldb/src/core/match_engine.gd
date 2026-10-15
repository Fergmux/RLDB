class_name MatchEngine
extends SpecialOps
## The single authority for one game: validates player commands, resolves turns,
## combat and summons, and produces redacted per-player views.
##
## Usage: var m = MatchEngine.new(); m.setup(decks, first_player, seed, config)
## then m.submit(player, command) -> "" or error, and m.view_for(player).

signal changed

var first_turn_player: int = 0
var command_count: int = 0


# ---------------------------------------------------------------- setup

## decks: [Array of card ids, Array of card ids]. Extra-deck ids go to the Extra Deck.
func setup(decks: Array, first_player: int, seed_value: int, cfg: Dictionary = {}) -> void:
	CardDB.ensure_loaded()
	config = cfg
	rng.seed = seed_value
	players = [_new_player(0), _new_player(1)]
	for p in 2:
		if cfg.has("names"):
			players[p]["name"] = cfg["names"][p]
		for id in decks[p]:
			var uid := _create_instance(int(id), p)
			if CardDB.is_extra_category(CardDB.get_def(int(id))["category"]):
				cards[uid]["zone"] = "extra"
				players[p]["extra"].append(uid)
			else:
				players[p]["draw"].append(uid)
		shuffle_array(players[p]["draw"])
		if cfg.has("start_hp"):
			players[p]["hp"] = cfg["start_hp"]
	first_turn_player = first_player
	active = first_player
	turn = 0
	add_log("Game start. %s goes first." % pname(first_player))
	_start_turn(first_player)
	run()


# ---------------------------------------------------------------- turn flow

func _start_turn(p: int) -> void:
	turn += 1
	active = p
	phase = PHASE_MAIN1
	add_log("— Turn %d: %s —" % [turn, pname(p)])
	add_fx({"k": "turn", "p": p, "turn": turn})
	# P-07: reset AP to base, then delayed modifiers, then draw, then start-of-turn effects.
	var ap := BASE_AP
	var notes := []
	for m in players[p]["ap_next"]:
		ap += m["n"]
		notes.append("%+d %s" % [m["n"], m["src"]])
	players[p]["ap_next"] = []
	if player_has_flag(p, "abyss_ap") and not players[p]["exhaust"].is_empty():
		ap += 1
		notes.append("+1 Marked by the Abyss")
	players[p]["ap"] = maxi(ap, 0)
	# Display-only bookkeeping (F02-06): the turn's starting allowance and the most AP held.
	players[p]["ap_start"] = players[p]["ap"]
	players[p]["ap_peak"] = players[p]["ap"]
	add_log("%s's AP is set to %d%s." % [pname(p), players[p]["ap"], (" (" + ", ".join(notes) + ")") if notes else ""])
	# P-19 (reworded Options): each active copy draws one additional card.
	var draw_n := BASE_DRAW + count_flag(p, "draw_extra")
	draw_cards(p, draw_n)
	# Medic heals at the start of its controller's turn, then decrements.
	for u in field_units(p):
		var m := status_count(u, "medic")
		if m > 0:
			if change_hp(p, m, " (Medic on %s)" % name_of(u)):
				return
			decrement_status(u, "medic")
	for item in players[p]["delayed"]:
		var du: int = item["uid"]
		if cards[du]["zone"] == "spent":
			push_frame(make_frame(du, p, [{"op": "summon", "target": du, "place": "orig", "stance": "choose"}], "%s returns" % name_of(du)))
	players[p]["delayed"] = []
	emit("start_turn", {"player": p})
	run()


## Advances to the next phase, or ends the turn from Main Phase 2.
func _advance_phase() -> void:
	match phase:
		PHASE_MAIN1:
			if turn == 1:
				phase = PHASE_MAIN2
				add_log("No Battle Phase on the first turn. Main Phase 2.")
			else:
				phase = PHASE_BATTLE
				add_log("Battle Phase.")
			add_fx({"k": "phase", "phase": phase, "turn": turn})
		PHASE_BATTLE:
			phase = PHASE_MAIN2
			add_log("Main Phase 2.")
			add_fx({"k": "phase", "phase": phase, "turn": turn})
		PHASE_MAIN2:
			_end_turn()


func _end_turn() -> void:
	var p := active
	phase = PHASE_END
	add_log("End of turn.")
	emit("end_turn", {"player": p})
	push_frame(make_frame(-1, p, [{"op": "end_turn_statuses"}, {"op": "discard_hand"}, {"op": "next_turn"}], "end of turn"))
	run()


# P-08: end-turn triggers, then status decrements, then discard.
func _op_end_turn_statuses(f: Dictionary, op: Dictionary) -> int:
	var p := active
	for u in field_units(p):
		var po := status_count(u, "poison")
		if po > 0:
			if change_hp(p, -po, " (Poison on %s)" % name_of(u)):
				return R.END
			decrement_status(u, "poison")
		for s in ["paralyse", "debilitate"]:
			if status_count(u, s) > 0:
				decrement_status(u, s)
				add_log("%s: %s -1 (now %d)." % [name_of(u), s.capitalize(), status_count(u, s)])
	return R.CONT


func _op_discard_hand(f: Dictionary, op: Dictionary) -> int:
	var p := active
	var kept := 0
	var discarded := 0
	for u in players[p]["hand"].duplicate():
		if status_count(u, "retain") > 0:
			decrement_status(u, "retain")
			kept += 1
			add_log("%s retains a card (Retain -1)." % pname(p), {p: "You retain %s (Retain -1)." % name_of(u)})
		else:
			move_to_pile(u, "spent")
			cards[u]["st"] = {}
			discarded += 1
	if discarded > 0:
		add_log("%s discards %d card%s to Spent." % [pname(p), discarded, "" if discarded == 1 else "s"])
	return R.CONT


func _op_next_turn(f: Dictionary, op: Dictionary) -> int:
	var p := active
	# Expire turn-limited effects.
	for u in cards:
		var inst: Dictionary = cards[u]
		inst["mods"] = inst["mods"].filter(func(m): return m["until"] != "turn")
	swap_uids = []
	# Return temporarily controlled units.
	for u in all_field_units():
		if cards[u]["control_until"] == turn:
			_return_control(u)
	stack.erase(f)
	_start_turn(opp(p))
	return R.WAIT if not pending.is_empty() else R.STAY


func _return_control(u: int) -> void:
	var inst: Dictionary = cards[u]
	var owner: int = inst["owner"]
	inst["control_until"] = -1
	var free := free_unit_slots(owner)
	if free.is_empty():
		add_log("%s cannot return to its owner (board full) and is sent to Spent." % name_of(u))
		_leave_field(u, "spent", "control")
		return
	players[inst["ctl"]]["units"][inst["slot"]] = -1
	inst["ctl"] = owner
	inst["slot"] = free[0]
	players[owner]["units"][free[0]] = u
	add_log("%s returns to %s's control." % [name_of(u), pname(owner)])


# ---------------------------------------------------------------- commands

## Validates and executes a player command. Returns "" or an error message.
func submit(p: int, cmd: Dictionary) -> String:
	if winner != -1:
		return "The game is over."
	var t: String = cmd.get("t", "")
	if t == "choose":
		var values := _int_array(cmd.get("values", []))
		if cmd.has("indices"):
			# Clients answer by option index so hidden uids never leave the authority.
			if pending.is_empty() or pending["id"] != int(cmd.get("id", -1)):
				return "No such pending choice."
			values = []
			for i in _int_array(cmd["indices"]):
				if i < 0 or i >= pending["options"].size():
					return "Invalid option."
				values.append(pending["options"][i]["v"])
		var e := answer_choice(p, int(cmd.get("id", -1)), values)
		if e == "":
			_after_command()
		return e
	if t == "cancel":
		var e2 := cancel_choice(p, int(cmd.get("id", -1)))
		if e2 == "":
			_after_command()
		return e2
	if t == "concede":
		end_game(opp(p), "%s conceded" % pname(p))
		_after_command()
		return ""
	var err := validate(p, cmd)
	if err != "":
		return err
	_execute(p, cmd)
	_after_command()
	return ""


func _after_command() -> void:
	command_count += 1
	changed.emit()


func _int_array(a) -> Array:
	var out := []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out


## Returns "" if the command is legal right now for player p, else a reason.
func validate(p: int, cmd: Dictionary) -> String:
	if not pending.is_empty():
		return "Waiting for %s." % ("your choice" if pending["player"] == p else "the opponent")
	if not stack.is_empty():
		return "An effect is resolving."
	if p != active:
		return "It is not your turn."
	var t: String = cmd.get("t", "")
	if t == "next_phase":
		return ""
	var uid: int = int(cmd.get("uid", -1))
	if not cards.has(uid):
		return "Unknown card."
	var inst: Dictionary = cards[uid]
	var main := phase in [PHASE_MAIN1, PHASE_MAIN2]
	var own_turn_phase := phase in [PHASE_MAIN1, PHASE_BATTLE, PHASE_MAIN2]
	var df := d(uid)
	# F02-02: summons may carry the chosen stance; card stance restrictions still apply.
	if cmd.has("stance"):
		if not (t in ["summon", "ritual", "arcane"]) or not (cmd["stance"] in ["atk", "def"]):
			return "Invalid stance."
		# Only judge the stance of a card the player may actually summon from its own pile, so
		# the reply never reveals anything about a card they cannot see (QA-F02-03).
		var own_src: bool = inst["owner"] == p and inst["zone"] == ("hand" if t == "summon" else "extra")
		if own_src and cmd["stance"] == "def" and has_flag_raw(uid, "no_defense"):
			return "This unit cannot be in Defense stance."
	match t:
		"summon":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if not is_unit(uid) or is_extra(uid): return "Not a unit you can normal summon."
			if not main: return "Units can only be summoned in a Main Phase."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			if free_unit_slots(p).is_empty(): return "No free unit zone."
			if _summon_blocked_by_type(p, unit_type(uid)): return "Your opponent's Bahatia prevents summoning %s units." % unit_type(uid)
			return ""
		"set":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if not (df["category"] in ["spell", "trap"]): return "Only Spells and Traps can be set."
			if not main: return "Cards can only be set in a Main Phase."
			if player_has_flag(opp(p), "no_set"): return "Draw Virus: you cannot set cards."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			if free_backrow_slots(p).is_empty(): return "No free Trap/Spell zone."
			return ""
		"cast":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if df["category"] != "spell": return "Not a Spell."
			if not own_turn_phase: return "Spells are cast during your turn."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			return _spell_target_check(p, uid)
		"activate_set":
			if inst["ctl"] != p or inst["zone"] != "backrow": return "Not your set card."
			if df["category"] != "spell": return "Only set Spells are activated manually; Traps respond to events."
			if not own_turn_phase: return "Spells are activated during your turn."
			return _spell_target_check(p, uid)
		"power":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if df["category"] != "power": return "Not a Power."
			if not main: return "Powers are played in a Main Phase."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			if free_power_slots(p).is_empty(): return "No free Power zone."
			if script_of(uid).get("flags", []).has("abyss_ap") and _deck_has_zero_cost(p):
				return "Marked by the Abyss cannot be activated while your deck contains a 0-cost card."
			return ""
		"ability":
			if inst["ctl"] != p or not (inst["zone"] in ["unit", "power"]): return "Not your card on the Field."
			if not own_turn_phase: return "Abilities are used during your turn."
			if is_debilitated(uid): return "Debilitated: effects suppressed."
			var abs: Array = script_of(uid).get("abilities", [])
			var idx: int = int(cmd.get("idx", 0))
			if idx < 0 or idx >= abs.size(): return "No such ability."
			return _ability_check(p, uid, idx, abs[idx])
		"stance":
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if phase != PHASE_MAIN1: return "Stance can only be changed in Main Phase 1."
			if has_flag(uid, "no_defense") and inst["stance"] == "atk": return "This unit cannot be in Defense stance."
			return ""
		"attack":
			return _attack_check(p, uid)
		"sacrifice":
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if not main: return "Sacrifice is only allowed in a Main Phase (proposal P-21)."
			if inst["summoned_turn"] == turn: return "A unit summoned this turn cannot be sacrificed."
			if is_debilitated(uid): return "Debilitated units cannot be sacrificed."
			if inst["control_until"] != -1: return "A temporarily controlled unit cannot be sacrificed."
			return ""
		"move":
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if not main: return "Nimble moves are only allowed in a Main Phase."
			if status_count(uid, "nimble") <= 0: return "Requires Nimble."
			if status_count(uid, "paralyse") > 0: return "Paralysed units cannot move."
			if has_flag(uid, "cant_move"): return "This unit cannot move zone."
			if inst["moved_turn"] == turn: return "Nimble: already moved this turn."
			if _adjacent_free(uid).is_empty(): return "No adjacent empty zone."
			return ""
		"ritual", "arcane":
			if inst["owner"] != p or inst["zone"] != "extra": return "Card is not in your Extra Deck."
			if df["category"] != t: return "Not a %s unit." % t.capitalize()
			if not main: return "Special summons from the Extra Deck follow normal summon timing (Main Phase)."
			if _summon_blocked_by_type(p, unit_type(uid)): return "Your opponent's Bahatia prevents summoning %s units." % unit_type(uid)
			if t == "ritual" and _ritual_materials(p, uid).is_empty(): return "No unit with enough Runes."
			if t == "arcane" and _arcane_total(p) < df["cost"]: return "Spent units' current costs total %d; %d required." % [_arcane_total(p), df["cost"]]
			return ""
	return "Unknown command."


func _deck_has_zero_cost(p: int) -> bool:
	for u in cards:
		var inst: Dictionary = cards[u]
		if inst["owner"] == p and d(u)["cost_kind"] == "ap" and d(u)["cost"] == 0:
			return true
	return false


func _summon_blocked_by_type(p: int, t: String) -> bool:
	for u in field_units(opp(p)):
		if has_flag(u, "type_summon_lock") and unit_type(u) == t and t != "":
			return true
	return false


func _spell_target_check(p: int, uid: int) -> String:
	var entry := script_of(uid)
	if entry.is_empty() or not entry.has("spell"):
		return "This card's effect is not implemented yet."
	var f := make_frame(uid, p, [], "")
	for op in entry["spell"]:
		if op["op"] == "choose" and not op.get("optional", false):
			if select(f, op["sel"]).is_empty():
				return "No legal target."
			break
		if op["op"] == "require" and op.has("cond") and not eval_cond(f, op["cond"]):
			return "Condition not met."
	return ""


func _ability_check(p: int, uid: int, idx: int, ab: Dictionary) -> String:
	if ab.get("opt", false) and cards[uid]["opt"].get(idx, -1) == turn:
		return "Already used this turn."
	var cost: Dictionary = ab.get("cost", {})
	if cost.get("ap", 0) > players[p]["ap"]:
		return "Not enough AP."
	var f := make_frame(uid, p, [], "")
	if ab.has("cond") and not eval_cond(f, ab["cond"]):
		return "Condition not met."
	for op in ab["ops"]:
		if op["op"] == "choose" and not op.get("optional", false):
			if select(f, op["sel"]).is_empty():
				return "No legal target."
			break
	return ""


func _adjacent_free(uid: int) -> Array:
	var p: int = cards[uid]["ctl"]
	return adjacent_slots(cards[uid]["slot"]).filter(func(s): return players[p]["units"][s] == -1)


func _execute(p: int, cmd: Dictionary) -> void:
	var t: String = cmd["t"]
	var uid: int = int(cmd.get("uid", -1))
	match t:
		"next_phase":
			_advance_phase()
		"summon":
			push_frame(make_frame(uid, p, [
				{"op": "pick_slot", "zone": "unit", "as": "slot", "cancellable": true},
				_stance_op(cmd),
				{"op": "pay", "target": "self"},
				{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"},
			] + summon_tail(uid, p), "summon " + name_of(uid)))
		"set":
			push_frame(make_frame(uid, p, [
				{"op": "pick_slot", "zone": "backrow", "as": "slot", "cancellable": true},
				{"op": "pay", "target": "self"},
				{"op": "set_card", "slot": "$slot"},
			], "set a card"))
		"cast":
			push_frame(make_frame(uid, p, [{"op": "pay", "target": "self"}] + _spell_ops(uid), name_of(uid)))
		"activate_set":
			cards[uid]["face_up"] = true
			push_frame(make_frame(uid, p, _spell_ops(uid), name_of(uid)))
			add_log("%s activates set Spell %s." % [pname(p), name_of(uid)])
		"power":
			push_frame(make_frame(uid, p, [
				{"op": "pick_slot", "zone": "power", "as": "slot", "cancellable": true},
				{"op": "pay", "target": "self"},
				{"op": "place_power", "slot": "$slot"},
				{"op": "window", "event": {"name": "activate", "player": p, "card": uid, "text": "%s plays Power %s" % [pname(p), name_of(uid)]}},
				{"op": "check_negated"},
			], name_of(uid)))
		"ability":
			var idx: int = int(cmd.get("idx", 0))
			var ab: Dictionary = script_of(uid)["abilities"][idx]
			var ops := [{"op": "ability_cost", "idx": idx}]
			ops.append({"op": "window", "event": {"name": "activate", "player": p, "card": uid, "text": "%s activates %s" % [pname(p), name_of(uid)]}})
			ops.append({"op": "check_negated"})
			ops += ab["ops"]
			push_frame(make_frame(uid, p, ops, "%s: %s" % [name_of(uid), ab.get("label", "ability")]))
		"stance":
			cards[uid]["stance_turn"] = turn
			_flip_stance(uid)
		"attack":
			push_frame(make_frame(uid, p, [{"op": "attack_target", "as": "target"}, {"op": "attack_declare"},
				{"op": "attack_window"}, {"op": "battle"}], "attack with " + name_of(uid)))
		"sacrifice":
			push_frame(make_frame(uid, p, [{"op": "sacrifice", "target": "self"}], "sacrifice " + name_of(uid)))
		"move":
			push_frame(make_frame(uid, p, [{"op": "pick_slot", "zone": "adjacent", "as": "slot", "cancellable": true},
				{"op": "move_slot", "slot": "$slot", "nimble": true}], "move " + name_of(uid)))
		"ritual":
			push_frame(make_frame(uid, p, [{"op": "ritual_material", "as": "mat", "cancellable": true},
				{"op": "pick_slot", "zone": "unit", "as": "slot", "cancellable": true, "freeing": "$mat"},
				_stance_op(cmd),
				{"op": "tribute", "target": "$mat", "ritual": true},
				{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"}] + summon_tail(uid, p), "Ritual summon " + name_of(uid)))
		"arcane":
			push_frame(make_frame(uid, p, [{"op": "arcane_materials", "as": "mats", "cancellable": true},
				{"op": "pick_slot", "zone": "unit", "as": "slot", "cancellable": true},
				_stance_op(cmd),
				{"op": "tribute", "target": "$mats", "to": "exhaust"},
				{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"}] + summon_tail(uid, p), "Arcane summon " + name_of(uid)))
	run()


## Stance step of a summon: fixed when the command chose it (F02-02), otherwise a prompt.
func _stance_op(cmd: Dictionary) -> Dictionary:
	if cmd.get("stance", "") in ["atk", "def"]:
		return {"op": "pick_stance", "as": "stance", "fixed": cmd["stance"]}
	return {"op": "pick_stance", "as": "stance", "cancellable": true}


func _spell_ops(uid: int) -> Array:
	var p: int = cards[uid]["owner"]
	var ops := [{"op": "to_limbo"},
		{"op": "window", "event": {"name": "activate", "player": p, "card": uid, "text": "%s casts %s" % [pname(p), name_of(uid)]}},
		{"op": "check_negated"}]
	ops += script_of(uid)["spell"]
	ops.append({"op": "finish_card", "target": "self"})
	return ops


# ---------------------------------------------------------------- command ops

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
		"column":
			var col: int = f["vars"].get("column", _col_any(f["src"]) if on_field(f["src"]) else f["event"].get("column", 0))
			slots = [col, col + 3].filter(func(s): return players[p]["units"][s] == -1)
		"orig":
			var o: int = f["event"].get("orig_slot", cards[f["src"]]["orig_slot"])
			slots = [o] if o >= 0 and players[p]["units"][o] == -1 else []
	slots.sort()
	if slots.is_empty():
		add_log("%s: no free zone." % f["label"])
		return R.END
	if slots.size() == 1 and not op.get("cancellable", false):
		f["vars"][op["as"]] = slots[0]
		return R.CONT
	var opts := []
	for s in slots:
		var label := ""
		match op["zone"]:
			"unit", "adjacent", "column", "orig": label = "%s row, column %d" % ["Front" if slot_row(s) == 0 else "Back", slot_col(s) + 1]
			"backrow": label = "Trap/Spell zone, column %d" % (s + 1)
			"power": label = "Power zone %d" % (s + 1)
		opts.append({"v": s, "label": label, "slot": s, "zone": op["zone"]})
	return ask(f, p, "slot", "Choose a zone for %s." % f["label"], opts, 1, 1, op.get("cancellable", false))


func _op_pick_stance(f: Dictionary, op: Dictionary) -> int:
	if has_flag_raw(f["src"], "no_defense") or op.get("fixed", "") == "atk":
		f["vars"][op["as"]] = "atk"
		return R.CONT
	if op.get("fixed", "") == "def":
		f["vars"][op["as"]] = "def"
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = "atk" if ans[0] == 0 else "def"
		return R.CONT
	return ask(f, f["ctl"], "stance", "Choose a stance for %s." % name_of(f["src"]),
		[{"v": 0, "label": "Attack stance"}, {"v": 1, "label": "Defense stance"}], 1, 1, op.get("cancellable", false))


func _op_pay(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	var cost := current_cost(uid)
	if cost > players[f["ctl"]]["ap"]:
		add_log("Not enough AP; action fails.")
		return R.END
	players[f["ctl"]]["ap"] -= cost
	add_log("%s pays %d AP (AP %d)." % [pname(f["ctl"]), cost, players[f["ctl"]]["ap"]])
	return R.CONT


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


## A cast Spell leaves the Hand while resolving.
func _op_to_limbo(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	if cards[uid]["zone"] == "hand":
		_remove_from_zone(uid)
		cards[uid]["zone"] = "limbo"
		add_log("%s casts %s." % [pname(f["ctl"]), name_of(uid)])
	if script_of(uid).get("flags", []).has("cost_up_on_activate"):
		change_cost_perm(uid, -1 if f["reversed"] else 1)
	return R.CONT


func _op_check_negated(f: Dictionary, op: Dictionary) -> int:
	if f["negated"]:
		add_log("%s was negated." % f["label"])
		var uid: int = f["src"]
		if on_field(uid):
			destroy(uid, "effect", -1, opp(f["ctl"]))
		elif cards[uid]["zone"] == "limbo":
			move_to_pile(uid, "exhaust" if has_flag_raw(uid, "exhaust_on_spent") else "spent")
		return R.END
	emit("effect_activated", {"player": f["ctl"], "card": f["src"]})
	return R.CONT


func _op_ability_cost(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	var ab: Dictionary = script_of(uid)["abilities"][op["idx"]]
	if ab.get("opt", false):
		cards[uid]["opt"][op["idx"]] = turn
	var cost: Dictionary = ab.get("cost", {})
	if cost.get("ap", 0) > 0:
		players[f["ctl"]]["ap"] -= cost["ap"]
		add_log("%s pays %d AP (AP %d)." % [pname(f["ctl"]), cost["ap"], players[f["ctl"]]["ap"]])
	if cost.get("hp", 0) > 0:
		if change_hp(f["ctl"], -cost["hp"], " (cost of %s)" % name_of(uid)):
			return R.END
	add_log("%s activates %s: %s." % [pname(f["ctl"]), name_of(uid), ab.get("label", "ability")])
	return R.CONT


## Negates the activation that opened the current response window and destroys that card.
func _op_negate(f: Dictionary, op: Dictionary) -> int:
	for i in range(stack.size() - 1, -1, -1):
		var other: Dictionary = stack[i]
		if other != f and other["src"] == f["event"].get("card", -2) and other["label"] != "response window":
			other["negated"] = true
			break
	return R.CONT


func _op_sacrifice(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var p: int = f["ctl"]
	var label := name_of(uid)
	var snap := _leave_field(uid, "spent", "sacrifice")
	add_log("%s sacrifices %s." % [pname(p), label])
	change_ap(p, 1, " (sacrifice)")
	emit("sacrificed", {"self": uid, "ctl": p, "player": p, "snapshot": snap, "debilitated": snap["st"].get("debilitate", 0) > 0})
	emit("tribute_or_sacrifice", {"self": uid, "ctl": p, "player": p, "debilitated": snap["st"].get("debilitate", 0) > 0})
	emit("any_sacrificed", {"unit": uid, "ctl": p, "player": p})
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
		if is_debilitated(u) or cards[u]["control_until"] != -1:
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


# ---------------------------------------------------------------- combat

func _attack_check(p: int, uid: int) -> String:
	var inst: Dictionary = cards[uid]
	if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
	if phase != PHASE_BATTLE: return "Attacks happen in the Battle Phase."
	if inst["stance"] != "atk": return "Only Attack-stance units can attack."
	if inst["attacked_turn"] == turn: return "This unit already attacked this turn."
	if status_count(uid, "paralyse") > 0: return "Paralysed."
	var why := _cannot_attack_reason(uid)
	if why != "": return why
	if attack_targets(uid).is_empty(): return "No legal attack target."
	return ""


func _cannot_attack_reason(uid: int) -> String:
	if has_flag(uid, "rider_no_attack"):
		var pr := protector_of(uid)
		if pr != -1 and unit_race(pr) == "Dragon":
			return "Dragon Rider cannot attack while protected by a Dragon."
	for other in adjacent_units(uid):
		if has_flag(other, "adjacent_no_attack"):
			return "%s prevents adjacent units from attacking." % name_of(other)
	return ""


## Legal attack targets: opposing unit uids, plus -1 for a direct attack.
func attack_targets(uid: int) -> Array:
	var p: int = cards[uid]["ctl"]
	var foes := field_units(opp(p))
	var out := []
	for u in foes:
		if not is_protected(u) or status_count(uid, "infiltrate") > 0:
			out.append(u)
	var forced := out.filter(func(u): return has_flag(u, "taunt"))
	if not forced.is_empty():
		out = forced
	if foes.is_empty() or has_flag(uid, "direct_attack"):
		out.append(-1)
	return out


func _op_attack_target(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var targets := attack_targets(uid)
	if status_count(uid, "blind") > 0:
		f["vars"][op["as"]] = targets[rng.randi_range(0, targets.size() - 1)]
		f["vars"]["blind"] = true
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans[0]
		return R.CONT
	var opts := []
	for t in targets:
		if t == -1:
			opts.append({"v": -1, "label": "Attack %s directly" % pname(opp(f["ctl"]))})
		else:
			opts.append(card_option(t, "Attack " + _target_label(t, f["ctl"])))
		# F02-12: preview of the battle from current public state (presentation only).
		opts[-1]["preview"] = battle_preview(uid, t)
	return ask(f, f["ctl"], "attack_target", "Choose a target for %s." % name_of(uid), opts, 1, 1, true)


func _op_attack_declare(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	var p: int = f["ctl"]
	var target: int = f["vars"]["target"]
	cards[uid]["attacked_turn"] = turn
	var desc := "%s attacks %s" % [name_of(uid), pname(opp(p)) + " directly" if target == -1 else name_of(target)]
	add_log("%s%s." % [desc, " (Blind: random target)" if f["vars"].get("blind", false) else ""])
	add_fx({"k": "attack", "from": {"p": p, "slot": cards[uid]["slot"]},
		"to": {"p": opp(p), "slot": cards[target]["slot"]} if target != -1 else {"p": opp(p), "direct": true}})
	if f["vars"].get("blind", false):
		decrement_status(uid, "blind")
	if target != -1 and is_protected(target):
		f["vars"]["infiltrated"] = true
		decrement_status(uid, "infiltrate")
		add_log("%s uses Infiltrate (Infiltrate -1)." % name_of(uid))
	f["vars"]["column"] = column_of(target) if target != -1 else column_of(uid)
	return R.CONT


func _op_attack_window(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var target: int = f["vars"]["target"]
	var ev := {"name": "attack", "player": f["ctl"], "attacker": uid, "target": target, "column": f["vars"]["column"],
		"lks": {uid: {"atk": atk_of(uid), "def": def_of(uid)}},
		"text": "%s attacks %s" % [name_of(uid), "directly" if target == -1 else name_of(target)]}
	f["event"] = ev
	_splice(f, [{"op": "window", "event": ev}])
	return R.CONT


## Type advantage bonus: 6 normally; each active Elemental Mastery makes it 12 per
## copy (one = 12, two = 24) per the user's P-19 answer.
func type_bonus(p: int) -> int:
	var n := count_flag(p, "elemental_mastery")
	return 6 if n == 0 else 12 * n


## P-13: Burn resolves after a completed (not cancelled/negated) attack, win or lose.
## The count is captured before battle so destruction resets cannot hide it.
func _apply_burn(a: int, p: int, burn: int) -> void:
	if burn <= 0 or winner != -1:
		return
	if unit_on_field(a):
		_set_status(a, "burn", 0)
	change_hp(p, -burn, " (Burn on %s after its attack)" % name_of(a))


func _advantaged(a: int, b: int) -> bool:
	var ta := unit_type(a)
	var tb := unit_type(b)
	return ta != "" and CardDB.TYPE_ADVANTAGE.get(ta, "") == tb


## The values a battle compares (shared by the battle itself and its preview): attacker ATK
## and defender ATK or DEF by stance, with the type-advantage bonus on the advantaged side.
func battle_values(a: int, target: int) -> Dictionary:
	var p: int = cards[a]["ctl"]
	var q: int = cards[target]["ctl"]
	var av := atk_of(a)
	var defending_atk: bool = cards[target]["stance"] == "atk"
	var dv := atk_of(target) if defending_atk else def_of(target)
	var notes := []
	var adv := ""
	var bonus := 0
	if _advantaged(a, target):
		bonus = type_bonus(p)
		av += bonus
		adv = "attacker"
		notes.append("type advantage +%d to attacker" % bonus)
	elif _advantaged(target, a):
		bonus = type_bonus(q)
		dv += bonus
		adv = "defender"
		notes.append("type advantage +%d to defender" % bonus)
	return {"av": av, "dv": dv, "defending_atk": defending_atk, "notes": notes, "adv": adv, "bonus": bonus}


## Why battle destruction of `uid` by an opponent with `vs` ({"atk", "type"}) would be
## prevented right now ("" = it would not). Mirrors destroy() for previews.
func _battle_survives(uid: int, vs: Dictionary) -> String:
	if has_flag(uid, "battle_immune_30atk") and vs["atk"] >= 30:
		return "%s cannot be destroyed by a unit with 30+ ATK" % name_of(uid)
	if has_flag(uid, "battle_immune_lightning") and vs["type"] == "Lightning":
		return "%s cannot be destroyed by a Lightning unit" % name_of(uid)
	if unit_race(uid) == "Warrior":
		for g in field_units(cards[uid]["ctl"]):
			if g != uid and has_flag(g, "warrior_guard") and column_of(g) == column_of(uid):
				# The guard's Eternal only saves a unit that can receive it (QA-F02-02).
				if not has_flag(uid, "no_buffs") and status_count(uid, "curse") == 0:
					return "%s is protected by %s" % [name_of(uid), name_of(g)]
	if status_count(uid, "eternal") > 0:
		return "Eternal saves %s" % name_of(uid)
	return ""


## F02-12 preview of attacking `target` (-1 = direct) with `a`, from the current public
## state only. Unknown face-down cards and triggered effects can still change the result,
## so `hidden_risk` flags opposing set cards. Never mutates state.
func battle_preview(a: int, target: int) -> Dictionary:
	var p: int = cards[a]["ctl"]
	var q := opp(p)
	var no_dmg := has_flag(a, "no_battle_damage")
	var burn := status_count(a, "burn")
	var hidden := false
	for u in players[q]["backrow"]:
		if u != -1 and not is_face_up(u):
			hidden = true
	var pv := {"target": target, "hidden_risk": hidden, "burn": burn, "notes": [], "atk_base": atk_of(a)}
	if target == -1:
		pv["outcome"] = "direct"
		pv["av"] = atk_of(a)
		pv["dmg_opp"] = 0 if no_dmg else atk_of(a)
		pv["dmg_you"] = burn
		pv["a_dies"] = false
		pv["t_dies"] = false
		pv["verdict"] = "neutral" if no_dmg else "good"
		if no_dmg:
			pv["notes"].append("%s's attacks do not inflict damage" % name_of(a))
		if burn > 0:
			pv["notes"].append("Burn: you lose %d HP after the attack" % burn)
		return pv
	var calc := battle_values(a, target)
	var av: int = calc["av"]
	var dv: int = calc["dv"]
	var def_atk: bool = calc["defending_atk"]
	pv["av"] = av
	pv["dv"] = dv
	pv["defending_atk"] = def_atk
	pv["adv"] = calc["adv"]
	pv["bonus"] = calc["bonus"]
	pv["def_base"] = atk_of(target) if def_atk else def_of(target)
	var a_vs := {"atk": atk_of(a), "type": unit_type(a)}
	var t_vs := {"atk": atk_of(target), "type": unit_type(target)}
	var a_dies := false
	var t_dies := false
	var dmg_opp := 0
	var dmg_you := 0
	var outcome := ""
	if def_atk:
		if av > dv:
			outcome = "win"
			t_dies = true
			dmg_opp = 0 if no_dmg else av - dv
			if no_dmg:
				pv["notes"].append("%s's attacks do not inflict damage" % name_of(a))
		elif av == dv:
			outcome = "trade"
			t_dies = true
			a_dies = true
		else:
			outcome = "loss"
			a_dies = true
			dmg_you = dv - av
	else:
		if av > dv:
			outcome = "win"
			t_dies = true
			if status_count(a, "pierce") > 0 and not no_dmg:
				dmg_opp = av - dv
				pv["notes"].append("Pierce: %d excess damage" % (av - dv))
		elif av == dv:
			outcome = "stalemate"
		else:
			outcome = "loss"
			dmg_you = dv - av
	if t_dies:
		var why := _battle_survives(target, a_vs)
		if why != "":
			t_dies = false
			pv["notes"].append(why)
	if a_dies:
		var why2 := _battle_survives(a, t_vs)
		if why2 != "":
			a_dies = false
			pv["notes"].append(why2)
	dmg_you += burn
	if burn > 0:
		pv["notes"].append("Burn: you lose %d HP after the attack" % burn)
	var verdict := "neutral"
	if (t_dies and not a_dies) or (not t_dies and not a_dies and dmg_opp > 0 and dmg_you == 0):
		verdict = "good"
	elif (a_dies and not t_dies) or (not t_dies and not a_dies and dmg_you > 0 and dmg_opp == 0):
		verdict = "bad"
	pv["outcome"] = outcome
	pv["a_dies"] = a_dies
	pv["t_dies"] = t_dies
	pv["dmg_opp"] = dmg_opp
	pv["dmg_you"] = dmg_you
	pv["verdict"] = verdict
	return pv


func _op_battle(f: Dictionary, op: Dictionary) -> int:
	var a: int = f["src"]
	var target: int = f["vars"]["target"]
	var p: int = f["ctl"]
	var q := opp(p)
	if not unit_on_field(a) or cards[a]["ctl"] != p or cards[a]["stance"] != "atk":
		add_log("The attack does not resolve (attacker no longer able to attack).")
		return R.END
	if target == -1:
		if not field_units(q).is_empty() and not has_flag(a, "direct_attack"):
			add_log("The direct attack is no longer legal.")
			return R.END
		var dburn := status_count(a, "burn")
		var dmg := atk_of(a)
		if has_flag(a, "no_battle_damage"):
			add_log("%s's attacks do not inflict damage." % name_of(a))
		else:
			change_hp(q, -dmg, " (direct attack by %s)" % name_of(a))
		_apply_burn(a, p, dburn)
		return R.CONT
	if not unit_on_field(target) or cards[target]["ctl"] != q:
		add_log("The attack does not resolve (target left the Field).")
		return R.END
	if is_protected(target) and not f["vars"].get("infiltrated", false):
		add_log("The attack does not resolve (target is now protected).")
		return R.END
	# Snapshot both combatants first: destruction is simultaneous for immunity checks.
	var snap_a := {"atk": atk_of(a), "type": unit_type(a), "debilitated": is_debilitated(a)}
	var burn_before := status_count(a, "burn")
	var pierce_before := status_count(a, "pierce")
	var snap_t := {"atk": atk_of(target), "type": unit_type(target), "debilitated": is_debilitated(target)}
	var calc := battle_values(a, target)
	var av: int = calc["av"]
	var dv: int = calc["dv"]
	var defending_atk: bool = calc["defending_atk"]
	var notes: Array = calc["notes"]
	var summary := "%s %d vs %s %s %d" % [name_of(a), av, name_of(target), "ATK" if defending_atk else "DEF", dv]
	if notes:
		summary += " (" + ", ".join(notes) + ")"
	add_log("Battle: " + summary + ".")
	var no_dmg := has_flag(a, "no_battle_damage")
	if defending_atk:
		if av > dv:
			destroy(target, "battle", a, p, snap_a)
			if winner == -1:
				if no_dmg:
					add_log("%s's attacks do not inflict damage." % name_of(a))
				else:
					change_hp(q, -(av - dv), " (battle)")
		elif av == dv:
			destroy(target, "battle", a, p, snap_a)
			destroy(a, "battle", target, q, snap_t)
		else:
			destroy(a, "battle", target, q, snap_t)
			if winner == -1:
				change_hp(p, -(dv - av), " (battle)")
	else:
		if av > dv:
			destroy(target, "battle", a, p, snap_a)
			# P-12: Pierce is consumed only when excess damage is actually applied to HP.
			if pierce_before > 0 and winner == -1:
				if no_dmg:
					add_log("%s's attacks do not inflict damage (Pierce not used)." % name_of(a))
				else:
					if unit_on_field(a):
						decrement_status(a, "pierce")
					change_hp(q, -(av - dv), " (Pierce)")
		elif av < dv:
			change_hp(p, -(dv - av), " (battle)")
	_apply_burn(a, p, burn_before)
	return R.CONT
