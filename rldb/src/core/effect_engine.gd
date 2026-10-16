class_name EffectEngine
extends GameCore
## Resumable effect resolution: a stack of frames, each a list of typed operations
## with a program counter. Operations that need a player decision create a pending
## choice and suspend; the answer resumes the same frame. Nothing here interprets
## English card text — card behaviour is declared in CardScripts as op lists.

enum R { CONT, WAIT, STAY, END }

const HIDDEN_PILES := ["hand", "draw", "spent", "exhaust", "extra"]

var stack: Array = []           # frames; back() is resolving
var trigger_queue: Array = []   # {uid, ctl, ops, label, event}
var window_queue: Array = []    # response-window events awaiting a frame
var pending: Dictionary = {}    # current choice, empty when none
var _next_choice_id: int = 1


## A finished game (lethal damage, concession, host claim) drops any open prompt and
## pending resolution so no stale choice survives into views.
func _on_game_over() -> void:
	pending = {}
	stack.clear()
	trigger_queue.clear()
	window_queue.clear()


# ---------------------------------------------------------------- frames

func make_frame(src: int, ctl: int, ops: Array, label: String, event: Dictionary = {}) -> Dictionary:
	return {"src": src, "ctl": ctl, "ops": ops, "pc": 0, "vars": {}, "label": label,
		"event": event, "reversed": reversal_active(), "negated": false, "committed": false}


func push_frame(f: Dictionary) -> void:
	stack.append(f)


## Runs resolution until a choice is needed, the stack empties or the game ends.
func run() -> void:
	var guard := 0
	while winner == -1 and pending.is_empty():
		guard += 1
		if guard > 20000:
			push_error("effect loop guard tripped")
			add_log("[engine] resolution aborted: loop guard")
			stack.clear()
			break
		if not window_queue.is_empty() or not trigger_queue.is_empty():
			# Windows go underneath, triggers on top: a destroyed card's own effects
			# (and other triggered effects) resolve before listening Traps respond.
			var wins: Array = window_queue.duplicate()
			window_queue.clear()
			for i in range(wins.size() - 1, -1, -1):
				push_frame(make_frame(-1, opp(active), [{"op": "window", "event": wins[i]}], "response window", wins[i]))
			if not trigger_queue.is_empty():
				_flush_triggers()
			continue
		if stack.is_empty():
			break
		var f: Dictionary = stack.back()
		if f["pc"] >= f["ops"].size():
			stack.pop_back()
			continue
		var op: Dictionary = f["ops"][f["pc"]]
		var r: int = _exec(f, op)
		match r:
			R.CONT:
				f["pc"] += 1
			R.END:
				stack.erase(f)
			R.WAIT, R.STAY:
				pass
	if winner != -1:
		stack.clear()
		pending = {}
		trigger_queue.clear()
		window_queue.clear()


func _exec(f: Dictionary, op: Dictionary) -> int:
	var fn := "_op_" + String(op["op"])
	if not has_method(fn):
		push_error("unknown op " + fn)
		add_log("[engine] unsupported operation %s" % op["op"])
		return R.CONT
	return call(fn, f, op)


# ---------------------------------------------------------------- choices

## Creates a pending choice. options: [{v, label, uid?}]. Returns R.WAIT.
func ask(f: Dictionary, player: int, kind: String, prompt: String, options: Array,
		min_n: int = 1, max_n: int = 1, cancellable: bool = false, extra: Dictionary = {}) -> int:
	pending = {"id": _next_choice_id, "player": player, "kind": kind, "prompt": prompt,
		"options": options, "min": min_n, "max": max_n, "cancellable": cancellable,
		"source": f["src"], "label": f["label"]}
	pending.merge(extra)
	_next_choice_id += 1
	f["_waiting"] = true
	return R.WAIT


## Returns the answer stored for the current op, or null if none yet.
func take_answer(f: Dictionary) -> Variant:
	if f.has("_ans"):
		var a = f["_ans"]
		f.erase("_ans")
		f.erase("_waiting")
		return a
	return null


