class_name MatchView
extends RefCounted
## Builds the redacted state a given player may see. This is what is sent over the
## network and what the UI renders, so hidden information never leaves the authority:
## opponent Hand/Draw/Spent/Exhaust/Extra contents and unrevealed set cards are
## reduced to counts or anonymous placeholders, and choice options are referred to
## by index rather than by card uid.


static func build(m: MatchEngine, viewer: int) -> Dictionary:
	var ps := []
	for p in 2:
		ps.append(_player_view(m, p, viewer))
	var v := {
		"you": viewer, "turn": m.turn, "active": m.active, "phase": m.phase, "winner": m.winner,
		"first_turn": m.turn == 1, "reversal": m.reversal_active(), "players": ps,
		"pending": _pending_view(m, viewer), "log": log_for(m, viewer),
		"resolving": not m.stack.is_empty(),
	}
	v["actions"] = actions_for(m, viewer)
	v["extra_avail"] = extra_availability(m, viewer, v["actions"])
	return v


## F03-08: what can be summoned from the viewer's Extra Deck right now, by method, so the Extra
## pile cue is never mistaken for Fusion-specific proof. {"any": bool, "methods": [...]} where a
## method is {"kind": "ritual" | "arcane", "uid": Extra unit} or {"kind": "fusion", "t": command,
## "via": method card, "idx": ability index, "targets": [Fusion units]}. Only the viewer's own
## cards appear, and only while the viewer can act.
static func extra_availability(m: MatchEngine, viewer: int, actions: Array) -> Dictionary:
	var methods := []
	var seen := {}
	var extra: Array = m.players[viewer]["extra"]
	for a in actions:
		if a.get("ok", false) and String(a["t"]) in ["ritual", "arcane"] and int(a["uid"]) in extra and not seen.has(a["uid"]):
			seen[a["uid"]] = true
			methods.append({"kind": a["t"], "uid": a["uid"]})
	var can_act := m.winner == -1 and m.pending.is_empty() and m.stack.is_empty() and m.active == viewer
	if can_act:
		for fm in m.fusion_methods(viewer):
			methods.append({"kind": "fusion", "t": fm["t"], "via": fm["uid"], "idx": fm.get("idx", -1), "targets": fm["targets"]})
	return {"any": not methods.is_empty(), "methods": methods}


## Whether `viewer` may see the identity of card `uid`.
static func can_see(m: MatchEngine, uid: int, viewer: int) -> bool:
	var inst: Dictionary = m.cards[uid]
	match inst["zone"]:
		"unit", "power", "limbo":
			return true
		"backrow":
			return inst["ctl"] == viewer or m.is_face_up(uid)
		_:
			return inst["owner"] == viewer


static func card_view(m: MatchEngine, uid: int, viewer: int) -> Dictionary:
	var inst: Dictionary = m.cards[uid]
	if not can_see(m, uid, viewer):
		return {"hidden": true, "zone": inst["zone"], "slot": inst["slot"], "ctl": inst["ctl"]}
	var df := m.d(uid)
	var v := {
		"uid": uid, "id": df["id"], "name": df["name"], "category": df["category"],
		"cost_kind": df["cost_kind"], "cost_text": m.cost_text(uid), "cost": m.current_cost(uid),
		"printed_cost": df["cost"], "zone": inst["zone"], "slot": inst["slot"], "owner": inst["owner"], "ctl": inst["ctl"],
		"face_up": m.is_face_up(uid), "statuses": inst["st"].duplicate(), "runes": inst["runes"],
		"text": _rules_text(df), "text_parts": rules_parts(df), "support": CardScripts.support_status(df["id"]), "art": df["art"],
		"keywords": df["keywords"],
	}
	var abs: Array = m.script_of(uid).get("abilities", [])
	if not abs.is_empty():
		v["abilities"] = ability_views(abs)
	if m.is_unit(uid):
		v["race"] = m.unit_race(uid)
		v["type"] = m.unit_type(uid)
		v["printed_atk"] = df["atk"]
		v["printed_def"] = df["def"]
		if inst["zone"] == "unit":
			var b := m.stat_breakdown(uid)
			v["atk"] = b["atk"]
			v["def"] = b["def"]
			v["stat_parts"] = b["parts"]
			v["stance"] = inst["stance"]
			v["protected"] = m.is_protected(uid)
			v["attacked"] = inst["attacked_turn"] == m.turn
			v["new"] = inst["summoned_turn"] == m.turn
			v["controlled_until"] = inst["control_until"]
		else:
			v["atk"] = m.base_atk(uid) if df["atk"] != null or inst["base_atk"] != null else null
			v["def"] = m.base_def(uid) if df["def"] != null or inst["base_def"] != null else null
	if inst["zone"] == "backrow":
		v["set_by_you"] = inst["ctl"] == viewer
	return v


