class_name BotForecast
extends RefCounted
## L27 (owner feedback 2026-11-05): a light, public-information battle model the bot uses to look
## past the move it is scoring. From a snapshot of the units on the Field it plays out, greedily:
##
##   1. the rest of the side to move's Battle Phase ("now": its Attack-stance units that have not
##      attacked yet; skipped on the first turn of the game and after the Battle Phase),
##   2. the other side's reply on its next turn ("next": every unit that will be able to attack,
##      since stance changes are free in the Setup Phase, plus one VIRTUAL unit standing for what
##      it will summon from its four fresh cards when it has a free zone),
##   3. the first side's follow-up turn (scored, not applied).
##
## Each attack is chosen by its value to the attacker: the worth of a destroyed unit (plus part of
## the unit it was protecting), minus the attacker's worth if it dies, plus the HP swing; a killing
## blow is worth LETHAL. The model follows the battle rules of BattleOps (stance, type advantage and
## its bonus, protection, Infiltrate, taunt, direct attacks only into an empty board or with
## direct_attack, Pierce, Burn, Eternal and the battle immunities) and reads only the Field, which
## both players see. It never mutates the match.

## Value of one HP of the opponent's / own (scaled further by BotBrain.hp_value's danger curve).
static var HPW := 1.2
## Share of a protected unit's worth credited for destroying its protector.
static var EXPOSE_W := 0.4
## Bonus for an attack that brings the defender to 0 HP.
const LETHAL := 1000.0
## Tie-break per point of attacker ATK (see attack_value).
static var ECONOMY := 0.03
## Smallest attack value worth making in the model.
static var MIN_GAIN := 0.25
## The virtual unit a side is expected to summon next turn (an ordinary unit; 10/10 measured best in
## the arena against 0, 8/8 and 12/12).
static var VIRTUAL_ATK := 10
static var VIRTUAL_DEF := 10
static var VIRTUAL_WORTH := 10.0
## How many such units a side is expected to summon (never more than its free zones).
static var VIRTUAL_COUNT := 1
## Unit worth: presence plus stats (BotBrain uses the same numbers for material).
static var W_UNIT := 6.0
static var W_ATK := 0.6
static var W_DEF := 0.35
static var W_STATUS := 1.5
static var W_EFFECT := 2.0


## Rough worth of a unit on the Field: presence, stats, statuses, Runes and having an effect.
static func worth(m: MatchEngine, u: int) -> float:
	var v := W_UNIT + W_ATK * float(m.atk_of(u)) + W_DEF * float(m.def_of(u))
	var st: Dictionary = m.cards[u]["st"]
	for s in st:
		var n := minf(float(st[s]), 4.0)
		v += (W_STATUS if CardDB.is_buff(String(s)) else -W_STATUS) * n
	v += 0.5 * float(m.cards[u]["runes"])
	if not m.is_debilitated(u):
		var sc := m.script_of(u)
		if sc.has("abilities") or sc.has("aura") or sc.has("on") or sc.has("flags"):
			v += W_EFFECT
	return maxf(v, 1.0)


## Snapshot of the Field for the model: {"units": [records], "hp": [hp0, hp1], "bonus": [type
## bonus per side], "free": [free unit zones per side], "turn", "active"}.
static func snapshot(m: MatchEngine) -> Dictionary:
	var units := []
	for p in 2:
		for u in m.field_units(p):
			units.append(_record(m, u))
	return {"units": units, "hp": [int(m.players[0]["hp"]), int(m.players[1]["hp"])],
		"bonus": [m.type_bonus(0), m.type_bonus(1)],
		"free": [m.free_unit_slots(0).size(), m.free_unit_slots(1).size()],
		"turn": m.turn, "active": m.active}


static func _record(m: MatchEngine, u: int) -> Dictionary:
	var inst: Dictionary = m.cards[u]
	var slot: int = int(inst["slot"])
	var guarded := false
	if m.unit_race(u) == "Warrior" and not m.has_flag(u, "no_buffs") and m.status_count(u, "curse") == 0:
		for g in m.field_units(int(inst["ctl"])):
			if g != u and m.has_flag(g, "warrior_guard") and m.column_of(g) == m.column_of(u):
				guarded = true
	return {
		"u": u, "p": int(inst["ctl"]), "slot": slot, "col": slot % 3, "row": slot / 3,
		"atk": m.atk_of(u), "def": m.def_of(u), "stance": String(inst["stance"]), "type": m.unit_type(u),
		"eternal": m.status_count(u, "eternal"), "para": m.status_count(u, "paralyse"),
		"locked": m.attack_locked_reason(u) != "" or m.has_flag(u, "no_attack"),
		"attacked": int(inst["attacked_turn"]) == m.turn,
		"imm30": m.has_flag(u, "battle_immune_30atk"), "immL": m.has_flag(u, "battle_immune_lightning"),
		"guarded": guarded, "taunt": m.has_flag(u, "taunt"), "infil": m.status_count(u, "infiltrate") > 0,
		"direct": m.has_flag(u, "direct_attack"), "nodmg": m.has_flag(u, "no_battle_damage"),
		"pierce": m.status_count(u, "pierce") > 0, "burn": m.status_count(u, "burn"),
		"blind": m.status_count(u, "blind") > 0, "no_def": m.has_flag(u, "no_defense"),
		"worth": worth(m, u), "alive": true, "virtual": false,
	}