## Validates and applies a choice answer. Returns an error string or "".
func answer_choice(player: int, choice_id: int, values: Array) -> String:
	if pending.is_empty() or pending["id"] != choice_id:
		return "No such pending choice."
	if pending["player"] != player:
		return "This choice belongs to the other player."
	var allowed := {}
	for o in pending["options"]:
		allowed[o["v"]] = true
	var seen := {}
	for v in values:
		if not allowed.has(v):
			return "Invalid option."
		if seen.has(v):
			return "Duplicate option."
		seen[v] = true
	if values.size() < pending["min"] or values.size() > pending["max"]:
		return "Choose between %d and %d options." % [pending["min"], pending["max"]]
	if pending.has("min_total"):
		var total := 0
		for v in values:
			total += maxi(current_cost(v), 0)
		if total < pending["min_total"]:
			return "Selected materials total %d; %d required." % [total, pending["min_total"]]
	var f: Dictionary = stack.back()
	f["_ans"] = values
	pending = {}
	run()
	return ""


## Cancels a cancellable pending choice: the frame is discarded before any commit.
func cancel_choice(player: int, choice_id: int) -> String:
	if pending.is_empty() or pending["id"] != choice_id:
		return "No such pending choice."
	if pending["player"] != player:
		return "This choice belongs to the other player."
	if not pending["cancellable"]:
		return "This choice cannot be cancelled."
	var f: Dictionary = stack.back()
	if f["committed"]:
		return "Action already committed."
	stack.pop_back()
	pending = {}
	add_log("", {player: "Cancelled %s." % f["label"]})
	run()
	return ""


func card_option(uid: int, label: String = "") -> Dictionary:
	return {"v": uid, "uid": uid, "label": label if label != "" else name_of(uid)}


# ---------------------------------------------------------------- references and selectors

func who(f: Dictionary, w) -> int:
	if w is int:
		return w
	match w:
		"self":
			return f["ctl"]
		"opp":
			return opp(f["ctl"])
		"active":
			return active
	return f["ctl"]


## Resolves a target reference to an Array of uids still present.
func refs(f: Dictionary, ref) -> Array:
	var out := []
	if ref is Array:
		out = ref.duplicate()
	elif ref is int:
		out = [ref]
	elif ref is String:
		if ref == "self":
			out = [f["src"]]
		elif ref.begins_with("$"):
			var v = f["vars"].get(ref.substr(1), [])
			out = v.duplicate() if v is Array else [v]
		elif ref.begins_with("event."):
			var v = f["event"].get(ref.substr(6), -1)
			out = v.duplicate() if v is Array else [v]
	return out.filter(func(u): return u is int and cards.has(u))


## Returns uids matching a selector, relative to frame f.
func select(f: Dictionary, sel: Dictionary) -> Array:
	var kind: String = sel.get("kind", "unit")
	var side: String = sel.get("side", "any")
	var sides: Array = []
	match side:
		"self": sides = [f["ctl"]]
		"opp": sides = [opp(f["ctl"])]
		_: sides = [f["ctl"], opp(f["ctl"])]
	var pool := []
	for p in sides:
		match kind:
			"unit": pool += field_units(p)
			"facedown": pool += backrow_cards(p).filter(func(u): return not is_face_up(u))
			"backrow": pool += backrow_cards(p)
			"power": pool += power_cards(p)
			"field_card": pool += field_cards(p)
			"hand", "draw", "spent", "exhaust", "extra": pool += players[p][kind]
			"spent_or_draw": pool += players[p]["spent"] + players[p]["draw"]
	var out := pool.filter(func(u): return _matches(f, u, sel))
	# Extremes are taken among otherwise-matching candidates; ties stay choosable.
	if sel.get("max_atk", false) and not out.is_empty():
		var best := -1
		for u in out:
			best = maxi(best, atk_of(u))
		out = out.filter(func(u): return atk_of(u) == best)
	if sel.get("min_atk", false) and not out.is_empty():
		var low := 1 << 30
		for u in out:
			low = mini(low, atk_of(u))
		out = out.filter(func(u): return atk_of(u) == low)
	return out


