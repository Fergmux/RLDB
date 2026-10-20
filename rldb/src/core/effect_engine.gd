class_name EffectEngine
extends GameCore
## Resumable effect resolution: a stack of frames, each a list of typed operations
## with a program counter. Operations that need a player decision create a pending
## choice and suspend; the answer resumes the same frame. Nothing here interprets
## English card text — card behaviour is declared in CardScripts as op lists.

enum R { CONT, WAIT, STAY, END }

const HIDDEN_PILES := ["hand", "draw", "spent", "exhaust", "extra"]
## D13 (owner feedback 2026-10-20): the three answers of a Trap response window. "Skip" declines
## this window only; "Skip for the rest of this turn" declines every window until the turn ends.
const TRAP_SKIP := "Skip"
const TRAP_SKIP_NONE := "Skip (no Trap can respond)"
const TRAP_PASS_TURN := "Skip for the rest of this turn"
## Option values of the two declining answers (an Activate option's value is the Trap's uid).
const TRAP_V_SKIP := -1
const TRAP_V_PASS_TURN := -2
## J6 (owner feedback 2026-10-22): a seat's Trap response prompts (players[p]["trap_prompts"]).
## The player picks one with the Trap Prompts button (it cycles Usable, Always, Off). "eligible"
## (Usable, the default): asked only when one of their Traps can respond (P-27; the pause shows an
## eligible Trap exists). "always": asked whenever they hold a face-down card set before this turn
## that some Trap could answer from, whether or not one of theirs can, so the pause reveals nothing.
## "off": never asked, so their Traps never respond.
const TRAP_PROMPT_ELIGIBLE := "eligible"
const TRAP_PROMPT_ALWAYS := "always"
const TRAP_PROMPT_OFF := "off"
const TRAP_PROMPT_MODES := [TRAP_PROMPT_ELIGIBLE, TRAP_PROMPT_ALWAYS, TRAP_PROMPT_OFF]

## Frames; back() is resolving.
var stack: Array = []
## {uid, ctl, ops, label, event}.
var trigger_queue: Array = []
## Response-window events awaiting a frame.
var window_queue: Array = []
## Current choice, empty when none.
var pending: Dictionary = {}
var _next_choice_id: int = 1


## A finished game (lethal damage, concession, host claim) drops any open prompt and
## pending resolution so no stale choice survives into views.
func _on_game_over() -> void:
	pending = {}
	stack.clear()
	trigger_queue.clear()
	window_queue.clear()


# ---------------------------------------------------------------- frames

## Builds an effect frame for card src controlled by ctl.
func make_frame(src: int, ctl: int, ops: Array, label: String, event: Dictionary = {}) -> Dictionary:
	return {"src": src, "ctl": ctl, "ops": ops, "pc": 0, "vars": {}, "label": label,
		"event": event, "reversed": reversal_active(), "negated": false, "committed": false}


## Pushes a frame to resolve.
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
		# F03-04: Arcane materials must match the requirement exactly (no overpayment).
		if pending.get("total_exact", false):
			if total != int(pending["total_required"]):
				return "Selected materials total %d; exactly %d required." % [total, int(pending["total_required"])]
		elif total < pending["min_total"]:
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


## Option dictionary selecting a card by uid.
func card_option(uid: int, label: String = "") -> Dictionary:
	return {"v": uid, "uid": uid, "label": label if label != "" else name_of(uid)}


# ---------------------------------------------------------------- references and selectors

## Resolves a player reference of a frame to a seat.
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
			"type_eq":
				# Same Type as a reference unit; a typeless reference matches nothing.
				var rt := refs(f, want)
				if rt.is_empty() or unit_type(rt[0]) == "" or not is_unit(uid) or unit_type(uid) != unit_type(rt[0]): return false
			"protected_by_src":
				# The back-row unit the source (a front-row unit) is protecting.
				if not unit_on_field(src) or (protected_by(src) == uid) != want: return false
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
			"playable":
				# A Power put into play by an effect still obeys its own activation limit.
				if want and has_flag_raw(uid, "abyss_ap") and _deck_has_zero_cost(f["ctl"]): return false
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

## Evaluates a number expression in frame f.
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
		elif x.has("sum_def"):
			for u in select(f, x["sum_def"]):
				base += def_of(u)
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


