class_name MatchEngine
extends SummonOps
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
	note("turn", {"p": p, "turn": turn})
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
				add_log("No Battle Phase on the first turn. Recovery Phase.")
			else:
				phase = PHASE_BATTLE
				add_log("Battle Phase.")
			add_fx({"k": "phase", "phase": phase, "turn": turn})
		PHASE_BATTLE:
			phase = PHASE_MAIN2
			add_log("Recovery Phase.")
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
		add_fx({"k": "discard", "p": p, "n": discarded})
	return R.CONT


func _op_next_turn(f: Dictionary, op: Dictionary) -> int:
	var p := active
	# Expire turn-limited effects.
	for u in cards:
		var inst: Dictionary = cards[u]
		inst["mods"] = inst["mods"].filter(func(m): return m["until"] != "turn")
	swapped = {}
	for u in cards:
		for m in cards[u]["mods"]:
			m.erase("pre_swap")
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
	var home: int = inst.get("control_slot", -1)
	inst.erase("control_slot")
	if home == -1 or players[owner]["units"][home] != -1:
		add_log("%s cannot return to its zone (now occupied) and is sent to Spent." % name_of(u))
		_leave_field(u, "spent", "control")
		return
	players[inst["ctl"]]["units"][inst["slot"]] = -1
	inst["ctl"] = owner
	inst["slot"] = home
	players[owner]["units"][home] = u
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
		note("concede", {"p": p})
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
			if not main: return "Units can only be summoned in the Setup or Recovery Phase."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			if free_unit_slots(p).is_empty(): return "No free unit zone."
			if _summon_blocked_by_type(p, unit_type(uid)): return "Your opponent's Bahatia prevents summoning %s units." % unit_type(uid)
			return ""
		"set":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if not (df["category"] in ["spell", "trap"]): return "Only Spells and Traps can be set."
			if not main: return "Cards can only be set in the Setup or Recovery Phase."
			if player_has_flag(opp(p), "no_set"): return "Draw Virus: you cannot set cards."
			if current_cost(uid) > players[p]["ap"]: return "Not enough AP (%d needed)." % current_cost(uid)
			if free_backrow_slots(p).is_empty(): return "No free Trap/Spell zone."
			return ""
		"cast":
			if inst["owner"] != p or inst["zone"] != "hand": return "Card is not in your Hand."
			if df["category"] != "spell": return "Not a Spell."
			# User rule 2026-10-16: nothing is played from the Hand in the Battle Phase; only cards
			# already on the Field (set Spells, abilities, Traps) act there.
			if not main: return "Spells in your Hand can only be cast in the Setup or Recovery Phase."
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
			if not main: return "Powers are played in the Setup or Recovery Phase."
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
			if phase != PHASE_MAIN1: return "Stance can only be changed in the Setup Phase."
			if has_flag(uid, "no_defense") and inst["stance"] == "atk": return "This unit cannot be in Defense stance."
			return ""
		"attack":
			return _attack_check(p, uid)
		"sacrifice":
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if not main: return "Sacrifice is only allowed in the Setup or Recovery Phase (proposal P-21)."
			if inst["summoned_turn"] == turn: return "A unit summoned this turn cannot be sacrificed."
			if is_debilitated(uid): return "Debilitated units cannot be sacrificed."
			if inst["control_until"] != -1: return "A temporarily controlled unit cannot be sacrificed."
			return ""
		"move":
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if not main: return "Nimble moves are only allowed in the Setup or Recovery Phase."
			if status_count(uid, "nimble") <= 0: return "Requires Nimble."
			if status_count(uid, "paralyse") > 0: return "Paralysed units cannot move."
			if has_flag(uid, "cant_move"): return "This unit cannot move zone."
			if inst["moved_turn"] == turn: return "Nimble: already moved this turn."
			if _adjacent_free(uid).is_empty(): return "No adjacent empty zone."
			return ""
		"ritual", "arcane":
			if inst["owner"] != p or inst["zone"] != "extra": return "Card is not in your Extra Deck."
			if df["category"] != t: return "Not a %s unit." % t.capitalize()
			if not main: return "Special summons from the Extra Deck follow normal summon timing (Setup or Recovery Phase)."
			if _summon_blocked_by_type(p, unit_type(uid)): return "Your opponent's Bahatia prevents summoning %s units." % unit_type(uid)
			if t == "ritual" and _ritual_materials(p, uid).is_empty(): return "No unit with enough Runes."
			# F03-04: some Spent units' current costs must total exactly the requirement.
			if t == "arcane" and not arcane_payable(p, int(df["cost"])): return "No Spent units' current costs total exactly %d." % int(df["cost"])
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
		if op["op"] == "near_self":
			_op_near_self(f, op)              # its list feeds the choice that follows
		if op["op"] == "choose" and not op.get("optional", false):
			if select(f, op["sel"]).is_empty():
				return "No legal target."
			break
		if op["op"] == "require" and op.has("cond") and not eval_cond(f, op["cond"]):
			return "Condition not met."
	if column_summon_blocked(f, entry["spell"]):
		return "No free zone in this column."
	# Hypnotise needs a zone on your side to put the unit in (ruling 2026-10-16).
	for op in entry["spell"]:
		if op["op"] == "take_control" and free_unit_slots(p).is_empty():
			return "No free zone on your side."
	# A Fusion Spell (Polymerization) needs a Fusion unit it could actually summon.
	for op in entry["spell"]:
		if op["op"] == "fusion" and fusion_candidates(p, op["sources"]).is_empty():
			return "No Fusion unit can be summoned."
	return ""


