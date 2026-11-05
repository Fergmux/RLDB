class_name MatchEngine
extends SummonOps
## The single authority for one game: validates player commands, resolves turns,
## combat and summons, and produces redacted per-player views.
##
## Usage: var m = MatchEngine.new(); m.setup(decks, first_player, seed, config)
## then m.submit(player, command) -> "" or error, and m.view_for(player).

signal changed

## Refusal of a summon command asking for Defense stance (B3).
const SUMMON_ATTACK_ONLY := "Units summoned in your Setup or Recovery Phase enter in Attack stance; change stance afterwards."
## Refusal of a manual stance change outside its timing (B3).
const STANCE_PHASE_ONLY := "Stance can only be changed in the Setup Phase, or in the Recovery Phase by a unit summoned in it."
## J25 (owner feedback 2026-10-22): refusal of a manual stance change by a Paralysed unit. A stance
## change forced by a card effect (EffectOps._op_stance) is not prevented.
const PARALYSED_STANCE := "Paralysed units cannot change stance."
## J11 (owner feedback 2026-10-22): the plate button's sacrifice confirmation: this answer goes on,
## Cancel (or Esc) keeps the unit. And the pick's prompt.
const SACRIFICE_YES := "Sacrifice"
const SACRIFICE_PICK_PROMPT := "Choose a unit to sacrifice."

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
		# L23: an evolution-only form never starts a game as its own card (an older saved deck or
		# series may list one): it is its base card, which can evolve into it.
		for id in CardDB.sanitize_deck(decks[p]):
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
	# Options (2026-10-18) draws with the start-of-turn effects below, not as part of this draw.
	draw_cards(p, BASE_DRAW)
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
	# L23: Evolve prompts come first among the start-of-turn effects, one per evolvable unit in Field
	# order; the "at the start of your turn" effects follow (start_turn_effects), and a unit that just
	# evolved skips them this turn (its new form's first fire next turn).
	var evolvers := field_units(p).filter(func(u): return can_evolve(u))
	if evolvers.is_empty():
		emit("start_turn", {"player": p})
	else:
		push_frame(make_frame(-1, p, [{"op": "start_turn_effects"}], "start of turn"))
		for i in range(evolvers.size() - 1, -1, -1):
			push_frame(make_frame(evolvers[i], p, [{"op": "evolve_offer"}], "Evolve %s" % name_of(evolvers[i])))
	run()


## L23: the two answers of an Evolve prompt (the bot always takes EVOLVE_YES).
const EVOLVE_YES := "Evolve"
const EVOLVE_SKIP := "Skip"