## Evaluates a condition in frame f.
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
			"self_has_debuff":
				if not cards.has(f["src"]) or has_any_debuff(f["src"]) != v: return false
			"var_owned":
				# The card chosen into var `v` belongs to the frame's controller (checked after it moved).
				var vo := refs(f, "$" + String(v))
				if vo.is_empty() or cards[vo[0]]["owner"] != f["ctl"]: return false
			"free_power_zone":
				if free_power_slots(f["ctl"]).is_empty() == v: return false
			"event_card_destroyable":
				# The activated card is still on the Field, or is a Spell resolving in limbo.
				var ec2: int = f["event"].get("card", -1)
				if (cards.has(ec2) and (on_field(ec2) or cards[ec2]["zone"] == "limbo")) != v: return false
			"self_front":
				if not unit_on_field(f["src"]) or (slot_row(cards[f["src"]]["slot"]) == 0) != v: return false
			"my_turn":
				if (active == f["ctl"]) != v: return false
			"var_nonempty":
				if refs(f, "$" + v).is_empty(): return false
			"protecting":
				if (protected_by(f["src"]) != -1) != v: return false
			"protected":
				if (unit_on_field(f["src"]) and is_protected(f["src"])) != v: return false
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
		note("trigger", t)
	trigger_queue.clear()
	# Stack is LIFO: push the opponent's group first so the active player's resolves first.
	for p in [opp(active), active]:
		if by_player[p].is_empty():
			continue
		push_frame(make_frame(-1, p, [{"op": "trigger_group", "items": by_player[p]}], "triggers"))


## True when every queued trigger is the same card's same effect on the same event and that effect
## neither refers to its own card nor asks anything (two copies of Options drawing), so asking the
## player to order them would be a choice without a difference. Effects on "self" (two Soul
## Devourers gaining Runes) still ask: a response may remove one copy between them.
func _identical_triggers(items: Array) -> bool:
	var first: Dictionary = items[0]
	var text := JSON.stringify(first["ops"])
	for word in ["\"self\"", "\"choose\"", "\"confirm\"", "\"mode\"", "\"declare_type\""]:
		if text.contains(word):
			return false
	for t in items:
		if not cards.has(t["uid"]) or cards[t["uid"]]["id"] != cards[first["uid"]]["id"]:
			return false
		if t["ops"] != first["ops"] or t["event"].get("name", "") != first["event"].get("name", "") \
				or t["event"].get("self", -1) != -1:
			return false
	return true


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
	elif items.size() > 1 and _identical_triggers(items):
		pick = 0                          # e.g. two copies of Options: the order cannot matter
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
		var win := {"op": "window", "event": {"name": "activate", "player": t["ctl"], "card": t["uid"], "text": "%s's effect" % name_of(t["uid"])}}
		if String(t["event"].get("name", "")) == "summoned":
			# Owner feedback 2026-10-18: a unit's On Summon effects resolve before any Trap answers
			# them (nothing negates an effect since 2026-10-18), so the window follows them.
			tops = tops + [win]
		else:
			tops = [win, {"op": "check_negated"}] + tops
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
	if passing_traps(responder):
		return R.CONT                     # D13: they skipped Traps for the rest of this turn
	var prompts := trap_prompt_mode(responder)
	if prompts == TRAP_PROMPT_OFF:
		return R.CONT                     # J6: their toggle is off; never asked
	var eligible := []
	var concealed := false   # any face-down card that could plausibly be a Trap
	var concealed_cols := []   # J6: columns of those not already used in this window
	for uid in backrow_cards(responder):
		if not is_face_up(uid) and cards[uid]["set_turn"] != turn:
			concealed = true
			if not (uid in used):
				concealed_cols.append(int(cards[uid]["slot"]))
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
	if prompts == TRAP_PROMPT_ALWAYS:
		# J6: asked while an unused face-down card is left and some Trap of the game could answer
		# this event there, so whether one of theirs can (even after a Trap was used in this
		# window) never shows. Both tests use public information only.
		if eligible.is_empty() and (concealed_cols.is_empty() or not trap_window_plausible(responder, ev, concealed_cols)):
			return R.CONT
	elif eligible.is_empty() and (not always or not concealed or not used.is_empty()):
		return R.CONT
	var ans: Variant = take_answer(f)
	if ans == null:
		# Skip stays the first option: the default answer of simulations and automatic recovery.
		var opts := [{"v": TRAP_V_SKIP, "label": TRAP_SKIP if not eligible.is_empty() else TRAP_SKIP_NONE},
			{"v": TRAP_V_PASS_TURN, "label": TRAP_PASS_TURN}]
		for uid in eligible:
			opts.append(card_option(uid, "Activate " + name_of(uid)))
		return ask(f, responder, "trap_response", "Respond to: %s" % ev.get("text", ev["name"]), opts, 1, 1, false, {"event": ev})
	var choice: int = ans[0]
	if choice == TRAP_V_PASS_TURN:
		players[responder]["trap_pass_turn"] = turn
		add_log("", {responder: "You skip Traps for the rest of this turn."})
		f["vars"]["passed"] = true
		return R.CONT
	if choice == TRAP_V_SKIP:
		f["vars"]["passed"] = true
		return R.CONT
	used.append(choice)
	activate_trap(choice, responder, ev)
	return R.STAY