## F03-08: the Fusion methods player p can activate right now that have a summonable Fusion
## unit. One entry per method: {"t": "cast" | "activate_set" | "ability", "uid": method card,
## "idx": ability index (abilities only), "targets": [Fusion units in p's Extra Deck]}.
## Legality is the activation's own: validate() (timing, phase, AP, once-per-turn, Debilitate,
## pending choices / resolving effects) and the same fusion_candidates() the summon uses
## (distinct current-stat materials, no Debilitated materials, zone after Field materials leave).
func fusion_methods(p: int) -> Array:
	var cmds := []
	for u in players[p]["hand"]:
		if category(u) == "spell":
			cmds.append({"t": "cast", "uid": u})
	for u in backrow_cards(p):
		if category(u) == "spell":
			cmds.append({"t": "activate_set", "uid": u})
	for u in field_units(p) + power_cards(p):
		var abs: Array = script_of(u).get("abilities", [])
		for i in abs.size():
			cmds.append({"t": "ability", "uid": u, "idx": i})
	var out := []
	for c in cmds:
		var ops: Array = script_of(c["uid"]).get("spell", []) if c["t"] != "ability" else script_of(c["uid"])["abilities"][c["idx"]]["ops"]
		var fop := {}
		var leaves := false
		for op in ops:
			if c["t"] == "ability" and op["op"] in ["move", "destroy"] and op.get("target", "") == "self":
				leaves = true
			if op["op"] == "fusion":
				fop = op
				break
		if fop.is_empty() or validate(p, c) != "":
			continue
		var targets := fusion_candidates(p, fop["sources"], c["uid"] if leaves else -1)
		if not targets.is_empty():
			var e: Dictionary = c.duplicate()
			e["targets"] = targets
			out.append(e)
	return out


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
		if op["op"] == "near_self":
			_op_near_self(f, op)              # its list feeds the choice that follows
		if op["op"] == "choose" and not op.get("optional", false):
			if select(f, op["sel"]).is_empty():
				return "No legal target."
			break
	if column_summon_blocked(f, ab["ops"]):
		return "No free zone in this column."
	# A Fusion ability needs a Fusion unit it could actually summon (the paying unit itself
	# leaves before the summon when the ability exhausts/destroys it).
	var leaves := false
	for op in ab["ops"]:
		if op["op"] in ["move", "destroy"] and op.get("target", "") == "self":
			leaves = true
		if op["op"] == "fusion" and fusion_candidates(p, op["sources"], uid if leaves else -1).is_empty():
			return "No Fusion unit can be summoned."
	return ""


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
			var sp := _lead_choices(script_of(uid)["spell"])
			sp[0] += _fusion_lead(script_of(uid)["spell"], sp[0], false)
			push_frame(make_frame(uid, p, sp[0] + [{"op": "pay", "target": "self"}] + _spell_ops(uid, sp[1]), name_of(uid)))
		"activate_set":
			var sp2 := _lead_choices(script_of(uid)["spell"])
			sp2[0] += _fusion_lead(script_of(uid)["spell"], sp2[0], false)
			push_frame(make_frame(uid, p, sp2[0] + [{"op": "flip_set_spell"}] + _spell_ops(uid, sp2[1]), name_of(uid)))
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
			# Targets/modes first and cancellable; the cost is paid once they are confirmed.
			var split := _lead_choices(ab["ops"])
			var flead := _fusion_lead(ab["ops"], split[0], true)
			split[0] += flead
			var ops: Array = split[0] + [{"op": "ability_cost", "idx": idx}]
			# F04-22: a Fusion method's self-destruction / exhaustion (Sepukku, Void Basilisk) is a
			# cost, paid with the AP/HP cost right after the committing stance, before the window.
			if not flead.is_empty():
				while not split[1].is_empty() and split[1][0]["op"] in ["move", "destroy"] and split[1][0].get("target", "") == "self":
					ops.append(split[1].pop_front())
			ops.append({"op": "window", "event": {"name": "activate", "player": p, "card": uid, "text": "%s activates %s" % [pname(p), name_of(uid)]}})
			ops.append({"op": "check_negated"})
			ops += split[1]
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
				{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"},
				{"op": "tribute_bonus", "target": "self"}] + summon_tail(uid, p), "Ritual summon " + name_of(uid)))
		"arcane":
			push_frame(make_frame(uid, p, [{"op": "arcane_materials", "as": "mats", "cancellable": true},
				{"op": "pick_slot", "zone": "unit", "as": "slot", "cancellable": true},
				_stance_op(cmd),
				{"op": "tribute", "target": "$mats", "to": "exhaust"},
				{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"}] + summon_tail(uid, p), "Arcane summon " + name_of(uid)))
	run()


## F04-22 / F07: a Fusion method's choices (Fusion unit, materials, zone, stance) lead its
## frame, cancellable, before any cost, self-destruction or response window. Empty when the
## effect has other lead choices or no Fusion. `ability`: a "move/destroy self" cost before the
## Fusion means the paying unit leaves (never a material; it frees its own zone).
func _fusion_lead(ops: Array, lead: Array, ability: bool) -> Array:
	if not lead.is_empty():
		return []
	var leaves := false
	for fo in ops:
		if ability and fo["op"] in ["move", "destroy"] and fo.get("target", "") == "self":
			leaves = true
		if fo["op"] == "fusion":
			return [{"op": "fusion_pick", "sources": fo["sources"], "exclude_self": leaves, "cancellable": true}]
	return []


## Stance step of a summon: fixed when the command chose it (F02-02), otherwise a prompt.
func _stance_op(cmd: Dictionary) -> Dictionary:
	if cmd.get("stance", "") in ["atk", "def"]:
		return {"op": "pick_stance", "as": "stance", "fixed": cmd["stance"]}
	return {"op": "pick_stance", "as": "stance", "cancellable": true}


## Splits an effect's ops into its leading target/mode choices (made cancellable, so they
## can be chosen before any cost is paid) and the rest. User decision 2026-10-15.
## A lead mode only records the choice; its option ops apply (via `mode_apply`) where the
## rest begins, i.e. after the cost, the response window and the negation check.
func _lead_choices(ops: Array) -> Array:
	var lead := []
	var applies := []
	var i := 0
	while i < ops.size() and ops[i]["op"] in ["choose", "mode", "near_self"] and not ops[i].get("random", false):
		var c: Dictionary = ops[i].duplicate()
		if c["op"] != "near_self":       # near_self only lists the units a following choice may pick
			c["cancellable"] = true
		if c["op"] == "mode":
			c["defer"] = "_mode%d" % i
			applies.append({"op": "mode_apply", "key": c["defer"], "options": c["options"]})
		lead.append(c)
		i += 1
	return [lead, applies + ops.slice(i)]


## A set Spell turns face up when its activation is committed (after any target choice).
func _op_flip_set_spell(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	cards[f["src"]]["face_up"] = true
	add_log("%s activates set Spell %s." % [pname(f["ctl"]), name_of(f["src"])])
	add_fx({"k": "spotlight", "p": f["ctl"], "id": d(f["src"])["id"], "how": "activate", "at": fx_pos(f["src"])})
	return R.CONT


func _spell_ops(uid: int, body = null) -> Array:
	var p: int = cards[uid]["owner"]
	var ops := [{"op": "to_limbo"},
		{"op": "window", "event": {"name": "activate", "player": p, "card": uid, "text": "%s casts %s" % [pname(p), name_of(uid)]}},
		{"op": "check_negated"}]
	ops += script_of(uid)["spell"] if body == null else body
	ops.append({"op": "finish_card", "target": "self"})
	return ops


# ---------------------------------------------------------------- command ops

func _op_pay(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	var cost := current_cost(uid)
	if cost > players[f["ctl"]]["ap"]:
		add_log("Not enough AP; action fails.")
		return R.END
	players[f["ctl"]]["ap"] -= cost
	note("play", {"uid": uid, "p": f["ctl"], "ap": cost, "set": f["ops"].any(func(o): return o["op"] == "set_card")})
	add_log("%s pays %d AP (AP %d)." % [pname(f["ctl"]), cost, players[f["ctl"]]["ap"]])
	return R.CONT


## A cast Spell leaves the Hand while resolving.
func _op_to_limbo(f: Dictionary, op: Dictionary) -> int:
	f["committed"] = true
	var uid: int = f["src"]
	if cards[uid]["zone"] == "hand":
		_remove_from_zone(uid)
		cards[uid]["zone"] = "limbo"
		add_log("%s casts %s." % [pname(f["ctl"]), name_of(uid)])
		add_fx({"k": "spotlight", "p": f["ctl"], "id": d(uid)["id"], "how": "cast"})   # the Spell is public now
	if script_of(uid).get("flags", []).has("cost_up_on_activate"):
		change_cost_perm(uid, -1 if f["reversed"] else 1)
	return R.CONT


func _op_check_negated(f: Dictionary, op: Dictionary) -> int:
	note("activation", {"frame": f})
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
	if not fx_pos(uid).is_empty():
		add_fx({"k": "trigger", "at": fx_pos(uid)})
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


## Independent deep copy of the whole match state, for look-ahead (the bot opponent tries moves
## on a copy and scores the result). The copy has no log history and emits nothing anyone hears.
func clone_for_sim() -> MatchEngine:
	var m := MatchEngine.new()
	m.cards = cards.duplicate(true)
	m.players = players.duplicate(true)
	m.turn = turn
	m.active = active
	m.phase = phase
	m.winner = winner
	m.rng.seed = rng.seed
	m.rng.state = rng.state
	m.config = config.duplicate(true)
	m.reversal_turn = reversal_turn
	m.reversal_count = reversal_count
	m.swap_turn = swap_turn
	m.swap_count = swap_count
	m.swapped = swapped.duplicate()
	m._next_log_seq = _next_log_seq
	m.stack = stack.duplicate(true)
	m.trigger_queue = trigger_queue.duplicate(true)
	m.window_queue = window_queue.duplicate(true)
	m.pending = pending.duplicate(true)
	m._next_choice_id = _next_choice_id
	m.first_turn_player = first_turn_player
	m.command_count = command_count
	return m
