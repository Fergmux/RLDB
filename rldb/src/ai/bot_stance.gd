class_name BotStance
extends RefCounted
## Bounded, explainable stance scoring for the bot (F11). It replaces the old rule "a unit whose
## DEF beats its ATK belongs in Defense". The score of a unit is the value of the best attack it
## could make, weighted by who may make it and by how aggressive the position allows:
##
##   score = offense * pressure_weight * factor
##
## offense        best attack result against a legal target (kill value + damage dealt - own loss
##                - damage taken), from battle_preview (current ATK/DEF, type advantage, Burn,
##                immunities) and the direct-attack rule; never below 0 (a bad attack is not made)
##                and capped at CAP so one unit cannot dominate the position.
## pressure_weight W_PRESSURE scaled up when the controller leads on HP and down when behind
##                (pressure versus board safety).
## factor         own unit in Attack = 1 (it attacks this Battle Phase), own unit in Defense =
##                NEXT_W (it can only flip and attack next turn), opposing unit = THREAT_W
##                (stance changes are free in its Setup Phase, so its current stance is no shield).
##
## Safety is therefore the other side of the same coin: an Attack-stance unit that the opponent
## can beat gives the opponent a high offense value, a Defense-stance unit usually gives them none.
## A guard in front of a protected unit adds PROTECTEE_W of the protected unit's worth to what
## killing it is worth (the value of a protected position). Only public board data is read.

const W_PRESSURE := 0.6
const POSTURE_SPAN := 40.0
const POSTURE_GAIN := 0.4
const NEXT_W := 0.4
const THREAT_W := 0.7
const PROTECTEE_W := 0.5
const DIRECT_W := 0.8
const W_HP := 1.2
const LETHAL := 60.0
const CAP := 30.0
## Small bonus for an Attack-stance unit that no opposing unit can destroy: stops passive boards.
const SAFE_ATTACK_W := 0.5


## Rough worth of a unit (presence plus stats).
static func worth(m: MatchEngine, u: int) -> float:
	return 6.0 + 0.45 * float(m.atk_of(u)) + 0.35 * float(m.def_of(u))


## HP lead of `p` scaled to -1..1.
static func posture(m: MatchEngine, p: int) -> float:
	return clampf(float(m.players[p]["hp"] - m.players[1 - p]["hp"]) / POSTURE_SPAN, -1.0, 1.0)


## Best attack `u` could make right now: {"value", "target" (-2 = none, -1 = direct), "why"}.
static func offense(m: MatchEngine, u: int) -> Dictionary:
	var best := {"value": 0.0, "target": -2, "why": "no useful attack"}
	if m.status_count(u, "paralyse") > 0:
		best["why"] = "paralysed"
		return best
	var q: int = 1 - int(m.cards[u]["ctl"])
	for t in m.attack_targets(u):
		var pv := m.battle_preview(u, t)
		var v := 0.0
		var why := ""
		if t == -1:
			v = W_HP * DIRECT_W * float(pv["dmg_opp"]) - W_HP * float(pv["dmg_you"])
			if int(pv["dmg_opp"]) >= int(m.players[q]["hp"]):
				v += LETHAL
			why = "direct %d dmg" % int(pv["dmg_opp"])
		else:
			if pv["t_dies"]:
				v += worth(m, t)
				var behind: int = m.protected_by(t)
				if behind != -1:
					v += PROTECTEE_W * worth(m, behind)
			if pv["a_dies"]:
				v -= worth(m, u)
			v += W_HP * float(int(pv["dmg_opp"]) - int(pv["dmg_you"]))
			why = "%s %s" % [pv["outcome"], m.name_of(t)]
		if v > float(best["value"]):
			best = {"value": minf(v, CAP), "target": t, "why": why}
	return best


## Stance score of unit `u` for the brain playing seat `me`. `stance` overrides the unit's
## current stance ("" = keep). Returns {"total", "offense", "weight", "factor", "safe_bonus",
## "why", "text"}; "text" is the one-line breakdown used in debug output.
static func explain(m: MatchEngine, u: int, me: int, stance: String = "") -> Dictionary:
	var c: int = m.cards[u]["ctl"]
	var st: String = stance if stance != "" else String(m.cards[u]["stance"])
	var off := offense(m, u)
	var weight := W_PRESSURE * (1.0 + POSTURE_GAIN * posture(m, c))
	var factor := THREAT_W
	if c == me:
		factor = 1.0 if st == "atk" else NEXT_W
	var total := float(off["value"]) * weight * factor
	var safe := 0.0
	if c == me and st == "atk" and not _threatened(m, u):
		safe = SAFE_ATTACK_W
		total += safe
	var text := "%s %s: %+.2f = offense %.1f (%s) x pressure %.2f x factor %.2f%s" % [
		m.name_of(u), st, total, float(off["value"]), off["why"], weight, factor,
		" + safe %.1f" % safe if safe > 0.0 else ""]
	return {"total": total, "offense": off["value"], "weight": weight, "factor": factor,
		"safe_bonus": safe, "why": off["why"], "text": text}


## Whether an opposing unit could currently destroy `u` in battle (hypothetically as an
## Attack-stance unit, since stance changes are free in the opponent's Setup Phase).
static func _threatened(m: MatchEngine, u: int) -> bool:
	for e in m.field_units(1 - int(m.cards[u]["ctl"])):
		if m.status_count(e, "paralyse") > 0 or not (u in m.attack_targets(e)):
			continue
		if m.battle_preview(e, u)["t_dies"]:
			return true
	return false


## Both stances side by side, for debug strings.
static func compare_text(m: MatchEngine, u: int, me: int) -> String:
	return "%s | %s" % [explain(m, u, me, "atk")["text"], explain(m, u, me, "def")["text"]]