func _matches(f: Dictionary, uid: int, sel: Dictionary) -> bool:
	var src: int = f["src"]
	for key in sel:
		var want = sel[key]
		match key:
			"kind", "side", "max_atk", "min_atk":
				pass
			"has_type":
				if not is_unit(uid) or (unit_type(uid) != "") != want: return false
			"atk_below_self":
				if not unit_on_field(src) or not is_unit(uid) or atk_of(uid) >= atk_of(src): return false
			"not_self":
				if uid == src: return false
			"race":
				if not is_unit(uid) or unit_race(uid) != want: return false
			"type":
				var t = want
				if want == "$self_type":
					t = unit_type(src)
				elif want == "$snap_type":
					t = f["event"].get("type", "")
					if t == "": return false
				if not is_unit(uid) or unit_type(uid) != t: return false
			"category":
				if not (category(uid) in want): return false
			"unit_card":
				if is_unit(uid) != want: return false
			"basic":
				if (category(uid) == "basic_unit") != want: return false
			"cost_max":
				var cc := current_cost(uid)
				if cc < 0 or cc > want: return false
			"cost_min":
				var cc2 := current_cost(uid)
				if cc2 < 0 or cc2 < want: return false
			"cost_eq":
				var target_cost = eval_num(f, want)
				if current_cost(uid) != target_cost: return false
			"race_eq":
				var r := refs(f, want)
				if r.is_empty() or unit_race(uid) != unit_race(r[0]): return false
			"atk_min":
				if not _unit_stat_ok(uid) or _pile_atk(uid) < want: return false
			"atk_max":
				if not _unit_stat_ok(uid) or _pile_atk(uid) > want: return false
			"def_max":
				if not _unit_stat_ok(uid) or _pile_def(uid) > want: return false
			"def_min":
				if not _unit_stat_ok(uid) or _pile_def(uid) < want: return false
			"has_buff":
				if has_any_buff(uid) != want: return false
			"has_debuff":
				if has_any_debuff(uid) != want: return false
			"has_status":
				if status_count(uid, want) <= 0: return false
			"revealed":
				if (status_count(uid, "reveal") > 0) != want: return false
			"face_down":
				if is_face_up(uid) == want: return false
			"column":
				var col := _col_any(src)
				if col == -1 or not on_field(uid) or _col_any(uid) != col: return false
			"adjacent":
				if not unit_on_field(src) or not unit_on_field(uid): return false
				if not (uid in adjacent_units(src)): return false
			"unprotected":
				if cards[uid]["zone"] != "unit" or is_protected(uid) == want: return false
			"cost_eq_printed":
				if d(uid)["cost_kind"] != "ap" or d(uid)["cost"] != want: return false
			"stance":
				if cards[uid]["zone"] != "unit" or cards[uid]["stance"] != want: return false
			"spell_trap":
				if not (category(uid) in ["spell", "trap"]): return false
			"ordinary_unit":
				if not (category(uid) in ["basic_unit", "unit"]): return false
			"name_prefix":
				if not name_of(uid).begins_with(want): return false
			"in":
				if not (uid in refs(f, want)): return false
			"not_in":
				if uid in refs(f, want): return false
			"no_eternal":
				pass
	return true


func _col_any(uid: int) -> int:
	var inst: Dictionary = cards[uid]
	if inst["zone"] == "unit":
		return slot_col(inst["slot"])
	if inst["zone"] == "backrow":
		return inst["slot"]
	# A card that just left the Field keeps its last column for its own triggers.
	if inst["orig_slot"] >= 0:
		return slot_col(inst["orig_slot"])
	return inst.get("last_col", -1)


func _unit_stat_ok(uid: int) -> bool:
	return is_unit(uid)


## Stats for units in piles use printed values; field units use live values.
func _pile_atk(uid: int) -> int:
	return atk_of(uid) if unit_on_field(uid) else base_atk(uid)


func _pile_def(uid: int) -> int:
	return def_of(uid) if unit_on_field(uid) else base_def(uid)


# ---------------------------------------------------------------- expressions and conditions