## L23 (owner feedback 2026-11-05, confirmed rules): "Evolve <card> into <next>?" for the frame's unit,
## at the start of its controller's turn: free (no AP), Evolve or Skip, no response window (it is not
## a Summon and not an effect activation). Asked only while the unit can still evolve.
func _op_evolve_offer(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var ans: Variant = take_answer(f)
	var ok: bool = cards.has(uid) and can_evolve(uid) and int(cards[uid]["ctl"]) == int(f["ctl"])
	if ans != null:
		if int(ans[0]) == 1 and ok:
			evolve_unit(uid)
		elif ok:
			add_log("%s does not evolve %s." % [pname(f["ctl"]), name_of(uid)])
		return R.CONT
	if not ok:
		return R.CONT
	var to := CardDB.evolves_into(int(cards[uid]["id"]))
	return ask(f, f["ctl"], "evolve", "Evolve %s into %s?" % [name_of(uid), String(CardDB.get_def(to)["name"])],
		[{"v": 1, "label": EVOLVE_YES}, {"v": 0, "label": EVOLVE_SKIP}], 1, 1, false, {"evolve_to": to})


## L23: the start-of-turn triggers after the Evolve prompts. A unit that evolved this turn does not
## fire its new form's "at the start of your turn" effects until its controller's next turn.
func _op_start_turn_effects(f: Dictionary, op: Dictionary) -> int:
	emit("start_turn", {"player": f["ctl"]})
	trigger_queue = trigger_queue.filter(func(t): return not (String(t["event"].get("name", "")) == "start_turn" \
			and cards.has(int(t["uid"])) and int(cards[int(t["uid"])].get("evolved_turn", -1)) == turn))
	return R.CONT


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
	# D13: "Skip for the rest of this turn" ends with the turn.
	for pl in players:
		pl["trap_pass_turn"] = -1
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
	# L9: presentation event {"k": "control", "from", "to" ({} when it goes to Spent), "p": owner, "id",
	# "back": true, "dest": "unit" | "spent"}.
	var from := fx_pos(u)
	if home == -1 or players[owner]["units"][home] != -1:
		add_log("%s cannot return to its zone (now occupied) and is sent to Spent." % name_of(u))
		var cfx := {"k": "control", "from": from, "to": {}, "p": owner, "id": d(u)["id"], "back": true, "dest": "spent"}
		_leave_field(u, "spent", "control")
		add_fx(cfx)
		return
	players[inst["ctl"]]["units"][inst["slot"]] = -1
	inst["ctl"] = owner
	inst["slot"] = home
	players[owner]["units"][home] = u
	add_log("%s returns to %s's control." % [name_of(u), pname(owner)])
	add_fx({"k": "control", "from": from, "to": fx_pos(u), "p": owner, "id": d(u)["id"], "back": true, "dest": "unit"})


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
	if t == "trap_prompts":
		# J6: a seat's own setting, allowed at any time (also during the opponent's turn or a
		# pending choice); never logged, so the opponent does not learn it.
		var e3 := set_trap_prompts(p, String(cmd.get("mode", "")))
		if e3 == "":
			_after_command()
		return e3
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
	if t == "sacrifice_pick":
		return sacrifice_pick_check(p)
	var uid: int = int(cmd.get("uid", -1))
	if not cards.has(uid):
		return "Unknown card."
	var inst: Dictionary = cards[uid]
	var main := phase in [PHASE_MAIN1, PHASE_MAIN2]
	var own_turn_phase := phase in [PHASE_MAIN1, PHASE_BATTLE, PHASE_MAIN2]
	var df := d(uid)
	# B3 (owner feedback 2026-10-20): a summon from a command happens in the player's own Setup
	# or Recovery Phase, so the unit always enters in Attack stance (no choice); the player changes
	# stance afterwards. An explicit "atk" is still accepted from older clients; "def" is refused
	# whatever the card, so the reply reveals nothing about it (QA-F02-03).
	if cmd.has("stance"):
		if not (t in ["summon", "ritual", "arcane"]) or not (cmd["stance"] in ["atk", "def"]):
			return "Invalid stance."
		if cmd["stance"] == "def":
			return SUMMON_ATTACK_ONLY
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
			if status_count(uid, "paralyse") > 0: return PARALYSED_STANCE
			if not can_change_stance(uid): return STANCE_PHASE_ONLY
			if has_flag(uid, "no_defense") and inst["stance"] == "atk": return "This unit cannot be in Defense stance."
			if inst["stance"] == "def" and attack_stance_locked(uid): return "%s cannot be in Attack stance while it is protected by a Dragon." % name_of(uid)
			return ""
		"attack":
			return _attack_check(p, uid, String(cmd.get("mode", "")))
		"sacrifice":
			return sacrifice_check(p, uid)
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
			var why_x := _extra_timing_check(p, uid)
			if why_x != "": return why_x
			if t == "ritual" and _ritual_materials(p, uid).is_empty(): return "No unit with enough Runes."
			# F03-04: some Spent units' current costs must total exactly the requirement.
			if t == "arcane" and not arcane_payable(p, int(extra_cost(uid))): return "No Spent units' current costs total exactly %d." % int(extra_cost(uid))
			return ""
		"ritual_tribute":
			# Owner feedback 2026-10-18: the Ritual summon started from the unit with the Runes;
			# "target" is the Ritual unit in the Extra Deck it is tributed for. J14 (2026-10-22):
			# without a target the player then picks the Ritual unit (ritual_pick).
			if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
			if int(cmd.get("target", -1)) == -1:
				if not ritual_tribute_targets(p, uid).is_empty(): return ""
				for rr in players[p]["extra"]:
					if category(rr) == "ritual" and _extra_timing_check(p, rr) != "": return _extra_timing_check(p, rr)
				return "This unit does not have enough Runes for a Ritual unit in your Extra Deck."
			var r: int = int(cmd.get("target", -1))
			if not cards.has(r) or not (r in players[p]["extra"]) or category(r) != "ritual": return "Not a Ritual unit in your Extra Deck."
			var why := validate(p, {"t": "ritual", "uid": r})
			if why != "": return why
			if not (uid in _ritual_materials(p, r)): return "This unit does not have enough Runes."
			return ""
	return "Unknown command."


## Timing and lock reasons an Extra Deck unit `uid` of player p cannot be special summoned now
## ("" when it may): no Extra Deck summons in the Battle Phase, Setup / Recovery Phase only, and
## an opposing Bahatia's Type lock. Shared by the summon commands and the Ritual Tribute pick.
func _extra_timing_check(p: int, uid: int) -> String:
	if extra_summons_locked(): return NO_EXTRA_IN_BATTLE
	if not (phase in [PHASE_MAIN1, PHASE_MAIN2]): return "Special summons from the Extra Deck follow normal summon timing (Setup or Recovery Phase)."
	if _summon_blocked_by_type(p, unit_type(uid)): return "Your opponent's Bahatia prevents summoning %s units." % unit_type(uid)
	return ""


## J14 (owner feedback 2026-10-22): the Ritual units in player p's Extra Deck that unit `mat` could be
## tributed for right now (enough Runes, summon timing and Type locks allow), in Extra Deck order.
func ritual_tribute_targets(p: int, mat: int) -> Array:
	var out := []
	if not cards.has(mat) or cards[mat]["ctl"] != p or cards[mat]["zone"] != "unit":
		return out
	for r in players[p]["extra"]:
		if category(r) == "ritual" and _extra_timing_check(p, r) == "" and mat in _ritual_materials(p, r):
			out.append(r)
	return out


## Why player p may not sacrifice unit `uid` now ("" when they may): their own unit on the Field, in
## the Setup or Recovery Phase (P-21), not summoned this turn, not Debilitated, not borrowed.
## Turn, pending and stack checks are the caller's (validate).
func sacrifice_check(p: int, uid: int) -> String:
	var inst: Dictionary = cards[uid]
	if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
	if not (phase in [PHASE_MAIN1, PHASE_MAIN2]): return "Sacrifice is only allowed in the Setup or Recovery Phase (proposal P-21)."
	if inst["summoned_turn"] == turn: return "A unit summoned this turn cannot be sacrificed."
	if is_debilitated(uid): return "Debilitated units cannot be sacrificed."
	if inst["control_until"] != -1: return "A temporarily controlled unit cannot be sacrificed."
	return ""


## J11 (owner feedback 2026-10-22): the units player p could sacrifice now, in Field order.
func sacrificable_units(p: int) -> Array:
	return field_units(p).filter(func(u): return sacrifice_check(p, u) == "")


## J11: why the plate's "Sacrifice Unit" button cannot start a sacrifice now ("" when it can): no
## unit on the Field, the phase, or the one reason every unit shares (else a general reason).
func sacrifice_pick_check(p: int) -> String:
	var units := field_units(p)
	if units.is_empty():
		return "You have no unit on the Field to sacrifice."
	var reasons := {}
	for u in units:
		var why := sacrifice_check(p, u)
		if why == "":
			return ""
		reasons[why] = true
	if reasons.size() == 1:
		return String(reasons.keys()[0])
	return "None of your units can be sacrificed now."


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
		if op["op"] == "draw":
			break                             # a later choice may pick the drawn card
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
	# A Fusion Spell (Fusion Ceremony) needs a Fusion unit it could actually summon.
	for op in entry["spell"]:
		if op["op"] == "fusion" and extra_summons_locked():
			return NO_EXTRA_IN_BATTLE
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
		var not_self: bool = leaves or (c["t"] == "ability" and fop.get("not_self", false))
		var targets := fusion_candidates(p, fop["sources"], c["uid"] if not_self else -1, leaves)
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
		if op["op"] == "draw":
			break                             # "draw a card, discard a card": the draw comes first
		if op["op"] == "near_self":
			_op_near_self(f, op)              # its list feeds the choice that follows
		if op["op"] == "choose" and not op.get("optional", false):
			if select(f, op["sel"]).is_empty():
				return "No legal target."
			break
	if column_summon_blocked(f, ab["ops"]):
		return "No free zone in this column."
	# A Fusion ability needs a Fusion unit it could actually summon (the paying unit itself
	# leaves before the summon when the ability exhausts/destroys it first; `not_self`: it is never a
	# material but stays on the Field until the Fusion unit has landed).
	var leaves := false
	for op in ab["ops"]:
		if op["op"] in ["move", "destroy"] and op.get("target", "") == "self":
			leaves = true
		if op["op"] == "fusion" and extra_summons_locked():
			return NO_EXTRA_IN_BATTLE
		if op["op"] == "fusion" and fusion_candidates(p, op["sources"], uid if leaves or op.get("not_self", false) else -1, leaves).is_empty():
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
				# "play": the Power is being played, not its effect activated (Hot Stove, 2026-10-18).
				{"op": "window", "event": {"name": "activate", "player": p, "card": uid, "play": true, "text": "%s plays Power %s" % [pname(p), name_of(uid)]}},
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
			# F04-22: a Fusion method's self-destruction / exhaustion placed before its Fusion is a
			# cost, paid with the AP/HP cost right after the committing stance, before the window.
			# (Since 2026-11-03 Seppuku and Void Basilisk do it after the summon, in the op's `then`.)
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
			# G07: an optional "mode" ("unit" / "direct") narrows the targets of a unit that
			# may attack directly; see BattleOps.attack_modes.
			push_frame(make_frame(uid, p, [{"op": "attack_target", "as": "target", "mode": String(cmd.get("mode", ""))}, {"op": "attack_declare"},
				{"op": "attack_window"}, {"op": "battle"}], "attack with " + name_of(uid)))
		"sacrifice":
			push_frame(make_frame(uid, p, [{"op": "sacrifice", "target": "self"}], "sacrifice " + name_of(uid)))
		"sacrifice_pick":
			# J11: the plate's Sacrifice Unit button: pick the unit, confirm, then the same sacrifice.
			push_frame(make_frame(-1, p, [{"op": "sacrifice_pick", "cancellable": true},
				{"op": "sacrifice_confirm"}, {"op": "sacrifice", "target": "self"}], "the sacrifice"))
		"move":
			push_frame(make_frame(uid, p, [{"op": "pick_slot", "zone": "adjacent", "as": "slot", "cancellable": true},
				{"op": "move_slot", "slot": "$slot", "nimble": true}], "move " + name_of(uid)))
		"ritual":
			_push_ritual(p, uid, cmd, -1)
		"ritual_tribute":
			if int(cmd.get("target", -1)) == -1:
				# J14: one "Ritual Summon" action; the Ritual unit is chosen in the card select tray.
				push_frame(make_frame(uid, p, [{"op": "ritual_pick", "mat": uid, "cancellable": true}], "Ritual summon"))
			else:
				_push_ritual(p, int(cmd["target"]), cmd, uid)
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
			return [{"op": "fusion_pick", "sources": fo["sources"], "exclude_self": leaves or (ability and fo.get("not_self", false)),
				"frees_zone": leaves, "cancellable": true}]
	return []


## The Ritual summon of Extra Deck unit `uid`; `mat` (or -1 to choose) is the tributed unit.
func _push_ritual(p: int, uid: int, cmd: Dictionary, mat: int) -> void:
	push_frame(make_frame(uid, p, _ritual_ops(p, uid, mat, cmd), "Ritual summon " + name_of(uid)))


## The ops of Ritual unit `uid`'s summon by player p with material `mat` (-1: the player chooses it).
func _ritual_ops(p: int, uid: int, mat: int, cmd: Dictionary = {}) -> Array:
	return [{"op": "ritual_material", "as": "mat", "cancellable": true, "preset": mat},
		{"op": "pick_slot", "zone": "unit", "as": "slot", "cancellable": true, "freeing": "$mat"},
		_stance_op(cmd),
		{"op": "tribute", "target": "$mat", "ritual": true},
		{"op": "place", "target": "self", "slot": "$slot", "stance": "$stance"},
		{"op": "tribute_bonus", "target": "self"}] + summon_tail(uid, p)


## J14 (owner feedback 2026-10-22): a Ritual Tribute started from unit op.mat without a target asks
## which Ritual unit to summon, in the card select tray (always, even with one candidate, so the
## flow is the same every time). The answer turns this frame into that unit's Ritual summon.
func _op_ritual_pick(f: Dictionary, op: Dictionary) -> int:
	var mat: int = int(op["mat"])
	var ans: Variant = take_answer(f)
	if ans != null:
		var r: int = int(ans[0])
		f["src"] = r
		f["label"] = "Ritual summon " + name_of(r)
		_splice(f, _ritual_ops(f["ctl"], r, mat))
		return R.CONT
	var opts := []
	for r in ritual_tribute_targets(f["ctl"], mat):
		opts.append(card_option(r))
	if opts.is_empty():
		return R.END
	return ask(f, f["ctl"], "select", "Choose the Ritual unit to summon by tributing %s." % name_of(mat), opts, 1, 1,
		op.get("cancellable", true), {"reveal_pile": true})


## Stance step of a summon command. Commands summon only in the player's own Setup or Recovery
## Phase, where B3 enters the unit in Attack stance without asking (SummonOps.stance_choice_open).
func _stance_op(_cmd: Dictionary) -> Dictionary:
	return {"op": "pick_stance", "as": "stance", "cancellable": true, "slot": "$slot"}


## B3 (owner feedback 2026-10-20): whether unit `uid` may change stance manually now. Always in
## the Setup Phase (rule 01: "Choose stance freely in Main Phase 1"); in the Recovery Phase only
## a unit summoned in this Recovery Phase, which entered in Attack stance without a choice, so its
## controller can still pick its initial stance ("the player can change if they wish").
func can_change_stance(uid: int) -> bool:
	if phase == PHASE_MAIN1:
		return true
	var inst: Dictionary = cards[uid]
	return phase == PHASE_MAIN2 and inst["summoned_turn"] == turn and String(inst.get("summoned_phase", "")) == PHASE_MAIN2


## Splits an effect's ops into its leading target/mode choices (made cancellable, so they
## can be chosen before any cost is paid) and the rest. User decision 2026-10-15.
## A lead mode only records the choice; its option ops apply (via `mode_apply`) where the
## rest begins, i.e. after the cost, the response window and the negation check.
func _lead_choices(ops: Array) -> Array:
	var lead := []
	var applies := []
	var i := 0
	# A Type declaration leads too (owner feedback 2026-10-18: Chaos Witch / Waang can cancel it), and
	# so does a zone pick (L9, 2026-11-05: Hypnotise's zone, chosen like a summon's before paying).
	while i < ops.size() and ops[i]["op"] in ["choose", "mode", "near_self", "declare_type", "pick_slot"] and not ops[i].get("random", false):
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
	emit("spell_activated", {"player": f["ctl"], "card": f["src"]})
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
		emit("spell_activated", {"player": f["ctl"], "card": uid})
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
		add_log("%s loses %d AP (AP %d)." % [pname(f["ctl"]), cost["ap"], players[f["ctl"]]["ap"]])
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


## J11 (owner feedback 2026-10-22): which unit the plate's Sacrifice Unit button sacrifices: a
## cancellable pick among the units that may be sacrificed now. The pick becomes the frame's card.
func _op_sacrifice_pick(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["src"] = int(ans[0])
		f["label"] = "the sacrifice of " + name_of(f["src"])
		return R.CONT
	var opts := []
	for u in sacrificable_units(f["ctl"]):
		opts.append(card_option(u))
	if opts.is_empty():
		return R.END
	return ask(f, f["ctl"], "select", SACRIFICE_PICK_PROMPT, opts, 1, 1, op.get("cancellable", true))


## J11: the last word before a sacrifice from the plate button (a sacrifice cannot be undone):
## "Sacrifice" goes on; Cancel (or Esc) ends it and nothing happens.
func _op_sacrifice_confirm(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		if int(ans[0]) == 1:
			return R.CONT
		add_log("", {f["ctl"]: "Cancelled %s." % f["label"]})
		return R.END
	return ask(f, f["ctl"], "confirm", "Sacrifice %s for +1 AP?" % name_of(f["src"]),
		[{"v": 1, "label": SACRIFICE_YES}], 1, 1, true)


func _op_sacrifice(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var p: int = f["ctl"]
	var label := name_of(uid)
	# D6: presentation of the sacrifice (a public unit consumed into AP), taken before it leaves the field.
	var sfx := {"k": "sacrifice", "p": p, "at": fx_pos(uid), "id": d(uid)["id"], "stance": String(cards[uid].get("stance", "atk")),
		"dest": "exhaust" if has_flag_raw(uid, "exhaust_on_spent") else "spent"}
	var snap := _leave_field(uid, "spent", "sacrifice")
	add_log("%s sacrifices %s." % [pname(p), label])
	add_fx(sfx)
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
