class_name CardScripts
extends RefCounted
## Declarative behaviour for every card, keyed by stable card id.
## Each entry may contain:
##   flags:     passive keywords checked by the engine (e.g. "direct_attack")
##   on:        triggered abilities [{when, scope, text, filter, ops}]
##   abilities: manual abilities [{label, opt (once per turn), cost {ap, hp}, cond, ops}]
##   spell:     ops resolved when the Spell is cast/activated
##   trap:      {when, column, power_only, by_effect, by_opponent, cond, ops}
##   aura:      continuous stat modifiers [{to, atk, def, cond, filter}]
##   fusion:    material requirements, one dict per material
##   impl:      "full" | "partial"; notes: why partial
## Cards absent from the table (other than effectless Basic Units) are UNIMPLEMENTED
## and are shown as such in the UI and the support ledger.

static var _table: Dictionary = {}


static func get_entry(id: int) -> Dictionary:
	if _table.is_empty():
		_table = _build()
	return _table.get(id, {})


static func is_implemented(id: int) -> bool:
	var d := CardDB.get_def(id)
	if d["category"] == "basic_unit":
		return true
	return not get_entry(id).is_empty()


static func support_status(id: int) -> String:
	var d := CardDB.get_def(id)
	if d["category"] == "basic_unit":
		return "full"
	var e := get_entry(id)
	if e.is_empty():
		return "unimplemented"
	return e.get("impl", "full")


## Continuous stat modifiers currently applying to unit `uid`. Recomputed on every read.
static func auras_for(g, uid: int) -> Array:
	var out := []
	var p: int = g.cards[uid]["ctl"]
	for p2 in [0, 1]:
		for src in g.field_units(p2) + g.power_cards(p2):
			if g.is_debilitated(src):
				continue
			var entry := get_entry(g.cards[src]["id"])
			for a in entry.get("aura", []):
				if _aura_applies(g, src, uid, a):
					var f: Dictionary = g.make_frame(src, p2, [], "")
					out.append({"atk": g.eval_num(f, a.get("atk", 0)), "def": g.eval_num(f, a.get("def", 0)), "src": g.name_of(src)})
	return out


static func _aura_applies(g, src: int, uid: int, a: Dictionary) -> bool:
	var sp: int = g.cards[src]["ctl"]
	var f: Dictionary = g.make_frame(src, sp, [], "")
	if a.has("cond") and not g.eval_cond(f, a["cond"]):
		return false
	match a["to"]:
		"self":
			if uid != src: return false
		"adjacent":
			if g.cards[src]["zone"] != "unit" or not (uid in g.adjacent_units(src)): return false
		"protector":
			if g.protector_of(src) != uid: return false
		"protector_dragon":
			if g.protector_of(src) != uid or g.unit_race(uid) != "Dragon": return false
		"own_units":
			if g.cards[uid]["ctl"] != sp: return false
		"opp_units":
			if g.cards[uid]["ctl"] == sp: return false
	if a.has("filter") and not g._matches(f, uid, a["filter"]):
		return false
	return true


# ---------------------------------------------------------------- op helpers

static func ch(sel: Dictionary, as_name: String = "t", optional: bool = false, prompt: String = "") -> Dictionary:
	var op := {"op": "choose", "sel": sel, "as": as_name, "optional": optional}
	if prompt != "":
		op["prompt"] = prompt
	return op


static func st(target, s: String, n = 1) -> Dictionary:
	return {"op": "status", "target": target, "s": s, "n": n}


## Status on "the Unit that Destroyed it": skipped when the destroyer was not a unit on the Field.
static func by_unit_st(s: String, n) -> Dictionary:
	return {"op": "status", "target": "event.by", "s": s, "n": n, "unit_only": true}


static func all_(sel: Dictionary, as_name: String = "all") -> Dictionary:
	return {"op": "all", "sel": sel, "as": as_name}


static func yes(prompt: String) -> Dictionary:
	return {"op": "confirm", "prompt": prompt}


static func need(var_name: String) -> Dictionary:
	return {"op": "require", "var": var_name}


static func hp(who: String, n) -> Dictionary:
	return {"op": "hp", "who": who, "n": n}


static func trig(when: String, ops: Array, scope: String = "self", text: String = "") -> Dictionary:
	return {"when": when, "ops": ops, "scope": scope, "text": text if text != "" else when.replace("_", " ")}


static func abil(label: String, ops: Array, opt: bool = true, cost: Dictionary = {}) -> Dictionary:
	return {"label": label, "ops": ops, "opt": opt, "cost": cost}


static func tag_team(ops: Array) -> Array:
	return [{"op": "require", "cond": {"other_in_column": true}}] + ops


## Short on-card button labels for activated abilities (F02-04). The full label stays in
## the card details. Unlisted labels fall back to a derived "Apply <Status>" / prefix form.
const SHORT_LABELS := {
	"Lose 1 AP: summon a unit with 20 ATK or less from your Spent in this column": "Revive (1 AP)",
	"Change this unit's Type: all Mage units become it": "Change Type",
	"Apply 6 Burn to a unit": "Apply Burn",
	"Apply 1 Pierce to a unit": "Apply Pierce",
	"Take 8 Damage: +8 ATK or destroy a Spell/Trap": "Blood Price",
	"Exhaust this unit: opponent takes 10 Damage x Eternal": "Eternal Strike",
	"Lose 1 AP: destroy a Trap with Reveal": "Break Trap",
	"Apply 1 Paralyse and 4 Burn to a unit in this column": "Paralyse + Burn",
	"Apply 4 Burn to a unit in this column": "Apply Burn",
	"Apply 1 Pierce to this unit": "Gain Pierce",
	"Apply 1 Cleanse or 10 Burn to a unit": "Cleanse or Burn",
	"Fusion Summon (Field and/or Spent), then exhaust this unit": "Fusion (Exhaust)",
	"Fusion Summon (Field), then destroy this unit": "Fusion (Destroy)",
	"Fusion Summon (Field)": "Fusion Summon",
	"Lose 1 AP: Fusion Summon (Field)": "Fusion (1 AP)",
	"Destroy a unit with a Rune": "Break Rune",
	"Apply 4 Poison to a unit in this column": "Apply Poison",
	"Apply 1 Infiltrate to a unit": "Apply Infiltrate",
	"Change this unit's Type (Water/Fire/Earth/Lightning)": "Change Type",
	"Apply 1 Curse to a unit with the same Type": "Apply Curse",
	"Apply 1 Paralyse to a unit in this column": "Apply Paralyse",
	"Your opponent's units lose 4 ATK": "Weaken Foes",
	"Take 2 Damage: apply Reveal to a Spell/Trap": "Reveal (2 HP)",
	"Apply 1 Paralyse to a unit": "Apply Paralyse",
	"Apply 1 Retain to a card in your Hand": "Apply Retain",
	"Exhaust a unit you control: destroy a unit": "Exhaust & Destroy",
	"Heal 4 HP or your opponent takes 4 Damage": "Heal or Drain",
	"Change Stance of your opponent's unprotected units": "Topple Foes",
	"Apply 1 Infiltrate and 1 Nimble to a unit": "Infiltrate, Nimble",   # F02-04: at most 18 characters
	"Discard a card to draw a card": "Discard & Draw",
	"Discard a unit to gain +1 AP": "Discard for AP",
	"Switch ATK/DEF of all units until end of turn": "Switch ATK/DEF",
	"Summon a Basic Unit from Draw to an adjacent zone": "Call Basic Unit",
	"Change this unit's Race: all your units become it": "Change Race",
	"Summon a Water unit from Spent in this column": "Revive Water",
	"Apply 3 Poison to a unit": "Apply Poison",
	"Change Type (Physical/Light/Dark)": "Change Type",
	"Apply 1 Nimble to all your units": "Nimble All",
	"Lose 1 AP: Heal 10 HP": "Heal 10 (1 AP)",
	"Exhaust the unit this protects: +1 Eternal and +1 AP": "Exhaust Ward",
	"Apply 10 Burn, 4 Poison or 1 Curse to a unit": "Afflict",
	"Apply Reveal to a Spell/Trap": "Apply Reveal",
	"Apply 1 Debilitate to a unit in this column": "Apply Debilitate",
	"Draw a card, then discard a card": "Draw & Discard",
	"Apply 1 Debilitate to a unit": "Apply Debilitate",
	"Apply 1 Infiltrate to this unit": "Gain Infiltrate",
	"Take 10 Damage: destroy a unit with lower ATK": "Execute (10 HP)",
	"Destroy a Power (+1 AP if it is yours)": "Break Power",
	"Double this unit's Debuffs and give them to an opponent's unit": "Spread Debuffs",
}