func eval_num(f: Dictionary, x) -> int:
	if x is int:
		return x
	if x is float:
		return int(x)
	if x is String and x.begins_with("$"):
		var v = f["vars"].get(x.substr(1), 0)
		return v if v is int else (v.size() if v is Array else 0)
	if x is Dictionary:
		var base := 0
		if x.has("count"):
			base = select(f, x["count"]).size()
		elif x.has("stat"):
			var r := refs(f, x.get("of", "self"))
			if r.is_empty():
				base = 0
			elif not unit_on_field(r[0]) and f["event"].get("lks", {}).has(r[0]):
				base = f["event"]["lks"][r[0]][x["stat"]]   # last-known state (P-11)
			else:
				base = _pile_atk(r[0]) if x["stat"] == "atk" else _pile_def(r[0])
		elif x.has("status"):
			var r2 := refs(f, x.get("of", "self"))
			base = 0 if r2.is_empty() else status_count(r2[0], x["status"])
		elif x.has("pile"):
			base = players[who(f, x.get("who", "self"))][x["pile"]].size()
		elif x.has("sum_atk"):
			for u in select(f, x["sum_atk"]):
				base += atk_of(u)
		elif x.has("value"):
			base = eval_num(f, x["value"])
		elif x.has("cost_of"):
			var r3 := refs(f, x["cost_of"])
			base = -99 if r3.is_empty() else current_cost(r3[0])
		elif x.has("unique_races"):
			var races := {}
			for u in field_units(who(f, x["unique_races"])):
				if unit_race(u) != "":
					races[unit_race(u)] = true
			base = races.size()
		elif x.has("min_atk"):
			var units := select(f, x["min_atk"])
			if units.is_empty():
				base = 0
			else:
				base = 1 << 30
				for u in units:
					base = mini(base, atk_of(u))
		return base * int(x.get("mul", 1)) + int(x.get("add", 0))
	return 0


func eval_cond(f: Dictionary, cond: Dictionary) -> bool:
	for key in cond:
		var v = cond[key]
		match key:
			"other_in_column":
				if not unit_on_field(f["src"]): return false
				var col := column_of(f["src"])
				var found := false
				for u in field_units(f["ctl"]):
					if u != f["src"] and column_of(u) == col:
						found = true
				if found != v: return false
			"count":
				var n := select(f, v).size()
				if cond.has("min") and n < cond["min"]: return false
				if cond.has("max") and n > cond["max"]: return false
			"min", "max":
				pass
			"hp_lower":
				if (players[f["ctl"]]["hp"] < players[opp(f["ctl"])]["hp"]) != v: return false
			"self_has_buff":
				if has_any_buff(f["src"]) != v: return false
			"self_front":
				if not unit_on_field(f["src"]) or (slot_row(cards[f["src"]]["slot"]) == 0) != v: return false
			"my_turn":
				if (active == f["ctl"]) != v: return false
			"var_nonempty":
				if refs(f, "$" + v).is_empty(): return false
			"protecting":
				if (protected_by(f["src"]) != -1) != v: return false
			"event_cost_min":
				var ec: int = f["event"].get("card", -1)
				if not cards.has(ec) or current_cost(ec) < v: return false
			"event_atk_min":
				var ea: int = f["event"].get("card", -1)
				if not cards.has(ea) or not unit_on_field(ea) or atk_of(ea) < v: return false
			"event_target_unit":
				var et: int = f["event"].get("target", -1)
				if (et != -1 and unit_on_field(et)) != v: return false
			"event_type":
				if f["event"].get("type", "") != v: return false
			"not":
				if eval_cond(f, v): return false
			"pile_has_zero_cost":
				pass
	return true


# ---------------------------------------------------------------- triggers

## Queues abilities of every card listening for `event_name`. Each listener's
## script entry has "on": [{"when": name, "cond": {...}, "ops": [...]}].
func emit(event_name: String, ev: Dictionary) -> void:
	ev["name"] = event_name
	var candidates := []
	for p in [active, opp(active)]:
		candidates += field_units(p) + power_cards(p) + backrow_cards(p).filter(func(u): return is_face_up(u))
	# Destroyed/left cards still trigger their own "self" events via snapshot.
	var self_uid: int = ev.get("self", -1)
	if self_uid != -1 and not (self_uid in candidates):
		candidates.append(self_uid)
	for uid in candidates:
		var entry := script_of(uid)
		for t in entry.get("on", []):
			if t["when"] != event_name:
				continue
			if not _listener_ok(uid, t, ev):
				continue
			var ctl: int = cards[uid]["ctl"] if on_field(uid) else ev.get("ctl", cards[uid]["owner"])
			trigger_queue.append({"uid": uid, "ctl": ctl, "ops": t["ops"], "label": "%s (%s)" % [name_of(uid), t.get("text", event_name)], "event": ev})


