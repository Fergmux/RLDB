class_name BattleOps
extends FusionOps
## Battle rules: who may attack and what, the attack command ops, damage resolution,
## type advantage, Burn, and the read-only battle preview shown to the attacker.


# ---------------------------------------------------------------- combat

func _attack_check(p: int, uid: int, mode: String = "") -> String:
	var inst: Dictionary = cards[uid]
	if inst["ctl"] != p or inst["zone"] != "unit": return "Not your unit."
	if phase != PHASE_BATTLE: return "Attacks happen in the Battle Phase."
	if inst["stance"] != "atk": return "Only Attack-stance units can attack."
	if inst["attacked_turn"] == turn: return "This unit already attacked this turn."
	if status_count(uid, "paralyse") > 0: return "Paralysed."
	var why := _cannot_attack_reason(uid)
	if why != "": return why
	if attack_targets(uid).is_empty(): return "No legal attack target."
	return _attack_mode_check(uid, mode)


func _cannot_attack_reason(uid: int) -> String:
	if has_flag(uid, "rider_no_attack"):
		var pr := protector_of(uid)
		if pr != -1 and unit_race(pr) == "Dragon":
			return "Dragon Rider cannot attack while protected by a Dragon."
	for other in adjacent_units(uid):
		if has_flag(other, "adjacent_no_attack"):
			return "%s prevents adjacent units from attacking." % name_of(other)
	return ""


## Legal attack targets: opposing unit uids, plus -1 for a direct attack. A forcing unit
## (Demented Apparition) overrides everything, including "can attack directly".
func attack_targets(uid: int) -> Array:
	var p: int = cards[uid]["ctl"]
	var foes := field_units(opp(p))
	var out := []
	for u in foes:
		if not is_protected(u) or status_count(uid, "infiltrate") > 0:
			out.append(u)
	var forced := out.filter(func(u): return has_flag(u, "taunt"))
	if not forced.is_empty():
		return forced
	if foes.is_empty() or has_flag(uid, "direct_attack"):
		out.append(-1)
	return out


## G07: the attack modes `uid` offers as separate actions. A unit that may attack directly
## (Diggie, Flying Sandworm) while there are opposing units it could attack instead gets two:
## "unit" (pick an opposing unit) and "direct" (no choice). Every other unit has one
## action and returns []. Blind units attack a random legal target, so they never split.
func attack_modes(uid: int) -> Array:
	if status_count(uid, "blind") > 0:
		return []
	var targets := attack_targets(uid)
	if not (-1 in targets) or targets.size() < 2:
		return []
	return ["unit", "direct"]


## Why the attack mode `mode` ("unit" / "direct", "" = no mode) is not legal for `uid` now.
func _attack_mode_check(uid: int, mode: String) -> String:
	if mode == "":
		return ""
	if not (mode in ["unit", "direct"]):
		return "Invalid attack mode."
	if status_count(uid, "blind") > 0:
		return "Blind: this unit attacks a random target."
	var targets := attack_targets(uid)
	if mode == "direct" and not (-1 in targets):
		return "This unit cannot attack directly now."
	if mode == "unit" and targets.filter(func(t): return t != -1).is_empty():
		return "No opposing unit can be attacked."
	return ""


## Attack targets narrowed to the declared mode: "unit" drops the direct attack, "direct"
## keeps only it, "" keeps every legal target.
func _mode_targets(targets: Array, mode: String) -> Array:
	match mode:
		"unit": return targets.filter(func(t): return t != -1)
		"direct": return targets.filter(func(t): return t == -1)
	return targets


func _op_attack_target(f: Dictionary, op: Dictionary) -> int:
	var uid: int = f["src"]
	var targets := attack_targets(uid)
	if status_count(uid, "blind") > 0:
		f["vars"][op["as"]] = targets[rng.randi_range(0, targets.size() - 1)]
		f["vars"]["blind"] = true
		return R.CONT
	targets = _mode_targets(targets, String(op.get("mode", "")))
	if targets.is_empty():
		add_log("%s has no legal attack target." % name_of(uid))
		return R.END
	if targets == [-1]:
		f["vars"][op["as"]] = -1          # "Attack Direct": nothing to choose
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
		if not (-1 in attack_targets(a)):
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