static func _virtual(p: int) -> Dictionary:
	return {"u": -1, "p": p, "slot": -1, "col": -1, "row": 0, "atk": VIRTUAL_ATK, "def": VIRTUAL_DEF, "stance": "atk",
		"type": "", "eternal": 0, "para": 0, "locked": false, "attacked": false, "imm30": false, "immL": false,
		"guarded": false, "taunt": false, "infil": false, "direct": false, "nodmg": false, "pierce": false,
		"burn": 0, "blind": false, "no_def": false, "worth": VIRTUAL_WORTH, "alive": true, "virtual": true}


## Whether record `t` is protected: a back-row unit with a living unit of its side in front.
static func _protected(s: Dictionary, t: Dictionary) -> bool:
	if int(t["row"]) != 1:
		return false
	for o in s["units"]:
		if o["alive"] and int(o["p"]) == int(t["p"]) and int(o["slot"]) == int(t["col"]):
			return true
	return false


## The living unit record protected by front-row record `t`, or {}.
static func _behind(s: Dictionary, t: Dictionary) -> Dictionary:
	if int(t["row"]) != 0 or int(t["slot"]) < 0:
		return {}
	for o in s["units"]:
		if o["alive"] and int(o["p"]) == int(t["p"]) and int(o["slot"]) == int(t["slot"]) + 3:
			return o
	return {}


static func _alive_count(s: Dictionary, p: int) -> int:
	var n := 0
	for o in s["units"]:
		if o["alive"] and int(o["p"]) == p:
			n += 1
	return n


## Legal targets of attacker record `a` (records; {} for the direct attack).
static func _targets(s: Dictionary, a: Dictionary) -> Array:
	var q := 1 - int(a["p"])
	var out := []
	var any := false
	for t in s["units"]:
		if not t["alive"] or int(t["p"]) != q:
			continue
		any = true
		if a["infil"] or not _protected(s, t):
			out.append(t)
	var lures := out.filter(func(t): return t["taunt"])
	if not lures.is_empty():
		out = lures
	if not any or a["direct"]:
		out.append({})
	return out


static func _survives(t: Dictionary, a: Dictionary) -> bool:
	if t["imm30"] and int(a["atk"]) >= 30:
		return true
	if t["immL"] and String(a["type"]) == "Lightning":
		return true
	return t["guarded"] or int(t["eternal"]) > 0


## Battle result of `a` attacking `t` ({} = direct): {"a_dies", "t_dies", "dmg_def", "dmg_att"}.
static func outcome(s: Dictionary, a: Dictionary, t: Dictionary) -> Dictionary:
	var burn := int(a["burn"])
	if t.is_empty():
		return {"a_dies": false, "t_dies": false, "dmg_def": 0 if a["nodmg"] else int(a["atk"]), "dmg_att": burn}
	var av := int(a["atk"])
	var def_atk: bool = String(t["stance"]) == "atk"
	var dv := int(t["atk"]) if def_atk else int(t["def"])
	var ta := String(a["type"])
	var tt := String(t["type"])
	if ta != "" and CardDB.TYPE_ADVANTAGE.get(ta, "") == tt:
		av += int(s["bonus"][int(a["p"])])
	elif tt != "" and CardDB.TYPE_ADVANTAGE.get(tt, "") == ta:
		dv += int(s["bonus"][int(t["p"])])
	var a_dies := false
	var t_dies := false
	var dmg_def := 0
	var dmg_att := 0
	if def_atk:
		if av > dv:
			t_dies = true
			dmg_def = 0 if a["nodmg"] else av - dv
		elif av == dv:
			t_dies = true
			a_dies = true
		else:
			a_dies = true
			dmg_att = dv - av
	else:
		if av > dv:
			t_dies = true
			if a["pierce"] and not a["nodmg"]:
				dmg_def = av - dv
		elif av < dv:
			dmg_att = dv - av
	if t_dies and _survives(t, a):
		t_dies = false
	if a_dies and _survives(a, t):
		a_dies = false
	return {"a_dies": a_dies, "t_dies": t_dies, "dmg_def": dmg_def, "dmg_att": dmg_att + burn}


## Value to the attacker of the result `r` of `a` attacking `t`.
static func attack_value(s: Dictionary, a: Dictionary, t: Dictionary, r: Dictionary, unused: Array) -> float:
	var q := 1 - int(a["p"])
	var v := 0.0
	if r["t_dies"]:
		v += float(t["worth"])
		var b := _behind(s, t)
		if not b.is_empty():
			v += EXPOSE_W * float(b["worth"])
		if _alive_count(s, q) == 1:
			# The last unit falls: the attackers still to come may strike directly.
			var rest := 0.0
			for o in unused:
				if o != a and not o["nodmg"]:
					rest += float(o["atk"])
			v += HPW * 0.8 * rest
	if r["a_dies"]:
		v -= float(a["worth"])
	v += HPW * float(int(r["dmg_def"]) - int(r["dmg_att"]))
	if int(r["dmg_def"]) >= int(s["hp"][q]):
		v += LETHAL
	if a["blind"]:
		v *= 0.5                           # Blind: the target is random
	# Economy of force: of two equal results, the weaker attacker goes first, so the stronger one
	# is left for the target only it can beat (break the guard with the small unit).
	return v - ECONOMY * float(a["atk"])


