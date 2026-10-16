class_name TutorialScript
extends RefCounted
## Command patterns and conditions of the tutorial (F03-15): matches a player's command against
## a lesson step's expected pattern, turns the scripted opponent's patterns into concrete engine
## commands, and evaluates step conditions. Pure functions over a MatchEngine and the lesson's
## key -> uid map (see TutorialLessons for the formats).


## Index of the pending option that pattern `opt` selects, or -1.
##   {slot: n [, zone]} a zone option, {card: key} the option for that card, {label: text} a label.
static func option_index(m: MatchEngine, keys: Dictionary, opt: Dictionary) -> int:
	var pd: Dictionary = m.pending
	if pd.is_empty():
		return -1
	var options: Array = pd["options"]
	for i in options.size():
		var o: Dictionary = options[i]
		if opt.has("slot"):
			if o.has("slot") and int(o["slot"]) == int(opt["slot"]) and (not opt.has("zone") or String(o.get("zone", "")) == String(opt["zone"])):
				return i
		elif opt.has("card"):
			var uid: int = int(keys.get(String(opt["card"]), -2))
			if int(o.get("uid", -3)) == uid or int(o.get("v", -3)) == uid:
				return i
		elif opt.has("label"):
			if String(o.get("label", "")).contains(String(opt["label"])):
				return i
	return -1


## The pending option indices command `cmd` picks (by index or by value), or null when malformed.
static func chosen_indices(m: MatchEngine, cmd: Dictionary):
	var pd: Dictionary = m.pending
	if pd.is_empty() or int(cmd.get("id", -1)) != int(pd["id"]):
		return null
	var out := []
	if cmd.has("indices"):
		for i in cmd["indices"]:
			out.append(int(i))
	else:
		for v in cmd.get("values", []):
			var found := -1
			for i in pd["options"].size():
				if int(pd["options"][i]["v"]) == int(v):
					found = i
			if found == -1:
				return null
			out.append(found)
	return out


## True when command `cmd` from the learner matches step pattern `pat`.
static func matches(m: MatchEngine, keys: Dictionary, pat: Dictionary, cmd: Dictionary) -> bool:
	var t: String = String(cmd.get("t", ""))
	if t != String(pat.get("t", "")):
		return false
	if t == "choose":
		var want := option_index(m, keys, pat.get("opt", {}))
		var got = chosen_indices(m, cmd)
		return want != -1 and got != null and got == [want]
	if pat.has("card") and int(cmd.get("uid", -1)) != int(keys.get(String(pat["card"]), -2)):
		return false
	if pat.has("stance") and String(cmd.get("stance", "")) != String(pat["stance"]):
		return false
	if pat.has("idx") and int(cmd.get("idx", 0)) != int(pat["idx"]):
		return false
	return true


## The concrete engine command for pattern `pat` in the current state ({} when it cannot apply).
static func resolve(m: MatchEngine, keys: Dictionary, pat: Dictionary) -> Dictionary:
	var t: String = String(pat.get("t", ""))
	if t == "choose":
		var i := option_index(m, keys, pat.get("opt", {}))
		if i == -1:
			return {}
		return {"t": "choose", "id": int(m.pending["id"]), "indices": [i]}
	var cmd := {"t": t}
	if pat.has("card"):
		if not keys.has(String(pat["card"])):
			return {}
		cmd["uid"] = int(keys[String(pat["card"])])
	for k in ["stance", "idx"]:
		if pat.has(k):
			cmd[k] = pat[k]
	return cmd


## Pattern that an action entry of MatchView.actions_for (or a command) would satisfy: used to
## keep only the step's expected actions enabled in the learner's view.
static func action_matches(m: MatchEngine, keys: Dictionary, pat: Dictionary, action: Dictionary) -> bool:
	if String(pat.get("t", "")) == "choose":
		return false
	return matches(m, keys, pat, action)


## True when step condition `cond` holds ({} always holds).
static func holds(m: MatchEngine, cond: Dictionary) -> bool:
	if cond.has("active") and m.active != int(cond["active"]):
		return false
	if cond.has("phase") and m.phase != String(cond["phase"]):
		return false
	if cond.has("pending_kind") and String(m.pending.get("kind", "")) != String(cond["pending_kind"]):
		return false
	if cond.has("pending_player") and (m.pending.is_empty() or int(m.pending["player"]) != int(cond["pending_player"])):
		return false
	if cond.has("active") or cond.has("phase"):
		# A turn/phase condition means the game has settled there (nothing resolving or pending).
		if not cond.has("pending_kind") and (not m.pending.is_empty() or not m.stack.is_empty()):
			return false
	return true