func _listener_ok(uid: int, t: Dictionary, ev: Dictionary) -> bool:
	var scope: String = t.get("scope", "self")
	var snap_debil: bool = ev.get("debilitated", false) if ev.get("self", -1) == uid else false
	if scope == "self":
		if ev.get("self", -1) != uid:
			return false
		if snap_debil:
			return false
		if on_field(uid) and is_debilitated(uid):
			return false
	else:
		if not on_field(uid) or is_debilitated(uid):
			return false
		if not cards[uid]["face_up"] and cards[uid]["zone"] == "backrow":
			return false
	var ctl: int = cards[uid]["ctl"] if on_field(uid) else ev.get("ctl", cards[uid]["owner"])
	match scope:
		"own_turn":
			if ev.get("player", -1) != ctl: return false
		"mine":
			if ev.get("ctl", -1) != ctl: return false
		"theirs":
			if ev.get("ctl", -1) == ctl: return false
	if t.has("filter"):
		var f := make_frame(uid, ctl, [], "")
		f["event"] = ev
		if not eval_cond(f, t["filter"]):
			return false
	return true


func _flush_triggers() -> void:
	var by_player := {active: [], opp(active): []}
	for t in trigger_queue:
		by_player[t["ctl"]].append(t)
	trigger_queue.clear()
	# Stack is LIFO: push the opponent's group first so the active player's resolves first.
	for p in [opp(active), active]:
		if by_player[p].is_empty():
			continue
		push_frame(make_frame(-1, p, [{"op": "trigger_group", "items": by_player[p]}], "triggers"))


## Resolves a controller's simultaneous triggers in the order they choose.
func _op_trigger_group(f: Dictionary, op: Dictionary) -> int:
	var items: Array = f["vars"].get("items", op["items"].duplicate())
	f["vars"]["items"] = items
	if items.is_empty():
		return R.CONT
	var pick := 0
	var self_first := -1
	for i in items.size():
		if items[i]["event"].get("self", -1) == items[i]["uid"]:
			self_first = i
			break
	if self_first != -1:
		pick = self_first
	elif items.size() > 1:
		var ans: Variant = take_answer(f)
		if ans == null:
			var opts := []
			for i in items.size():
				opts.append({"v": i, "label": items[i]["label"], "uid": items[i]["uid"]})
			return ask(f, f["ctl"], "order", "Choose which of your triggered effects resolves next.", opts)
		pick = ans[0]
	var t: Dictionary = items.pop_at(pick)
	var tops: Array = t["ops"]
	if t["ctl"] == active:
		# P-24: triggered effects are effect activations; the opponent may respond (Energy Dispel etc.).
		tops = [{"op": "window", "event": {"name": "activate", "player": t["ctl"], "card": t["uid"], "text": "%s's effect" % name_of(t["uid"])}},
			{"op": "check_negated"}] + tops
	var tf := make_frame(t["uid"], t["ctl"], tops, t["label"], t["event"])
	add_log("Trigger: %s." % t["label"])
	if not fx_pos(t["uid"]).is_empty():
		add_fx({"k": "trigger", "at": fx_pos(t["uid"])})
	push_frame(tf)
	return R.STAY if not items.is_empty() else R.CONT


# ---------------------------------------------------------------- response windows (Traps)