## Attackers of side p for a stage. now: the current Battle Phase (Attack stance, not attacked
## yet, not Paralysed); else its next turn (it may change stance; Paralyse still counts down at
## the end of each controller's turn, so a unit Paralysed now is free next turn only if it is the
## side to move with 1 stack left).
static func attackers(s: Dictionary, p: int, now: bool, virtual: bool) -> Array:
	var out := []
	for o in s["units"]:
		if not o["alive"] or int(o["p"]) != p or o["locked"]:
			continue
		if now:
			if String(o["stance"]) != "atk" or o["attacked"] or int(o["para"]) > 0:
				continue
		else:
			var left := int(o["para"])
			if p == int(s["active"]):
				left -= 1
			if left > 0:
				continue
		out.append(o)
	if virtual:
		for i in mini(VIRTUAL_COUNT, int(s["free"][p])):
			out.append(_virtual(p))
	return out


## Plays one side's battle greedily. apply: change the snapshot (dead units, HP, attackers' stance).
## Returns {"value": total attack value to side p, "dmg": HP dealt, "taken": HP lost, "kills", "losses"}.
static func battle(s: Dictionary, p: int, now: bool, virtual: bool, apply: bool) -> Dictionary:
	var q := 1 - p
	var unused := attackers(s, p, now, virtual)
	var summoned := unused.filter(func(o): return o["virtual"])
	var res := {"value": 0.0, "dmg": 0, "taken": 0, "kills": 0, "losses": 0}
	var hp: Array = s["hp"]
	var saved := []
	if not apply:
		saved = [hp.duplicate()]
		for o in s["units"]:
			saved.append([o, o["alive"], o["eternal"], o["stance"]])
	while not unused.is_empty():
		var best_v := MIN_GAIN
		var best_a: Dictionary = {}
		var best_t: Dictionary = {}
		var best_r: Dictionary = {}
		for a in unused:
			for t in _targets(s, a):
				var r := outcome(s, a, t)
				var v := attack_value(s, a, t, r, unused)
				if v > best_v:
					best_v = v
					best_a = a
					best_t = t
					best_r = r
		if best_a.is_empty():
			break
		unused.erase(best_a)
		best_a["fought"] = true
		res["value"] += best_v
		best_a["stance"] = "atk"
		if best_r["t_dies"]:
			best_t["alive"] = false
			res["kills"] += 1
		elif not best_t.is_empty() and (best_t["guarded"] or int(best_t["eternal"]) > 0) and _would_die(s, best_a, best_t):
			best_t["eternal"] = maxi(0, int(best_t["eternal"]) - (0 if best_t["guarded"] else 1))
		if best_r["a_dies"]:
			best_a["alive"] = false
			res["losses"] += 1
		hp[q] = int(hp[q]) - int(best_r["dmg_def"])
		hp[p] = int(hp[p]) - int(best_r["dmg_att"])
		res["dmg"] += int(best_r["dmg_def"])
		res["taken"] += int(best_r["dmg_att"])
		if int(hp[q]) <= 0 or int(hp[p]) <= 0:
			break
	if not apply:
		s["hp"] = saved[0]
		for i in range(1, saved.size()):
			var e: Array = saved[i]
			e[0]["alive"] = e[1]
			e[0]["eternal"] = e[2]
			e[0]["stance"] = e[3]
		return res
	# The units the side was expected to summon stay on its board (in a free zone, front row
	# first; in Defense if they did not attack), so the follow-up turn meets them.
	for v in summoned:
		if not v["alive"]:
			continue
		var slot := _free_slot(s, p)
		if slot == -1:
			break
		v["virtual"] = false
		v["slot"] = slot
		v["col"] = slot % 3
		v["row"] = slot / 3
		if not v.get("fought", false):
			v["stance"] = "def"
		s["units"].append(v)
	return res


## First free unit zone of side p in the snapshot (front row first), or -1.
static func _free_slot(s: Dictionary, p: int) -> int:
	var used := {}
	for o in s["units"]:
		if o["alive"] and int(o["p"]) == p:
			used[int(o["slot"])] = true
	for slot in 6:
		if not used.has(slot):
			return slot
	return -1


## Whether `t` would be destroyed by `a` without its Eternal / guard (so Eternal is consumed).
static func _would_die(s: Dictionary, a: Dictionary, t: Dictionary) -> bool:
	var plain: Dictionary = t.duplicate()
	plain["eternal"] = 0
	plain["guarded"] = false
	plain["imm30"] = false
	plain["immL"] = false
	return outcome(s, a, plain)["t_dies"]
