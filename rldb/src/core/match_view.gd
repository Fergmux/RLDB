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
	return v


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
		"text": _rules_text(df), "support": CardScripts.support_status(df["id"]), "art": df["art"],
		"keywords": df["keywords"],
	}
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


static func _rules_text(df: Dictionary) -> String:
	var lines := []
	if df["condition"] != "":
		lines.append(("Materials: " if df["category"] == "fusion" else ("Activates: " if df["category"] == "trap" else "Condition: ")) + df["condition"])
	if df["on_summon"] != "":
		var prefix := "On Summon: "
		match df["category"]:
			"spell": prefix = "Effect: "
			"trap": prefix = "Effect: "
		lines.append(prefix + df["on_summon"])
	if df["on_field"] != "":
		lines.append(("Effect: " if df["category"] == "power" else "On Field: ") + df["on_field"])
	if df["on_destruction"] != "":
		lines.append("On Destruction: " + df["on_destruction"])
	return "\n".join(lines)


static func _player_view(m: MatchEngine, p: int, viewer: int) -> Dictionary:
	var pl: Dictionary = m.players[p]
	var v := {
		"name": pl["name"], "hp": pl["hp"], "ap": pl["ap"],
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
	return {"id": pd["id"], "mine": true, "player": viewer, "kind": pd["kind"], "prompt": pd["prompt"],
		"options": opts, "min": pd["min"], "max": pd["max"], "cancellable": pd["cancellable"],
		"min_total": pd.get("min_total", 0)}


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
			out.append({"seq": e["seq"], "turn": e["turn"], "text": text})
	return out


## Actions for each of the viewer's cards, with a reason when currently illegal.
static func actions_for(m: MatchEngine, viewer: int) -> Array:
	var out := []
	if m.winner != -1:
		return out
	var can_act := m.pending.is_empty() and m.stack.is_empty() and m.active == viewer
	var pl: Dictionary = m.players[viewer]
	var phase_label := {"main1": "Go to Battle Phase" if m.turn != 1 else "Go to Main Phase 2", "battle": "Go to Main Phase 2", "main2": "End turn"}
	out.append({"t": "next_phase", "label": phase_label.get(m.phase, "Next"), "ok": can_act, "reason": "" if can_act else "Not your move."})
	if not can_act:
		return out
	var cands := []
	for u in pl["hand"]:
		match m.category(u):
			"spell": cands += [{"t": "cast", "uid": u, "label": "Cast"}, {"t": "set", "uid": u, "label": "Set face-down"}]
			"trap": cands.append({"t": "set", "uid": u, "label": "Set face-down"})
			"power": cands.append({"t": "power", "uid": u, "label": "Play Power"})
			_: cands.append({"t": "summon", "uid": u, "label": "Summon"})
	for u in m.field_units(viewer):
		cands.append({"t": "attack", "uid": u, "label": "Attack"})
		cands.append({"t": "stance", "uid": u, "label": "Change stance"})
		cands.append({"t": "sacrifice", "uid": u, "label": "Sacrifice (+1 AP)"})
		if m.status_count(u, "nimble") > 0:
			cands.append({"t": "move", "uid": u, "label": "Move (Nimble)"})
	for u in m.field_units(viewer) + m.power_cards(viewer):
		var abs: Array = m.script_of(u).get("abilities", [])
		for i in abs.size():
			var lbl: String = abs[i]["label"]
			if abs[i].get("opt", false):
				lbl += " (once per turn)"
			cands.append({"t": "ability", "uid": u, "idx": i, "label": lbl})
	for u in m.backrow_cards(viewer):
		if m.category(u) == "spell":
			cands.append({"t": "activate_set", "uid": u, "label": "Activate"})
	for u in pl["extra"]:
		match m.category(u):
			"ritual": cands.append({"t": "ritual", "uid": u, "label": "Ritual Summon"})
			"arcane": cands.append({"t": "arcane", "uid": u, "label": "Arcane Summon"})
	for c in cands:
		var reason := m.validate(viewer, c)
		c["ok"] = reason == ""
		c["reason"] = reason
		out.append(c)
	return out