## Trap owners respond to an event. Repeats until the owner passes or no traps remain.
func _op_window(f: Dictionary, op: Dictionary) -> int:
	var ev: Dictionary = op["event"]
	var responder := opp(active)
	if winner != -1:
		return R.END
	var used: Array = f["vars"].get("used", [])
	f["vars"]["used"] = used
	if f["vars"].get("passed", false):
		return R.CONT
	if ev.get("player", -1) == responder:
		return R.CONT
	var eligible := []
	var concealed := false   # any face-down card that could plausibly be a Trap
	for uid in backrow_cards(responder):
		if not is_face_up(uid) and cards[uid]["set_turn"] != turn:
			concealed = true
		if category(uid) != "trap" or uid in used:
			continue
		if cards[uid]["set_turn"] == turn:
			continue
		if _trap_eligible(uid, responder, ev):
			eligible.append(uid)
	# Opening the window only when a Trap is eligible would tell the opponent so.
	# With hidden_response_windows the responder is asked whenever they hold a
	# face-down card, and simply passes when nothing can respond.
	# P-27 (user): prompt only when a legal response exists; dummy windows are off by default.
	var always: bool = config.get("hidden_response_windows", false)
	if eligible.is_empty() and (not always or not concealed or not used.is_empty()):
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans == null:
		var opts := [{"v": -1, "label": "Pass" if not eligible.is_empty() else "Pass (no Trap can respond)"}]
		for uid in eligible:
			opts.append(card_option(uid, "Activate " + name_of(uid)))
		return ask(f, responder, "trap_response", "Respond to: %s" % ev.get("text", ev["name"]), opts, 1, 1, false, {"event": ev})
	var choice: int = ans[0]
	if choice == -1:
		f["vars"]["passed"] = true
		return R.CONT
	used.append(choice)
	activate_trap(choice, responder, ev)
	return R.STAY


func _trap_eligible(uid: int, p: int, ev: Dictionary) -> bool:
	var tr: Dictionary = script_of(uid).get("trap", {})
	if tr.is_empty():
		return false
	var whens: Array = tr["when"] if tr["when"] is Array else [tr["when"]]
	if not (ev["name"] in whens):
		return false
	if current_cost(uid) < 0:
		return false
	if is_debilitated(uid):
		return false
	var f := make_frame(uid, p, [], "")
	f["event"] = ev
	match ev["name"]:
		"attack":
			if ev["player"] == p: return false
			if tr.get("target_unit_only", false) and ev.get("target", -1) == -1: return false
			if tr.get("column", false):
				if ev["column"] != cards[uid]["slot"]: return false
		"summon":
			if ev["player"] == p: return false
		"activate":
			if ev["player"] == p: return false
			if tr.get("power_only", false) and category(ev["card"]) != "power": return false
		"destroyed":
			if ev["ctl"] != p: return false
			if tr.get("by_effect", false) and ev["cause"] != "effect": return false
			if tr.get("by_opponent", false) and ev.get("by_player", -1) != opp(p): return false
	if tr.has("cond") and not eval_cond(f, tr["cond"]):
		return false
	if column_summon_blocked(f, tr["ops"]):
		return false
	# A Trap whose effect opens with a target choice is only offered when that choice has a legal
	# target (feedback 07: Wabuku on a direct attack with nothing in its column). needs_target
	# extends the check to a later or optional choice.
	for op in tr["ops"]:
		if op["op"] == "choose":
			if tr.get("needs_target", false) or not op.get("optional", false):
				return not select(f, op["sel"]).is_empty()
			break
		if not tr.get("needs_target", false) and not (op["op"] in ["cost_perm"]):
			break
	return true


## Free zones for a summon placed "column" (the source's column) or "orig" (the zone it
## left) by frame f.
func placement_slots(f: Dictionary, zone: String) -> Array:
	var p: int = f["ctl"]
	match zone:
		"column":
			var col: int = f["vars"].get("column", _col_any(f["src"]) if on_field(f["src"]) else f["event"].get("column", 0))
			return [col, col + 3].filter(func(s): return players[p]["units"][s] == -1)
		"orig":
			var o: int = f["event"].get("orig_slot", cards[f["src"]]["orig_slot"])
			return [o] if o >= 0 and players[p]["units"][o] == -1 else []
	return []