## A card definition shown outside a match instance (e.g. opened from the game log), with the
## same fields card_view() gives a visible card so it renders identically.
static func def_view(id: int) -> Dictionary:
	var df := CardDB.get_def(id)
	var v := {
		"uid": -2000 - id, "id": id, "name": df["name"], "category": df["category"],
		"cost_kind": df["cost_kind"], "cost_text": CardDB.cost_label(df), "cost": df["cost"],
		"printed_cost": df["cost"], "zone": "pile", "slot": -1, "owner": -1, "ctl": -1,
		"face_up": true, "statuses": {}, "runes": 0,
		"text": _rules_text(df), "text_parts": rules_parts(df), "support": CardScripts.support_status(id), "art": df["art"],
		"keywords": df["keywords"],
	}
	var abs: Array = CardScripts.get_entry(id).get("abilities", [])
	if not abs.is_empty():
		v["abilities"] = ability_views(abs)
	if CardDB.is_unit_category(df["category"]):
		v["race"] = df["race"]
		v["type"] = df["type"]
		v["printed_atk"] = df["atk"]
		v["printed_def"] = df["def"]
		v["atk"] = df["atk"]
		v["def"] = df["def"]
	return v


## Display view of a card summary (Series.card_summary) for menus, rewards, decks and the
## spotlight: a full card face with no game instance behind it.
static func summary_view(c: Dictionary) -> Dictionary:
	var kind := "ap"
	match c["category"]:
		"fusion": kind = "fusion"
		"ritual": kind = "ritual"
		"arcane": kind = "arcane"
	var d := CardDB.get_def(c["id"])
	var printed = d["cost"]
	return {"uid": -1000 - c["id"], "id": c["id"], "name": c["name"], "category": c["category"], "cost_kind": kind,
		"cost_text": c["cost_text"], "cost": printed if printed != null else 0, "printed_cost": printed,
		"race": c["race"], "type": c["type"], "atk": c["atk"], "def": c["def"], "printed_atk": c["atk"], "printed_def": c["def"],
		"text": c["text"], "support": c["support"], "art": d["art"], "statuses": {}, "runes": 0, "zone": "pile"}


static func _rules_text(df: Dictionary) -> String:
	var lines := []
	for part in rules_parts(df):
		lines.append("%s: %s" % [part["k"], part["t"]])
	return "\n".join(lines)


## Rules text split by timing (F02-08): [{"k": "On Summon", "t": "..."}, ...] in card order.
static func rules_parts(df: Dictionary) -> Array:
	var out := []
	if df["condition"] != "":
		out.append({"k": "Materials" if df["category"] == "fusion" else ("Activates" if df["category"] == "trap" else "Condition"), "t": df["condition"]})
	if df["on_summon"] != "":
		out.append({"k": "Effect" if df["category"] in ["spell", "trap"] else "On Summon", "t": df["on_summon"]})
	if df["on_field"] != "":
		out.append({"k": "Effect" if df["category"] == "power" else "On Field", "t": df["on_field"]})
	if df["on_destruction"] != "":
		out.append({"k": "On Destruction", "t": df["on_destruction"]})
	return out


## Activated abilities with their short button label and full description (F02-04).
static func ability_views(abs: Array) -> Array:
	var shorts := []
	for ab in abs:
		shorts.append(CardScripts.short_label(String(ab["label"])))
	var out := []
	for i in abs.size():
		var sh: String = shorts[i]
		if shorts.count(sh) > 1:
			sh = "%s %d" % [sh, shorts.slice(0, i + 1).count(shorts[i])]
		var cost: Dictionary = abs[i].get("cost", {})
		out.append({"label": String(abs[i]["label"]), "short": sh, "opt": abs[i].get("opt", false),
			"ap": int(cost.get("ap", 0)), "hp": int(cost.get("hp", 0))})
	return out


static func _player_view(m: MatchEngine, p: int, viewer: int) -> Dictionary:
	var pl: Dictionary = m.players[p]
	var v := {
		"name": pl["name"], "hp": pl["hp"], "ap": pl["ap"],
		"ap_start": pl.get("ap_start", pl["ap"]), "ap_peak": pl.get("ap_peak", pl["ap"]),
		"counts": {"hand": pl["hand"].size(), "draw": pl["draw"].size(), "spent": pl["spent"].size(),
			"exhaust": pl["exhaust"].size(), "extra": pl["extra"].size()},
		"units": [], "backrow": [], "powers": [],
		"ap_next": pl["ap_next"].duplicate(true) if p == viewer else [],
	}
	for z in ["units", "backrow", "powers"]:
		for uid in pl[z]:
			v[z].append(null if uid == -1 else card_view(m, uid, viewer))
	if p == viewer:
		for z in ["hand", "spent", "exhaust", "extra"]:
			v[z] = pl[z].map(func(u): return card_view(m, u, viewer))
		# Own Draw inspection: contents in a display order unrelated to the real order.
		var shown: Array = pl["draw"].duplicate()
		shown.sort()
		v["draw_inspect"] = shown.map(func(u): return card_view(m, u, viewer))
	return v


