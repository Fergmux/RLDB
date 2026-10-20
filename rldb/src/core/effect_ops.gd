class_name EffectOps
extends EffectEngine
## The generic, card-agnostic ops of the effect language (log, choose, if, mode, status, stat,
## hp, ap, draw, move, destroy, stance, finish_card). The interpreter and trigger core stay in
## EffectEngine; ops are found by name ("_op_" + name), so they may live anywhere in the chain.


# ---------------------------------------------------------------- generic ops

func _op_log(f: Dictionary, op: Dictionary) -> int:
	add_log(op["text"])
	return R.CONT


## Choose cards matching a selector. Options: optional, n ("any" or int), as, prompt,
## random (no prompt), reveal (pile shown to chooser).
func _op_choose(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		f["vars"][op["as"]] = ans.filter(func(v): return v != -1)
		return R.CONT
	var cands := choose_candidates(f, op)
	var chooser: int = who(f, op.get("chooser", "self"))
	if op["sel"].get("kind", "unit") in ["hand", "draw", "spent", "exhaust", "extra", "spent_or_draw"]:
		cands.sort()
	if cands.is_empty():
		f["vars"][op["as"]] = []
		if not op.get("optional", false) and not op.get("quiet", false):
			# F02-09: a resolving effect with nothing to choose explains itself (toast + log).
			# Named publicly only when its source card is public.
			var msg := "%s: no legal target." % f["label"]
			add_log(msg if is_public_card(f["src"]) else "", {f["ctl"]: msg})
			log_entries[-1]["toast"] = true
			# G09: shown over the card whose effect found nothing (MatchView.log_for redacts the uid).
			log_entries[-1]["toast_src"] = f["src"]
			log_entries[-1]["toast_at"] = fx_pos(f["src"])
		return R.END if op.get("end_if_none", false) else R.CONT
	if op.get("random", false):
		f["vars"][op["as"]] = [cands[rng.randi_range(0, cands.size() - 1)]]
		return R.CONT
	var n = op.get("n", 1)
	var max_n: int = cands.size() if n is String else mini(n, cands.size())
	var min_n: int = 0 if (op.get("optional", false) or n is String) else max_n
	if op.has("min"):
		min_n = clampi(int(op["min"]), 0, max_n)
	# User feedback 2026-10-15: even a single legal target is picked by the player (no auto-pick).
	var opts := []
	if op.get("optional", false) and max_n == 1:
		opts.append({"v": -1, "label": "Skip"})
		min_n = 1
	for u in cands:
		opts.append(card_option(u, _target_label(u, chooser)))
	return ask(f, chooser, "select", op.get("prompt", "%s: choose." % f["label"]), opts, min_n, max_n, op.get("cancellable", false),
		{"reveal_pile": op["sel"].get("kind", "unit") in ["hand", "draw", "spent", "exhaust", "extra"]})


## The cards a "choose" op of frame `f` offers: its selector minus the excluded ones. The one place
## this is decided, so the targeting preview (lead_targets) can never disagree with the real prompt.
func choose_candidates(f: Dictionary, op: Dictionary) -> Array:
	var cands := select(f, op["sel"])
	if op.has("exclude"):
		var ex := refs(f, op["exclude"])
		cands = cands.filter(func(u): return not (u in ex))
	if cards.has(f["src"]) and cards[f["src"]]["zone"] == "hand":
		cands = cands.filter(func(u): return u != f["src"])   # a Spell choosing before it is cast never picks itself
	return cands


## D9: the Field cards the first target choice of `ops` (an ability or set-Spell effect of card `uid`)
## offers right now, or [] when that choice is not about Field cards (or there is none). Read-only; it
## uses the same selector logic as the real prompt (choose_candidates), so a preview is never a guess.
func lead_targets(uid: int, ops: Array) -> Array:
	var f := make_frame(uid, cards[uid]["ctl"], ops, name_of(uid))
	for op in ops:
		if op["op"] != "choose":
			continue
		if not (String(op["sel"].get("kind", "unit")) in ["unit", "facedown", "backrow", "power", "field_card"]):
			return []
		if op.get("random", false):
			return []
		return choose_candidates(f, op)
	return []


func _target_label(uid: int, viewer: int) -> String:
	var inst: Dictionary = cards[uid]
	var owner_tag := "your" if inst["ctl"] == viewer else "opponent's"
	if inst["zone"] == "unit":
		return "%s %s (%d/%d, %s row col %d)" % [owner_tag, name_of(uid), atk_of(uid), def_of(uid),
			"front" if slot_row(inst["slot"]) == 0 else "back", slot_col(inst["slot"]) + 1]
	if inst["zone"] == "backrow" and not is_face_up(uid) and inst["ctl"] != viewer:
		return "%s set Spell/Trap (col %d)" % [owner_tag, inst["slot"] + 1]
	return "%s %s" % [owner_tag, name_of(uid)]


## Select all matching cards into a variable.
func _op_all(f: Dictionary, op: Dictionary) -> int:
	f["vars"][op["as"]] = select(f, op["sel"])
	return R.CONT


## Optional effect prompt ("You can ..."). "No" ends the frame.
func _op_confirm(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		if ans[0] == 1:
			return R.CONT
		add_log("%s declines %s." % [pname(f["ctl"]), f["label"]])
		return R.END
	if op.has("cond") and not eval_cond(f, op["cond"]):
		return R.END
	return ask(f, f["ctl"], "confirm", op.get("prompt", "Use %s?" % f["label"]),
		[{"v": 1, "label": "Yes"}, {"v": 0, "label": "No"}])


func _op_if(f: Dictionary, op: Dictionary) -> int:
	var branch: Array = op.get("then", []) if eval_cond(f, op["cond"]) else op.get("else", [])
	if not branch.is_empty():
		_splice(f, branch)
	return R.CONT


## Inserts ops right after the current op in this frame.
func _splice(f: Dictionary, ops: Array) -> void:
	var new_ops: Array = f["ops"].slice(0, f["pc"] + 1)
	new_ops += ops
	new_ops += f["ops"].slice(f["pc"] + 1)
	f["ops"] = new_ops


## Player picks one of several labelled op lists.
func _op_mode(f: Dictionary, op: Dictionary) -> int:
	var ans: Variant = take_answer(f)
	if ans != null:
		if op.has("defer"):               # lead mode: applied later by its mode_apply op
			f["vars"][op["defer"]] = ans[0]
		else:
			_splice(f, op["options"][ans[0]]["ops"])
		return R.CONT
	# Only options that can actually do something are offered (e.g. Auric's "Destroy a Spell/Trap"
	# while no Spell/Trap is set), so a cost is never paid for an impossible effect.
	var opts := []
	for i in op["options"].size():
		if _option_possible(f, op["options"][i]["ops"]):
			opts.append({"v": i, "label": op["options"][i]["label"]})
	if opts.is_empty():
		add_log("%s: no effect can be applied." % f["label"])
		return R.END
	return ask(f, f["ctl"], "mode", op.get("prompt", "Choose an effect."), opts, 1, 1, op.get("cancellable", false))


## False when an option opens with a required target choice that has no legal target.
func _option_possible(f: Dictionary, ops: Array) -> bool:
	for o in ops:
		if o["op"] == "choose":
			return o.get("optional", false) or not select(f, o["sel"]).is_empty()
		return true
	return true


## Applies the option chosen earlier by a deferred lead mode (see MatchEngine._lead_choices).
func _op_mode_apply(f: Dictionary, op: Dictionary) -> int:
	var i: int = int(f["vars"].get(op["key"], -1))
	if i >= 0 and i < op["options"].size():
		_splice(f, op["options"][i]["ops"])
	return R.CONT


## Stop resolving unless the condition holds.
func _op_require(f: Dictionary, op: Dictionary) -> int:
	if op.has("var") and refs(f, "$" + op["var"]).is_empty():
		return R.END
	if op.has("cond") and not eval_cond(f, op["cond"]):
		add_log("%s: condition not met." % f["label"])
		return R.END
	return R.CONT


func _op_status(f: Dictionary, op: Dictionary) -> int:
	var n := eval_num(f, op.get("n", 1))
	for u in refs(f, op["target"]):
		if op.get("unit_only", false) and not unit_on_field(u):
			continue                      # e.g. "the Unit that Destroyed it" when a Power/Trap did
		if on_field(u) or cards[u]["zone"] == "hand":
			apply_status(u, op["s"], n)
	return R.CONT


## Gain/loss of ATK/DEF from a card effect. Reversible by Sneaky Snunday; while Freaky Funday
## lasts, ATK and DEF are switched.
func _op_stat(f: Dictionary, op: Dictionary) -> int:
	var a := eval_num(f, op.get("atk", 0))
	var df := eval_num(f, op.get("def", 0))
	if f["reversed"]:
		a = -a
		df = -df
	if swap_active():
		var t := a
		a = df
		df = t
	for u in refs(f, op["target"]):
		if not unit_on_field(u):
			continue
		var ua := a
		var ud := df
		if has_flag(u, "no_gain"):
			ua = mini(ua, 0)
			ud = mini(ud, 0)
		cards[u]["mods"].append({"atk": ua, "def": ud, "until": op.get("until", "field"), "src": name_of(f["src"]) if f["src"] != -1 else "effect"})
		add_log("%s %+d ATK / %+d DEF%s (now %d/%d)." % [name_of(u), ua, ud, " until end of turn" if op.get("until", "") == "turn" else "", atk_of(u), def_of(u)])
		var ev := {"k": "stat", "at": fx_pos(u), "atk": ua, "def": ud}
		# F03-18: a chosen target shows a short arrow from the effect's source to it (both seats).
		if op["target"] is String and String(op["target"]).begins_with("$") and f["src"] != -1 and f["src"] != u:
			var from := fx_pos(f["src"])
			if not from.is_empty():
				ev["from"] = from
		add_fx(ev)
	return R.CONT


## Sets base ATK/DEF (and optionally Type/Race) for effect-determined units.
func _op_set_base(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op.get("target", "self")):
		if op.has("atk"):
			cards[u]["base_atk"] = eval_num(f, op["atk"])
		if op.has("def"):
			cards[u]["base_def"] = eval_num(f, op["def"])
		add_log("%s becomes %d/%d." % [name_of(u), atk_of(u), def_of(u)])
	return R.CONT


## HP change for a player from a card effect: negative = Damage, positive = Heal. Not reversed by
## Sneaky Snunday since 2026-10-18 (Damage and Healing are not "gains and losses").
func _op_hp(f: Dictionary, op: Dictionary) -> int:
	var n := eval_num(f, op["n"])
	var p := who(f, op.get("who", "self"))
	change_hp(p, n, " (%s)" % f["label"])
	return R.CONT


func _op_ap(f: Dictionary, op: Dictionary) -> int:
	var n := eval_num(f, op["n"])
	if f["reversed"] and not op.get("payment", false):
		n = -n
	var p := who(f, op.get("who", "self"))
	if op.get("next_turn", false):
		players[p]["ap_next"].append({"n": n, "src": f["label"]})
		add_log("%s will %s %d AP at the start of their next turn (%s)." % [pname(p), "gain" if n > 0 else "lose", absi(n), f["label"]])
	else:
		change_ap(p, n, " (%s)" % f["label"])
	return R.CONT


func _op_draw(f: Dictionary, op: Dictionary) -> int:
	draw_cards(who(f, op.get("who", "self")), eval_num(f, op.get("n", 1)))
	return R.CONT


func _op_move(f: Dictionary, op: Dictionary) -> int:
	# "Exhaust this unit: ..." (`cost`): a source that already left the Field cannot pay, so the
	# effect ends instead of pulling the card out of a pile (review 2026-10-17).
	if op.get("cost", false) and op["target"] == "self" and cards.has(f["src"]) and not on_field(f["src"]):
		add_log("%s is no longer on the Field, so its effect ends." % name_of(f["src"]))
		return R.END
	for u in refs(f, op["target"]):
		var from: String = cards[u]["zone"]
		var was_public := not (from in HIDDEN_PILES)
		if from == "backrow" and not is_face_up(u):
			was_public = false
		var label := public_label(u)
		var xfx := {}
		if op["to"] == "exhaust":
			# Presentation only (F03-16). A card in a hidden pile is identified to its owner and to the
			# effect's controller, who chose it from the revealed pile; everyone else sees a card back.
			var owner0: int = cards[u]["owner"]
			xfx = {"k": "exhaust", "p": owner0, "from": from, "at": fx_pos(u)}
			xfx.merge(fx_identity(u, [0, 1] if was_public else [owner0, f["ctl"]]))
		if from == "unit" or from == "backrow" or from == "power":
			_leave_field(u, op["to"], "effect", f)
		else:
			move_to_pile(u, op["to"])
		var owner: int = cards[u]["owner"]
		var dest_name: String = {"draw_top": "the top of Draw"}.get(op["to"], op["to"].capitalize())
		if was_public:
			add_log("%s moves from %s to %s." % [label, from.capitalize(), dest_name])
		else:
			# Hidden source pile: the opponent learns only that a card moved.
			add_log("%s moves a card from %s to %s." % [pname(owner), from.capitalize(), dest_name],
				{owner: "%s moves from %s to %s." % [name_of(u), from.capitalize(), dest_name]})
		if not xfx.is_empty():
			add_fx(xfx)
	return R.CONT


func _op_destroy(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		if on_field(u):
			var done := destroy(u, "effect", f["src"], f["ctl"])
			# "Destroy this Unit, ...": if the cost was prevented, nothing else happens.
			if not done and op["target"] == "self":
				add_log("%s was not destroyed, so its effect ends." % name_of(u))
				return R.END
	return R.CONT


func _op_stance(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op["target"]):
		if unit_on_field(u):
			_flip_stance(u)
	return R.CONT


func _flip_stance(u: int) -> void:
	if has_flag(u, "no_defense") and cards[u]["stance"] == "atk":
		add_log("%s cannot be in Defense stance." % name_of(u))
		return
	cards[u]["stance"] = "def" if cards[u]["stance"] == "atk" else "atk"
	add_log("%s changes to %s stance." % [name_of(u), "Defense" if cards[u]["stance"] == "def" else "Attack"])
	add_fx({"k": "stance", "at": fx_pos(u), "to": cards[u]["stance"]})


## Ends a used Spell/Trap: to Spent (or Exhaust if it says so).
func _op_finish_card(f: Dictionary, op: Dictionary) -> int:
	for u in refs(f, op.get("target", "self")):
		if on_field(u):
			var dest := "exhaust" if has_flag_raw(u, "exhaust_on_spent") else "spent"
			_leave_field(u, dest, "used", f)
		elif cards[u]["zone"] == "limbo":
			move_to_pile(u, "exhaust" if has_flag_raw(u, "exhaust_on_spent") else "spent")
	return R.CONT