## True when a top-level summon into "column"/"orig" has no free zone, so the Trap is not
## offered and the Spell/ability is refused before anything is paid.
func column_summon_blocked(f: Dictionary, ops: Array) -> bool:
	for op in ops:
		if op["op"] == "summon" and op.get("place", "any") in ["column", "orig"] and placement_slots(f, op["place"]).is_empty():
			return true
	return false


func activate_trap(uid: int, p: int, ev: Dictionary) -> void:
	cards[uid]["face_up"] = true
	add_log("%s activates Trap %s." % [pname(p), name_of(uid)])
	add_fx({"k": "spotlight", "p": p, "id": d(uid)["id"], "how": "trap", "at": fx_pos(uid)})
	emit("trap_activated", {"player": p, "card": uid})
	var tr: Dictionary = script_of(uid)["trap"]
	var ops: Array = tr["ops"].duplicate()
	ops.append({"op": "finish_card", "target": "self"})
	push_frame(make_frame(uid, p, ops, name_of(uid), ev))


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
	var cands := select(f, op["sel"])
	if op.has("exclude"):
		var ex := refs(f, op["exclude"])
		cands = cands.filter(func(u): return not (u in ex))
	if cards.has(f["src"]) and cards[f["src"]]["zone"] == "hand":
		cands = cands.filter(func(u): return u != f["src"])   # a Spell choosing before it is cast never picks itself
	var chooser: int = who(f, op.get("chooser", "self"))
	if op["sel"].get("kind", "unit") in ["hand", "draw", "spent", "exhaust", "extra", "spent_or_draw"]:
		cands.sort()
	if cands.is_empty():
		f["vars"][op["as"]] = []
		if not op.get("optional", false) and not op.get("quiet", false):
			# F02-09: a resolving effect with nothing to choose explains itself (toast + log).
			# Named publicly only when its source card is public.
			var msg := "%s: no legal target, so this part does nothing." % f["label"]
			add_log(msg if is_public_card(f["src"]) else "", {f["ctl"]: msg})
			log_entries[-1]["toast"] = true
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


func _target_label(uid: int, viewer: int) -> String:
	var inst: Dictionary = cards[uid]
	var owner_tag := "your" if inst["ctl"] == viewer else "opponent's"
	if inst["zone"] == "unit":
		return "%s %s (%d/%d, %s row col %d)" % [owner_tag, name_of(uid), atk_of(uid), def_of(uid),
			"front" if slot_row(inst["slot"]) == 0 else "back", slot_col(inst["slot"]) + 1]
	if inst["zone"] == "backrow" and not is_face_up(uid) and inst["ctl"] != viewer:
		return "%s face-down card (col %d)" % [owner_tag, inst["slot"] + 1]
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
	# Only options that can actually do something are offered (e.g. Auric's "Destroy a face-down
	# card" while no face-down card exists), so a cost is never paid for an impossible effect.
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


## Gain/loss of ATK/DEF from a card effect. Reversible by Sneaky Snunday.
func _op_stat(f: Dictionary, op: Dictionary) -> int:
	var a := eval_num(f, op.get("atk", 0))
	var df := eval_num(f, op.get("def", 0))
	if f["reversed"]:
		a = -a
		df = -df
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
		add_fx({"k": "stat", "at": fx_pos(u), "atk": ua, "def": ud})
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


## HP change for a player from a card effect. Negative = loss. Reversible.
func _op_hp(f: Dictionary, op: Dictionary) -> int:
	var n := eval_num(f, op["n"])
	if f["reversed"]:
		n = -n
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
	for u in refs(f, op["target"]):
		var from: String = cards[u]["zone"]
		var was_public := not (from in HIDDEN_PILES)
		if from == "backrow" and not is_face_up(u):
			was_public = false
		var label := public_label(u)
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


## Script flags that apply regardless of zone (e.g. "if sent from Field to Spent").
func has_flag_raw(uid: int, flag: String) -> bool:
	return script_of(uid).get("flags", []).has(flag)


# ---------------------------------------------------------------- leaving Field and destruction

## Moves a field card to a pile, snapshotting it first. Returns the snapshot.
func _leave_field(uid: int, dest: String, cause: String, f = null) -> Dictionary:
	var snap := snapshot(uid)
	if dest == "spent" and has_flag_raw(uid, "exhaust_on_spent"):
		dest = "exhaust"
	move_to_pile(uid, dest)
	return snap