static func _pending_view(m: MatchEngine, viewer: int) -> Dictionary:
	var pd: Dictionary = m.pending
	if pd.is_empty():
		return {}
	if pd["player"] != viewer:
		return {"id": pd["id"], "mine": false, "player": pd["player"], "kind": pd["kind"],
			"prompt": "Waiting for %s: %s" % [m.pname(pd["player"]), _public_kind(pd["kind"])]}
	var opts := []
	for i in pd["options"].size():
		var o: Dictionary = pd["options"][i]
		var ov := {"i": i, "label": o["label"]}
		if o.has("preview"):
			ov["preview"] = o["preview"]
		if o.has("value"):
			ov["value"] = o["value"]          # e.g. an Arcane material's current cost (F03-04)
		if o.has("slot"):
			ov["slot"] = o["slot"]
			ov["zone"] = o["zone"]
		if o.has("uid") and m.cards.has(o["uid"]):
			var u: int = o["uid"]
			var inst: Dictionary = m.cards[u]
			if inst["zone"] in ["unit", "backrow", "power"]:
				ov["ref"] = {"p": inst["ctl"], "zone": inst["zone"], "slot": inst["slot"]}
			# The chooser sees the card itself (whole hidden pile shown for the selection).
			if can_see(m, u, viewer) or pd.get("reveal_pile", false):
				var cv := card_view(m, u, viewer) if can_see(m, u, viewer) else _forced_view(m, u, viewer)
				ov["card"] = cv
		opts.append(ov)
	var out := {"id": pd["id"], "mine": true, "player": viewer, "kind": pd["kind"], "prompt": pd["prompt"],
		"options": opts, "min": pd["min"], "max": pd["max"], "cancellable": pd["cancellable"],
		"min_total": pd.get("min_total", 0)}
	if pd.has("total_required"):
		out["total_required"] = pd["total_required"]
		out["total_exact"] = pd.get("total_exact", false)
	if pd["kind"] == "trap_response" and pd.has("event"):
		out["cause"] = _cause_refs(m, pd["event"])
	return out


## Why picking option indices `picks` would be rejected for the viewer's pending choice `pd`
## (a _pending_view result), or "" when the authority will accept the count and total. The
## material picker uses this so its Confirm agrees with the authority (F03-04).
static func multi_pick_error(pd: Dictionary, picks: Array) -> String:
	if pd.is_empty():
		return "No choice."
	if picks.size() < int(pd.get("min", 1)) or picks.size() > int(pd.get("max", 1)):
		return "Choose between %d and %d options." % [int(pd.get("min", 1)), int(pd.get("max", 1))]
	if pd.has("total_required") or int(pd.get("min_total", 0)) > 0:
		var total := 0
		for i in picks:
			for o in pd.get("options", []):
				if int(o["i"]) == int(i):
					total += maxi(int(o.get("value", o.get("card", {}).get("cost", 0))), 0)
		if pd.get("total_exact", false):
			if total != int(pd["total_required"]):
				return "Selected total %d; exactly %d required." % [total, int(pd["total_required"])]
		elif total < int(pd.get("min_total", 0)):
			return "Selected total %d; %d required." % [total, int(pd["min_total"])]
	return ""


## Public board positions of what a Trap is responding to: the attacker and its target (or the
## defending player for a direct attack), or the card whose summon / activation opened the window.
static func _cause_refs(m: MatchEngine, ev: Dictionary) -> Dictionary:
	if ev.get("name", "") == "attack":
		var t: int = int(ev.get("target", -1))
		return {"attacker": m.fx_pos(int(ev.get("attacker", -1))),
			"target": m.fx_pos(t) if t != -1 else {}, "direct_p": m.opp(int(ev.get("player", 0)))}
	var c: int = int(ev.get("card", -1))
	return {"card": m.fx_pos(c)} if c != -1 and m.cards.has(c) else {}


## A selection effect may reveal a normally hidden card to the chooser only.
static func _forced_view(m: MatchEngine, uid: int, viewer: int) -> Dictionary:
	var inst: Dictionary = m.cards[uid]
	var real_owner: int = inst["owner"]
	inst["owner"] = viewer
	var v := card_view(m, uid, viewer)
	inst["owner"] = real_owner
	v["owner"] = real_owner
	return v


static func _public_kind(kind: String) -> String:
	match kind:
		"trap_response": return "deciding whether to respond"
		"order": return "ordering triggered effects"
		"slot": return "choosing a zone"
		"stance": return "choosing a stance"
		"attack_target": return "choosing an attack target"
		"confirm": return "deciding whether to use an effect"
	return "making a choice"