## J6: the Trap entries of every card in the game (CardScripts "trap"), read once.
static var _pool_traps: Array = []


## J6: true when some Trap of the whole card pool, set face-down in one of `cols` by player p, could
## answer event `ev` by its timing and public conditions (who acted, the column, a Power or an
## effect, how a card was destroyed). Its own state conditions ("cond", cost, Debilitate) are not
## asked: they depend on which card it is. Uses no hidden information, so a hidden-window prompt
## built on it reveals nothing; it only spares prompts no Trap could ever answer.
func trap_window_plausible(p: int, ev: Dictionary, cols: Array) -> bool:
	if _pool_traps.is_empty():
		CardDB.ensure_loaded()
		for c in CardDB.all():
			var tr: Dictionary = CardScripts.get_entry(int(c["id"])).get("trap", {})
			if String(c.get("category", "")) == "trap" and not tr.is_empty():
				_pool_traps.append(tr)
	for tr in _pool_traps:
		var whens: Array = tr["when"] if tr["when"] is Array else [tr["when"]]
		if not (ev["name"] in whens):
			continue
		match String(ev["name"]):
			"attack":
				if ev["player"] == p: continue
				if tr.get("target_unit_only", false) and ev.get("target", -1) == -1: continue
				if tr.get("column", false) and not (int(ev.get("column", -9)) in cols): continue
			"summon":
				if ev["player"] == p: continue
			"activate":
				if ev["player"] == p: continue
				if tr.get("power_only", false) and (not cards.has(ev.get("card", -1)) or category(ev["card"]) != "power"): continue
				if tr.get("effect_only", false) and ev.get("play", false): continue
			"destroyed":
				if ev["ctl"] != p: continue
				if tr.get("by_effect", false) and ev["cause"] != "effect": continue
				if tr.get("by_opponent", false) and ev.get("by_player", -1) != opp(p): continue
		return true
	return false


## J6: player p's Trap response prompt mode (TRAP_PROMPT_*; "eligible" for an unknown value).
func trap_prompt_mode(p: int) -> String:
	var mode := String(players[p].get("trap_prompts", TRAP_PROMPT_ELIGIBLE))
	return mode if mode in TRAP_PROMPT_MODES else TRAP_PROMPT_ELIGIBLE


## J6: sets player p's Trap response prompt mode. Turning prompts off while p's own response prompt
## is open answers it with Skip, so nobody waits on a prompt its player chose not to see.
func set_trap_prompts(p: int, mode: String) -> String:
	if not (mode in TRAP_PROMPT_MODES):
		return "Unknown Trap prompt setting."
	players[p]["trap_prompts"] = mode
	if mode == TRAP_PROMPT_OFF and not pending.is_empty() and pending["player"] == p and pending["kind"] == "trap_response":
		return answer_choice(p, int(pending["id"]), [TRAP_V_SKIP])
	return ""


## D13: true while player p has chosen "Skip for the rest of this turn" (no Trap window is opened
## for them until the turn ends).
func passing_traps(p: int) -> bool:
	return int(players[p].get("trap_pass_turn", -1)) == turn


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
			if tr.get("effect_only", false) and ev.get("play", false): return false
		"destroyed":
			if ev["ctl"] != p: return false
			if tr.get("by_effect", false) and ev["cause"] != "effect": return false
			if tr.get("by_opponent", false) and ev.get("by_player", -1) != opp(p): return false
		"st_destroyed":
			pass                          # any Spell/Trap, either side (Counter Transmutation)
	if tr.has("cond") and not eval_cond(f, tr["cond"]):
		return false
	if column_summon_blocked(f, tr["ops"]):
		return false
	# A Trap whose effect opens with a target choice is only offered when that choice has a legal
	# target (feedback 07: Wabuku on a direct attack with nothing in its column). needs_target
	# extends the check to a later or optional choice; "any_target" skips it (Wabuku).
	if tr.get("any_target", false):
		return true
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