## Last-known state of a card before it leaves Field (P-11).
func snapshot(uid: int) -> Dictionary:
	var inst: Dictionary = cards[uid]
	var s := inst.duplicate(true)
	if inst["zone"] == "unit":
		s["atk_now"] = atk_of(uid)
		s["def_now"] = def_of(uid)
		s["type_now"] = unit_type(uid)
		s["race_now"] = unit_race(uid)
	return s


## Destroys a field card. Handles replacement (Mans Best Friend), protection flags and
## Eternal. Returns true if the card was destroyed.
## battle_vs: the other combatant's state captured before either unit was destroyed
## ({"atk", "type", "debilitated"}), so simultaneous destruction reads consistent values.
func destroy(uid: int, cause: String, by_uid: int, by_player: int, battle_vs: Dictionary = {}) -> bool:
	if not on_field(uid):
		return false
	var inst: Dictionary = cards[uid]
	if inst["zone"] == "unit":
		if cause == "battle" and not battle_vs.is_empty():
			if has_flag(uid, "battle_immune_30atk") and battle_vs["atk"] >= 30:
				add_log("%s cannot be destroyed by battle with a unit of 30+ ATK." % name_of(uid))
				return false
			if has_flag(uid, "battle_immune_lightning") and battle_vs["type"] == "Lightning":
				add_log("%s cannot be destroyed by battle with a Lightning unit." % name_of(uid))
				return false
		_guardian_replacement(uid)
		if status_count(uid, "eternal") > 0:
			decrement_status(uid, "eternal")
			add_log("Eternal prevents the destruction of %s (Eternal -1)." % name_of(uid))
			return false
	var p: int = inst["ctl"]
	var label := public_label(uid)
	var was_unit: bool = inst["zone"] == "unit"
	var snap := snapshot(uid)
	var debil := is_debilitated(uid)
	var dpos := fx_pos(uid)
	var dest := "spent"
	if (has_flag_raw(uid, "exhaust_on_destroy") and not debil) or has_flag_raw(uid, "exhaust_on_spent"):
		dest = "exhaust"
	move_to_pile(uid, dest)
	add_log("%s is destroyed%s." % [label, " by battle" if cause == "battle" else ""])
	add_fx({"k": "destroy", "at": dpos, "cause": cause})
	var ev := {"self": uid, "ctl": p, "cause": cause, "by": by_uid, "by_player": by_player,
		"snapshot": snap, "debilitated": debil, "was_unit": was_unit, "player": active,
		"text": "%s destroyed" % label, "type": snap.get("type_now", ""), "orig_slot": snap["slot"]}
	emit("destroyed", ev)
	if was_unit:
		if by_player != -1 and by_player != p:
			emit("destroyed_opp_unit", {"self": by_uid, "victim": uid, "ctl": by_player, "cause": cause, "player": active,
				"debilitated": battle_vs.get("debilitated", false)})
		if cause == "battle" and by_uid != -1:
			emit("battle_destroyed", {"self": by_uid, "victim": uid, "ctl": by_player, "player": active,
				"debilitated": battle_vs.get("debilitated", false)})
		emit("unit_destroyed", {"victim": uid, "ctl": p, "type": snap.get("type_now", ""), "cause": cause, "player": active, "by": by_uid})
		window_queue.append({"name": "destroyed", "self": uid, "ctl": p, "cause": cause, "by_player": by_player,
			"by": by_uid, "player": active, "text": "%s destroyed" % label})
	return true


## Mans Best Friend: if your Warrior in its column would be destroyed, give it Eternal and destroy MBF.
func _guardian_replacement(uid: int) -> void:
	if unit_race(uid) != "Warrior":
		return
	for g in field_units(cards[uid]["ctl"]):
		if g != uid and has_flag(g, "warrior_guard") and column_of(g) == column_of(uid):
			add_log("%s protects %s." % [name_of(g), name_of(uid)])
			apply_status(uid, "eternal", 1)
			destroy(g, "effect", g, cards[g]["ctl"])
			return