static func log_for(m: MatchEngine, viewer: int, since: int = 0) -> Array:
	var out := []
	for e in m.log_entries:
		if e["seq"] <= since:
			continue
		var text: String = e["priv"].get(viewer, e["pub"])
		if text != "":
			var row := {"seq": e["seq"], "turn": e["turn"], "text": text, "fx": e.get("fx", [])}
			if e.get("toast", false):
				row["toast"] = true
			out.append(row)
		elif e["pub"] != "" and not e.get("fx", []).is_empty():
			# Presentation-only events carry public board positions/amounts, never identities.
			out.append({"seq": e["seq"], "turn": e["turn"], "text": "", "fx": e["fx"]})
	return out


## Actions for each of the viewer's cards, with a reason when currently illegal.
static func actions_for(m: MatchEngine, viewer: int) -> Array:
	var out := []
	if m.winner != -1:
		return out
	var can_act := m.pending.is_empty() and m.stack.is_empty() and m.active == viewer
	var pl: Dictionary = m.players[viewer]
	var phase_label := {"main1": "Go to Battle Phase" if m.turn != 1 else "Go to Recovery", "battle": "Go to Recovery", "main2": "End turn"}
	out.append({"t": "next_phase", "label": phase_label.get(m.phase, "Next"), "ok": can_act, "reason": "" if can_act else "Not your move."})
	if not can_act:
		return out
	var cands := []
	# Labels are short on-card button texts (F02-04); "full" is the longer description.
	for u in pl["hand"]:
		match m.category(u):
			"spell": cands += [{"t": "cast", "uid": u, "label": "Cast", "full": "Cast this Spell"},
				{"t": "set", "uid": u, "label": "Set", "full": "Set face-down in a Trap/Spell zone"}]
			"trap": cands.append({"t": "set", "uid": u, "label": "Set", "full": "Set face-down in a Trap/Spell zone"})
			"power": cands.append({"t": "power", "uid": u, "label": "Play Power", "full": "Play this Power in a Power zone"})
			_:
				# F02-02: the stance is chosen by the button, not by a follow-up prompt.
				cands.append({"t": "summon", "uid": u, "stance": "atk", "label": "Summon Attack", "full": "Summon in Attack stance"})
				cands.append({"t": "summon", "uid": u, "stance": "def", "label": "Summon Defense", "full": "Summon in Defense stance"})
	for u in m.field_units(viewer):
		if m.attack_targets(u) == [-1]:
			cands.append({"t": "attack", "uid": u, "label": "Attack Direct", "full": "Attack the opponent directly"})
		else:
			cands.append({"t": "attack", "uid": u, "label": "Attack", "full": "Declare an attack"})
		var to_def: bool = m.cards[u]["stance"] == "atk"
		cands.append({"t": "stance", "uid": u, "label": "To Defense" if to_def else "To Attack",
			"full": "Change to %s stance" % ("Defense" if to_def else "Attack")})
		cands.append({"t": "sacrifice", "uid": u, "label": "Sacrifice", "full": "Sacrifice this unit (+1 AP)"})
		if m.status_count(u, "nimble") > 0:
			cands.append({"t": "move", "uid": u, "label": "Move", "full": "Move to an adjacent empty zone (Nimble)"})
	for u in m.field_units(viewer) + m.power_cards(viewer):
		var abs: Array = m.script_of(u).get("abilities", [])
		var views := ability_views(abs)
		for i in abs.size():
			var full: String = abs[i]["label"]
			if abs[i].get("opt", false):
				full += " (once per turn)"
			cands.append({"t": "ability", "uid": u, "idx": i, "label": views[i]["short"], "full": full})
	for u in m.backrow_cards(viewer):
		if m.category(u) == "spell":
			cands.append({"t": "activate_set", "uid": u, "label": "Activate", "full": "Activate this set Spell"})
	for u in pl["extra"]:
		match m.category(u):
			"ritual":
				cands.append({"t": "ritual", "uid": u, "stance": "atk", "label": "Summon Attack", "full": "Ritual Summon in Attack stance"})
				cands.append({"t": "ritual", "uid": u, "stance": "def", "label": "Summon Defense", "full": "Ritual Summon in Defense stance"})
			"arcane":
				cands.append({"t": "arcane", "uid": u, "stance": "atk", "label": "Summon Attack", "full": "Arcane Summon in Attack stance"})
				cands.append({"t": "arcane", "uid": u, "stance": "def", "label": "Summon Defense", "full": "Arcane Summon in Defense stance"})
	for c in cands:
		var reason := m.validate(viewer, c)
		c["ok"] = reason == ""
		c["reason"] = reason
		out.append(c)
	return out