## Flips Trap uid face up for player p and queues its effect for event ev.
func activate_trap(uid: int, p: int, ev: Dictionary) -> void:
	cards[uid]["face_up"] = true
	add_log("%s activates Trap %s." % [pname(p), name_of(uid)])
	add_fx({"k": "spotlight", "p": p, "id": d(uid)["id"], "how": "trap", "at": fx_pos(uid)})
	emit("trap_activated", {"player": p, "card": uid})
	note("trap", {"uid": uid, "p": p})
	var tr: Dictionary = script_of(uid)["trap"]
	var ops: Array = tr["ops"].duplicate()
	ops.append({"op": "finish_card", "target": "self"})
	push_frame(make_frame(uid, p, ops, name_of(uid), ev))


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


## Destroys a field card (or a Spell resolving in limbo, for Energy Dispel). Handles replacement
## (Man's Best Friend), protection flags and Eternal. Returns true if the card was destroyed.
## battle_vs: the other combatant's state captured before either unit was destroyed
## ({"atk", "type", "debilitated"}), so simultaneous destruction reads consistent values.
func destroy(uid: int, cause: String, by_uid: int, by_player: int, battle_vs: Dictionary = {}) -> bool:
	if not on_field(uid) and not (cards.has(uid) and cards[uid]["zone"] == "limbo"):
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
	var was_spell_trap: bool = category(uid) in ["spell", "trap"]
	var snap := snapshot(uid)
	var debil := is_debilitated(uid)
	var dpos := fx_pos(uid)
	# Presentation identity (B5): only a card everyone can see (a unit or a face-up card) is named.
	var pub_id: int = int(d(uid)["id"]) if was_unit or is_face_up(uid) else -1
	var pub_stance: String = String(inst.get("stance", "atk"))
	var dest := "spent"
	if (has_flag_raw(uid, "exhaust_on_destroy") and not debil) or has_flag_raw(uid, "exhaust_on_spent"):
		dest = "exhaust"
	move_to_pile(uid, dest)
	# A hidden card's label ("a set Spell/Trap") starts the sentence, so it is capitalised.
	add_log("%s is destroyed%s." % [label.substr(0, 1).to_upper() + label.substr(1), " by battle" if cause == "battle" else ""])
	if not dpos.is_empty():               # a resolving Spell (limbo) has no board position
		var dfx := {"k": "destroy", "at": dpos, "cause": cause, "dest": dest}
		if pub_id >= 0:
			dfx["id"] = pub_id
			if was_unit:
				dfx["stance"] = pub_stance
		add_fx(dfx)
	var ev := {"self": uid, "ctl": p, "cause": cause, "by": by_uid, "by_player": by_player,
		"snapshot": snap, "debilitated": debil, "was_unit": was_unit, "player": active,
		"text": "%s destroyed" % label, "type": snap.get("type_now", ""), "orig_slot": snap["slot"]}
	emit("destroyed", ev)
	if was_unit:
		if by_player != -1 and by_player != p:
			emit("destroyed_opp_unit", {"self": by_uid, "victim": uid, "ctl": by_player, "cause": cause, "player": active,
				"debilitated": battle_vs.get("debilitated", false)})
		emit("unit_destroyed", {"victim": uid, "ctl": p, "type": snap.get("type_now", ""), "cause": cause, "player": active, "by": by_uid})
		window_queue.append({"name": "destroyed", "self": uid, "ctl": p, "cause": cause, "by_player": by_player,
			"by": by_uid, "player": active, "text": "%s destroyed" % label})
	elif was_spell_trap:
		# Counter Transmutation (2026-10-18) responds to any destroyed Spell/Trap. Named only when it
		# was public: a set card that was destroyed face down stays unnamed.
		window_queue.append({"name": "st_destroyed", "self": uid, "ctl": p, "cause": cause, "by_player": by_player,
			"by": by_uid, "player": active, "text": "%s destroyed" % label, "slot": snap["slot"],
			"was_public": label != "a set Spell/Trap"})
	return true


## Man's Best Friend: if your Warrior in its column would be destroyed, give it Eternal and destroy MBF.
func _guardian_replacement(uid: int) -> void:
	if unit_race(uid) != "Warrior":
		return
	for g in field_units(cards[uid]["ctl"]):
		if g != uid and has_flag(g, "warrior_guard") and column_of(g) == column_of(uid):
			add_log("%s protects %s." % [name_of(g), name_of(uid)])
			apply_status(uid, "eternal", 1)
			destroy(g, "effect", g, cards[g]["ctl"])
			return