static func short_label(label: String) -> String:
	if SHORT_LABELS.has(label):
		return SHORT_LABELS[label]
	var re := RegEx.new()
	re.compile("^Apply [0-9]+ ([A-Za-z]+) to ")
	var m := re.search(label)
	if m != null:
		return "Apply " + m.get_string(1)
	if label.length() <= 18:
		return label
	var head := label.split(":")[0]
	return head if head.length() <= 18 else head.substr(0, 17) + "…"


const COL_OTHER := {"kind": "unit", "side": "self", "column": true, "not_self": true}
const GOD_SUMMON := [{"op": "status", "target": "self", "s": "eternal", "n": 1}, {"op": "status", "target": "self", "s": "cleanse", "n": 1}]
const GOD_DESTROY := [{"op": "cost_perm", "target": "self", "n": 1}]


static func _build() -> Dictionary:
	var t := {}

	# ------------------------------------------------------------ Units
	# 2026-10-17 database: the Tag Team searches moved between IDs; each is keyed by stable ID.
	# 2026-10-18: every search is optional ("you can"); the discount lasts until the end of the turn.
	# L (6): optional Trap search. B (7): optional Spell search (its Cleanse is gone).
	t[6] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "category": ["trap"]}, "c", true, "Add a Trap from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]))]}
	t[7] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "category": ["spell"]}, "c", true, "Add a Spell from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]))]}
	t[8] = {"on": [trig("summoned", tag_team([{"op": "fusion_possible", "sources": ["field"]}, yes("Fusion Summon using units you control?"), {"op": "fusion", "sources": ["field"]}]))]}
	# F (9): optional same-Cost unit search with -1 AP this turn. 2026-10-18 On Destroy: every
	# unit (both sides) in its column whose current cost is 1 or lower; Extra Deck units have none.
	t[9] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "cost_eq": {"cost_of": "$col"}}, "c", true, "Add a unit with the same Cost from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])),
		trig("destroyed", [all_({"kind": "unit", "column": true, "cost_max": 1}), {"op": "destroy", "target": "$all"}])]}
	# W (10): optional same-Race unit search with -1 AP this turn (2026-10-18 adds "you can").
	# On Destroy: every Spell/Trap in its column, both sides, revealed or not.
	t[10] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "race_eq": "$col"}, "c", true, "Add a unit with the same Race from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])),
		trig("destroyed", [all_({"kind": "backrow", "spell_trap": true, "column": true}), {"op": "destroy", "target": "$all"}])]}
	# J (11): optional same-Type unit search with -1 AP this turn (a typeless partner matches nothing).
	# 2026-10-18 On Destroy: destroy a Power (either side; mandatory when one exists).
	t[11] = {"on": [trig("summoned", tag_team([all_(COL_OTHER, "col"),
		ch({"kind": "draw", "side": "self", "unit_card": true, "type_eq": "$col"}, "c", true, "Add a unit with the same Type from Draw to Hand? It costs 1 AP less this turn."),
		{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])),
		trig("destroyed", [ch({"kind": "power"}, "u", false, "Destroy a Power."), {"op": "destroy", "target": "$u"}])]}
	t[12] = {"on": [trig("summoned", tag_team([yes("Draw a card and gain +1 AP?"), {"op": "draw", "n": 1}, {"op": "ap", "n": 1}]))],
		# 2026-11-03: 1 AP (was 2), and only a unit with 20 ATK or less (printed ATK, as in any pile).
		"abilities": [abil("Lose 1 AP: summon a unit with 20 ATK or less from your Spent in this column", [
			ch({"kind": "spent", "side": "self", "unit_card": true, "atk_max": 20}, "u", false, "Summon a unit with 20 ATK or less from your Spent into this column."),
			{"op": "summon", "target": "$u", "place": "column", "stance": "choose"}], false, {"ap": 1})]}
	# 2026-10-18: Dark by default. The Type change is one-shot: this unit and every Mage unit on the
	# Field (both sides) become the chosen Type and keep it until something changes it again.
	t[13] = {"abilities": [abil("Change this unit's Type: all Mage units become it", [{"op": "declare_type", "types": CardDB.ELEMENTS, "as": "ty"},
			{"op": "set_type", "target": "self", "var": "ty"}, all_({"kind": "unit", "race": "Mage", "not_self": true}), {"op": "set_type", "target": "$all", "var": "ty"}])],
		"on": [trig("destroyed", [yes("Change an opponent's unit to a Type of your choosing?"), ch({"kind": "unit", "side": "opp"}, "u"), need("u"),
			{"op": "declare_type", "types": CardDB.ELEMENTS, "as": "ty"}, {"op": "set_type", "target": "$u", "var": "ty"}])]}
	t[14] = {"on": [trig("summoned", [ch({"kind": "unit"}, "u", true, "Apply 1 Rune to a unit?"), st("$u", "rune")]),
		trig("destroyed", [hp("self", -6), hp("opp", -6)])],
		"abilities": [abil("Apply 6 Burn to a unit", [ch({"kind": "unit"}, "u"), st("$u", "burn", 6)])]}
	# 2026-11-03: when tributed (from the Field, undebilitated) for a Fusion or Ritual summon, the
	# unit summoned gets 1 Pierce as it lands (the Magentric hook).
	t[15] = {"tribute_bonus": {"s": "pierce", "n": 1}, "abilities": [abil("Apply 1 Pierce to a unit", [ch({"kind": "unit"}, "u"), st("$u", "pierce")])],
		"on": [trig("destroyed", [ch({"kind": "unit", "race": "Mage", "column": true}, "u", true, "Apply 1 Eternal to a Mage unit in this column?"), st("$u", "eternal")])]}
	# L11 (2026-11-05): Loak (19) and Mimic (95) also take the copied unit's art while on the Field ("art").
	t[19] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "opp", "unprotected": true, "column": true}, "u", false, "Choose an opponent's unprotected unit in this column."),
		need("u"), st("$u", "eternal"), {"op": "copy_stats", "from": "$u", "race": true, "art": true}])]}
	t[20] = {"on": [trig("summoned", [{"op": "copy_all_buffs"}]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 1 Pierce to a unit?"), st("$u", "pierce")])],
		"aura": [{"to": "self", "atk": {"count": {"kind": "unit", "side": "opp"}, "mul": 4}, "def": {"count": {"kind": "unit", "side": "opp"}, "mul": 4}}]}
	# 2026-11-03: every unit the opponent summons (any kind of summon) while Shen is on the Field
	# permanently loses 10 ATK.
	t[21] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY),
			trig("any_summoned", [{"op": "stat", "target": "event.unit", "atk": -10}], "theirs", "your opponent summoned a unit")],
		"aura": [{"to": "self", "atk": {"pile": "exhaust", "mul": 10}, "def": {"pile": "exhaust", "mul": 10}}]}
	t[22] = {"flags": ["adjacent_no_attack"], "on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY)]}
	t[23] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY)],
		"abilities": [abil("Take 8 Damage: +8 ATK or destroy a Spell/Trap", [{"op": "mode", "options": [
			{"label": "This unit permanently gains +8 ATK", "ops": [{"op": "stat", "target": "self", "atk": 8}]},
			{"label": "Destroy a Spell/Trap", "ops": [ch({"kind": "backrow", "spell_trap": true}, "u"), {"op": "destroy", "target": "$u"}]}]}], true, {"hp": 8})]}
	t[161] = {"on": [trig("summoned", GOD_SUMMON), trig("destroyed", GOD_DESTROY), trig("start_turn", [st("self", "eternal")], "own_turn", "start of turn")],
		"abilities": [abil("Exhaust this unit: opponent takes 10 Damage x Eternal", [{"op": "let", "as": "e", "n": {"status": "eternal", "of": "self"}},
			{"op": "move", "target": "self", "to": "exhaust", "cost": true}, hp("opp", {"value": "$e", "mul": -10})])]}
	t[24] = {"on": [trig("summoned", [st("self", "infiltrate")])]}
	t[25] = {"on": [trig("summoned", [all_({"kind": "unit", "basic": true, "unprotected": true}), {"op": "destroy", "target": "$all"}])]}
	t[26] = {"on": [trig("summoned", tag_team([ch({"kind": "draw", "side": "self", "cost_eq": 0}, "c", false, "Add a 0-cost card from Draw to Hand."), {"op": "move", "target": "$c", "to": "hand"}])),
		trig("destroyed", [all_({"kind": "backrow", "spell_trap": true, "side": "self"}), {"op": "destroy", "target": "$all"}])]}
	t[27] = {"on": [trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Dragon", "cost_max": 1, "not_self": true}, "u", true, "Summon a 1-cost or lower Dragon from Spent to this zone?"),
		need("u"), {"op": "summon", "target": "$u", "place": "orig", "stance": "choose"}])]}
	t[28] = {"on": [trig("summoned", [ch({"kind": "spent", "side": "self", "race": "Beast", "cost_max": 1}, "u", true, "Summon a 1-cost or lower Beast from Spent into this column?"),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "choose"}])]}
	t[29] = {"on": [trig("summoned", [ch({"kind": "backrow", "spell_trap": true, "column": true, "revealed": false}, "u", true, "Apply Reveal to a Spell/Trap in this column?"), st("$u", "reveal")])],
		"abilities": [abil("Lose 1 AP: destroy a Trap with Reveal", [ch({"kind": "backrow", "category": ["trap"], "has_status": "reveal"}, "u"), {"op": "destroy", "target": "$u"}], true, {"ap": 1})]}
	t[30] = {"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true}, "u", true, "Send a unit from Draw to Spent, then apply 1 Retain to a unit in your Hand?"),
			need("u"), {"op": "move", "target": "$u", "to": "spent"},
			ch({"kind": "hand", "side": "self", "unit_card": true}, "h", false, "Apply 1 Retain to a unit in your Hand."), st("$h", "retain")]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "unit_card": true, "not_self": true}, "u", true, "Move a unit from Spent to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[31] = {"on": [trig("summoned", [st("self", "pierce")]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 6 Medic to a unit?"), st("$u", "medic", 6)])]}
	t[32] = {"on": [trig("summoned", [ch({"kind": "power"}, "u", false, "Destroy a Power."), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 1 Paralyse and 4 Burn to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "paralyse"), st("$u", "burn", 4)])]}
	t[33] = {"abilities": [abil("Apply 4 Burn to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "burn", 4)])]}
	t[34] = {"aura": [{"to": "adjacent", "def": 6}]}
	t[35] = {"abilities": [abil("Apply 1 Pierce to this unit", [st("self", "pierce")])]}
	t[36] = {"on": [trig("summoned", [all_({"kind": "unit"}), st("$all", "burn", 6)]),
		trig("destroyed", [yes("Lose 1 AP next turn to revive Dante at the start of your next turn?"),
			{"op": "ap", "n": -1, "next_turn": true, "payment": true}, {"op": "delay_revive"}])],
		"abilities": [abil("Apply 1 Cleanse or 10 Burn to a unit", [ch({"kind": "unit"}, "u"),
			{"op": "mode", "options": [{"label": "1 Cleanse", "ops": [st("$u", "cleanse")]}, {"label": "10 Burn", "ops": [st("$u", "burn", 10)]}]}])],
		"aura": [{"to": "self", "atk": {"status": "burn", "of": "self"}}]}
	t[37] = {"on": [trig("summoned", [st("self", "pierce", 2)]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Warrior", "not_self": true}, "u", true, "Add a Warrior unit from Spent to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])],
		# 2026-11-03: +8 ATK while it is Protecting a unit (the front unit shielding one behind it);
		# it used to be +10 while Protected by one.
		"aura": [{"to": "self", "atk": 8, "cond": {"protecting": true}}]}
	t[38] = {"flags": ["no_gain", "no_buffs"], "on": [trig("summoned", [ch({"kind": "field_card", "has_status": "reveal"}, "u", true, "Destroy a card with Reveal?"), {"op": "destroy", "target": "$u"}])],
		"aura": [{"to": "self", "atk": {"count": {"kind": "unit", "side": "self", "adjacent": true}, "mul": -6}, "def": {"count": {"kind": "unit", "side": "self", "adjacent": true}, "mul": -6}}]}
	t[39] = {"flags": ["battle_immune_30atk"]}
	t[67] = {"on": [trig("summoned", [ch({"kind": "unit", "column": true}, "u", true, "Apply 2 Paralyse to a unit in this column?"), st("$u", "paralyse", 2)])],
		# 2026-11-03: the Fusion Summon comes first, then this unit is exhausted (it used to be exhausted
		# first, as a cost). Owner, 3 Nov: it may be one of the materials itself; then the "then Exhaust
		# this Unit" does not happen (the `then` op only acts on it while it is still on the Field). The
		# `then` ops run right after the Fusion unit lands, before its On Summon effects, and only if the
		# summon happens.
		"abilities": [abil("Fusion Summon (Field and/or Spent), then exhaust this unit", [{"op": "fusion", "sources": ["field", "spent"],
			"then": [{"op": "move", "target": "self", "to": "exhaust", "from_field": true}]}], false)]}
	# 2026-11-03: Fusion Summon first, then this unit is destroyed. Owner, 3 Nov: it may be one of the
	# materials itself; then the destruction does not happen (see Void Basilisk).
	t[68] = {"abilities": [abil("Fusion Summon (Field), then destroy this unit", [{"op": "fusion", "sources": ["field"],
		"then": [{"op": "destroy", "target": "self", "keep_going": true}]}], false)]}
	# 2026-11-03: the On Summon is an optional 1 Cleanse on an adjacent unit; when tributed, the
	# Fusion or Ritual unit summoned gets 1 Cleanse (was 2 Pierce).
	t[69] = {"tribute_bonus": {"s": "cleanse", "n": 1}, "on": [trig("summoned", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u", true, "Apply 1 Cleanse to an adjacent unit?"), st("$u", "cleanse")])],
		"abilities": [abil("Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], false)]}
	t[40] = {"abilities": [abil("Lose 1 AP: Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], false, {"ap": 1})]}
	t[70] = {"on": [trig("summoned", [st("self", "nimble", 3)]), trig("moved", [{"op": "stat", "target": "self", "atk": 6}])]}
	t[71] = {"on": [trig("moved", [st("self", "medic", 3)])], "abilities": [abil("Apply 1 Nimble to a unit", [ch({"kind": "unit"}, "u"), st("$u", "nimble")])]}
	t[72] = {"aura": [{"to": "self", "def": 16, "cond": {"self_front": true}}, {"to": "self", "atk": 16, "cond": {"self_front": false}}],
		"on": [trig("summoned", [st("self", "nimble")]), trig("end_turn", [{"op": "wukong_swap"}], "own_turn", "end of turn"),
			trig("destroyed", [ch({"kind": "unit", "side": "self"}, "u", true, "Move a unit to an adjacent zone?"), need("u"), {"op": "move_unit", "target": "$u", "to": "adjacent"}])]}
	t[73] = {"flags": ["warrior_guard"], "on": [trig("summoned", [ch({"kind": "draw", "side": "self", "race": "Warrior"}, "c", false, "Add a Warrior from Draw to Hand."), {"op": "move", "target": "$c", "to": "hand"}])]}
	t[74] = {"on": [trig("tribute_or_sacrifice", [ch({"kind": "unit"}, "u", false, "Apply 1 Infiltrate to a unit."), st("$u", "infiltrate")])]}
	t[16] = {"on": [trig("destroyed_opp_unit", [st("self", "rune")], "mine", "you destroyed an opponent's unit")]}
	t[17] = {"on": [trig("start_turn", [st("self", "rune")], "own_turn", "start of turn")]}
	t[18] = {"on": [trig("summoned", [ch({"kind": "unit", "column": true}, "u", true, "Apply 1 Paralyse to a unit in this column?"), st("$u", "paralyse")]),
		trig("destroyed_opp_unit", [st("self", "rune")], "self", "destroyed an opponent's unit")]}
	t[75] = {"on": [trig("own_unit_moved", [st("self", "rune")], "mine", "your unit moved")]}
	# 2026-11-03: a new optional On Summon, 10 Poison on a unit in this column (either side).
	t[76] = {"on": [trig("summoned", [ch({"kind": "unit", "column": true}, "u", true, "Apply 10 Poison to a unit in this column?"), st("$u", "poison", 10)]),
		trig("any_sacrificed", [st("self", "rune")], "any", "a unit was sacrificed")]}
	# 2026-11-03: when tributed, the Fusion or Ritual unit summoned gets 1 Infiltrate.
	t[77] = {"tribute_bonus": {"s": "infiltrate", "n": 1}, "on": [trig("trap_activated", [st("self", "rune")], "any", "a Trap was activated")]}
	t[78] = {"on": [trig("summoned", [st("self", "cleanse")]),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "race": "Dragon", "not_self": true}, "u", true, "Add a Dragon unit from Spent to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])],
		"abilities": [abil("Apply 4 Poison to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "poison", 4)])]}
	t[79] = {"on": [trig("summoned", [ch({"kind": "unit", "type": "Water"}, "u", false, "Destroy a Water unit."), {"op": "destroy", "target": "$u"}]),
		trig("destroyed", [ch({"kind": "facedown"}, "u", true, "Apply Reveal to a Spell/Trap?"), st("$u", "reveal")])],
		"abilities": [abil("Apply 1 Infiltrate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "infiltrate")])]}
	t[99] = {"on": [trig("summoned", [ch({"kind": "spent", "side": "self", "unit_card": true}, "u", false, "Move a unit from your Spent to Draw."), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[100] = {"on": [trig("destroyed", [by_unit_st("paralyse", 2)])]}
	t[102] = {"abilities": [
		abil("Change this unit's Type (Water/Fire/Earth/Lightning)", [{"op": "declare_type", "types": ["Water", "Fire", "Earth", "Lightning"], "as": "ty"}, {"op": "set_type", "target": "self", "var": "ty"}]),
		abil("Apply 1 Curse to a unit with the same Type", [ch({"kind": "unit", "type": "$self_type"}, "u"), st("$u", "curse")])]}
	# 2026-11-03: while Protected by a Dragon unit it cannot be in Attack stance: it is put in Defense
	# stance and cannot change back to Attack while protected (EffectEngine.enforce_stance_locks).
	t[135] = {"flags": ["rider_no_attack"], "aura": [{"to": "protector_dragon", "atk": 14}]}
	t[150] = {"flags": ["no_defense"], "on": [trig("summoned", [ch({"kind": "spent", "side": "self"}, "u", false, "Move a card from Spent to the top of Draw."), {"op": "move", "target": "$u", "to": "draw_top"}]),
		trig("tribute_or_sacrifice", [{"op": "ap", "n": 1}])]}
	t[162] = {"flags": ["direct_attack"], "on": [trig("destroyed", [by_unit_st("blind", 1)]),
		trig("sacrificed", [{"op": "cost_perm", "target": "self", "n": 1}])]}
	# L23 (2026-11-05): Spawn (155) evolves into Larva (156), which evolves into Siphonophore (157). The
	# chain is card data (cards.json `evolves_into`); MatchEngine asks at the start of the turn.
	t[155] = {"on": [trig("summoned", [st("self", "eternal")])], "aura": [{"to": "protector", "atk": 6}]}
	t[156] = {"on": [trig("summoned", [st("self", "eternal")]),
			trig("start_turn", [{"op": "draw", "n": 1}, ch({"kind": "hand", "side": "self"}, "h", false, "Discard a card: send it from Hand to Spent."),
				{"op": "move", "target": "$h", "to": "spent"}], "own_turn", "start of turn")],
		"aura": [{"to": "protector", "atk": 6}]}
	t[157] = {"on": [trig("summoned", [st("self", "eternal")]), trig("start_turn", [{"op": "draw", "n": 1}], "own_turn", "start of turn")],
		"aura": [{"to": "adjacent", "atk": 6, "cond": {"protected": true}}]}
	# 2026-10-18: after the 30 Damage, every 'Divine Serpent' unit you control (this one too) is destroyed.
	var serpent := trig("summoned", [{"op": "require", "cond": {"count": {"kind": "unit", "side": "self", "adjacent": true, "name_prefix": "Divine Serpent"}, "min": 2}}, hp("opp", -30),
		all_({"kind": "unit", "side": "self", "name_prefix": "Divine Serpent"}), {"op": "destroy", "target": "$all"}])
	t[158] = {"on": [serpent], "abilities": [abil("Apply 1 Paralyse to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "paralyse")])]}
	t[159] = {"on": [serpent], "aura": [{"to": "adjacent", "def": 10}]}
	t[160] = {"on": [serpent], "abilities": [abil("Your opponent's units lose 4 ATK", [all_({"kind": "unit", "side": "opp"}), {"op": "stat", "target": "$all", "atk": -4}])]}

	# ------------------------------------------------------------ Spells
	t[80] = {"spell": [all_({"kind": "unit"}), st("$all", "nimble")]}
	t[81] = {"spell": [all_({"kind": "unit"}), st("$all", "blind")]}
	t[82] = {"spell": [{"op": "fusion", "sources": ["field"]}]}
	t[41] = {"spell": [ch({"kind": "hand", "side": "self", "not_self": true}, "h", false, "Apply 1 Retain to a card in your Hand."), st("$h", "retain"), {"op": "ap", "n": 1, "next_turn": true}]}
	t[42] = {"spell": [{"op": "ambush"}]}
	t[43] = {"spell": [{"op": "swap_all"}]}
	t[154] = {"spell": [{"op": "reversal"}]}
	t[83] = {"spell": [ch({"kind": "unit"}, "u", false, "Apply 1 Rune to a unit."), st("$u", "rune")]}
	t[84] = {"spell": [ch({"kind": "unit", "def_max": 20}, "u", false, "Destroy a unit with 20 DEF or less."), {"op": "destroy", "target": "$u"}]}
	t[101] = {"flags": ["exhaust_on_spent"], "spell": [ch({"kind": "spent", "side": "opp"}, "u", false, "Exhaust a card from your opponent's Spent."), {"op": "move", "target": "$u", "to": "exhaust"}]}
	t[104] = {"spell": [all_({"kind": "unit", "side": "opp", "unprotected": true}), {"op": "stance", "target": "$all"}]}
	t[136] = {"flags": ["exhaust_on_spent"], "spell": [all_({"kind": "unit", "atk_min": 20}), {"op": "destroy", "target": "$all"}]}
	t[138] = {"spell": [ch({"kind": "unit", "has_buff": true}, "u", false, "Destroy a unit with a Buff."), {"op": "destroy", "target": "$u"}]}
	t[180] = {"spell": [ch({"kind": "unit", "side": "opp", "atk_max": 16}, "u", false, "Take control of an opponent's unit with 16 ATK or less."), {"op": "take_control", "target": "$u"}]}
	# 2026-10-18: the chosen unit (not the Spell) permanently costs 1 AP more, for the rest of the game.
	t[182] = {"spell": [ch({"kind": "unit"}, "u", false, "Apply 1 Blind and 1 Infiltrate to a unit; it gains +10 ATK this turn and permanently costs 1 AP more."),
		st("$u", "blind"), st("$u", "infiltrate"), {"op": "stat", "target": "$u", "atk": 10, "until": "turn"}, {"op": "cost_perm", "target": "$u", "n": 1}]}
	t[152] = {"spell": [ch({"kind": "power"}, "u", false, "Destroy a Power."), {"op": "destroy", "target": "$u"}]}

	# ------------------------------------------------------------ Traps
	t[85] = {"trap": {"when": "activate", "ops": [ch({"kind": "unit"}, "u", false, "Apply 1 Rune to a unit."), st("$u", "rune")]}}
	t[86] = {"trap": {"when": "destroyed", "by_opponent": true, "ops": [ch({"kind": "unit"}, "u", false, "Apply 4 Medic to a unit."), st("$u", "medic", 4)]}}
	# 2026-11-03: "Destroy an opponent's card": any card the opponent has on the Field (Unit, Spell/Trap, Power).
	t[87] = {"trap": {"when": "destroyed", "by_effect": true, "ops": [ch({"kind": "field_card", "side": "opp"}, "u", false, "Destroy an opponent's card."), {"op": "destroy", "target": "$u"}]}}
	# 2026-11-03 (replaces C-03): "If your opponent's Unit in this Column declares an Attack". The attacker's
	# column is the Trap's column (column i faces column i), whatever its target, a direct attack included.
	t[45] = {"flags": ["cost_up_on_activate"], "trap": {"when": "attack", "attacker_column": true, "ops": [{"op": "cost_perm", "target": "self", "n": 1}, hp("opp", {"stat": "atk", "of": "event.attacker", "mul": -1})]}}
	t[46] = {"trap": {"when": "attack", "cond": {"count": {"kind": "field_card", "side": "opp"}, "min": 4}, "ops": [all_({"kind": "unit", "side": "opp", "stance": "atk"}), {"op": "destroy", "target": "$all"}]}}
	# 2026-11-03: the same trigger as Magic Cylinder; its cost is 1 (owner ruling, in the data).
	t[47] = {"flags": ["cost_up_on_activate"], "trap": {"when": "attack", "attacker_column": true, "ops": [{"op": "cost_perm", "target": "self", "n": 1}, hp("self", {"stat": "atk", "of": "event.attacker"})]}}
	# F03-19 (user-confirmed 2026-10-16): the controller chooses any opposing unit; no highest-ATK rule.
	t[48] = {"trap": {"when": "summon", "cond": {"count": {"kind": "unit", "side": "opp"}, "min": 3}, "ops": [ch({"kind": "unit", "side": "opp"}, "u", false, "Choose one of your opponent's units; it permanently loses 20 ATK."), {"op": "stat", "target": "$u", "atk": -20}]}}
	# 2026-10-18: any summon (the 2-cost minimum is gone).
	t[49] = {"trap": {"when": "summon", "ops": [st("event.card", "paralyse", 3)]}}
	# Owner feedback 2026-10-18: offered on every attack, direct ones included, even with no unit
	# in its column (it then has no target).
	t[50] = {"trap": {"when": "attack", "any_target": true, "ops": [ch({"kind": "unit", "side": "self", "column": true}, "u", false, "Apply 1 Eternal to a unit in this column."), st("$u", "eternal")]}}
	t[51] = {"trap": {"when": "attack", "ops": [all_({"kind": "unit", "side": "self", "column": true}), {"op": "stat", "target": "$all", "def": 8, "until": "turn"}]}}
	t[103] = {"trap": {"when": "summon", "ops": [{"op": "let", "as": "low", "n": {"min_atk": {"kind": "unit", "side": "self"}}}, {"op": "stat", "target": "event.card", "atk": {"value": "$low", "mul": -1}}]}}
	# 2026-10-18: no longer negates. It destroys the card whose effect was activated (a resolving
	# Spell counts) and the effect still resolves; going from Field to Spent raises its own cost.
	t[140] = {"flags": ["cost_up_on_spent"], "trap": {"when": "activate", "cond": {"event_card_destroyable": true},
		"ops": [{"op": "destroy", "target": "event.card"}]}}
	# Owner feedback 2026-10-18: only when a Power's effect is activated, not when it is played.
	t[153] = {"trap": {"when": "activate", "power_only": true, "effect_only": true, "ops": [{"op": "destroy", "target": "event.card"}, hp("opp", -4)]}}
	t[163] = {"trap": {"when": ["activate", "attack"], "ops": [ch({"kind": "field_card", "side": "self", "not_self": true}, "u", false, "Destroy any number of your cards (+10 HP each)."),
		{"op": "plan_b"}]}}
	t[163]["trap"]["ops"][0]["n"] = "any"
	# User decision 2026-10-15: Plan B must destroy at least one card, and is only offered
	# when you control another card to destroy.
	t[163]["trap"]["ops"][0]["min"] = 1
	t[163]["trap"]["needs_target"] = true
	t[164] = {"trap": {"when": "attack", "cond": {"event_target_unit": true}, "ops": [st("event.target", "curse"), {"op": "no_loyalty"}]}}
	t[52] = {"trap": {"when": "summon", "cond": {"event_cost_min": 2}, "ops": [ch({"kind": "spent", "side": "self", "unit_card": true, "cost_max": 2}, "u", false, "Summon a 2-cost or lower unit from your Spent."),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "atk"}]}}
	t[165] = {"trap": {"when": "summon", "cond": {"event_atk_min": 20}, "ops": [ch({"kind": "spent", "side": "self", "unit_card": true, "atk_max": 20}, "u", false, "Summon a unit with 20 ATK or less from your Spent."),
		need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "atk"}]}}
	# Do Not Open Box (2026-11-03): "If your opponent Destroys this Trap: Summon a Unit from Draw in this
	# Column." It answers its own destruction while set (`self_destroyed`), by an opponent's effect, through
	# the ordinary Trap window. The column is the zone it was set in (the window event carries it).
	t[191] = {"trap": {"when": "st_destroyed", "self_destroyed": true, "by_opponent": true,
		"ops": [ch({"kind": "draw", "side": "self", "unit_card": true}, "u", false, "Summon a unit from your Draw into this column."),
			need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "choose"}]}}
	# Counter Transmutation (2026-10-18): when any Spell/Trap is destroyed (either side), its owner puts
	# a Power from their own Spent into a free Power zone without paying its cost.
	t[184] = {"trap": {"when": "st_destroyed", "cond": {"free_power_zone": true},
		"ops": [ch({"kind": "spent", "side": "self", "category": ["power"], "playable": true}, "u", false, "Play a Power from your Spent."),
			need("u"), {"op": "put_power", "target": "$u"}]}}

	# ------------------------------------------------------------ Powers
	t[88] = {"flags": ["elemental_mastery"]}   # +6 per copy on top of the base +6 (BattleOps.type_bonus)
	t[53] = {"aura": [{"to": "own_units", "filter": {"basic": true}, "atk": 8}]}
	t[54] = {"aura": [{"to": "own_units", "atk": {"unique_races": "self", "mul": 4}, "def": {"unique_races": "self", "mul": 4}}]}
	t[89] = {"abilities": [abil("Lose 1 AP: Fusion Summon (Field)", [{"op": "fusion", "sources": ["field"]}], true, {"ap": 1})]}
	t[55] = {"abilities": [abil("Take 2 Damage: apply Reveal to a Spell/Trap", [ch({"kind": "facedown"}, "u"), st("$u", "reveal")], true, {"hp": 2})]}
	t[90] = {"abilities": [abil("Apply 1 Paralyse to a unit", [ch({"kind": "unit"}, "u"), st("$u", "paralyse")])]}
	t[91] = {"on": [trig("start_turn", [ch({"kind": "unit"}, "u", true, "Apply 1 Rune to a unit?"), st("$u", "rune")], "own_turn", "start of turn")]}
	t[92] = {"abilities": [abil("Apply 1 Retain to a card in your Hand", [ch({"kind": "hand", "side": "self"}, "h"), st("$h", "retain")])]}
	t[137] = {"flags": ["hand_fusion"]}
	t[148] = {"abilities": [abil("Exhaust a unit you control: destroy a unit", [ch({"kind": "unit", "side": "self"}, "x", false, "Exhaust a unit you control."),
		{"op": "move", "target": "$x", "to": "exhaust"}, ch({"kind": "unit"}, "u", false, "Destroy a unit."), {"op": "destroy", "target": "$u"}])]}
	t[149] = {"flags": ["abyss_ap"]}
	t[139] = {"flags": ["spells_cost_less"]}
	t[166] = {"flags": ["traps_cost_less"]}
	t[167] = {"abilities": [abil("Heal 4 HP or your opponent takes 4 Damage", [{"op": "mode", "options": [
		{"label": "Heal 4 HP", "ops": [hp("self", 4)]}, {"label": "Opponent takes 4 Damage", "ops": [hp("opp", -4)]}]}])]}
	# 2026-10-18: draw first, then discard (Hand to Spent).
	t[168] = {"abilities": [abil("Draw a card, then discard a card", [{"op": "draw", "n": 1}, ch({"kind": "hand", "side": "self"}, "h", false, "Discard a card: send it from Hand to Spent."),
		{"op": "move", "target": "$h", "to": "spent"}])]}
	# 2026-10-18: each copy draws a card at the start of your turn (after the turn's normal draw).
	t[169] = {"on": [trig("start_turn", [{"op": "draw", "n": 1}], "own_turn", "start of turn")]}
	t[178] = {"flags": ["units_cost_less_if_behind"]}   # -1 AP since 2026-11-03 (GameCore.current_cost)
	t[179] = {"aura": [{"to": "own_units", "filter": {"type": "Fire"}, "atk": 8}],
		"on": [{"when": "unit_destroyed", "scope": "mine", "filter": {"event_type": "Fire"}, "text": "your Fire unit was destroyed", "ops": [hp("self", -6), hp("opp", -6)]}]}
	t[44] = {"flags": ["no_set"]}

	# ------------------------------------------------------------ Fusion
	# 2026-11-03: "Unit with 20 or more ATK or DEF" (stat_min) is a material whose current ATK or
	# current DEF is 20 or more (FusionOps._mat_stats, as Razeon's old "20 ATK or more").
	t[56] = {"fusion": [{"stat_min": 20}, {"type": "Lightning"}], "on": [trig("summoned", [all_({"kind": "facedown"}), st("$all", "reveal")]),
		trig("destroyed", [all_({"kind": "unit"}), st("$all", "paralyse")])]}
	# 2026-11-03: the On Summon is gone; a second once-per-turn ability targets one unit.
	t[57] = {"fusion": [{"stat_min": 20}, {"type": "Earth"}],
		"abilities": [abil("Change Stance of your opponent's unprotected units", [all_({"kind": "unit", "side": "opp", "unprotected": true}), {"op": "stance", "target": "$all"}]),
			abil("Apply 1 Infiltrate and 1 Nimble to a unit", [ch({"kind": "unit"}, "u"), st("$u", "infiltrate"), st("$u", "nimble")])]}
	t[57]["abilities"][0]["cond"] = {"count": {"kind": "unit", "side": "opp", "unprotected": true}, "min": 1}
	# 2026-11-03: discard (Hand to Spent) first, then draw.
	t[58] = {"fusion": [{"stat_min": 20}, {"type": "Fire"}], "on": [trig("summoned", [ch({"kind": "power"}, "u", true, "Destroy a Power?"), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Discard a card to draw a card", [ch({"kind": "hand", "side": "self"}, "h", false, "Discard a card (Hand to Spent), then draw a card."),
			{"op": "move", "target": "$h", "to": "spent"}, {"op": "draw", "n": 1}])]}
	t[59] = {"fusion": [{"race": "Mage"}, {"type": "Water"}], "on": [trig("summoned", [ch({"kind": "backrow", "spell_trap": true}, "u", true, "Destroy a Spell or Trap?"), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 1 Paralyse to a unit", [ch({"kind": "unit"}, "u"), st("$u", "paralyse")]), abil("Apply 1 Infiltrate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "infiltrate")])]}
	t[60] = {"fusion": [{"has_debuff": true}, {"has_buff": true}], "on": [trig("summoned", [ch({"kind": "unit"}, "u", false, "Apply 3 Debilitate to a unit."), st("$u", "debilitate", 3)])],
		"abilities": [abil("Apply 3 Poison to a unit", [ch({"kind": "unit"}, "u"), st("$u", "poison", 3)])]}
	# 2026-11-03: On Summon an optional 8 Medic on an adjacent unit (its controller's own, as every
	# "Adjacent" card); the ability discards a unit card from Hand (to Spent) for +1 AP.
	t[61] = {"fusion": [{"stat_min": 20}, {"type": "Light"}], "on": [trig("summoned", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u", true, "Apply 8 Medic to an adjacent unit?"), st("$u", "medic", 8)])],
		"abilities": [abil("Discard a unit to gain +1 AP", [ch({"kind": "hand", "side": "self", "unit_card": true}, "h", false, "Discard a unit (Hand to Spent) to gain 1 AP."),
			{"op": "move", "target": "$h", "to": "spent"}, {"op": "ap", "n": 1}])]}
	t[93] = {"fusion": [{"stat_min": 20}, {"type": "Physical"}], "on": [trig("summoned", [st("self", "eternal")])]}
	t[94] = {"fusion": [{"has_type": true}, {"same_type_as": 0}], "on": [trig("summoned", [{"op": "mirrorflesh"}]),
		trig("destroyed", [ch({"kind": "unit", "type": "$snap_type"}, "u", false, "Destroy a unit with the same Type."), {"op": "destroy", "target": "$u"}])]}
	t[141] = {"fusion": [{"type": "Dark"}, {"type": "Light"}], "flags": ["type_summon_lock"],
		"abilities": [abil("Change Type (Physical/Light/Dark)", [{"op": "declare_type", "types": ["Physical", "Light", "Dark"], "as": "ty"}, {"op": "set_type", "target": "self", "var": "ty"}])],
		"on": [trig("destroyed", [ch({"kind": "unit", "type": "$snap_type"}, "u", true, "Make a unit with the same Type lose 12 ATK/DEF?"), {"op": "stat", "target": "$u", "atk": -12, "def": -12}])]}
	t[142] = {"fusion": [{"race": "Dragon"}, {"type": "Lightning"}], "on": [trig("summoned", [st("self", "pierce")]),
		trig("start_turn", [{"op": "stat", "target": "self", "atk": 4, "def": -4}], "own_turn", "start of turn")]}
	# 2026-11-03: On Summon 2 Blind to the opponent's units; the second ability is Freaky Funday's
	# switch (ATK/DEF of every unit now on the Field, and in card effects, until end of turn).
	t[143] = {"fusion": [{"stat_min": 20}, {"type": "Water"}], "on": [trig("summoned", [all_({"kind": "unit", "side": "opp"}), st("$all", "blind", 2)])],
		"abilities": [abil("Apply 1 Nimble to all your units", [all_({"kind": "unit", "side": "self"}), st("$all", "nimble")]),
			abil("Switch ATK/DEF of all units until end of turn", [{"op": "swap_all"}])]}
	t[144] = {"fusion": [{"race": "Warrior"}, {"type": "Earth"}], "flags": ["battle_immune_lightning"],
		"on": [trig("summoned", [ch({"kind": "unit"}, "u", true, "Apply 1 Cleanse to a unit?"), st("$u", "cleanse")]),
			trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "type": "Earth", "unit_card": true, "not_self": true}, "u", true, "Add an Earth unit from Spent or Draw to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])]}
	t[145] = {"fusion": [{"race": "Mage"}, {"type": "Fire"}], "on": [trig("summoned", [all_({"kind": "unit"}), st("$all", "burn", 10)])],
		"abilities": [abil("Lose 1 AP: Heal 10 HP", [hp("self", 10)], true, {"ap": 1})]}
	# Akiramari (2026-11-03): three Basic Unit materials. On Summon an optional search of any card
	# from Draw that costs 1 AP less this turn (as the Tag Teams). Once per turn a Basic Unit from
	# Draw into a free zone of yours adjacent to it ("beside"). +8 ATK/DEF per adjacent Basic Unit
	# of yours. The On Destroy summon is unchanged; the 5 Medic On Summon is gone.
	var akiramari_count := {"count": {"kind": "unit", "side": "self", "adjacent": true, "basic": true}, "mul": 8}
	t[146] = {"fusion": [{"category": ["basic_unit"]}, {"category": ["basic_unit"]}, {"category": ["basic_unit"]}],
		"on": [trig("summoned", [ch({"kind": "draw", "side": "self"}, "c", true, "Add a card from Draw to Hand? It costs 1 AP less this turn."),
				{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]),
			trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "basic": true}, "u", true, "Summon a Basic Unit from Spent or Draw to this zone?"), need("u"), {"op": "summon", "target": "$u", "place": "orig", "stance": "choose"}])],
		"abilities": [abil("Summon a Basic Unit from Draw to an adjacent zone", [ch({"kind": "draw", "side": "self", "basic": true}, "u", false, "Summon a Basic Unit from Draw to a zone adjacent to Akiramari."),
			{"op": "summon", "target": "$u", "place": "beside", "stance": "choose"}])],
		"aura": [{"to": "self", "atk": akiramari_count, "def": akiramari_count}]}
	# Demented Apparition (2026-11-03 ruling): an opponent's unit that can attack it cannot attack
	# other units ("taunt", BattleOps.attack_targets); direct attacks are not restricted.
	t[147] = {"fusion": [{"stat_min": 20}, {"type": "Dark"}], "flags": ["taunt"],
		"on": [trig("summoned", [all_({"kind": "unit", "side": "opp", "unprotected": true}), st("$all", "paralyse", 2)]),
			trig("start_turn", [all_({"kind": "unit", "side": "opp"}), {"op": "stat", "target": "$all", "def": -8}], "own_turn", "start of turn"),
			trig("destroyed", [all_({"kind": "unit"}), {"op": "stance", "target": "$all"}])]}
	t[181] = {"fusion": [{"race": "Warrior"}, {"type": "Fire"}], "on": [trig("summoned", [st("self", "pierce", 2)]), trig("destroyed", [hp("self", -12)])],
		"abilities": [abil("Exhaust the unit this protects: +1 Eternal and +1 AP", [ch({"kind": "unit", "side": "self", "protected_by_src": true}, "u", false, "Exhaust the unit this unit is protecting."),
			{"op": "move", "target": "$u", "to": "exhaust"}, st("self", "eternal"), {"op": "ap", "n": 1}])]}
	t[181]["abilities"][0]["cond"] = {"protecting": true}
	# Ultimate Dragon (2026-11-03): ?/?, the combined ATK/DEF of the units Tributed for its Fusion
	# Summon (as Mirrorflesh 94; its Type stays none).
	t[151] = {"fusion": [{"race": "Dragon"}, {"race": "Dragon"}, {"race": "Dragon"}], "abilities": [abil("Apply 10 Burn, 4 Poison or 1 Curse to a unit", [ch({"kind": "unit"}, "u"),
		{"op": "mode", "options": [{"label": "10 Burn", "ops": [st("$u", "burn", 10)]}, {"label": "4 Poison", "ops": [st("$u", "poison", 4)]}, {"label": "1 Curse", "ops": [st("$u", "curse")]}]}])],
		"on": [trig("summoned", [{"op": "mirrorflesh", "keep_type": true}]),
			trig("destroyed", [yes("Double all Debuffs on the Field?"), {"op": "double_debuffs", "side": "any"}])]}
	# Necro, the Loathsome (2026-10-18). On Summon it takes a copy of every Debuff on the other units
	# (a copied Debilitate suppresses its own effects too). The ability doubles its Debuffs, then
	# applies those doubled stacks to a chosen opponent's unit.
	# 2026-11-03 materials: Monster Unit + Dark Unit.
	t[188] = {"fusion": [{"race": "Monster"}, {"type": "Dark"}], "on": [trig("summoned", [{"op": "copy_all_debuffs"}])],
		"abilities": [abil("Double this unit's Debuffs and give them to an opponent's unit", [ch({"kind": "unit", "side": "opp"}, "u", false, "Choose an opponent's unit to receive this unit's doubled Debuffs."),
			{"op": "spread_debuffs", "target": "$u"}])]}
	t[188]["abilities"][0]["cond"] = {"self_has_debuff": true}
	# Owlbear Druid (new 2026-11-03). The Race change is one-shot, like Chaos Witch's (13) Type change:
	# this unit, then every unit of its controller, take the declared Race (any Race of the card pool)
	# and keep it until changed again. While it is on the Field, the opponent's units with its current
	# Race cannot attack (BattleOps._cannot_attack_reason).
	t[189] = {"fusion": [{"race": "Beast"}, {"type": "Physical"}], "flags": ["same_race_no_attack"],
		"abilities": [abil("Change this unit's Race: all your units become it", [{"op": "declare_type", "types": CardDB.RACES, "as": "race", "prompt": "Choose a Race."},
			{"op": "set_race", "target": "self", "var": "race"}, all_({"kind": "unit", "side": "self", "not_self": true}), {"op": "set_race", "target": "$all", "var": "race"}])]}
	# Snow Tiger Paladin (new 2026-11-03). Owner ruling "Both at turn start": at the start of its
	# controller's turn, Protecting a Unit (a unit behind it) makes their Traps cost 1 AP less, and
	# Protected by a Unit (a unit in front of it) makes their Traps on the Field indestructible, each
	# until the start of their next turn (GameCore.turn_effect_active).
	t[190] = {"fusion": [{"race": "Beast"}, {"type": "Light"}],
		"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true, "cost_max": 2}, "u", true, "Summon a 2-cost or lower unit from Draw into this column?"),
				need("u"), {"op": "summon", "target": "$u", "place": "column", "stance": "choose"}]),
			trig("start_turn", [{"op": "if", "cond": {"protecting": true}, "then": [{"op": "turn_effect", "effect": GameCore.TFX_TRAPS_COST_LESS, "text": "Traps cost 1 AP less"}]},
				{"op": "if", "cond": {"protected": true}, "then": [{"op": "turn_effect", "effect": GameCore.TFX_TRAPS_INDESTRUCTIBLE, "text": "Traps cannot be Destroyed"}]}], "own_turn", "start of turn")]}
	# Only triggers when it is Protecting or Protected by a unit (neither: nothing to do).
	t[190]["on"][1]["filter"] = {"not": {"protecting": false, "protected": false}}

	# ------------------------------------------------------------ Ritual
	t[98] = {"on": [trig("summoned", [st("self", "burn", 8)]), trig("destroyed", [by_unit_st("burn", 4)])],
		"abilities": [abil("Apply Reveal to a Spell/Trap", [ch({"kind": "facedown"}, "u"), st("$u", "reveal")])]}
	t[62] = {"on": [trig("summoned", [st("self", "curse")]), trig("destroyed", [ch({"kind": "unit"}, "u", true, "Apply 1 Curse to a unit?"), st("$u", "curse")])],
		"abilities": [abil("Apply 1 Debilitate to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "debilitate")])]}
	# The Last Foundation (2026-11-03): the Reveal is optional (asked only while a Spell/Trap is on
	# the Field); a once-per-turn Freaky Funday switch; On Destroy its controller exhausts a card of
	# their own choice from their own Spent (mandatory while it holds another card).
	t[63] = {"on": [trig("summoned", [{"op": "confirm", "prompt": "Apply Reveal to all Spells/Traps?", "cond": {"count": {"kind": "backrow", "spell_trap": true}, "min": 1}},
			all_({"kind": "backrow", "spell_trap": true}), st("$all", "reveal")]),
		trig("end_turn", [st("self", "eternal")], "own_turn", "end of turn"),
		trig("destroyed", [ch({"kind": "spent", "side": "self", "not_self": true}, "u", false, "Exhaust a card from your Spent."), {"op": "move", "target": "$u", "to": "exhaust"}])],
		"abilities": [abil("Switch ATK/DEF of all units until end of turn", [{"op": "swap_all"}])]}
	t[64] = {"aura": [{"to": "self", "atk": {"pile": "exhaust", "mul": 4}, "def": {"pile": "exhaust", "mul": 4}}],
		"on": [trig("destroyed", [ch({"kind": "exhaust", "side": "self"}, "u", true, "Move a card from Exhaust to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}
	t[66] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "self", "adjacent": true}, "u", false, "Apply 1 Eternal to an adjacent unit."), st("$u", "eternal")])],
		"abilities": [abil("Draw a card, then discard a card", [{"op": "draw", "n": 1}, ch({"kind": "hand", "side": "self"}, "h", false, "Discard a card: send it from Hand to Spent."), {"op": "move", "target": "$h", "to": "spent"}])]}
	t[95] = {"on": [trig("summoned", [ch({"kind": "unit", "side": "opp", "unprotected": true, "column": true}, "u", false, "Choose an opponent's unprotected unit in this column."),
		need("u"), st("$u", "paralyse", 2), {"op": "copy_stats", "from": "$u", "type": true, "art": true}]),
		trig("destroyed", [{"op": "double_debuffs", "side": "opp"}])]}
	# The Creeping Null (2026-11-03): an optional Rune On Summon; On Destroy its controller destroys a
	# unit with at least 1 Rune, either side (mandatory while one exists).
	t[65] = {"on": [trig("summoned", [ch({"kind": "unit"}, "u", true, "Apply 1 Rune to a unit?"), st("$u", "rune")]),
			trig("destroyed", [ch({"kind": "unit", "has_status": "rune"}, "u", false, "Destroy a unit with a Rune."), {"op": "destroy", "target": "$u"}])],
		"abilities": [abil("Apply 1 Debilitate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "debilitate")])]}
	t[97] = {"on": [trig("summoned", [st("self", "cleanse", 3)]), trig("destroyed", [ch({"kind": "unit", "race": "Warrior"}, "u", true, "Apply 2 Rune to a Warrior unit?"), st("$u", "rune", 2)])],
		"abilities": [abil("Apply 1 Infiltrate to this unit", [st("self", "infiltrate")])],
		"aura": [{"to": "self", "atk": 20, "cond": {"hp_lower": true}}]}
	# Yamata (2026-11-03): the start-of-turn 6 Damage became a once-per-turn 6 Poison in its column.
	t[183] = {"on": [trig("summoned", [st("self", "eternal", 8)]),
		trig("destroyed", [ch({"kind": "spent_or_draw", "side": "self", "category": ["power"]}, "u", true, "Add a Power from Spent or Draw to Hand?"), {"op": "move", "target": "$u", "to": "hand"}])],
		"abilities": [abil("Apply 6 Poison to a unit in this column", [ch({"kind": "unit", "column": true}, "u"), st("$u", "poison", 6)])]}
	t[96] = {"on": [trig("summoned", [{"op": "roma", "per": 10}])],
		"abilities": [abil("Take 10 Damage: destroy a unit with lower ATK", [ch({"kind": "unit", "atk_below_self": true}, "u"), {"op": "destroy", "target": "$u"}], true, {"hp": 10})]}
	# Bronze Salaman (2026-10-18): an optional Fusion Summon from the Field as it lands; when it is
	# sacrificed or tributed (undebilitated), an optional Retain on a card in your Hand.
	t[186] = {"on": [trig("summoned", [{"op": "fusion_possible", "sources": ["field"]}, yes("Fusion Summon using units you control?"), {"op": "fusion", "sources": ["field"]}]),
		trig("tribute_or_sacrifice", [ch({"kind": "hand", "side": "self"}, "h", true, "Apply 1 Retain to a card in your Hand?"), st("$h", "retain")])]}

	# ------------------------------------------------------------ Arcane
	# Grandmother Kaya (2026-11-03): only while the opponent has more cards on the Field than you.
	t[170] = {"on": [trig("summoned", [{"op": "if", "cond": {"opp_more_cards": true}, "then": [ch({"kind": "hand", "side": "self"}, "h", true, "Discard a card (Hand to Spent) to gain 1 AP?"),
			need("h"), {"op": "move", "target": "$h", "to": "spent"}, {"op": "ap", "n": 1}]}]),
		trig("destroyed", [{"op": "require", "cond": {"count": {"kind": "spent", "side": "self", "not_self": true}, "min": 1}},
			yes("Take 10 Damage to add a card from Spent to Hand?"), hp("self", -10), ch({"kind": "spent", "side": "self", "not_self": true}, "u", false, "Add a card from Spent to Hand."), {"op": "move", "target": "$u", "to": "hand"}])]}
	t[170]["on"][0]["filter"] = {"opp_more_cards": true}   # no trigger at all while the condition fails
	t[171] = {"flags": ["direct_attack", "exhaust_on_destroy"], "on": [trig("start_turn", [{"op": "stat", "target": "self", "atk": 6}], "own_turn", "start of turn")]}
	t[172] = {"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true, "race": "Beast"}, "c", true, "Add a Beast unit from Draw to Hand? It costs 1 AP less this turn."),
			{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])],
		"abilities": [abil("Destroy a unit with a Rune", [ch({"kind": "unit", "has_status": "rune"}, "u"), {"op": "destroy", "target": "$u"}])]}
	# Thunderclap Dragon (2026-11-03): "..., then Exhaust this Unit" on its On Destroy: it goes to
	# Exhaust instead of Spent when destroyed undebilitated (as Flying Sandworm 171).
	t[173] = {"flags": ["exhaust_on_destroy"], "on": [trig("summoned", [hp("opp", {"count": {"kind": "unit", "side": "opp"}, "mul": -4})]), trig("destroyed", [all_({"kind": "unit"}), st("$all", "paralyse")])]}
	t[174] = {"on": [trig("tribute_or_sacrifice", [{"op": "ap", "n": 1}])]}
	# 2026-10-18: the On Destroy DEF gain is no longer optional.
	t[175] = {"on": [trig("summoned", [all_({"kind": "unit", "side": "opp"}), {"op": "stance", "target": "$all"}]),
		trig("destroyed", [all_({"kind": "unit", "side": "self"}), {"op": "stat", "target": "$all", "def": 10}])],
		"abilities": [abil("Apply 1 Debilitate to a unit", [ch({"kind": "unit"}, "u"), st("$u", "debilitate")])]}
	# 2026-10-18: DEF is effect-determined too (the combined DEF of the other Water units).
	# 2026-11-03: once per turn a Water unit from your Spent into this column; "Adjacent Units cannot
	# declare an Attack" is Zorath's (22) lock on its controller's adjacent units. The Medic is gone.
	t[176] = {"flags": ["adjacent_no_attack"], "on": [trig("summoned", [{"op": "set_base", "target": "self", "atk": {"sum_atk": {"kind": "unit", "type": "Water", "not_self": true}},
			"def": {"sum_def": {"kind": "unit", "type": "Water", "not_self": true}}}])],
		"abilities": [abil("Summon a Water unit from Spent in this column", [ch({"kind": "spent", "side": "self", "unit_card": true, "type": "Water"}, "u", false, "Summon a Water unit from your Spent into this column."),
			{"op": "summon", "target": "$u", "place": "column", "stance": "choose"}])]}
	# Card-specific Exhaust recovery (decisions.md): optional, your own Exhaust, current ordinary
	# cost 1 or lower (Extra Deck cards have no ordinary cost and never qualify).
	t[177] = {"flags": ["no_battle_damage"], "aura": [{"to": "self", "atk": 20, "cond": {"my_turn": true}}],
		"on": [trig("destroyed", [ch({"kind": "exhaust", "side": "self", "cost_max": 1}, "u", true, "Move a 1-cost or lower card from your Exhaust to Draw?"), {"op": "move", "target": "$u", "to": "draw"}])]}
	# Fence of the Marked Claw (2026-10-18): an optional Monster search with -1 AP this turn; whenever
	# a Spell is activated (either player's), an optional Rune on any unit.
	t[187] = {"on": [trig("summoned", [ch({"kind": "draw", "side": "self", "unit_card": true, "race": "Monster"}, "c", true, "Add a Monster unit from Draw to Hand? It costs 1 AP less this turn."),
			{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}]),
		trig("spell_activated", [ch({"kind": "unit"}, "u", true, "A Spell was activated: apply 1 Rune to a unit?"), st("$u", "rune")], "any", "a Spell was activated")]}
	# Drako, Councillor of The Order (2026-10-18): an optional Power search (Draw or Spent) with -1 AP
	# this turn; once per turn destroy any Power, gaining 1 AP when it was your own.
	t[185] = {"on": [trig("summoned", [ch({"kind": "spent_or_draw", "side": "self", "category": ["power"]}, "c", true, "Add a Power from Draw or Spent to Hand? It costs 1 AP less this turn."),
			{"op": "move", "target": "$c", "to": "hand"}, {"op": "cost_turn", "target": "$c", "n": -1}])],
		"abilities": [abil("Destroy a Power (+1 AP if it is yours)", [ch({"kind": "power"}, "u", false, "Destroy a Power. If it is yours, gain 1 AP."),
			{"op": "destroy", "target": "$u"}, {"op": "if", "cond": {"var_owned": "u"}, "then": [{"op": "ap", "n": 1}]}])]}

	return t
